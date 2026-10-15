\set ON_ERROR_STOP on
begin;

\set user_a '''c3000000-0000-4000-8000-000000000001'''
\set user_b '''c3000000-0000-4000-8000-000000000002'''

create or replace function pg_temp.ok(v boolean, msg text)
returns void language plpgsql as $$
begin
  if v is distinct from true then
    raise exception 'retention_continuity_assert_failed: %', msg;
  end if;
end $$;

insert into auth.users (id, email) values
  (:user_a, 'retention-continuity-a@example.test'),
  (:user_b, 'retention-continuity-b@example.test');

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;

select *
from public.ensure_text_material_continuity(
  'Biyoloji',
  'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür.',
  'material_retention_continuity_0001',
  'sv_retention_continuity_0000000000000001',
  null
)
\gset source_

select *
from public.create_recall_continuity_action('material_retention_continuity_0001', null)
\gset action_

reset role;
set role service_role;
select expected_answer as canonical_answer
from public.recall_actions
where id = :'action_action_id'::uuid
\gset secret_
reset role;
set role authenticated;

select public.open_recall_continuity_attempt(
  :'action_action_id'::uuid,
  'attempt-retention-continuity-0001'
);
select *
from public.submit_recall_continuity_attempt(
  :'action_action_id'::uuid,
  'attempt-retention-continuity-0001',
  'answer',
  :'secret_canonical_answer'
)
\gset first_

select *
from public.read_recall_retention_continuity('material_retention_continuity_0001')
\gset schedule1_

select pg_temp.ok(
  :'schedule1_latest_outcome_band' = 'independent_retrieval'
  and :'schedule1_review_count'::integer = 1
  and :'schedule1_success_streak'::integer = 1
  and :'schedule1_interval_seconds'::integer = 86400
  and :'schedule1_reason_code' = 'INDEPENDENT_RETRIEVAL_OBSERVED'
  and :'schedule1_policy_version' = 'retention-v1',
  'first unassisted server Recall did not create the canonical 1-day retention schedule'
);

select *
from public.create_recall_continuity_action('material_retention_continuity_0001', null)
\gset action2_

select public.open_recall_continuity_attempt(
  :'action2_action_id'::uuid,
  'attempt-retention-continuity-0002'
);
select *
from public.submit_recall_continuity_attempt(
  :'action2_action_id'::uuid,
  'attempt-retention-continuity-0002',
  'answer',
  :'secret_canonical_answer'
)
\gset second_

select *
from public.read_recall_retention_continuity('material_retention_continuity_0001')
\gset schedule2_

select pg_temp.ok(
  :'schedule2_review_count'::integer = 2
  and :'schedule2_success_streak'::integer = 2
  and :'schedule2_interval_seconds'::integer = 259200,
  'second unassisted retrieval did not advance the canonical retention streak to 3 days'
);

select *
from public.create_recall_continuity_action('material_retention_continuity_0001', null)
\gset action3_

select public.open_recall_continuity_attempt(
  :'action3_action_id'::uuid,
  'attempt-retention-continuity-0003'
);
select *
from public.submit_recall_continuity_attempt(
  :'action3_action_id'::uuid,
  'attempt-retention-continuity-0003',
  'answer',
  'yanlis'
)
\gset third_

select *
from public.read_recall_retention_continuity('material_retention_continuity_0001')
\gset schedule3_

select pg_temp.ok(
  :'schedule3_latest_outcome_band' = 'repair_needed'
  and :'schedule3_success_streak'::integer = 0
  and :'schedule3_interval_seconds'::integer = 600
  and :'schedule3_reason_code' = 'RETRIEVAL_REPAIR_NEEDED',
  'incorrect retrieval did not reset the server streak and schedule repair'
);

select *
from public.ensure_text_material_continuity(
  'Biyoloji güncel',
  'Klorofil ışığın soğurulmasına yardım eder.',
  'material_retention_continuity_0001',
  'sv_retention_continuity_0000000000000002',
  'sv_retention_continuity_0000000000000001'
)
\gset replacement_

select count(*)::integer as visible_schedules
from public.read_recall_retention_continuity('material_retention_continuity_0001')
\gset after_replace_

select pg_temp.ok(
  :'after_replace_visible_schedules'::integer = 0,
  'retention from a replaced source remained visible as current truth'
);

reset role;

select set_config('request.jwt.claim.sub', :user_b, false);
set role authenticated;
select count(*)::integer as foreign_schedules
from public.read_recall_retention_continuity('material_retention_continuity_0001')
\gset other_

select pg_temp.ok(
  :'other_foreign_schedules'::integer = 0,
  'retention continuity crossed account tenancy'
);

reset role;
rollback;
