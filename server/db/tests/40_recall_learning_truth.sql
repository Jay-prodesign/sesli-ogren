\set ON_ERROR_STOP on

begin;

-- Assumes M4 core/RPC migrations + 0003_recall_learning_truth.sql + 0004_server_authoritative_recall_assistance.sql.
-- Existing Architecture Proof harness creates auth.users and can set request.jwt.claim.sub.

do $$
begin
  if to_regclass('public.recall_actions') is null
     or to_regclass('public.learner_evidence') is null
     or to_regclass('public.learner_states') is null
     or to_regclass('public.recall_attempt_sessions') is null then
    raise exception 'm5 learning truth tables missing';
  end if;
end $$;

-- Direct authenticated writes must remain revoked.
do $$
begin
  if has_table_privilege('authenticated', 'public.recall_actions', 'INSERT')
     or has_table_privilege('authenticated', 'public.learner_evidence', 'INSERT')
     or has_table_privilege('authenticated', 'public.learner_states', 'INSERT')
     or has_table_privilege('authenticated', 'public.learner_states', 'UPDATE') then
    raise exception 'authenticated client has direct learning-truth write privilege';
  end if;
end $$;

-- expected_answer must not be readable by authenticated clients.
do $$
begin
  if has_column_privilege(
       'authenticated', 'public.recall_actions', 'expected_answer', 'SELECT'
     ) then
    raise exception 'expected answer leaked to authenticated client';
  end if;
end $$;

-- Rule helpers are deterministic and preserve outcome distinctions.
do $$
begin
  if public.la_recall_normalize(' Klorofil! ') <> 'klorofil' then
    raise exception 'normalization mismatch';
  end if;
  if not public.la_recall_distance_le_one('klorofi', 'klorofil') then
    raise exception 'partial-answer distance mismatch';
  end if;
  if public.la_recall_state_for_outcome('correct') <> 'retrieved_once'
     or public.la_recall_state_for_outcome('helped_correct') <> 'developing'
     or public.la_recall_state_for_outcome('answer_exposed') <> 'not_assessed'
     or public.la_recall_state_for_outcome('unknown') <> 'not_assessed' then
    raise exception 'state derivation mismatch';
  end if;

  if public.la_recall_next_reason_for_outcome('correct')
       <> 'ONE_UNASSISTED_RETRIEVAL_OBSERVED'
     or public.la_recall_next_reason_for_outcome('helped_correct')
       <> 'HINTED_SUCCESS_NEEDS_UNASSISTED_RETRIEVAL'
     or public.la_recall_next_reason_for_outcome('answer_exposed')
       <> 'ANSWER_EXPOSED_NO_RETRIEVAL_CLAIM'
     or public.la_recall_next_reason_for_outcome('unknown')
       <> 'NO_EVALUABLE_RETRIEVAL' then
    raise exception 'outcome-specific next-action reason mismatch';
  end if;
end $$;

-- Assistance must be server-authoritative: clients cannot write attempt truth directly,
-- cannot call the retired client-claimed hint signature, and can call only bounded RPCs.
do $$
begin
  if has_table_privilege('authenticated', 'public.recall_attempt_sessions', 'INSERT')
     or has_table_privilege('authenticated', 'public.recall_attempt_sessions', 'UPDATE')
     or has_table_privilege('authenticated', 'public.recall_attempt_sessions', 'DELETE') then
    raise exception 'authenticated client has direct Recall attempt-session write privilege';
  end if;

  if to_regprocedure('public.submit_recall_attempt(uuid,text,text,text,boolean)') is not null then
    raise exception 'retired client-claimed hint RPC signature still exists';
  end if;

  if to_regprocedure('public.submit_recall_attempt(uuid,text,text,text)') is null
     or to_regprocedure('public.reveal_recall_hint(uuid,text)') is null
     or to_regprocedure('public.reveal_recall_answer(uuid,text)') is null then
    raise exception 'server-authoritative Recall RPCs missing';
  end if;

  if not has_function_privilege('authenticated',
       'public.submit_recall_attempt(uuid,text,text,text)', 'EXECUTE')
     or not has_function_privilege('authenticated',
       'public.reveal_recall_hint(uuid,text)', 'EXECUTE')
     or not has_function_privilege('authenticated',
       'public.reveal_recall_answer(uuid,text)', 'EXECUTE') then
    raise exception 'authenticated role missing bounded Recall RPC execute privilege';
  end if;

  if not has_column_privilege(
       'authenticated', 'public.learner_evidence', 'assistance', 'SELECT'
     ) then
    raise exception 'authenticated learner cannot read canonical assistance classification';
  end if;

  if not exists (
       select 1
       from pg_constraint
       where conrelid = 'public.learner_evidence'::regclass
         and conname = 'learner_evidence_rule_version_check'
     ) then
    raise exception 'learner evidence rule-version constraint missing';
  end if;

  if not exists (
       select 1
       from pg_constraint
       where conrelid = 'public.learner_states'::regclass
         and conname = 'learner_states_rule_version_check'
     ) then
    raise exception 'learner state rule-version constraint missing';
  end if;
