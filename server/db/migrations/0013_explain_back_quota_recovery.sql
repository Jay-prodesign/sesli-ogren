\set ON_ERROR_STOP on

-- Recover quota reserved by an evaluator claim that expired before any
-- provider dispatch. A retry after a real provider dispatch remains billable.
alter table public.explain_back_attempts
  add column if not exists evaluation_quota_reserved boolean not null default false;

create or replace function public.claim_explain_back_attempt(
  p_account_id uuid,
  p_attempt_id text,
  p_lease_seconds integer default 120
)
returns table (
  attempt_id text,
  lease_token uuid,
  source_text text,
  source_content_hash text,
  response_digest text,
  response_length integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_attempt public.explain_back_attempts%rowtype;
  v_token uuid := gen_random_uuid();
  v_limit integer;
  v_used integer;
begin
  if p_lease_seconds < 15 or p_lease_seconds > 300 then
    raise exception 'invalid_lease_seconds' using errcode = '22023';
  end if;

  select *
  into v_attempt
  from public.explain_back_attempts a
  where a.account_id = p_account_id
    and a.attempt_id = p_attempt_id
  for update;

  if not found then
    return;
  end if;

  if v_attempt.evaluation_state in ('SUCCEEDED', 'FAILED_FINAL', 'RECONCILIATION_REQUIRED') then
    return;
  end if;

  if v_attempt.evaluation_state = 'PROCESSING' then
    if v_attempt.evaluation_lease_expires_at is not null
       and v_attempt.evaluation_lease_expires_at >= now() then
      return;
    end if;

    if v_attempt.evaluator_dispatch_state = 'not_dispatched' then
      if v_attempt.evaluation_quota_reserved then
        update public.quota_ledger q
        set consumed = greatest(q.consumed - 1, 0)
        where q.account_id = p_account_id
          and q.period_start = current_date
          and q.capability = 'explain_back';
      end if;

      update public.explain_back_attempts a
      set evaluation_state = 'PENDING',
          evaluation_quota_reserved = false,
          evaluation_lease_token = null,
          evaluation_lease_expires_at = null,
          evaluation_failure_class = 'lease_expired_before_dispatch'
      where a.account_id = p_account_id
        and a.attempt_id = p_attempt_id;
      v_attempt.evaluation_state := 'PENDING';
    else
      update public.explain_back_attempts a
      set evaluation_state = 'RECONCILIATION_REQUIRED',
          evaluator_dispatch_state = 'dispatch_unknown',
          evaluation_failure_class = 'lease_expired_after_dispatch',
          evaluation_lease_token = null,
          evaluation_lease_expires_at = null
      where a.account_id = p_account_id
        and a.attempt_id = p_attempt_id;
      return;
    end if;
  end if;

  if v_attempt.evaluation_attempt_count >= 3 then
    update public.explain_back_attempts a
    set evaluation_state = 'FAILED_FINAL',
        evaluation_failure_class = 'max_attempts_exhausted',
        evaluation_lease_token = null,
        evaluation_lease_expires_at = null
    where a.account_id = p_account_id
      and a.attempt_id = p_attempt_id;
    return;
  end if;

  select coalesce(
           (e.limits ->> 'explain_back_daily')::integer,
           (e.limits ->> 'explain_daily')::integer,
           (e.limits ->> 'summary_daily')::integer,
           0
         )
    into v_limit
  from public.entitlements e
  where e.account_id = p_account_id
    and e.status = 'active';

  insert into public.quota_ledger (
    account_id,
    period_start,
    capability,
    consumed
  )
  values (
    p_account_id,
    current_date,
    'explain_back',
    0
  )
  on conflict (account_id, period_start, capability) do nothing;

  select q.consumed
    into v_used
  from public.quota_ledger q
  where q.account_id = p_account_id
    and q.period_start = current_date
    and q.capability = 'explain_back'
  for update;

  if coalesce(v_used, 0) >= coalesce(v_limit, 0) then
    raise exception 'quota_exceeded' using errcode = 'P0001';
  end if;

  update public.quota_ledger q
  set consumed = q.consumed + 1
  where q.account_id = p_account_id
    and q.period_start = current_date
    and q.capability = 'explain_back';

  update public.explain_back_attempts a
  set evaluation_state = 'PROCESSING',
      evaluation_attempt_count = evaluation_attempt_count + 1,
      evaluation_quota_reserved = true,
      evaluator_dispatch_state = 'not_dispatched',
      evaluator_adapter_ref = null,
      evaluator_provider_execution_ref = null,
      evaluation_failure_class = null,
      evaluation_lease_token = v_token,
      evaluation_lease_expires_at = now() + make_interval(secs => p_lease_seconds)
  where a.account_id = p_account_id
    and a.attempt_id = p_attempt_id;

  return query
  select a.attempt_id,
         v_token,
         e.normalized_text,
         a.source_content_hash,
         a.response_digest,
         a.response_length
  from public.explain_back_attempts a
  join public.extracted_contents e
    on e.id = a.extracted_content_id
   and e.account_id = a.account_id
   and e.invalidated_at is null
  where a.account_id = p_account_id
    and a.attempt_id = p_attempt_id;
end;
$$;

revoke all on function public.claim_explain_back_attempt(uuid, text, integer)
from public, anon, authenticated;
grant execute on function public.claim_explain_back_attempt(uuid, text, integer)
to service_role;
