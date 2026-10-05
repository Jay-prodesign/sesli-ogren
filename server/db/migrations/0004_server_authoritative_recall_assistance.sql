-- Sesli Öğren / Learning App — M5 server-authoritative Recall assistance delta (LA-0022).
-- Requires 0003_recall_learning_truth.sql.
-- Assistance truth must be derived from server-owned attempt state, never a client claim.
-- Hint and answer-exposure are distinct because answer exposure must never become
-- independent retrieval evidence.
\set ON_ERROR_STOP on

alter table public.learner_evidence
  add column if not exists assistance text not null default 'none'
  check (assistance in ('none', 'hint', 'answer_exposed'));

-- 0003 represented assistance only as help_used. Preserve any pre-existing hinted
-- development rows while extending the evidence vocabulary for answer exposure.
update public.learner_evidence
set assistance = case when help_used then 'hint' else 'none' end
where assistance = 'none';

alter table public.learner_evidence
  drop constraint if exists learner_evidence_outcome_check;
alter table public.learner_evidence
  add constraint learner_evidence_outcome_check
  check (outcome in (
    'correct', 'helped_correct', 'answer_exposed',
    'partial', 'incorrect', 'unknown'
  ));

-- 0004 changes Recall evidence semantics by making answer exposure canonical.
-- Preserve historical v1 evidence as historical truth, but require all new
-- evidence produced by this migration's RPC to use recall-evidence-v2.
alter table public.learner_evidence
  drop constraint if exists learner_evidence_rule_version_check;
alter table public.learner_evidence
  add constraint learner_evidence_rule_version_check
  check (rule_version in ('recall-evidence-v1', 'recall-evidence-v2'));

-- LearnerState is a mutable derived projection, so migrate existing projections
-- to the current v2 state policy rather than mislabeling historical evidence.
alter table public.learner_states
  drop constraint if exists learner_states_rule_version_check;
update public.learner_states
set rule_version = 'recall-state-v2'
where rule_version = 'recall-state-v1';
alter table public.learner_states
  add constraint learner_states_rule_version_check
  check (rule_version = 'recall-state-v2');

grant select (assistance) on public.learner_evidence to authenticated;

create table public.recall_attempt_sessions (
  account_id uuid not null references public.accounts(id) on delete cascade,
  attempt_id text not null check (attempt_id ~ '^[A-Za-z0-9_.:-]{8,128}$'),
  recall_action_id uuid not null references public.recall_actions(id) on delete cascade,
  assistance text not null default 'none'
    check (assistance in ('none', 'hint', 'answer_exposed')),
  created_at timestamptz not null default now(),
  submitted_at timestamptz,
  primary key (account_id, attempt_id)
);

alter table public.recall_attempt_sessions enable row level security;
alter table public.recall_attempt_sessions force row level security;
revoke all on public.recall_attempt_sessions from anon, authenticated;
grant select (
  account_id, attempt_id, recall_action_id, assistance, created_at, submitted_at
) on public.recall_attempt_sessions to authenticated;
grant all on public.recall_attempt_sessions to service_role;

create policy recall_attempt_sessions_owner_read on public.recall_attempt_sessions
for select to authenticated
using ((select auth.uid()) is not null and account_id = (select auth.uid()));

create or replace function public.la_recall_state_for_outcome(p_outcome text)
returns text
language sql immutable set search_path = ''
as $$
  select case p_outcome
    when 'correct' then 'retrieved_once'
    when 'helped_correct' then 'developing'
    when 'partial' then 'developing'
    when 'incorrect' then 'needs_review'
    when 'answer_exposed' then 'not_assessed'
    when 'unknown' then 'not_assessed'
    else 'not_assessed'
  end
$$;

create or replace function public.la_recall_next_reason_for_outcome(p_outcome text)
returns text
language sql immutable set search_path = ''
as $$
  select case p_outcome
    when 'correct' then 'ONE_UNASSISTED_RETRIEVAL_OBSERVED'
    when 'helped_correct' then 'HINTED_SUCCESS_NEEDS_UNASSISTED_RETRIEVAL'
    when 'answer_exposed' then 'ANSWER_EXPOSED_NO_RETRIEVAL_CLAIM'
    when 'partial' then 'PARTIAL_RETRIEVAL_NEEDS_RETRY'
    when 'incorrect' then 'INCORRECT_RETRIEVAL_NEEDS_REPAIR'
    when 'unknown' then 'NO_EVALUABLE_RETRIEVAL'
    else 'NO_EVALUABLE_RETRIEVAL'
  end
$$;

create or replace function public.reveal_recall_hint(p_action_id uuid, p_attempt_id text)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := public.la_require_user();
  v_action public.recall_actions%rowtype;
  v_session public.recall_attempt_sessions%rowtype;