end $;


do $$
begin
  if public.la_recall_next_reason('not_assessed') <> 'NO_EVALUABLE_RETRIEVAL' then
    raise exception 'not_assessed Recall must preserve NO_EVALUABLE_RETRIEVAL continuation reason';
  end if;
end
$$;


-- Behavioral regression: exercise the server-authoritative Recall RPC path,
-- not only schema/privilege presence. This specifically protects the S-001
-- answer-exposure correction and immediate retry/idempotency contract.
\set user_a '''c1000000-0000-4000-8000-000000000001'''
\set user_b '''c1000000-0000-4000-8000-000000000002'''

create or replace function pg_temp.ok(v boolean, msg text) returns void language plpgsql as $
begin
  if v is distinct from true then
    raise exception 'recall_behavior_assert_failed: %', msg;
  end if;
end $;

create or replace function pg_temp.denied(stmt text, expected text, msg text)
returns void language plpgsql as $
declare err text;
begin
  begin
    execute stmt;
  exception when others then
    err := sqlerrm;
    if expected <> '*' and position(expected in err) = 0 then
      raise exception 'recall_behavior_assert_failed: % (wrong error: %)', msg, err;
    end if;
    return;
  end;
  raise exception 'recall_behavior_assert_failed: % (statement succeeded)', msg;
end $;

insert into auth.users (id, email) values
  (:user_a, 'm5-recall-a@example.test'),
  (:user_b, 'm5-recall-b@example.test');

-- Build one real learner-owned source/action through authenticated RPCs.
select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;
select public.create_text_material(
  'M5 Recall regression',
  'Mitokondri hücresel enerji üretiminde önemli görevler üstlenen bir organeldir.'
) as material_a \gset
select action_id as action_a
from public.create_recall_action(:'material_a') \gset
reset role;

-- expected_answer is intentionally server-only; the harness may inspect it as
-- the database owner solely to drive deterministic regression assertions.
select expected_answer as expected_a
from public.recall_actions
where id = :'action_a' \gset

-- 1) Unassisted exact recall is independent evidence and immediate replay is
-- idempotent: no duplicate evidence and the same transition is returned.
select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;
select
  evidence_id::text as clean_evidence,
  outcome as clean_outcome,
  state_kind as clean_state,
  evidence_count::text as clean_count,
  next_reason_code as clean_reason
from public.submit_recall_attempt(
  :'action_a',
  'm5-clean-0001',
  'answer',
  :'expected_a'
) \gset

select pg_temp.ok(:'clean_outcome' = 'correct', 'unassisted exact recall outcome');
select pg_temp.ok(:'clean_state' = 'retrieved_once', 'unassisted exact recall state');
select pg_temp.ok(
  :'clean_reason' = 'ONE_UNASSISTED_RETRIEVAL_OBSERVED',
  'unassisted exact recall reason'
);

select
  evidence_id::text as replay_evidence,
  outcome as replay_outcome,
  state_kind as replay_state,
  evidence_count::text as replay_count,
  next_reason_code as replay_reason
from public.submit_recall_attempt(
  :'action_a',
  'm5-clean-0001',
  'answer',
  :'expected_a'
) \gset

select pg_temp.ok(:'replay_evidence' = :'clean_evidence', 'immediate replay evidence id stable');
select pg_temp.ok(:'replay_outcome' = :'clean_outcome', 'immediate replay outcome stable');
select pg_temp.ok(:'replay_state' = :'clean_state', 'immediate replay state stable');
select pg_temp.ok(:'replay_count' = :'clean_count', 'immediate replay evidence count stable');
select pg_temp.ok(:'replay_reason' = :'clean_reason', 'immediate replay reason stable');
select pg_temp.ok(
  (select count(*) = 1 from public.learner_evidence
   where account_id = :user_a and attempt_id = 'm5-clean-0001'),
  'immediate replay did not duplicate evidence'
);

-- Conflicting reuse of the same logical attempt fails closed.
select pg_temp.denied(
  format(
    'select * from public.submit_recall_attempt(%L::uuid,%L,%L,%L)',
    :'action_a', 'm5-clean-0001', 'answer', 'deliberately-wrong'
  ),
  'attempt_id_reused',
  'conflicting replay rejected'
);

-- 2) Hint history is server-owned and produces helped_correct, never correct.
select public.reveal_recall_hint(:'action_a', 'm5-hint-0001');
select
  outcome as hint_outcome,
  state_kind as hint_state,
  next_reason_code as hint_reason
