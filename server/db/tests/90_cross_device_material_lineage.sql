\set ON_ERROR_STOP on
begin;

\set user_a '''c1000000-0000-4000-8000-000000000001'''
\set user_b '''c1000000-0000-4000-8000-000000000002'''

create or replace function pg_temp.ok(v boolean, msg text)
returns void language plpgsql as $$
begin
  if v is distinct from true then
    raise exception 'continuity_assert_failed: %', msg;
  end if;
end $$;

create or replace function pg_temp.expect_continuity_error(
  p_title text,
  p_text text,
  p_material_key text,
  p_source_key text,
  p_expected_previous text,
  p_expected_error text
)
returns void language plpgsql as $$
begin
  begin
    perform public.ensure_text_material_continuity(
      p_title,
      p_text,
      p_material_key,
      p_source_key,
      p_expected_previous
    );
    raise exception 'continuity_call_unexpectedly_succeeded';
  exception
    when others then
      if sqlerrm = p_expected_error then
        return;
      end if;
      raise;
  end;
end $$;

insert into auth.users (id, email) values
  (:user_a, 'continuity-a@example.test'),
  (:user_b, 'continuity-b@example.test');

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;

select *
from public.ensure_text_material_continuity(
  'Biyoloji notu',
  'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür.',
  'material_cross_device_0001',
  'sv_cross_device_000000000000000000000001',
  null
)
\gset first_

select *
from public.ensure_text_material_continuity(
  'Biyoloji notu',
  'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür.',
  'material_cross_device_0001',
  'sv_cross_device_000000000000000000000001',
  null
)
\gset replay_

select pg_temp.ok(
  :'first_material_id'::uuid = :'replay_material_id'::uuid
  and :'first_source_asset_id'::uuid = :'replay_source_asset_id'::uuid
  and :'first_extracted_content_id'::uuid = :'replay_extracted_content_id'::uuid,
  'exact cross-device replay duplicated canonical material/source rows'
);

select pg_temp.ok(
  (
    select count(*) = 1
    from public.materials
    where account_id = :user_a
      and client_material_key = 'material_cross_device_0001'
      and lifecycle_status = 'active'
  ),
  'stable material lineage did not collapse replay'
);

select pg_temp.expect_continuity_error(
  'Biyoloji notu',
  'Aynı SourceVersion kimliği farklı içerikle tekrar kullanılamaz.',
  'material_cross_device_0001',
  'sv_cross_device_000000000000000000000001',
  null,
  'idempotency_key_reused'
);

select *
from public.ensure_text_material_continuity(
  'Biyoloji notu — güncel',
  'Klorofil ışığın soğurulmasına yardım eder.',
  'material_cross_device_0001',
  'sv_cross_device_000000000000000000000002',
  'sv_cross_device_000000000000000000000001'
)
\gset second_

select pg_temp.ok(
  :'first_material_id'::uuid = :'second_material_id'::uuid
  and :'first_source_asset_id'::uuid <> :'second_source_asset_id'::uuid
  and :'second_source_version'::integer = 2,
  'source replacement did not preserve Material lineage and advance Source lineage'
);

reset role;
set role service_role;

select pg_temp.ok(
  (
    select revoked_at is not null
    from public.source_assets
    where id = :'first_source_asset_id'::uuid
  ),
  'previous canonical source was not revoked after replacement'
);

select pg_temp.ok(
  (
    select invalidated_at is not null
    from public.extracted_contents
    where id = :'first_extracted_content_id'::uuid
  ),
  'previous extracted source truth was not invalidated after replacement'
);

reset role;
set role authenticated;

select pg_temp.expect_continuity_error(
  'Stale device',
  'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür.',
  'material_cross_device_0001',
  'sv_cross_device_000000000000000000000001',
  null,
  'source_conflict'
);

select pg_temp.expect_continuity_error(
  'Stale device',
  'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür.',
  'material_cross_device_0001',
  'sv_cross_device_000000000000000000000001',
  'sv_cross_device_000000000000000000000002',
  'stale_client_source_version'
);

select *
from public.read_material_continuity('material_cross_device_0001')
\gset current_

select pg_temp.ok(
  :'current_material_id'::uuid = :'first_material_id'::uuid
  and :'current_client_source_id' = 'sv_cross_device_000000000000000000000002'
  and :'current_normalized_text' = 'Klorofil ışığın soğurulmasına yardım eder.',
  'continuity read did not expose the exact current source truth'
);

select public.ensure_text_material(
  'Legacy mirror',
  'Mitokondri hücresel solunum sırasında enerji üretimine katkı sağlar.',
  'sv_legacy_cross_device_00000001'
) as legacy_material
\gset

select *
from public.ensure_text_material_continuity(
  'Legacy mirror',
  'Mitokondri hücresel solunum sırasında enerji üretimine katkı sağlar.',
  'material_legacy_cross_device_0001',
  'sv_legacy_cross_device_00000001',
  null
)
\gset legacy_

select pg_temp.ok(
  :'legacy_material'::uuid = :'legacy_material_id'::uuid,
  'legacy server mirror was duplicated instead of adopting stable Material lineage'
);

reset role;

select set_config('request.jwt.claim.sub', :user_b, false);
set role authenticated;

select *
from public.ensure_text_material_continuity(
  'Biyoloji notu',
  'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür.',
  'material_cross_device_0001',
  'sv_cross_device_000000000000000000000001',
  null
)
\gset other_

select pg_temp.ok(
  :'other_material_id'::uuid <> :'first_material_id'::uuid,
  'cross-device lineage leaked across account tenancy'
);

select *
from public.read_material_continuity('material_cross_device_0001')
\gset other_read_

select pg_temp.ok(
  :'other_read_material_id'::uuid = :'other_material_id'::uuid
  and :'other_read_client_source_id' = 'sv_cross_device_000000000000000000000001',
  'tenant continuity read escaped the authenticated learner namespace'
);

reset role;
rollback;
