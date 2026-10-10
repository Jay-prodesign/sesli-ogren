\set ON_ERROR_STOP on

-- V0 Focus mode: source-grounded free-question help on the existing durable
-- generation authority. The learner question is bounded and retained only
-- while the job may need a safe retry; successful completion keeps only its
-- digest and help kind.
alter table public.generation_jobs
  add column if not exists request_context jsonb not null default '{}'::jsonb;

alter table public.generation_jobs
  drop constraint if exists generation_jobs_request_context_check;
alter table public.generation_jobs
  add constraint generation_jobs_request_context_check
  check (
    jsonb_typeof(request_context) = 'object'
    and octet_length(request_context::text) <= 4096
  );

alter table public.generation_jobs
  drop constraint if exists generation_jobs_target_artifact_type_check;
alter table public.generation_jobs
  add constraint generation_jobs_target_artifact_type_check
  check (target_artifact_type in ('SUMMARY', 'EXPLAIN', 'FOCUS_HELP'));

alter table public.artifacts
  drop constraint if exists artifacts_artifact_type_check;
alter table public.artifacts
  add constraint artifacts_artifact_type_check
  check (artifact_type in ('SUMMARY', 'EXPLAIN', 'FOCUS_HELP'));

alter table public.entitlements
  alter column limits
  set default '{"summary_daily":20,"explain_daily":20,"explain_back_daily":20,"focus_daily":20}'::jsonb;

update public.entitlements
set limits = limits || jsonb_build_object(
  'focus_daily',
  coalesce(
    (limits ->> 'explain_daily')::integer,
    (limits ->> 'summary_daily')::integer,
    20
  )
)
where not (limits ? 'focus_daily');

create or replace function public.la_focus_contract()
returns text
language sql
immutable
set search_path = ''
as $$
  select 'focus.v1'::text
$$;

