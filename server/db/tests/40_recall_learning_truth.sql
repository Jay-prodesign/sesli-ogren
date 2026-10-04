\set ON_ERROR_STOP on

begin;

-- Assumes M4 core/RPC migrations + 0003_recall_learning_truth.sql.
-- Existing Architecture Proof harness creates auth.users and can set request.jwt.claim.sub.

do $$
begin
  if to_regclass('public.recall_actions') is null
     or to_regclass('public.learner_evidence') is null
     or to_regclass('public.learner_states') is null then
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
     or public.la_recall_state_for_outcome('unknown') <> 'needs_review' then
    raise exception 'state derivation mismatch';
  end if;
end $$;

rollback;
