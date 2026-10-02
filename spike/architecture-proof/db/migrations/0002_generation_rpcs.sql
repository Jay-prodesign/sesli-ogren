-- Sesli Öğren / Learning App — Architecture Proof RPCs (LA-0013 / LA-0014 / LA-0015).
--
-- Clients never write tables directly. User RPCs run as SECURITY DEFINER with an explicit
-- owner check on every referenced row; foreign or missing rows raise the same non-revealing
-- error. Worker RPCs are granted to service_role only and are guarded by a lease token, so a
-- stale worker cannot mutate the current execution.
-- Semantics adapted from MoonlighC/ai-study-buddy@317e21d migration 010 (MIT): attempt
-- dispatch_state / budget_effect lineage, lease tokens, "ambiguous dispatch is never
-- automatically re-sent". Re-keyed to canonical generation_jobs / generation_attempts.

\set ON_ERROR_STOP on

create or replace function public.la_require_user() returns uuid
language plpgsql stable set search_path = '' as $$
declare v uuid := auth.uid();
begin
  if v is null then raise exception 'not_authenticated' using errcode = '28000'; end if;
  if not exists (select 1 from public.accounts a where a.id = v and a.status = 'active') then
    raise exception 'account_inactive' using errcode = '28000';
  end if;
  return v;
end;
$$;

-- Deterministic contract identifier for the summary task; bumping it creates a new fingerprint.
create or replace function public.la_summary_contract() returns text
language sql immutable as $$ select 'summary.v1'::text $$;

