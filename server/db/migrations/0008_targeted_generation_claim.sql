-- LA-0041: exact-job worker claim for authenticated on-demand generation wake-up.
-- Service-role only. The Edge Function verifies learner ownership with RLS first.
\set ON_ERROR_STOP on

create or replace function public.claim_generation_job_by_id(
  p_job_id uuid,
  p_lease_seconds integer default 120
)
returns table (
  job_id uuid,
  attempt_id uuid,
  lease_token uuid,
  attempt_idempotency_key text,
  generation_contract text,
  normalized_text text,
  source_asset_id uuid,
  extracted_content_id uuid
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job public.generation_jobs%rowtype;
  v_prev public.generation_attempts%rowtype;
  v_attempt uuid;
  v_token uuid := gen_random_uuid();
begin
  if p_lease_seconds < 15 or p_lease_seconds > 600 then
    raise exception 'invalid_lease_seconds' using errcode = '22023';
  end if;

  select * into v_job
  from public.generation_jobs
  where id = p_job_id
  for update;

  if not found then return; end if;

  if v_job.state = 'PROCESSING' and v_job.lease_expires_at < now() then
    select * into v_prev
    from public.generation_attempts
    where id = v_job.active_attempt_id;

    if v_prev.dispatch_state = 'not_dispatched' then
      update public.generation_attempts
      set status = 'abandoned',
          budget_effect = 'released',
          failure_class = 'lease_expired',
          completed_at = now()
      where id = v_prev.id;

      update public.generation_jobs
      set state = 'QUEUED',
          lease_token = null,
          lease_expires_at = null
      where id = v_job.id;
    else
      update public.generation_attempts
      set dispatch_state = 'dispatch_unknown',
          status = 'failed',
          failure_class = 'lease_expired_after_dispatch',
          completed_at = now()
      where id = v_prev.id;

      update public.generation_jobs
      set state = 'FAILED_RETRYABLE',
          failure_class = 'reconciliation_required',
          lease_token = null,
          lease_expires_at = null
      where id = v_job.id;

      update public.materials
      set processing_state = 'failed'
      where id = v_job.material_id;

      return;
    end if;

    select * into v_job
    from public.generation_jobs
    where id = p_job_id
    for update;
  end if;

  if v_job.state <> 'QUEUED' then return; end if;

  if v_job.attempt_count >= v_job.max_attempts then
    update public.generation_jobs
    set state = 'FAILED_FINAL',
        failure_class = 'max_attempts_exhausted',
        completed_at = now()
    where id = v_job.id;

    update public.materials
    set processing_state = 'failed'
    where id = v_job.material_id;

    return;
  end if;

  insert into public.generation_attempts (
    job_id,
    account_id,
    attempt_number,
    predecessor_attempt_id,
    attempt_idempotency_key,
    adapter_ref
  )
  values (
    v_job.id,
    v_job.account_id,
    v_job.attempt_count + 1,
    v_job.active_attempt_id,
    v_job.id::text || ':' || (v_job.attempt_count + 1)::text,
    'unassigned'
  )
  returning id into v_attempt;

  update public.generation_jobs
  set state = 'PROCESSING',
      active_attempt_id = v_attempt,
      attempt_count = v_job.attempt_count + 1,
      lease_token = v_token,
      lease_expires_at = now() + make_interval(secs => p_lease_seconds),
      started_at = coalesce(started_at, now())
  where id = v_job.id;

  update public.materials
  set processing_state = 'processing'
  where id = v_job.material_id;

  return query
  select
    v_job.id,
    v_attempt,
    v_token,
    v_job.id::text || ':' || (v_job.attempt_count + 1)::text,
    v_job.generation_contract,
    e.normalized_text,
    v_job.source_asset_id,
    v_job.extracted_content_id
  from public.extracted_contents e
  where e.id = v_job.extracted_content_id;
end;
$$;

revoke all on function public.claim_generation_job_by_id(uuid, integer)
from public, anon, authenticated;

grant execute on function public.claim_generation_job_by_id(uuid, integer)
to service_role;
