\set ON_ERROR_STOP on

-- Source-bound semantic evaluation state for canonical Explain/teach-back.
-- Learner response plaintext is deliberately NOT persisted. Only its digest,
-- length, bounded evaluator result, and dispatch/recovery metadata are stored.

alter table public.explain_back_attempts
  add column if not exists evaluation_state text not null default 'PENDING',
  add column if not exists evaluation_attempt_count integer not null default 0,
  add column if not exists evaluator_dispatch_state text not null default 'not_dispatched',
  add column if not exists evaluator_adapter_ref text,
  add column if not exists evaluator_provider_execution_ref text,
  add column if not exists evaluation_failure_class text,
  add column if not exists evaluation_lease_token uuid,
  add column if not exists evaluation_lease_expires_at timestamptz;

alter table public.explain_back_attempts
  drop constraint if exists explain_back_attempts_evaluation_state_check;
alter table public.explain_back_attempts
  add constraint explain_back_attempts_evaluation_state_check
  check (
    evaluation_state in (
      'PENDING',
      'PROCESSING',
      'SUCCEEDED',
      'FAILED_RETRYABLE',
      'FAILED_FINAL',
      'RECONCILIATION_REQUIRED'
    )
  );

alter table public.explain_back_attempts
  drop constraint if exists explain_back_attempts_evaluation_attempt_count_check;
alter table public.explain_back_attempts
  add constraint explain_back_attempts_evaluation_attempt_count_check
  check (evaluation_attempt_count between 0 and 3);

alter table public.explain_back_attempts
  drop constraint if exists explain_back_attempts_evaluator_dispatch_state_check;
alter table public.explain_back_attempts
  add constraint explain_back_attempts_evaluator_dispatch_state_check
  check (
    evaluator_dispatch_state in (
      'not_dispatched',
      'dispatched',
      'response_known',
      'dispatch_unknown'
    )
  );

alter table public.explain_back_attempts
  drop constraint if exists explain_back_attempts_evaluation_consistency_check;
alter table public.explain_back_attempts
  add constraint explain_back_attempts_evaluation_consistency_check
  check (
    (
      evaluation_state = 'SUCCEEDED'
      and evaluation_kind is not null
      and evaluator_ref is not null
      and evaluated_at is not null
    )
    or
    (
      evaluation_state <> 'SUCCEEDED'
      and evaluation_kind is null
      and evaluator_ref is null
      and evaluated_at is null
    )
  );

update public.explain_back_attempts
set evaluation_state = 'SUCCEEDED',
    evaluator_dispatch_state = 'response_known'
where evaluation_kind is not null;

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
begin
  if p_lease_seconds < 15 or p_lease_seconds > 300 then
    raise exception 'invalid_lease_seconds' using errcode = '22023';
  end if;

  select *
  into v_attempt
  from public.explain_back_attempts
  where account_id = p_account_id
    and attempt_id = p_attempt_id
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
      update public.explain_back_attempts
      set evaluation_state = 'PENDING',
          evaluation_lease_token = null,
          evaluation_lease_expires_at = null,
          evaluation_failure_class = 'lease_expired_before_dispatch'
      where account_id = p_account_id
        and attempt_id = p_attempt_id;
      v_attempt.evaluation_state := 'PENDING';
    else
      update public.explain_back_attempts
      set evaluation_state = 'RECONCILIATION_REQUIRED',
          evaluator_dispatch_state = 'dispatch_unknown',
          evaluation_failure_class = 'lease_expired_after_dispatch',
          evaluation_lease_token = null,
          evaluation_lease_expires_at = null
      where account_id = p_account_id
        and attempt_id = p_attempt_id;
      return;
    end if;
  end if;

  if v_attempt.evaluation_attempt_count >= 3 then
    update public.explain_back_attempts
    set evaluation_state = 'FAILED_FINAL',
        evaluation_failure_class = 'max_attempts_exhausted',
        evaluation_lease_token = null,
        evaluation_lease_expires_at = null
    where account_id = p_account_id
      and attempt_id = p_attempt_id;
    return;
  end if;

  update public.explain_back_attempts
  set evaluation_state = 'PROCESSING',
      evaluation_attempt_count = evaluation_attempt_count + 1,
      evaluator_dispatch_state = 'not_dispatched',
      evaluator_adapter_ref = null,
      evaluator_provider_execution_ref = null,
      evaluation_failure_class = null,
      evaluation_lease_token = v_token,
      evaluation_lease_expires_at = now() + make_interval(secs => p_lease_seconds)
  where account_id = p_account_id
    and attempt_id = p_attempt_id;

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

