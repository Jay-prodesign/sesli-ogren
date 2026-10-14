\set ON_ERROR_STOP on
begin;

\set user_a '''c4000000-0000-4000-8000-000000000001'''
\set user_b '''c4000000-0000-4000-8000-000000000002'''

create or replace function pg_temp.ok(v boolean, msg text)
returns void language plpgsql as $$
begin
  if v is distinct from true then
    raise exception 'unified_retention_assert_failed: %', msg;
  end if;
end $$;

create or replace function pg_temp.expect_retention_error(
  p_material text,
  p_source text,
  p_anchor jsonb,
  p_kind text,
  p_band text,
  p_event text,
  p_review_count integer,
  p_success_streak integer,
  p_reviewed_at timestamptz,
  p_revision bigint,
  p_expected_error text
)
returns void language plpgsql as $$
begin
  begin
    perform public.write_retention_continuity(
      p_material,
      p_source,
      p_anchor,
      p_kind,
      p_band,
      p_event,
      p_review_count,
      p_success_streak,
      p_reviewed_at,
      p_revision
    );
    raise exception 'retention_call_unexpectedly_succeeded';
  exception
    when others then
      if sqlerrm = p_expected_error then
        return;
      end if;
      raise;
  end;
end $$;

insert into auth.users (id, email) values
  (:user_a, 'unified-retention-a@example.test'),
  (:user_b, 'unified-retention-b@example.test');

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;

select *
from public.ensure_text_material_continuity(
  'Biyoloji',
  'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür.',
  'material_unified_retention_0001',
  'sv_unified_retention_0000000000000001',
  null
)
\gset source_

select *
from public.create_recall_continuity_action('material_unified_retention_0001', null)
\gset action_

select *
from public.write_retention_continuity(
  'material_unified_retention_0001',
  'sv_unified_retention_0000000000000001',
  :'action_source_anchor'::jsonb,
  'quiz',
  'independent_retrieval',
  'quiz:event-device-a-0001',
  1,
  1,
  '2026-10-14T08:00:00Z'::timestamptz,
  null
)
\gset quiz1_

select pg_temp.ok(
  :'quiz1_latest_evidence_kind' = 'quiz'
  and :'quiz1_review_count'::integer = 1
  and :'quiz1_success_streak'::integer = 1
  and :'quiz1_interval_seconds'::integer = 86400
  and :'quiz1_revision'::bigint = 1,
  'first Quiz retention snapshot did not create revision 1'
);

-- An ambiguous-network retry is idempotent even when the caller still carries
-- the pre-write expected revision.
select *
from public.write_retention_continuity(
  'material_unified_retention_0001',
  'sv_unified_retention_0000000000000001',
  :'action_source_anchor'::jsonb,
  'quiz',
  'independent_retrieval',
  'quiz:event-device-a-0001',
  1,
  1,
  '2026-10-14T08:00:00Z'::timestamptz,
  null
)
\gset retry_

select pg_temp.ok(
  :'retry_revision'::bigint = 1,
  'idempotent retention retry unexpectedly advanced revision'
);

-- The server rejects a semantic inflation that the real Flashcard flow can
-- never produce. Flashcard self-report is supported/repair evidence only.
select pg_temp.expect_retention_error(
  'material_unified_retention_0001',
  'sv_unified_retention_0000000000000001',
  :'action_source_anchor'::jsonb,
  'flashcard',
  'independent_retrieval',
  'flashcard:forged-independent',
  2,
  2,
  '2026-10-14T08:15:00Z'::timestamptz,
  1,
  'invalid_retention_evidence_outcome'
);

select public.open_recall_continuity_attempt(
  :'action_action_id'::uuid,
  'attempt-unified-retention-0001'
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
  'attempt-unified-retention-0001',
  'answer',
  :'secret_canonical_answer'
)
\gset recall_

select *
from public.read_retention_continuity('material_unified_retention_0001')
\gset after_recall_

select pg_temp.ok(
  :'after_recall_latest_evidence_kind' = 'recall'
  and :'after_recall_review_count'::integer = 2
  and :'after_recall_success_streak'::integer = 2
  and :'after_recall_interval_seconds'::integer = 259200
  and :'after_recall_revision'::bigint = 2,
  'server Recall did not advance the unified Quiz schedule to revision 2'
);

select *
from public.write_retention_continuity(
  'material_unified_retention_0001',
  'sv_unified_retention_0000000000000001',
  :'action_source_anchor'::jsonb,
  'flashcard',
  'supported_retrieval',
  'flashcard:event-device-b-0001',
  3,
  0,
  '2026-10-14T09:00:00Z'::timestamptz,
  2
)
\gset flash_

select pg_temp.ok(
  :'flash_latest_evidence_kind' = 'flashcard'
  and :'flash_review_count'::integer = 3
  and :'flash_success_streak'::integer = 0
  and :'flash_interval_seconds'::integer = 43200
  and :'flash_revision'::bigint = 3,
  'Flashcard continuation did not CAS-advance unified retention'
);

select pg_temp.expect_retention_error(
  'material_unified_retention_0001',
  'sv_unified_retention_0000000000000001',
  :'action_source_anchor'::jsonb,
  'quiz',
  'independent_retrieval',
  'quiz:stale-device-event',
  4,
  1,
  '2026-10-14T10:00:00Z'::timestamptz,
  2,
  'retention_revision_conflict'
);

select pg_temp.expect_retention_error(
  'material_unified_retention_0001',
  'sv_unified_retention_0000000000000001',
  :'action_source_anchor'::jsonb,
  'recall',
  'independent_retrieval',
  'recall:client-forgery',
  4,
  1,
  '2026-10-14T10:00:00Z'::timestamptz,
  3,
  'invalid_retention_evidence_kind'
);

reset role;
select set_config('request.jwt.claim.sub', :user_b, false);
set role authenticated;

select count(*)::integer as foreign_count
from public.read_retention_continuity('material_unified_retention_0001')
\gset other_

select pg_temp.ok(
  :'other_foreign_count'::integer = 0,
  'unified retention crossed account tenancy'
);

reset role;
select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;

select *
from public.ensure_text_material_continuity(
  'Biyoloji güncel',
  'Klorofil ışığın soğurulmasına yardım eder.',
  'material_unified_retention_0001',
  'sv_unified_retention_0000000000000002',
  'sv_unified_retention_0000000000000001'
)
\gset replacement_

select count(*)::integer as current_count
from public.read_retention_continuity('material_unified_retention_0001')
\gset replaced_

select pg_temp.ok(
  :'replaced_current_count'::integer = 0,
  'retention from a replaced source remained visible as current timing'
);

reset role;
rollback;
