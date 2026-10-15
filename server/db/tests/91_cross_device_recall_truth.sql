\set ON_ERROR_STOP on
begin;

\set user_a '''c2000000-0000-4000-8000-000000000001'''
\set user_b '''c2000000-0000-4000-8000-000000000002'''

create or replace function pg_temp.ok(v boolean, msg text)
returns void language plpgsql as $$
begin
  if v is distinct from true then
    raise exception 'recall_continuity_assert_failed: %', msg;
  end if;
end $$;

create or replace function pg_temp.expect_stale_submit(p_action uuid, p_attempt text)
returns void language plpgsql as $$
begin
  begin
    perform public.submit_recall_continuity_attempt(p_action, p_attempt, 'unknown', '');
    raise exception 'stale_recall_submit_unexpectedly_succeeded';
  exception
    when others then
      if sqlerrm = 'recall_action_not_found_or_stale' then
        return;
      end if;
      raise;
  end;
end $$;

insert into auth.users (id, email) values
  (:user_a, 'recall-continuity-a@example.test'),
  (:user_b, 'recall-continuity-b@example.test');

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;

select *
from public.ensure_text_material_continuity(
  'Biyoloji',
  'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür. Klorofil ışığın soğurulmasına yardım eder.',
  'material_recall_continuity_0001',
  'sv_recall_continuity_000000000000000001',
  null
)
\gset source_

select *
from public.create_recall_continuity_action(
  'material_recall_continuity_0001',
  null
)
\gset action_

select pg_temp.ok(
  :'action_client_material_id' = 'material_recall_continuity_0001'
  and :'action_client_source_id' = 'sv_recall_continuity_000000000000000001'
  and position('_____' in :'action_prompt_text') > 0,
  'server Recall action did not preserve client material/source lineage'
);

select public.open_recall_continuity_attempt(
  :'action_action_id'::uuid,
  'attempt-recall-continuity-0001'
) as assistance
\gset opened_

select pg_temp.ok(
  :'opened_assistance' = 'none',
  'new cross-device Recall attempt did not start unassisted'
);

reset role;
set role service_role;
select expected_answer as canonical_answer
from public.recall_actions
where id = :'action_action_id'::uuid
\gset secret_
reset role;
set role authenticated;

select *
from public.submit_recall_continuity_attempt(
  :'action_action_id'::uuid,
  'attempt-recall-continuity-0001',
  'answer',
  :'secret_canonical_answer'
)
\gset result_

select pg_temp.ok(
  :'result_outcome' = 'correct'
  and :'result_state_kind' = 'retrieved_once'
  and :'result_assistance' = 'none'
  and :'result_correct_answer' = :'secret_canonical_answer'
  and position(:'secret_canonical_answer' in :'result_source_excerpt') > 0
  and :'result_client_source_id' = 'sv_recall_continuity_000000000000000001',
  'server-authoritative Recall result lost outcome, assistance, or exact source evidence'
);

select *
from public.read_latest_recall_continuity('material_recall_continuity_0001')
\gset latest_

select pg_temp.ok(
  :'latest_evidence_id'::uuid = :'result_evidence_id'::uuid
  and :'latest_action_id'::uuid = :'action_action_id'::uuid
  and :'latest_outcome' = 'correct'
  and :'latest_client_source_id' = 'sv_recall_continuity_000000000000000001',
  'second-device Recall projection did not reopen latest canonical evidence'
);

select *
from public.create_recall_continuity_action(
  'material_recall_continuity_0001',
  '{"startOffset":57,"endOffset":99}'::jsonb
)
\gset anchored_

select pg_temp.ok(
  (:'anchored_source_anchor'::jsonb ->> 'startOffset')::integer >= 0
  and position('_____' in :'anchored_prompt_text') > 0,
  'anchored Recall action was not source-grounded'
);

select public.open_recall_continuity_attempt(
  :'anchored_action_id'::uuid,
  'attempt-recall-continuity-hint'
);
select public.reveal_recall_hint(
  :'anchored_action_id'::uuid,
  'attempt-recall-continuity-hint'
) as hint_text
\gset hint_
select *
from public.submit_recall_continuity_attempt(
  :'anchored_action_id'::uuid,
  'attempt-recall-continuity-hint',
  'unknown',
  ''
)
\gset hinted_

select pg_temp.ok(
  :'hinted_outcome' = 'unknown'
  and :'hinted_assistance' = 'hint',
  'server assistance truth was not preserved through continuity submission'
);

select *
from public.ensure_text_material_continuity(
  'Biyoloji güncel',
  'Mitokondri hücresel solunum sırasında ATP üretimine katkı sağlar.',
  'material_recall_continuity_0001',
  'sv_recall_continuity_000000000000000002',
  'sv_recall_continuity_000000000000000001'
)
\gset replacement_

select pg_temp.expect_stale_submit(
  :'action_action_id'::uuid,
  'attempt-recall-continuity-stale'
);

reset role;

select set_config('request.jwt.claim.sub', :user_b, false);
set role authenticated;
select count(*)::integer as foreign_latest
from public.read_latest_recall_continuity('material_recall_continuity_0001')
\gset other_

select pg_temp.ok(
  :'other_foreign_latest'::integer = 0,
  'Recall continuity projection crossed account tenancy'
);

reset role;
rollback;
