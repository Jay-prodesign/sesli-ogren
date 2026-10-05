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
end $$;


do $$
begin
  if public.la_recall_next_reason('not_assessed') <> 'NO_EVALUABLE_RETRIEVAL' then
    raise exception 'not_assessed Recall must preserve NO_EVALUABLE_RETRIEVAL continuation reason';
  end if;
end
$$;

rollback;
