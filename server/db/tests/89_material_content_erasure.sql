\set ON_ERROR_STOP on
begin;

\set user_a '''d9000000-0000-4000-8000-000000000001'''
\set user_b '''d9000000-0000-4000-8000-000000000002'''

create or replace function pg_temp.ok(v boolean, msg text)
returns void language plpgsql as $$
begin
  if v is distinct from true then
    raise exception 'material_erasure_assert_failed: %', msg;
  end if;
end $$;

insert into auth.users (id, email) values
  (:user_a, 'material-erasure-a@example.test'),
  (:user_b, 'material-erasure-b@example.test');

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;
select public.create_text_material(
  'Private biology note',
  'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür.'
) as material_a \gset
select public.request_summary(
  :'material_a'::uuid,
  'material-erasure-summary-0001',
  false
) as job_a \gset
reset role;

set role service_role;
select attempt_id as attempt_a, lease_token as lease_a
from public.claim_generation_job_by_id(:'job_a'::uuid, 120)
\gset

select public.mark_attempt_dispatched(
  :'attempt_a'::uuid,
  :'lease_a'::uuid,
  'test:material-erasure'
);

select public.complete_generation_attempt(
  :'attempt_a'::uuid,
  :'lease_a'::uuid,
  '{"summary":"Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür.","key_points":["Işık enerjisi kullanılır"],"language":"tr-TR"}'::jsonb,
  'test-material-erasure-provider',
  '{"total_tokens":12,"cost_class":"test"}'::jsonb,
  8
) as artifact_a
\gset
reset role;

select set_config('request.jwt.claim.sub', :user_b, false);
set role authenticated;
select public.create_text_material(
  'Other learner note',
  'Mitokondri hücresel solunum sırasında enerji üretimine katkı sağlar.'
) as material_b \gset
reset role;

select pg_temp.ok(
  exists(select 1 from public.source_assets where material_id = :'material_a'::uuid and inline_text is not null),
  'fixture did not persist learner source text before deletion'
);
select pg_temp.ok(
  exists(
    select 1
    from public.extracted_contents e
    join public.source_assets s on s.id = e.source_asset_id
    where s.material_id = :'material_a'::uuid
      and length(e.normalized_text) > 0
  ),
  'fixture did not persist extracted learner text before deletion'
);
select pg_temp.ok(
  exists(select 1 from public.artifacts where id = :'artifact_a'::uuid),
  'fixture did not persist generated content before deletion'
);

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;
select public.delete_material(:'material_a'::uuid);
-- Owner replay is intentionally idempotent.
select public.delete_material(:'material_a'::uuid);
reset role;

select pg_temp.ok(
  (
    select lifecycle_status = 'deleted'
       and title = 'Deleted material'
       and deleted_at is not null
    from public.materials
    where id = :'material_a'::uuid
  ),
  'minimal material tombstone was not preserved'
);
select pg_temp.ok(
  not exists(select 1 from public.source_assets where material_id = :'material_a'::uuid),
  'learner source payload survived material deletion'
);
select pg_temp.ok(
  not exists(
    select 1
    from public.extracted_contents e
    join public.source_assets s on s.id = e.source_asset_id
    where s.material_id = :'material_a'::uuid
  ),
  'extracted learner text survived material deletion'
);
select pg_temp.ok(
  not exists(select 1 from public.generation_jobs where material_id = :'material_a'::uuid),
  'generation job survived material deletion'
);
select pg_temp.ok(
  not exists(select 1 from public.generation_attempts where id = :'attempt_a'::uuid),
  'generation attempt survived material deletion'
);
select pg_temp.ok(
  not exists(select 1 from public.artifacts where material_id = :'material_a'::uuid),
  'generated artifact content survived material deletion'
);
select pg_temp.ok(
  exists(
    select 1
    from public.usage_events
    where account_id = :user_a
      and generation_job_id is null
      and generation_attempt_id is null
  ),
  'aggregate usage accounting should survive without content-bearing generation references'
);
select pg_temp.ok(
  exists(
    select 1
    from public.materials m
    join public.source_assets s on s.material_id = m.id
    where m.id = :'material_b'::uuid
      and m.lifecycle_status = 'active'
      and s.inline_text is not null
  ),
  'deleting one learner material touched another learner'
);

select set_config('request.jwt.claim.sub', :user_b, false);
set role authenticated;
do $$
begin
  begin
    perform public.delete_material(:'material_a'::uuid);
    raise exception 'cross_owner_delete_unexpectedly_succeeded';
  exception
    when no_data_found then
      null;
    when others then
      if sqlerrm <> 'material_not_found' then
        raise;
      end if;
  end;
end
$$;
reset role;

rollback;