begin
  if p_attempt_id is null or p_attempt_id !~ '^[A-Za-z0-9_.:-]{8,128}$' then
    raise exception 'invalid_attempt_id' using errcode = '22023';
  end if;

  select a.* into v_action
  from public.recall_actions a
  join public.materials m
    on m.id = a.material_id
   and m.account_id = v_user
   and m.lifecycle_status = 'active'
  join public.source_assets s
    on s.id = a.source_asset_id
   and s.account_id = v_user
   and s.revoked_at is null
  join public.extracted_contents e
    on e.id = a.extracted_content_id
   and e.account_id = v_user
   and e.invalidated_at is null
  where a.id = p_action_id
    and a.account_id = v_user
    and a.revoked_at is null;

  if not found then
    raise exception 'recall_action_not_found_or_stale' using errcode = 'P0002';
  end if;

  insert into public.recall_attempt_sessions (
    account_id, attempt_id, recall_action_id, assistance
  )
  values (v_user, p_attempt_id, p_action_id, 'hint')
  on conflict (account_id, attempt_id) do update
    set assistance = case
      when public.recall_attempt_sessions.assistance = 'answer_exposed'
        then 'answer_exposed'
      else 'hint'
    end
  where public.recall_attempt_sessions.recall_action_id = excluded.recall_action_id
    and public.recall_attempt_sessions.submitted_at is null;

  select * into v_session
  from public.recall_attempt_sessions
  where account_id = v_user and attempt_id = p_attempt_id;

  if not found
     or v_session.recall_action_id <> p_action_id
     or v_session.submitted_at is not null then
    raise exception 'attempt_id_reused' using errcode = '22023';
  end if;

  return left(v_action.expected_answer, 1)
    || ' · ' || char_length(v_action.expected_answer)::text;
end;
$$;

create or replace function public.reveal_recall_answer(p_action_id uuid, p_attempt_id text)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := public.la_require_user();
  v_action public.recall_actions%rowtype;
  v_session public.recall_attempt_sessions%rowtype;
begin
  if p_attempt_id is null or p_attempt_id !~ '^[A-Za-z0-9_.:-]{8,128}$' then
    raise exception 'invalid_attempt_id' using errcode = '22023';
  end if;

  select a.* into v_action
  from public.recall_actions a
  join public.materials m
    on m.id = a.material_id
   and m.account_id = v_user
   and m.lifecycle_status = 'active'
  join public.source_assets s
    on s.id = a.source_asset_id
   and s.account_id = v_user
   and s.revoked_at is null
  join public.extracted_contents e
    on e.id = a.extracted_content_id
   and e.account_id = v_user
   and e.invalidated_at is null
  where a.id = p_action_id
    and a.account_id = v_user
    and a.revoked_at is null;

  if not found then
    raise exception 'recall_action_not_found_or_stale' using errcode = 'P0002';
  end if;

  insert into public.recall_attempt_sessions (
    account_id, attempt_id, recall_action_id, assistance
  )
  values (v_user, p_attempt_id, p_action_id, 'answer_exposed')
  on conflict (account_id, attempt_id) do update
    set assistance = 'answer_exposed'
  where public.recall_attempt_sessions.recall_action_id = excluded.recall_action_id
    and public.recall_attempt_sessions.submitted_at is null;

  select * into v_session
  from public.recall_attempt_sessions
  where account_id = v_user and attempt_id = p_attempt_id;

  if not found
     or v_session.recall_action_id <> p_action_id
     or v_session.submitted_at is not null then
    raise exception 'attempt_id_reused' using errcode = '22023';
  end if;

  return v_action.expected_answer;
end;
$$;

drop function if exists public.submit_recall_attempt(uuid, text, text, text, boolean);

create or replace function public.submit_recall_attempt(
  p_action_id uuid,
  p_attempt_id text,
  p_response_disposition text,
  p_answer text default ''
)
returns table (
  evidence_id uuid,
  outcome text,
  state_kind text,
  evidence_count integer,
  next_reason_code text
)
language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := public.la_require_user();
  v_action public.recall_actions%rowtype;
  v_existing public.learner_evidence%rowtype;
  v_session public.recall_attempt_sessions%rowtype;
  v_normalized text;
  v_expected text;
  v_outcome text;
  v_digest text;
  v_state text;
  v_count integer;
  v_evidence uuid;