create or replace function public.request_focus_help(
  p_material_id uuid,
  p_source_content_hash text,
  p_question text,
  p_help_kind text,
  p_idempotency_key text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := public.la_require_user();
  v_question text := btrim(coalesce(p_question, ''));
  v_kind text := btrim(coalesce(p_help_kind, ''));
  v_question_digest text;
  v_source uuid;
  v_extracted uuid;
  v_hash text;
  v_fp text;
  v_job public.generation_jobs%rowtype;
  v_limit integer;
  v_used integer;
begin
  if length(v_question) < 2 or length(v_question) > 600 then
    raise exception 'invalid_focus_question' using errcode = '22023';
  end if;
  if v_kind not in ('hint', 'direct_explanation') then
    raise exception 'invalid_focus_help_kind' using errcode = '22023';
  end if;

  v_question_digest := public.la_sha256(v_question);

  select s.id, e.id, e.source_content_hash
    into v_source, v_extracted, v_hash
  from public.materials m
  join public.source_assets s
    on s.material_id = m.id
   and s.revoked_at is null
  join public.extracted_contents e
    on e.source_asset_id = s.id
   and e.invalidated_at is null
  where m.id = p_material_id
    and m.account_id = v_user
    and m.lifecycle_status = 'active'
  order by s.source_version desc, e.created_at desc
  limit 1;

  if v_source is null then
    raise exception 'material_not_found' using errcode = 'P0002';
  end if;
  if v_hash <> p_source_content_hash then
    raise exception 'stale_source' using errcode = 'P0001';
  end if;

  select *
    into v_job
  from public.generation_jobs
  where account_id = v_user
    and idempotency_key = p_idempotency_key;

  if found then
    if v_job.material_id <> p_material_id
       or v_job.generation_contract <> public.la_focus_contract()
       or coalesce(v_job.request_context ->> 'help_kind', '') <> v_kind
       or coalesce(
            v_job.request_context ->> 'question_digest',
            public.la_sha256(coalesce(v_job.request_context ->> 'question', ''))
          ) <> v_question_digest then
      raise exception 'idempotency_key_reused' using errcode = '22023';
    end if;
    return v_job.id;
  end if;

  v_fp := public.la_sha256(
    concat_ws(
      '|',
      p_material_id::text,
      v_extracted::text,
      v_hash,
      'FOCUS_HELP',
      public.la_focus_contract(),
      v_kind,
      v_question_digest
    )
  );

  select *
    into v_job
  from public.generation_jobs
  where account_id = v_user
    and request_fingerprint = v_fp
    and intent = 'initial'
    and state not in ('FAILED_FINAL', 'CANCELLED');

  if found then
    return v_job.id;
  end if;

  select coalesce(
           (e.limits ->> 'focus_daily')::integer,
           (e.limits ->> 'explain_daily')::integer,
           (e.limits ->> 'summary_daily')::integer,
           0
         )
    into v_limit
  from public.entitlements e
  where e.account_id = v_user
    and e.status = 'active';

  select coalesce(q.consumed, 0)
    into v_used
  from public.quota_ledger q
  where q.account_id = v_user
    and q.period_start = current_date
    and q.capability = 'focus';

  if coalesce(v_used, 0) + (
       select count(*)
       from public.generation_jobs j
       where j.account_id = v_user
         and j.target_artifact_type = 'FOCUS_HELP'
         and j.state in ('QUEUED', 'PROCESSING')
         and j.created_at::date = current_date
     ) >= coalesce(v_limit, 0) then
    raise exception 'quota_exceeded' using errcode = 'P0001';
  end if;

  insert into public.generation_jobs (
    account_id,
    material_id,
    capability,
    target_artifact_type,
    source_asset_id,
    extracted_content_id,
    generation_contract,
    idempotency_key,
    request_fingerprint,
    intent,
    request_context
  )
  values (
    v_user,
    p_material_id,
    'structured_generation',
    'FOCUS_HELP',
    v_source,
    v_extracted,
    public.la_focus_contract(),
    p_idempotency_key,
    v_fp,
    'initial',
    jsonb_build_object(
      'help_kind', v_kind,
      'question', v_question,
      'question_digest', v_question_digest
    )
  )
  returning * into v_job;

  update public.materials
  set processing_state = 'queued'
  where id = p_material_id;

  return v_job.id;
end;
$$;

create or replace function public.read_focus_help(
  p_job_id uuid,
  p_source_content_hash text
)
returns table (
  artifact_id uuid,
  source_content_hash text,
  content jsonb,
  provider_execution_ref text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := public.la_require_user();
  v_material uuid;
  v_current_hash text;
begin
  select j.material_id
    into v_material
  from public.generation_jobs j
  where j.id = p_job_id
    and j.account_id = v_user
    and j.generation_contract = public.la_focus_contract()
    and j.target_artifact_type = 'FOCUS_HELP';

  if v_material is null then
    raise exception 'job_not_found' using errcode = 'P0002';
  end if;

  select e.source_content_hash
    into v_current_hash
  from public.materials m
  join public.source_assets s
    on s.material_id = m.id
   and s.revoked_at is null
  join public.extracted_contents e
    on e.source_asset_id = s.id
   and e.invalidated_at is null
  where m.id = v_material
    and m.account_id = v_user
    and m.lifecycle_status = 'active'
  order by s.source_version desc, e.created_at desc
  limit 1;

  if v_current_hash is null then
    raise exception 'material_not_found' using errcode = 'P0002';
  end if;
  if v_current_hash <> p_source_content_hash then
    raise exception 'stale_source' using errcode = 'P0001';
  end if;

  return query
  select a.id,
         e.source_content_hash,
         a.content,
         ga.provider_execution_ref,
         a.created_at
  from public.artifacts a
  join public.generation_jobs j on j.id = a.generation_job_id
  join public.extracted_contents e on e.id = j.extracted_content_id
  join public.generation_attempts ga on ga.id = a.generation_attempt_id
  where a.account_id = v_user
    and a.generation_job_id = p_job_id
    and a.artifact_type = 'FOCUS_HELP'
    and a.status = 'available'
    and e.invalidated_at is null
    and e.source_content_hash = p_source_content_hash
    and j.generation_contract = public.la_focus_contract()
  limit 1;
end;
$$;

create or replace function public.la_valid_focus_content(p jsonb)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select coalesce(
    jsonb_typeof(p) = 'object'
    and jsonb_typeof(p -> 'response') = 'string'
    and length(btrim(p ->> 'response')) between 1 and 12000
    and jsonb_typeof(p -> 'key_points') = 'array'
    and jsonb_array_length(p -> 'key_points') between 1 and 8
    and not exists (
      select 1
      from jsonb_array_elements(p -> 'key_points') item
      where jsonb_typeof(item) <> 'string'
         or length(btrim(item #>> '{}')) = 0
    )
    and jsonb_typeof(p -> 'language') = 'string'
    and length(btrim(p ->> 'language')) between 1 and 32,
    false
  )
$$;

create or replace function public.complete_focus_generation_attempt(
  p_attempt_id uuid,
  p_lease_token uuid,
  p_content jsonb,
  p_provider_ref text,
  p_usage jsonb,
  p_latency_ms integer
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job public.generation_jobs%rowtype;
  v_artifact uuid;
  v_prev uuid;
  v_version integer;
begin
  v_job := public.la_current_attempt(p_attempt_id, p_lease_token);

  if v_job.generation_contract <> public.la_focus_contract()
     or v_job.target_artifact_type <> 'FOCUS_HELP' then
    raise exception 'wrong_generation_contract' using errcode = 'P0001';
  end if;
  if (
    select dispatch_state
    from public.generation_attempts
    where id = p_attempt_id
  ) <> 'dispatched' then
    raise exception 'invalid_dispatch_transition' using errcode = 'P0001';
  end if;
  if not public.la_valid_focus_content(p_content) then
    raise exception 'invalid_focus_content' using errcode = '22023';
  end if;

  select id
    into v_prev
  from public.artifacts
  where material_id = v_job.material_id
    and artifact_type = 'FOCUS_HELP'
    and status = 'available'
  order by version desc
  limit 1;

  select coalesce(max(version), 0) + 1
    into v_version
  from public.artifacts
  where material_id = v_job.material_id
    and artifact_type = 'FOCUS_HELP';

  insert into public.artifacts (
    account_id,
    material_id,
    artifact_type,
    version,
    generation_job_id,
    generation_attempt_id,
    content,
    generation_settings,
    supersedes_artifact_id
  )
  values (
    v_job.account_id,
    v_job.material_id,
    'FOCUS_HELP',
    v_version,
    v_job.id,
    p_attempt_id,
    p_content,
    jsonb_build_object(
      'contract', v_job.generation_contract,
      'help_kind', v_job.request_context ->> 'help_kind',
      'adapter',
      (
        select adapter_ref
        from public.generation_attempts
        where id = p_attempt_id
      )
    ),
    v_prev
  )
  returning id into v_artifact;

  if v_prev is not null then
    update public.artifacts
    set status = 'superseded'
    where id = v_prev;
  end if;

  insert into public.evidence_refs (
    account_id,
    artifact_id,
    source_asset_id,
    extracted_content_id,
    anchor
  )
  values (
    v_job.account_id,
    v_artifact,
    v_job.source_asset_id,
    v_job.extracted_content_id,
    jsonb_build_object(
      'scope', 'whole_source',
      'focus_help_kind', v_job.request_context ->> 'help_kind'
    )
  );

  update public.generation_attempts
  set status = 'succeeded',
      dispatch_state = 'response_known',
      budget_effect = 'consumed',
      provider_execution_ref = p_provider_ref,
      latency_ms = p_latency_ms,
      completed_at = now()
  where id = p_attempt_id;

  insert into public.usage_events (
    account_id,
    capability,
    generation_job_id,
    generation_attempt_id,
    quantity,
    unit,
    cost_class,
    estimated_cost_usd,
    idempotency_key
  )
  values (
    v_job.account_id,
    'focus',
    v_job.id,
    p_attempt_id,
    coalesce((p_usage ->> 'total_tokens')::numeric, 0),
    'tokens',
    coalesce(p_usage ->> 'cost_class', 'unknown'),
    (p_usage ->> 'estimated_cost_usd')::numeric,
    'usage:' || v_job.id::text
  )
  on conflict (idempotency_key) do nothing;

  insert into public.quota_ledger (
    account_id,
    period_start,
    capability,
    consumed
  )
  values (
    v_job.account_id,
    current_date,
    'focus',
    1
  )
  on conflict (account_id, period_start, capability)
  do update set consumed = public.quota_ledger.consumed + 1;

  update public.generation_jobs
  set state = 'SUCCEEDED',
      failure_class = null,
      completed_at = now(),
      lease_token = null,
      lease_expires_at = null,
      request_context = jsonb_build_object(
        'help_kind', request_context ->> 'help_kind',
        'question_digest', request_context ->> 'question_digest'
      )
  where id = v_job.id;

  update public.materials
  set processing_state = 'ready'
  where id = v_job.material_id;

  return v_artifact;
end;
$$;

revoke all on function public.la_focus_contract(),
                       public.request_focus_help(uuid, text, text, text, text),
                       public.read_focus_help(uuid, text),
                       public.la_valid_focus_content(jsonb),
                       public.complete_focus_generation_attempt(uuid, uuid, jsonb, text, jsonb, integer)
from public, anon, authenticated;

grant execute on function public.request_focus_help(uuid, text, text, text, text),
                          public.read_focus_help(uuid, text)
to authenticated;

grant execute on function public.la_focus_contract(),
                          public.la_valid_focus_content(jsonb),
                          public.complete_focus_generation_attempt(uuid, uuid, jsonb, text, jsonb, integer)
to service_role;