create or replace function public.mark_explain_back_dispatched(
  p_account_id uuid,
  p_attempt_id text,
  p_lease_token uuid,
  p_adapter_ref text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_adapter_ref is null or length(btrim(p_adapter_ref)) not between 1 and 512 then
    raise exception 'invalid_adapter_ref' using errcode = '22023';
  end if;

  update public.explain_back_attempts
  set evaluator_dispatch_state = 'dispatched',
      evaluator_adapter_ref = p_adapter_ref
  where account_id = p_account_id
    and attempt_id = p_attempt_id
    and evaluation_state = 'PROCESSING'
    and evaluation_lease_token = p_lease_token
    and evaluation_lease_expires_at >= now()
    and evaluator_dispatch_state = 'not_dispatched';

  if not found then
    raise exception 'stale_evaluation_lease' using errcode = 'P0001';
  end if;
end;
$$;

create or replace function public.complete_explain_back_attempt(
  p_account_id uuid,
  p_attempt_id text,
  p_lease_token uuid,
  p_evaluation_kind text,
  p_evaluator_ref text,
  p_feedback text,
  p_targeted_repair text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_evaluation_kind not in ('sufficient', 'gap_detected', 'not_evaluable') then
    raise exception 'invalid_evaluation_kind' using errcode = '22023';
  end if;
  if p_evaluator_ref is null or length(btrim(p_evaluator_ref)) not between 1 and 512 then
    raise exception 'invalid_evaluator_ref' using errcode = '22023';
  end if;
  if p_feedback is null or length(btrim(p_feedback)) not between 1 and 4000 then
    raise exception 'invalid_feedback' using errcode = '22023';
  end if;
  if p_targeted_repair is null or length(p_targeted_repair) > 4000 then
    raise exception 'invalid_targeted_repair' using errcode = '22023';
  end if;

  update public.explain_back_attempts
  set evaluation_state = 'SUCCEEDED',
      evaluator_dispatch_state = 'response_known',
      evaluator_provider_execution_ref = p_evaluator_ref,
      evaluation_failure_class = null,
      evaluation_lease_token = null,
      evaluation_lease_expires_at = null,
      evaluation_kind = p_evaluation_kind,
      evaluator_ref = p_evaluator_ref,
      feedback = btrim(p_feedback),
      targeted_repair = btrim(p_targeted_repair),
      evaluated_at = now()
  where account_id = p_account_id
    and attempt_id = p_attempt_id
    and evaluation_state = 'PROCESSING'
    and evaluation_lease_token = p_lease_token
    and evaluation_lease_expires_at >= now()
    and evaluator_dispatch_state = 'dispatched';

  if not found then
    raise exception 'stale_evaluation_lease' using errcode = 'P0001';
  end if;

  return 'SUCCEEDED';
end;
$$;

create or replace function public.fail_explain_back_attempt(
  p_account_id uuid,
  p_attempt_id text,
  p_lease_token uuid,
  p_failure_class text,
  p_provider_ref text default null
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_attempt_count integer;
  v_state text;
begin
  if p_failure_class not in ('retryable', 'final', 'ambiguous') then
    raise exception 'invalid_failure_class' using errcode = '22023';
  end if;

  select evaluation_attempt_count
  into v_attempt_count
  from public.explain_back_attempts
  where account_id = p_account_id
    and attempt_id = p_attempt_id
    and evaluation_state = 'PROCESSING'
    and evaluation_lease_token = p_lease_token
    and evaluation_lease_expires_at >= now()
  for update;

  if not found then
    raise exception 'stale_evaluation_lease' using errcode = 'P0001';
  end if;

  v_state := case
    when p_failure_class = 'ambiguous' then 'RECONCILIATION_REQUIRED'
    when p_failure_class = 'final' then 'FAILED_FINAL'
    when v_attempt_count >= 3 then 'FAILED_FINAL'
    else 'FAILED_RETRYABLE'
  end;

  update public.explain_back_attempts
  set evaluation_state = v_state,
      evaluator_dispatch_state = case
        when p_failure_class = 'ambiguous' then 'dispatch_unknown'
        else 'response_known'
      end,
      evaluator_provider_execution_ref = p_provider_ref,
      evaluation_failure_class = case
        when p_failure_class = 'ambiguous' then 'reconciliation_required'
        else p_failure_class
      end,
      evaluation_lease_token = null,
      evaluation_lease_expires_at = null
  where account_id = p_account_id
    and attempt_id = p_attempt_id;

  return v_state;
end;
$$;

revoke all on function public.claim_explain_back_attempt(uuid, text, integer),
                       public.mark_explain_back_dispatched(uuid, text, uuid, text),
                       public.complete_explain_back_attempt(uuid, text, uuid, text, text, text, text),
                       public.fail_explain_back_attempt(uuid, text, uuid, text, text)
from public, anon, authenticated;

grant execute on function public.claim_explain_back_attempt(uuid, text, integer),
                          public.mark_explain_back_dispatched(uuid, text, uuid, text),
                          public.complete_explain_back_attempt(uuid, text, uuid, text, text, text, text),
                          public.fail_explain_back_attempt(uuid, text, uuid, text, text)
to service_role;