begin
  if p_attempt_id is null
     or p_attempt_id !~ '^[A-Za-z0-9_.:-]{8,128}$' then
    raise exception 'invalid_attempt_id' using errcode = '22023';
  end if;
  if p_response_disposition not in ('answer', 'unknown') then
    raise exception 'invalid_response_disposition' using errcode = '22023';
  end if;
  if char_length(coalesce(p_answer, '')) > 4000 then
    raise exception 'recall_answer_too_large' using errcode = '22023';
  end if;

  select a.* into v_action
  from public.recall_actions a
  join public.materials m
    on m.id = a.material_id
   and m.account_id = v_user
   and m.lifecycle_status = 'active'
  join public.source_assets s
    on s.id = a.source_asset_id
   and s.account_id = v_user
   and s.revoked_at is null
  join public.extracted_contents e
    on e.id = a.extracted_content_id
   and e.account_id = v_user
   and e.invalidated_at is null
  where a.id = p_action_id
    and a.account_id = v_user
    and a.revoked_at is null
  for update of a;

  if not found then
    raise exception 'recall_action_not_found_or_stale' using errcode = 'P0002';
  end if;

  insert into public.recall_attempt_sessions(
    account_id, attempt_id, recall_action_id, assistance
  )
  values(v_user, p_attempt_id, p_action_id, 'none')
  on conflict(account_id, attempt_id) do nothing;

  select * into v_session
  from public.recall_attempt_sessions
  where account_id = v_user and attempt_id = p_attempt_id
  for update;

  if not found or v_session.recall_action_id <> p_action_id then
    raise exception 'attempt_id_reused' using errcode = '22023';
  end if;

  v_normalized := case
    when p_response_disposition = 'unknown' then ''
    else public.la_recall_normalize(p_answer)
  end;
  if char_length(v_normalized) > 1000 then
    raise exception 'recall_answer_too_large' using errcode = '22023';
  end if;

  v_expected := public.la_recall_normalize(v_action.expected_answer);
  v_outcome := case
    when p_response_disposition = 'unknown' or v_normalized = '' then 'unknown'
    when v_session.assistance = 'answer_exposed' then 'answer_exposed'
    when v_normalized = v_expected and v_session.assistance = 'hint'
      then 'helped_correct'
    when v_normalized = v_expected then 'correct'
    when char_length(v_expected) >= 5
      and public.la_recall_distance_le_one(v_normalized, v_expected) then 'partial'
    else 'incorrect'
  end;
  v_digest := public.la_sha256(v_normalized);

  select * into v_existing
  from public.learner_evidence
  where account_id = v_user and attempt_id = p_attempt_id
  for update;

  if found then
    if v_existing.recall_action_id <> p_action_id
       or v_existing.response_disposition <> p_response_disposition
       or v_existing.assistance <> v_session.assistance
       or v_existing.help_used <> (v_session.assistance <> 'none')
       or v_existing.response_digest <> v_digest then
      raise exception 'attempt_id_reused' using errcode = '22023';
    end if;

    select s.state_kind, s.evidence_count
      into state_kind, evidence_count
    from public.learner_states s
    where s.account_id = v_user
      and s.material_id = v_action.material_id;

    if state_kind is null then
      raise exception 'learner_state_missing' using errcode = 'P0001';
    end if;

    evidence_id := v_existing.id;
    outcome := v_existing.outcome;
    next_reason_code := public.la_recall_next_reason_for_outcome(v_existing.outcome);
    return next;
    return;
  end if;

  insert into public.learner_evidence(
    account_id, material_id, source_asset_id, extracted_content_id,
    recall_action_id, attempt_id, response_disposition, outcome,
    assistance, help_used, response_digest, response_length, rule_version
  )
  values(
    v_user, v_action.material_id, v_action.source_asset_id,
    v_action.extracted_content_id, v_action.id, p_attempt_id,
    p_response_disposition, v_outcome, v_session.assistance,
    v_session.assistance <> 'none', v_digest, char_length(v_normalized),
    'recall-evidence-v2'
  )
  returning id into v_evidence;

  update public.recall_attempt_sessions
  set submitted_at = now()
  where account_id = v_user and attempt_id = p_attempt_id;

  v_state := public.la_recall_state_for_outcome(v_outcome);
  select count(*)::integer into v_count
  from public.learner_evidence e
  where e.account_id = v_user
    and e.material_id = v_action.material_id
    and e.source_asset_id = v_action.source_asset_id
    and e.invalidated_at is null;

  insert into public.learner_states(
    account_id, material_id, source_asset_id, extracted_content_id,
    state_kind, evidence_count, latest_evidence_id, rule_version, updated_at
  )
  values(
    v_user, v_action.material_id, v_action.source_asset_id,
    v_action.extracted_content_id, v_state, v_count,
    v_evidence, 'recall-state-v2', now()
  )
  on conflict(account_id, material_id) do update set
    source_asset_id = excluded.source_asset_id,
    extracted_content_id = excluded.extracted_content_id,
    state_kind = excluded.state_kind,
    evidence_count = excluded.evidence_count,
    latest_evidence_id = excluded.latest_evidence_id,
    rule_version = excluded.rule_version,
    updated_at = excluded.updated_at;

  evidence_id := v_evidence;
  outcome := v_outcome;
  state_kind := v_state;
  evidence_count := v_count;
  next_reason_code := public.la_recall_next_reason_for_outcome(v_outcome);
  return next;
end;
$$;

revoke all on function public.reveal_recall_hint(uuid, text),
                       public.reveal_recall_answer(uuid, text),
                       public.submit_recall_attempt(uuid, text, text, text),
                       public.la_recall_next_reason_for_outcome(text)
  from public, anon, authenticated;

grant execute on function public.reveal_recall_hint(uuid, text),
                          public.reveal_recall_answer(uuid, text),
                          public.submit_recall_attempt(uuid, text, text, text)
  to authenticated;

grant execute on function public.la_recall_next_reason_for_outcome(text)
  to service_role;
