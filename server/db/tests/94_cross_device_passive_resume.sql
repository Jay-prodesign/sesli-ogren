\set ON_ERROR_STOP on
begin;

\set user_a '''c5000000-0000-4000-8000-000000000001'''
\set user_b '''c5000000-0000-4000-8000-000000000002'''

create or replace function pg_temp.ok(v boolean, msg text)
returns void language plpgsql as $$
begin
  if v is distinct from true then
    raise exception 'passive_resume_assert_failed: %', msg;
  end if;
end $$;

create or replace function pg_temp.expect_resume_conflict(
  p_material text,
  p_source text,
  p_surface text,
  p_progress double precision,
  p_chunk integer,
  p_revision bigint,
  p_update text
)
returns void language plpgsql as $$
begin
  begin
    perform public.write_passive_resume_continuity(
      p_material, p_source, p_surface, p_progress, p_chunk, p_revision, p_update
    );
    raise exception 'resume_conflict_unexpectedly_succeeded';
  exception
    when others then
      if sqlerrm = 'resume_revision_conflict' then
        return;
      end if;
      raise;
  end;
end $$;

insert into auth.users(id, email) values
  (:user_a, 'resume-a@example.test'),
  (:user_b, 'resume-b@example.test');

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;

select *
from public.ensure_text_material_continuity(
  'Biyoloji',
  'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür.',
  'material_passive_resume_0001',
  'sv_passive_resume_000000000000000001',
  null
)
\gset source_

select *
from public.write_passive_resume_continuity(
  'material_passive_resume_0001',
  'sv_passive_resume_000000000000000001',
  'reader',
  0.35,
  null,
  null,
  'reader-update-00000001'
)
\gset reader1_

select pg_temp.ok(
  :'reader1_revision'::bigint = 1
  and abs(:'reader1_reader_progress'::double precision - 0.35) < 0.000001,
  'first Reader resume was not written at revision 1'
);

select *
from public.write_passive_resume_continuity(
  'material_passive_resume_0001',
  'sv_passive_resume_000000000000000001',
  'reader',
  0.35,
  null,
  null,
  'reader-update-00000001'
)
\gset reader_replay_

select pg_temp.ok(
  :'reader_replay_revision'::bigint = 1
  and abs(:'reader_replay_reader_progress'::double precision - 0.35) < 0.000001,
  'Reader idempotent replay advanced or changed canonical resume'
);

select *
from public.write_passive_resume_continuity(
  'material_passive_resume_0001',
  'sv_passive_resume_000000000000000001',
  'reader',
  0.80,
  null,
  1,
  'reader-update-00000002'
)
\gset reader2_

select pg_temp.ok(
  :'reader2_revision'::bigint = 2
  and abs(:'reader2_reader_progress'::double precision - 0.80) < 0.000001,
  'Reader CAS update did not advance revision'
);

select pg_temp.expect_resume_conflict(
  'material_passive_resume_0001',
  'sv_passive_resume_000000000000000001',
  'reader',
  0.20,
  null,
  1,
  'reader-stale-00000001'
);

select *
from public.write_passive_resume_continuity(
  'material_passive_resume_0001',
  'sv_passive_resume_000000000000000001',
  'listen',
  null,
  4,
  null,
  'listen-update-00000001'
)
\gset listen1_

select pg_temp.ok(
  :'listen1_revision'::bigint = 1
  and :'listen1_listen_chunk_index'::integer = 4,
  'Listen resume did not maintain an independent revision stream'
);

select count(*)::integer as visible_count
from public.read_passive_resume_continuity('material_passive_resume_0001')
\gset before_replace_

select pg_temp.ok(
  :'before_replace_visible_count'::integer = 2,
  'Reader and Listen resume were not both visible for the current source'
);

select *
from public.ensure_text_material_continuity(
  'Biyoloji güncel',
  'Klorofil ışığın soğurulmasına yardım eder.',
  'material_passive_resume_0001',
  'sv_passive_resume_000000000000000002',
  'sv_passive_resume_000000000000000001'
)
\gset replacement_

select count(*)::integer as visible_count
from public.read_passive_resume_continuity('material_passive_resume_0001')
\gset after_replace_

select pg_temp.ok(
  :'after_replace_visible_count'::integer = 0,
  'passive resume survived a SourceVersion replacement'
);

reset role;
select set_config('request.jwt.claim.sub', :user_b, false);
set role authenticated;

select count(*)::integer as visible_count
from public.read_passive_resume_continuity('material_passive_resume_0001')
\gset other_

select pg_temp.ok(
  :'other_visible_count'::integer = 0,
  'passive resume crossed account tenancy'
);

reset role;
rollback;