-- ---------------------------------------------------------------------------
-- User RPC: create a pasted-text Material with SourceAsset + ExtractedContent
-- ---------------------------------------------------------------------------
create or replace function public.create_text_material(p_title text, p_text text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := public.la_require_user();
  v_material uuid;
  v_source uuid;
  v_text text := btrim(coalesce(p_text, ''));
begin
  if length(v_text) = 0 then raise exception 'empty_source' using errcode = '22023'; end if;
  if length(v_text) > 200000 then raise exception 'source_too_large' using errcode = '22023'; end if;

  insert into public.materials (account_id, title, material_type)
  values (v_user, btrim(p_title), 'text') returning id into v_material;

  insert into public.source_assets (material_id, account_id, source_type, inline_text, content_hash,
                                    mime_type, byte_size, extraction_status)
  values (v_material, v_user, 'pasted_text', p_text, public.la_sha256(p_text), 'text/plain',
          octet_length(p_text), 'extracted')
  returning id into v_source;

  -- Pasted text needs no OCR/parsing: extraction is the identity normalisation (whitespace trim).
  insert into public.extracted_contents (source_asset_id, account_id, method, method_version,
                                         normalized_text, source_content_hash)
  values (v_source, v_user, 'pasted_text_identity', '1', v_text, public.la_sha256(p_text));

  return v_material;
end;
$$;

-- ---------------------------------------------------------------------------
-- User RPC: request a Summary (idempotent)
-- ---------------------------------------------------------------------------
create or replace function public.request_summary(p_material_id uuid, p_idempotency_key text,
                                                  p_regenerate boolean default false)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := public.la_require_user();
  v_source uuid;
  v_extracted uuid;
  v_hash text;
  v_fp text;
  v_job public.generation_jobs%rowtype;
  v_limit integer;
  v_used integer;
begin
  -- Same key replays the original answer (only for the same caller + same material).
  select * into v_job from public.generation_jobs
   where account_id = v_user and idempotency_key = p_idempotency_key;
  if found then
    if v_job.material_id <> p_material_id then
      raise exception 'idempotency_key_reused' using errcode = '22023';
    end if;
    return v_job.id;
  end if;

  select s.id, e.id, e.source_content_hash into v_source, v_extracted, v_hash
  from public.materials m
  join public.source_assets s on s.material_id = m.id and s.revoked_at is null
  join public.extracted_contents e on e.source_asset_id = s.id and e.invalidated_at is null
  where m.id = p_material_id and m.account_id = v_user and m.lifecycle_status = 'active'
  order by s.source_version desc, e.created_at desc
  limit 1;
  if v_source is null then raise exception 'material_not_found' using errcode = 'P0002'; end if;

  v_fp := public.la_sha256(concat_ws('|', p_material_id::text, v_extracted::text, v_hash,
                                     'SUMMARY', public.la_summary_contract()));

  if not p_regenerate then
    -- An ordinary repeat request (even with a new key) reuses the live job: no duplicate billable output.
    select * into v_job from public.generation_jobs
     where account_id = v_user and request_fingerprint = v_fp and intent = 'initial'
       and state not in ('FAILED_FINAL', 'CANCELLED');
    if found then return v_job.id; end if;
  end if;

  -- Server-authoritative quota check (UsageEvent/QuotaLedger seam).
  select coalesce((e.limits ->> 'summary_daily')::integer, 0) into v_limit
  from public.entitlements e where e.account_id = v_user and e.status = 'active';
  select coalesce(q.consumed, 0) into v_used from public.quota_ledger q
   where q.account_id = v_user and q.period_start = current_date and q.capability = 'summary';
  if coalesce(v_used, 0) + (select count(*) from public.generation_jobs j
                             where j.account_id = v_user and j.state in ('QUEUED', 'PROCESSING')
                               and j.created_at::date = current_date)
     >= coalesce(v_limit, 0) then
    raise exception 'quota_exceeded' using errcode = 'P0001';
  end if;

  insert into public.generation_jobs (account_id, material_id, capability, target_artifact_type,
       source_asset_id, extracted_content_id, generation_contract, idempotency_key,
       request_fingerprint, intent)
  values (v_user, p_material_id, 'structured_generation', 'SUMMARY', v_source, v_extracted,
          public.la_summary_contract(), p_idempotency_key, v_fp,
          case when p_regenerate then 'regenerate' else 'initial' end)
  returning * into v_job;

  update public.materials set processing_state = 'queued' where id = p_material_id;
  return v_job.id;
end;
$$;

-- ---------------------------------------------------------------------------
-- User RPC: explicit retry of a retryable failure (never of an ambiguous dispatch)
-- ---------------------------------------------------------------------------
create or replace function public.retry_generation_job(p_job_id uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := public.la_require_user();
  v_job public.generation_jobs%rowtype;
  v_dispatch text;
begin
  select * into v_job from public.generation_jobs where id = p_job_id and account_id = v_user for update;
  if not found then raise exception 'job_not_found' using errcode = 'P0002'; end if;
  if v_job.state <> 'FAILED_RETRYABLE' then raise exception 'job_not_retryable' using errcode = 'P0001'; end if;
  select a.dispatch_state into v_dispatch from public.generation_attempts a where a.id = v_job.active_attempt_id;
  if v_dispatch = 'dispatch_unknown' then
    raise exception 'reconciliation_required' using errcode = 'P0001';
  end if;
  update public.generation_jobs set state = 'QUEUED', failure_class = null where id = p_job_id;
  update public.materials set processing_state = 'queued' where id = v_job.material_id;
  return 'QUEUED';
end;
$$;

-- ---------------------------------------------------------------------------
-- User RPC: delete a Material (revokes source, invalidates derived state)
-- ---------------------------------------------------------------------------
create or replace function public.delete_material(p_material_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_user uuid := public.la_require_user();
begin
  update public.materials set lifecycle_status = 'deleted', deleted_at = now()
   where id = p_material_id and account_id = v_user and lifecycle_status = 'active';
  if not found then raise exception 'material_not_found' using errcode = 'P0002'; end if;
  update public.source_assets set revoked_at = now() where material_id = p_material_id and revoked_at is null;
  update public.extracted_contents e set invalidated_at = now()
    from public.source_assets s where e.source_asset_id = s.id and s.material_id = p_material_id
     and e.invalidated_at is null;
  update public.artifacts set status = 'deleted' where material_id = p_material_id;
  update public.generation_jobs set state = 'CANCELLED', lease_token = null, lease_expires_at = null
   where material_id = p_material_id and state in ('QUEUED', 'PROCESSING', 'FAILED_RETRYABLE');
end;
$$;

-- ---------------------------------------------------------------------------
-- Worker RPC: claim the next runnable job and open a new attempt
-- ---------------------------------------------------------------------------
create or replace function public.claim_generation_job(p_lease_seconds integer default 120)
returns table (job_id uuid, attempt_id uuid, lease_token uuid, attempt_idempotency_key text,
               generation_contract text, normalized_text text, source_asset_id uuid,
               extracted_content_id uuid)
language plpgsql security definer set search_path = '' as $$
declare
  v_job public.generation_jobs%rowtype;
  v_prev public.generation_attempts%rowtype;
  v_attempt uuid;
  v_token uuid := gen_random_uuid();
begin
  -- Expired leases: safe to re-run only if the provider was never called.
  for v_job in
    select * from public.generation_jobs
     where state = 'PROCESSING' and lease_expires_at < now() for update skip locked
  loop
    select * into v_prev from public.generation_attempts where id = v_job.active_attempt_id;
    if v_prev.dispatch_state = 'not_dispatched' then
      update public.generation_attempts set status = 'abandoned', budget_effect = 'released',
             failure_class = 'lease_expired', completed_at = now() where id = v_prev.id;
      update public.generation_jobs set state = 'QUEUED', lease_token = null, lease_expires_at = null
       where id = v_job.id;
    else
      -- Dispatched or unknown: never auto-resend a potentially billable call; require reconciliation.
      update public.generation_attempts set dispatch_state = 'dispatch_unknown', status = 'failed',
             failure_class = 'lease_expired_after_dispatch', completed_at = now() where id = v_prev.id;
      update public.generation_jobs set state = 'FAILED_RETRYABLE', failure_class = 'reconciliation_required',
             lease_token = null, lease_expires_at = null where id = v_job.id;
      update public.materials set processing_state = 'failed' where id = v_job.material_id;
    end if;
  end loop;

  select * into v_job from public.generation_jobs
   where state = 'QUEUED' order by created_at for update skip locked limit 1;
  if not found then return; end if;
  if v_job.attempt_count >= v_job.max_attempts then
    update public.generation_jobs set state = 'FAILED_FINAL', failure_class = 'max_attempts_exhausted',
           completed_at = now() where id = v_job.id;
    update public.materials set processing_state = 'failed' where id = v_job.material_id;
    return;
  end if;

  insert into public.generation_attempts (job_id, account_id, attempt_number, predecessor_attempt_id,
                                          attempt_idempotency_key, adapter_ref)
  values (v_job.id, v_job.account_id, v_job.attempt_count + 1, v_job.active_attempt_id,
          v_job.id::text || ':' || (v_job.attempt_count + 1)::text, 'unassigned')
  returning id into v_attempt;

  update public.generation_jobs
     set state = 'PROCESSING', active_attempt_id = v_attempt, attempt_count = v_job.attempt_count + 1,
         lease_token = v_token, lease_expires_at = now() + make_interval(secs => p_lease_seconds),
         started_at = coalesce(started_at, now())
   where id = v_job.id;
  update public.materials set processing_state = 'processing' where id = v_job.material_id;

  return query
  select v_job.id, v_attempt, v_token, v_job.id::text || ':' || (v_job.attempt_count + 1)::text,
         v_job.generation_contract, e.normalized_text, v_job.source_asset_id, v_job.extracted_content_id
    from public.extracted_contents e where e.id = v_job.extracted_content_id;
end;
$$;

create or replace function public.la_current_attempt(p_attempt_id uuid, p_lease_token uuid)
returns public.generation_jobs language plpgsql set search_path = '' as $$
declare v_job public.generation_jobs%rowtype;
begin
  select j.* into v_job from public.generation_jobs j
   where j.active_attempt_id = p_attempt_id and j.lease_token = p_lease_token
     and j.state = 'PROCESSING' and j.lease_expires_at >= now()
   for update;
  if not found then raise exception 'stale_lease' using errcode = 'P0001'; end if;
  return v_job;
end;
$$;

-- Worker RPC: record that the provider call is about to be sent (ambiguity starts here).
create or replace function public.mark_attempt_dispatched(p_attempt_id uuid, p_lease_token uuid,
                                                          p_adapter_ref text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform public.la_current_attempt(p_attempt_id, p_lease_token);
  update public.generation_attempts set dispatch_state = 'dispatched', adapter_ref = p_adapter_ref
   where id = p_attempt_id and dispatch_state = 'not_dispatched';
  if not found then raise exception 'invalid_dispatch_transition' using errcode = 'P0001'; end if;
end;
$$;

create or replace function public.la_valid_summary_content(p jsonb) returns boolean
language sql immutable as $$
  select jsonb_typeof(p) = 'object'
     and jsonb_typeof(p -> 'summary') = 'string' and length(btrim(p ->> 'summary')) between 1 and 20000
     and jsonb_typeof(p -> 'key_points') = 'array' and jsonb_array_length(p -> 'key_points') <= 30
     and (p ? 'language') and jsonb_typeof(p -> 'language') = 'string'
$$;

create or replace function public.la_finalize_success(p_job public.generation_jobs, p_attempt_id uuid,
    p_content jsonb, p_provider_ref text, p_usage jsonb, p_latency_ms integer)
returns uuid language plpgsql set search_path = '' as $$
declare
  v_artifact uuid;
  v_prev uuid;
  v_version integer;
begin
  if not public.la_valid_summary_content(p_content) then
    raise exception 'invalid_summary_content' using errcode = '22023';
  end if;
  select id into v_prev from public.artifacts
   where material_id = p_job.material_id and artifact_type = 'SUMMARY' and status = 'available'
   order by version desc limit 1;
  select coalesce(max(version), 0) + 1 into v_version from public.artifacts
   where material_id = p_job.material_id and artifact_type = 'SUMMARY';

  insert into public.artifacts (account_id, material_id, artifact_type, version, generation_job_id,
       generation_attempt_id, content, generation_settings, supersedes_artifact_id)
  values (p_job.account_id, p_job.material_id, 'SUMMARY', v_version, p_job.id, p_attempt_id, p_content,
          jsonb_build_object('contract', p_job.generation_contract,
                             'adapter', (select adapter_ref from public.generation_attempts where id = p_attempt_id)),
          v_prev)
  returning id into v_artifact;
  if v_prev is not null then update public.artifacts set status = 'superseded' where id = v_prev; end if;

  insert into public.evidence_refs (account_id, artifact_id, source_asset_id, extracted_content_id, anchor)
  values (p_job.account_id, v_artifact, p_job.source_asset_id, p_job.extracted_content_id,
          jsonb_build_object('scope', 'whole_source'));

  update public.generation_attempts
     set status = 'succeeded', dispatch_state = 'response_known', budget_effect = 'consumed',
         provider_execution_ref = p_provider_ref, latency_ms = p_latency_ms, completed_at = now()
   where id = p_attempt_id;

  insert into public.usage_events (account_id, capability, generation_job_id, generation_attempt_id,
       quantity, unit, cost_class, estimated_cost_usd, idempotency_key)
  values (p_job.account_id, 'summary', p_job.id, p_attempt_id,
          coalesce((p_usage ->> 'total_tokens')::numeric, 0), 'tokens',
          coalesce(p_usage ->> 'cost_class', 'unknown'), (p_usage ->> 'estimated_cost_usd')::numeric,
          'usage:' || p_job.id::text)          -- one billable usage per job, whatever the attempt count
  on conflict (idempotency_key) do nothing;

  insert into public.quota_ledger (account_id, period_start, capability, consumed)
  values (p_job.account_id, current_date, 'summary', 1)
  on conflict (account_id, period_start, capability) do update set consumed = quota_ledger.consumed + 1;

  update public.generation_jobs set state = 'SUCCEEDED', failure_class = null, completed_at = now(),
         lease_token = null, lease_expires_at = null where id = p_job.id;
  update public.materials set processing_state = 'ready' where id = p_job.material_id;
  return v_artifact;
end;
$$;

-- Worker RPC: complete the current attempt with validated structured output.
create or replace function public.complete_generation_attempt(p_attempt_id uuid, p_lease_token uuid,
    p_content jsonb, p_provider_ref text, p_usage jsonb, p_latency_ms integer)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_job public.generation_jobs%rowtype;
begin
  v_job := public.la_current_attempt(p_attempt_id, p_lease_token);
  if (select dispatch_state from public.generation_attempts where id = p_attempt_id) <> 'dispatched' then
    raise exception 'invalid_dispatch_transition' using errcode = 'P0001';
  end if;
  return public.la_finalize_success(v_job, p_attempt_id, p_content, p_provider_ref, p_usage, p_latency_ms);
end;
$$;

-- Worker RPC: record a failure. 'ambiguous' = the provider may have executed (timeout after send).
create or replace function public.fail_generation_attempt(p_attempt_id uuid, p_lease_token uuid,
    p_failure_class text, p_provider_ref text default null)
returns text language plpgsql security definer set search_path = '' as $$
declare
  v_job public.generation_jobs%rowtype;
  v_state text;
begin
  if p_failure_class not in ('retryable', 'final', 'ambiguous') then
    raise exception 'invalid_failure_class' using errcode = '22023';
  end if;
  v_job := public.la_current_attempt(p_attempt_id, p_lease_token);
  update public.generation_attempts
     set status = 'failed', failure_class = p_failure_class, provider_execution_ref = p_provider_ref,
         completed_at = now(),
         dispatch_state = case when p_failure_class = 'ambiguous' then 'dispatch_unknown'
                               when dispatch_state = 'dispatched' then 'response_known'
                               else dispatch_state end,
         budget_effect = case when p_failure_class = 'ambiguous' then 'reserved' else 'released' end
   where id = p_attempt_id;
  v_state := case
    when p_failure_class = 'final' then 'FAILED_FINAL'
    when p_failure_class = 'ambiguous' then 'FAILED_RETRYABLE'
    when v_job.attempt_count >= v_job.max_attempts then 'FAILED_FINAL'
    else 'FAILED_RETRYABLE' end;
  update public.generation_jobs
     set state = v_state, lease_token = null, lease_expires_at = null,
         failure_class = case when p_failure_class = 'ambiguous' then 'reconciliation_required' else p_failure_class end,
         completed_at = case when v_state = 'FAILED_FINAL' then now() end
   where id = v_job.id;
  update public.materials set processing_state = 'failed' where id = v_job.material_id;
  return v_state;
end;
$$;

-- Worker RPC: resolve an ambiguous attempt from the provider's own record (no re-send).
create or replace function public.reconcile_generation_attempt(p_attempt_id uuid, p_provider_completed boolean,
    p_content jsonb default null, p_provider_ref text default null, p_usage jsonb default '{}'::jsonb)
returns text language plpgsql security definer set search_path = '' as $$
declare
  v_job public.generation_jobs%rowtype;
begin
  select j.* into v_job from public.generation_jobs j
    join public.generation_attempts a on a.id = j.active_attempt_id
   where a.id = p_attempt_id and a.dispatch_state = 'dispatch_unknown'
     and j.state = 'FAILED_RETRYABLE' and j.failure_class = 'reconciliation_required'
   for update of j;
  if not found then raise exception 'nothing_to_reconcile' using errcode = 'P0001'; end if;
  if p_provider_completed then
    perform public.la_finalize_success(v_job, p_attempt_id, p_content, p_provider_ref, p_usage, null);
    return 'SUCCEEDED';
  end if;
  update public.generation_attempts set dispatch_state = 'response_known', budget_effect = 'released'
   where id = p_attempt_id;
  update public.generation_jobs set state = 'QUEUED', failure_class = null where id = v_job.id;
  update public.materials set processing_state = 'queued' where id = v_job.material_id;
  return 'QUEUED';
end;
$$;

-- ---------------------------------------------------------------------------
-- Function privileges: users get user RPCs; workers (service_role) get worker RPCs only.
-- ---------------------------------------------------------------------------
revoke all on all functions in schema public from public, anon, authenticated;
grant execute on function public.create_text_material(text, text),
                          public.request_summary(uuid, text, boolean),
                          public.retry_generation_job(uuid),
                          public.delete_material(uuid)
  to authenticated;
grant execute on function public.claim_generation_job(integer),
                          public.mark_attempt_dispatched(uuid, uuid, text),
                          public.complete_generation_attempt(uuid, uuid, jsonb, text, jsonb, integer),
                          public.fail_generation_attempt(uuid, uuid, text, text),
                          public.reconcile_generation_attempt(uuid, boolean, jsonb, text, jsonb)
  to service_role;
-- helpers used inside RLS/definers
grant execute on function public.la_require_user(), public.la_sha256(text), public.la_summary_contract(),
                          public.la_valid_summary_content(jsonb)
  to authenticated, service_role;
