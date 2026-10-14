\set ON_ERROR_STOP on
begin;

\set user_a '''c4000000-0000-4000-8000-000000000001'''
\set user_b '''c4000000-0000-4000-8000-000000000002'''

create or replace function pg_temp.ok(v boolean, msg text)
returns void language plpgsql as $$
begin
  if v is distinct from true then
    raise exception 'media_continuity_assert_failed: %', msg;
  end if;
end $$;

create or replace function pg_temp.expect_media_error(
  p_expected text,
  p_call text
)
returns void language plpgsql as $$
begin
  begin
    execute p_call;
    raise exception 'media_call_unexpectedly_succeeded';
  exception
    when others then
      if sqlerrm = p_expected then
        return;
      end if;
      raise;
  end;
end $$;

insert into auth.users (id, email) values
  (:user_a, 'media-continuity-a@example.test'),
  (:user_b, 'media-continuity-b@example.test');

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;

select *
from public.prepare_media_material_continuity(
  'Ders notu.docx',
  'material_media_continuity_0001',
  'sv_media_continuity_00000000000000000001',
  null,
  'document',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  2048,
  repeat('a', 64)
)
\gset prepared_

select pg_temp.ok(
  :'prepared_storage_bucket' = 'study-materials'
  and :'prepared_already_current'::boolean = false
  and :'prepared_storage_path' =
      :user_a::text || '/' || :'prepared_material_id'::text || '/sv_media_continuity_00000000000000000001',
  'media prepare did not return the owner/material scoped private storage path'
);

insert into storage.objects(bucket_id, name, owner, owner_id, metadata)
values(
  'study-materials',
  :'prepared_storage_path',
  :user_a,
  :user_a::text,
  jsonb_build_object('size', 2048, 'mimetype', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document')
);

select *
from public.finalize_media_material_continuity(
  'Ders notu.docx',
  'material_media_continuity_0001',
  'sv_media_continuity_00000000000000000001',
  null,
  'document',
  'Ders notu.docx',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  2048,
  repeat('a', 64),
  'study-materials',
  :'prepared_storage_path',
  'Birinci bölüm öğrenme için kaynak metnidir.',
  'office_openxml_text',
  'openxml-v1',
  '[{"startOffset":0,"endOffset":42}]'::jsonb,
  '["Layout sadeleştirildi"]'::jsonb
)
\gset first_

select *
from public.read_material_continuity_v2('material_media_continuity_0001')
\gset read1_

select pg_temp.ok(
  :'read1_source_type' = 'document'
  and :'read1_source_name' = 'Ders notu.docx'
  and :'read1_storage_path' = :'prepared_storage_path'
  and :'read1_extraction_method' = 'office_openxml_text'
  and :'read1_extraction_method_version' = 'openxml-v1'
  and :'read1_warnings'::jsonb = '["Layout sadeleştirildi"]'::jsonb
  and :'read1_client_source_id' = 'sv_media_continuity_00000000000000000001',
  'media continuity read lost original-media or extraction provenance'
);

select *
from public.prepare_media_material_continuity(
  'Ders notu.docx',
  'material_media_continuity_0001',
  'sv_media_continuity_00000000000000000001',
  null,
  'document',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  2048,
  repeat('a', 64)
)
\gset replay_

select pg_temp.ok(
  :'replay_already_current'::boolean = true
  and :'replay_storage_path' = :'prepared_storage_path',
  'exact media replay was not idempotent'
);

select *
from public.prepare_media_material_continuity(
  'Tahta fotoğrafı.jpg',
  'material_media_continuity_0001',
  'sv_media_continuity_00000000000000000002',
  'sv_media_continuity_00000000000000000001',
  'image',
  'image/jpeg',
  4096,
  repeat('b', 64)
)
\gset prepared2_

insert into storage.objects(bucket_id, name, owner, owner_id, metadata)
values(
  'study-materials',
  :'prepared2_storage_path',
  :user_a,
  :user_a::text,
  jsonb_build_object('size', 4096, 'mimetype', 'image/jpeg')
);

select *
from public.finalize_media_material_continuity(
  'Tahta fotoğrafı.jpg',
  'material_media_continuity_0001',
  'sv_media_continuity_00000000000000000002',
  'sv_media_continuity_00000000000000000001',
  'image',
  'Tahta fotoğrafı.jpg',
  'image/jpeg',
  4096,
  repeat('b', 64),
  'study-materials',
  :'prepared2_storage_path',
  'Fotosentez klorofil ve ışık ilişkisini açıklar.',
  'mlkit_ocr',
  'mlkit-text-recognition-0.17.1',
  '[{"startOffset":0,"endOffset":45}]'::jsonb,
  '[]'::jsonb
)
\gset second_

select pg_temp.ok(
  :'second_material_id'::uuid = :'first_material_id'::uuid
  and :'second_source_version'::integer = 2
  and :'second_superseded_storage_path' = :'prepared_storage_path',
  'media replacement did not preserve Material lineage or expose superseded object cleanup'
);

select pg_temp.ok(
  (
    select revoked_at is not null
    from public.source_assets
    where id = :'first_source_asset_id'::uuid
  ) is not true,
  'owner RLS unexpectedly exposed revoked media source'
);

delete from storage.objects
where bucket_id = 'study-materials'
  and name = :'second_superseded_storage_path';

select pg_temp.ok(
  not exists (
    select 1
    from storage.objects
    where bucket_id = 'study-materials'
      and name = :'prepared_storage_path'
  ),
  'owner could not remove superseded raw media through storage RLS'
);

select count(*)::integer as visible_count
from public.list_material_continuity_v2()
\gset list_a_

select pg_temp.ok(
  :'list_a_visible_count'::integer = 1,
  'media library continuity did not collapse to one current material'
);

reset role;
set role service_role;

select pg_temp.ok(
  (
    select revoked_at is not null
    from public.source_assets
    where id = :'first_source_asset_id'::uuid
  ),
  'previous media source was not revoked after replacement'
);

reset role;
select set_config('request.jwt.claim.sub', :user_b, false);
set role authenticated;

select count(*)::integer as foreign_count
from public.list_material_continuity_v2()
\gset list_b_

select pg_temp.ok(
  :'list_b_foreign_count'::integer = 0,
  'media continuity crossed account tenancy'
);

reset role;
rollback;