from public.submit_recall_attempt(
  :'action_a',
  'm5-hint-0001',
  'answer',
  :'expected_a'
) \gset

select pg_temp.ok(:'hint_outcome' = 'helped_correct', 'hinted exact answer is helped_correct');
select pg_temp.ok(:'hint_state' = 'developing', 'hinted success is not retrieved_once');
select pg_temp.ok(
  :'hint_reason' = 'HINTED_SUCCESS_NEEDS_UNASSISTED_RETRIEVAL',
  'hinted success requires unassisted retry'
);
select pg_temp.ok(
  (select assistance = 'hint' and help_used
   from public.learner_evidence
   where account_id = :user_a and attempt_id = 'm5-hint-0001'),
  'hint assistance persisted canonically'
);

-- 3) Answer exposure cannot be laundered into independent retrieval.
select public.reveal_recall_answer(:'action_a', 'm5-exposed-0001');
select
  outcome as exposed_outcome,
  state_kind as exposed_state,
  next_reason_code as exposed_reason
from public.submit_recall_attempt(
  :'action_a',
  'm5-exposed-0001',
  'answer',
  :'expected_a'
) \gset

select pg_temp.ok(:'exposed_outcome' = 'answer_exposed', 'shown answer remains answer_exposed');
select pg_temp.ok(:'exposed_state' = 'not_assessed', 'shown answer creates no retrieval claim');
select pg_temp.ok(
  :'exposed_reason' = 'ANSWER_EXPOSED_NO_RETRIEVAL_CLAIM',
  'shown answer keeps explicit no-retrieval reason'
);
select pg_temp.ok(
  (select assistance = 'answer_exposed' and help_used
   from public.learner_evidence
   where account_id = :user_a and attempt_id = 'm5-exposed-0001'),
  'answer exposure persisted canonically'
);
select pg_temp.ok(
  (select rule_version = 'recall-evidence-v2'
   from public.learner_evidence
   where account_id = :user_a and attempt_id = 'm5-exposed-0001'),
  'new server Recall evidence uses v2 semantics'
);
select pg_temp.ok(
  (select rule_version = 'recall-state-v2'
   from public.learner_states
   where account_id = :user_a and material_id = :'material_a'),
  'derived learner state uses v2 policy'
);

-- 4) Assistance is monotonic: answer exposure followed by a hint cannot
-- downgrade the attempt to hinted-only evidence.
select public.reveal_recall_answer(:'action_a', 'm5-monotonic-0001');
select public.reveal_recall_hint(:'action_a', 'm5-monotonic-0001');
select pg_temp.ok(
  (select assistance = 'answer_exposed'
   from public.recall_attempt_sessions
   where account_id = :user_a and attempt_id = 'm5-monotonic-0001'),
  'hint cannot downgrade prior answer exposure'
);
select
  outcome as monotonic_outcome,
  state_kind as monotonic_state
from public.submit_recall_attempt(
  :'action_a',
  'm5-monotonic-0001',
  'answer',
  :'expected_a'
) \gset
select pg_temp.ok(:'monotonic_outcome' = 'answer_exposed', 'monotonic assistance controls outcome');
select pg_temp.ok(:'monotonic_state' = 'not_assessed', 'monotonic exposure remains non-positive state');

reset role;

-- 5) Another authenticated learner cannot reveal or submit against A's action.
select set_config('request.jwt.claim.sub', :user_b, false);
set role authenticated;
select pg_temp.ok((select count(*) = 0 from public.recall_actions), 'B cannot list A recall actions');
select pg_temp.ok((select count(*) = 0 from public.learner_evidence), 'B cannot list A recall evidence');
select pg_temp.denied(
  format(
    'select public.reveal_recall_answer(%L::uuid,%L)',
    :'action_a', 'm5-cross-0001'
  ),
  'recall_action_not_found_or_stale',
  'B cannot reveal A answer'
);
select pg_temp.denied(
  format(
    'select * from public.submit_recall_attempt(%L::uuid,%L,%L,%L)',
    :'action_a', 'm5-cross-0001', 'answer', :'expected_a'
  ),
  'recall_action_not_found_or_stale',
  'B cannot submit against A action'
);
reset role;

-- 6) Once an attempt is submitted, support RPCs cannot reopen or mutate it.
select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;
select pg_temp.denied(
  format(
    'select public.reveal_recall_answer(%L::uuid,%L)',
    :'action_a', 'm5-clean-0001'
  ),
  'attempt_id_reused',
  'submitted attempt cannot be reopened with answer exposure'
);
select pg_temp.denied(
  format(
    'select public.reveal_recall_hint(%L::uuid,%L)',
    :'action_a', 'm5-clean-0001'
  ),
  'attempt_id_reused',
  'submitted attempt cannot be reopened with hint'
);
reset role;

rollback;
