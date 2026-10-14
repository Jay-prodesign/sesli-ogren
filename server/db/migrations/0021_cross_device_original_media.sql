\set ON_ERROR_STOP on

-- Original-media cross-device continuity. The existing private study-materials
-- bucket remains the only raw-source authority; this migration only binds its
-- owner-scoped object path to canonical Material / SourceAsset lineage.
alter table public.materials
  drop constraint if exists materials_material_type_check;
alter table public.materials
  add constraint materials_material_type_check
  check (material_type in ('text', 'pdf', 'image', 'document', 'presentation'));

alter table public.source_assets
  drop constraint if exists source_assets_source_type_check;
alter table public.source_assets
  add constraint source_assets_source_type_check
  check (source_type in ('pasted_text', 'pdf', 'image', 'document', 'presentation'));

alter table public.source_assets
  add column if not exists source_name text;

alter table public.source_assets
  drop constraint if exists source_assets_source_name_check;
alter table public.source_assets
  add constraint source_assets_source_name_check
  check (source_name is null or length(btrim(source_name)) between 1 and 300);

create or replace function public.prepare_media_material_continuity(
  p_title text,
  p_client_material_id text,
  p_client_source_id text,
  p_expected_previous_source_id text,
  p_source_type text,
  p_mime_type text,
  p_byte_size bigint,
  p_content_hash text
)
returns table (
  material_id uuid,
  storage_bucket text,
  storage_path text,
  already_current boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := public.la_require_user();
  v_title text := btrim(coalesce(p_title, ''));
  v_material_key text := btrim(coalesce(p_client_material_id, ''));
  v_source_key text := btrim(coalesce(p_client_source_id, ''));
  v_expected_key text := nullif(btrim(coalesce(p_expected_previous_source_id, '')), '');
  v_source_type text := btrim(coalesce(p_source_type, ''));
  v_mime_type text := btrim(coalesce(p_mime_type, ''));
  v_material_type text;
  v_material uuid;
  v_current_key text;
  v_current_hash text;
  v_current_type text;
  v_current_mime text;
  v_current_size bigint;
  v_current_path text;
  v_path text;
begin
  if v_material_key !~ '^[A-Za-z0-9_.:-]{8,128}$' then
    raise exception 'invalid_client_material_id' using errcode = '22023';
  end if;
  if v_source_key !~ '^[A-Za-z0-9_.:-]{8,128}$' then
    raise exception 'invalid_client_source_id' using errcode = '22023';
  end if;
  if v_expected_key is not null
     and v_expected_key !~ '^[A-Za-z0-9_.:-]{8,128}$' then
    raise exception 'invalid_expected_source_id' using errcode = '22023';
  end if;
  if length(v_title) = 0 or length(v_title) > 300 then
    raise exception 'invalid_material_title' using errcode = '22023';
  end if;
  if v_source_type not in ('pdf', 'image', 'document', 'presentation') then
    raise exception 'invalid_media_source_type' using errcode = '22023';
  end if;
  if length(v_mime_type) = 0 or length(v_mime_type) > 200 then
    raise exception 'invalid_media_mime_type' using errcode = '22023';
  end if;
  if p_byte_size is null or p_byte_size <= 0 or p_byte_size > 52428800 then
    raise exception 'invalid_media_byte_size' using errcode = '22023';
  end if;
  if p_content_hash is null or p_content_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'invalid_media_content_hash' using errcode = '22023';
  end if;

  v_material_type := v_source_type;

  select m.id
    into v_material
  from public.materials m
  where m.account_id = v_user
    and m.client_material_key = v_material_key
    and m.lifecycle_status = 'active'
  for update;

  if v_material is null then
    begin
      insert into public.materials (
        account_id,
        title,
        material_type,
        lifecycle_status,
        processing_state,
        client_material_key
      )
      values (
        v_user,
        v_title,
        v_material_type,
        'active',
        'processing',
        v_material_key
      )
      returning id into v_material;
    exception
      when unique_violation then
        select m.id
          into v_material
        from public.materials m
        where m.account_id = v_user
          and m.client_material_key = v_material_key
          and m.lifecycle_status = 'active'
        for update;
        if v_material is null then
          raise;
        end if;
    end;
  end if;

  select s.client_source_version_key,
         s.content_hash,
         s.source_type,
         s.mime_type,
         s.byte_size,
         s.storage_path
    into v_current_key,
         v_current_hash,
         v_current_type,
         v_current_mime,
         v_current_size,
         v_current_path
  from public.source_assets s
  join public.extracted_contents e
    on e.source_asset_id = s.id
   and e.account_id = v_user
   and e.invalidated_at is null
  where s.account_id = v_user
    and s.material_id = v_material
    and s.revoked_at is null
  order by s.source_version desc, e.created_at desc
  limit 1
  for update of s;

  if v_current_key = v_source_key then
    if v_current_hash <> p_content_hash
       or v_current_type <> v_source_type
       or v_current_mime <> v_mime_type
       or v_current_size <> p_byte_size
       or v_current_path is null then
      raise exception 'idempotency_key_reused' using errcode = '22023';
    end if;

    return query
    select v_material, 'study-materials'::text, v_current_path, true;
    return;
  end if;

  if v_current_key is not null
     and (v_expected_key is null or v_expected_key <> v_current_key) then
    raise exception 'source_conflict' using errcode = 'P0001';
  end if;
  if v_current_key is null and v_expected_key is not null then
    raise exception 'source_conflict' using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.source_assets s
    where s.account_id = v_user
      and s.client_source_version_key = v_source_key
  ) then
    raise exception 'stale_client_source_version' using errcode = 'P0001';
  end if;

  v_path := v_user::text || '/' || v_material::text || '/' || v_source_key;

  return query
  select v_material, 'study-materials'::text, v_path, false;
end;
$$;

create or replace function public.finalize_media_material_continuity(
  p_title text,
  p_client_material_id text,
  p_client_source_id text,
  p_expected_previous_source_id text,
  p_source_type text,
  p_source_name text,
  p_mime_type text,
  p_byte_size bigint,
  p_content_hash text,
  p_storage_bucket text,
  p_storage_path text,
  p_normalized_text text,
  p_extraction_method text,
  p_extraction_method_version text,
  p_anchors jsonb,
  p_warnings jsonb
)
returns table (
  material_id uuid,
  source_asset_id uuid,
  extracted_content_id uuid,
  source_version integer,
  source_content_hash text,
  superseded_storage_path text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := public.la_require_user();
  v_title text := btrim(coalesce(p_title, ''));
  v_material_key text := btrim(coalesce(p_client_material_id, ''));
  v_source_key text := btrim(coalesce(p_client_source_id, ''));
  v_expected_key text := nullif(btrim(coalesce(p_expected_previous_source_id, '')), '');
  v_source_type text := btrim(coalesce(p_source_type, ''));
  v_source_name text := btrim(coalesce(p_source_name, ''));
  v_mime_type text := btrim(coalesce(p_mime_type, ''));
  v_text text := btrim(coalesce(p_normalized_text, ''));
  v_material uuid;
  v_source uuid;
  v_extracted uuid;
  v_current_source uuid;
  v_current_key text;
  v_current_hash text;
  v_current_path text;
  v_current_version integer;
  v_next_version integer;
  v_expected_path text;
  v_superseded_path text;
begin
  if v_material_key !~ '^[A-Za-z0-9_.:-]{8,128}$'
     or v_source_key !~ '^[A-Za-z0-9_.:-]{8,128}$' then
    raise exception 'invalid_media_lineage_key' using errcode = '22023';
  end if;
  if v_expected_key is not null
     and v_expected_key !~ '^[A-Za-z0-9_.:-]{8,128}$' then
    raise exception 'invalid_expected_source_id' using errcode = '22023';
  end if;
  if length(v_title) = 0 or length(v_title) > 300
     or length(v_source_name) = 0 or length(v_source_name) > 300 then
    raise exception 'invalid_media_title' using errcode = '22023';
  end if;
  if v_source_type not in ('pdf', 'image', 'document', 'presentation') then
    raise exception 'invalid_media_source_type' using errcode = '22023';
  end if;
  if length(v_mime_type) = 0 or length(v_mime_type) > 200
     or p_byte_size is null or p_byte_size <= 0 or p_byte_size > 52428800
     or p_content_hash is null or p_content_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'invalid_media_metadata' using errcode = '22023';
  end if;
  if length(v_text) = 0 or length(v_text) > 200000 then
    raise exception 'invalid_media_extracted_text' using errcode = '22023';
  end if;
  if length(btrim(coalesce(p_extraction_method, ''))) = 0
     or length(btrim(coalesce(p_extraction_method_version, ''))) = 0 then
    raise exception 'invalid_media_extraction_method' using errcode = '22023';
  end if;
  if p_anchors is null or jsonb_typeof(p_anchors) <> 'array'
     or jsonb_array_length(p_anchors) = 0
     or p_warnings is null or jsonb_typeof(p_warnings) <> 'array' then
    raise exception 'invalid_media_provenance' using errcode = '22023';
  end if;
  if exists (
    select 1
    from jsonb_array_elements(p_anchors) a
    where not (a ? 'startOffset')
       or not (a ? 'endOffset')
       or (a ->> 'startOffset') !~ '^[0-9]+$'
       or (a ->> 'endOffset') !~ '^[0-9]+$'
       or (a ->> 'startOffset')::integer < 0
       or (a ->> 'endOffset')::integer <= (a ->> 'startOffset')::integer
       or (a ->> 'endOffset')::integer > char_length(v_text)
  ) then
    raise exception 'invalid_media_anchor' using errcode = '22023';
  end if;

  select m.id
    into v_material
  from public.materials m
  where m.account_id = v_user
    and m.client_material_key = v_material_key
    and m.lifecycle_status = 'active'
  for update;

  if v_material is null then
    raise exception 'material_not_found' using errcode = 'P0002';
  end if;

  v_expected_path := v_user::text || '/' || v_material::text || '/' || v_source_key;
  if p_storage_bucket <> 'study-materials' or p_storage_path <> v_expected_path then
    raise exception 'invalid_media_storage_path' using errcode = '22023';
  end if;

  if not exists (
    select 1
    from storage.objects o
    where o.bucket_id = 'study-materials'
      and o.name = v_expected_path
  ) then
    raise exception 'media_upload_missing' using errcode = 'P0002';
  end if;

  select s.id,
         s.client_source_version_key,
         s.content_hash,
         s.storage_path,
         s.source_version
    into v_current_source,
         v_current_key,
         v_current_hash,
         v_current_path,
         v_current_version
  from public.source_assets s
  join public.extracted_contents e
    on e.source_asset_id = s.id
   and e.account_id = v_user
   and e.invalidated_at is null
  where s.account_id = v_user
    and s.material_id = v_material
    and s.revoked_at is null
  order by s.source_version desc, e.created_at desc
  limit 1
  for update of s;

  if v_current_key = v_source_key then
    if v_current_hash <> p_content_hash or v_current_path <> v_expected_path then
      raise exception 'idempotency_key_reused' using errcode = '22023';
    end if;

    select e.id
      into v_extracted
    from public.extracted_contents e
    where e.account_id = v_user
      and e.source_asset_id = v_current_source
      and e.invalidated_at is null
    order by e.created_at desc
    limit 1;

    select s.storage_path
      into v_superseded_path
    from public.source_assets s
    where s.account_id = v_user
      and s.material_id = v_material
      and s.revoked_at is not null
      and s.storage_path is not null
      and s.source_version < v_current_version
    order by s.source_version desc
    limit 1;

    return query
    select v_material, v_current_source, v_extracted, v_current_version, v_current_hash, v_superseded_path;
    return;
  end if;

  if v_current_key is not null
     and (v_expected_key is null or v_expected_key <> v_current_key) then
    raise exception 'source_conflict' using errcode = 'P0001';
  end if;
  if v_current_key is null and v_expected_key is not null then
    raise exception 'source_conflict' using errcode = 'P0001';
  end if;
  if exists (
    select 1
    from public.source_assets s
    where s.account_id = v_user
      and s.client_source_version_key = v_source_key
  ) then
    raise exception 'stale_client_source_version' using errcode = 'P0001';
  end if;

  v_superseded_path := v_current_path;

  if v_current_source is not null then
    update public.extracted_contents e
       set invalidated_at = coalesce(e.invalidated_at, now())
     where e.account_id = v_user
       and e.invalidated_at is null
       and exists (
         select 1
         from public.source_assets s
         where s.id = e.source_asset_id
           and s.account_id = v_user
           and s.material_id = v_material
           and s.revoked_at is null
       );

    update public.recall_actions a
       set revoked_at = coalesce(a.revoked_at, now())
     where a.account_id = v_user
       and a.material_id = v_material
       and a.revoked_at is null;

    update public.learner_evidence e
       set invalidated_at = coalesce(e.invalidated_at, now())
     where e.account_id = v_user
       and e.material_id = v_material
       and e.invalidated_at is null;

    delete from public.learner_states s
     where s.account_id = v_user
       and s.material_id = v_material;

    update public.source_assets s
       set revoked_at = coalesce(s.revoked_at, now())
     where s.account_id = v_user
       and s.material_id = v_material
       and s.revoked_at is null;
  end if;

  select coalesce(max(s.source_version), 0) + 1
    into v_next_version
  from public.source_assets s
  where s.account_id = v_user
    and s.material_id = v_material;

  insert into public.source_assets (
    material_id,
    account_id,
    source_type,
    source_name,
    knowledge_class,
    trust_class,
    storage_bucket,
    storage_path,
    content_hash,
    mime_type,
    byte_size,
    source_version,
    extraction_status,
    client_source_version_key
  )
  values (
    v_material,
    v_user,
    v_source_type,
    v_source_name,
    'LEARNER_OWNED',
    'USER_PROVIDED',
    'study-materials',
    v_expected_path,
    p_content_hash,
    v_mime_type,
    p_byte_size,
    v_next_version,
    'extracted',
    v_source_key
  )
  returning id into v_source;

  insert into public.extracted_contents (
    source_asset_id,
    account_id,
    method,
    method_version,
    normalized_text,
    anchors,
    warnings,
    source_content_hash
  )
  values (
    v_source,
    v_user,
    btrim(p_extraction_method),
    btrim(p_extraction_method_version),
    v_text,
    p_anchors,
    p_warnings,
    p_content_hash
  )
  returning id into v_extracted;

  update public.materials
     set title = v_title,
         material_type = v_source_type,
         processing_state = 'ready',
         client_source_key = v_source_key,
         updated_at = now()
   where id = v_material
     and account_id = v_user;

  return query
  select v_material, v_source, v_extracted, v_next_version, p_content_hash, v_superseded_path;
end;
$$;

create or replace function public.read_material_continuity_v2(
  p_client_material_id text
)
returns table (
  material_id uuid,
  title text,
  client_material_id text,
  source_asset_id uuid,
  client_source_id text,
  source_version integer,
  source_content_hash text,
  source_type text,
  source_name text,
  mime_type text,
  byte_size bigint,
  storage_bucket text,
  storage_path text,
  inline_text text,
  extracted_content_id uuid,
  normalized_text text,
  extraction_method text,
  extraction_method_version text,
  anchors jsonb,
  warnings jsonb,
  material_updated_at timestamptz,
  source_created_at timestamptz
)
language sql
security definer
set search_path = ''
as $$
  select m.id,
         m.title,
         m.client_material_key,
         s.id,
         s.client_source_version_key,
         s.source_version,
         s.content_hash,
         s.source_type,
         coalesce(s.source_name, m.title),
         s.mime_type,
         s.byte_size,
         s.storage_bucket,
         s.storage_path,
         s.inline_text,
         e.id,
         e.normalized_text,
         e.method,
         e.method_version,
         e.anchors,
         e.warnings,
         m.updated_at,
         s.created_at
  from public.materials m
  join public.source_assets s
    on s.material_id = m.id
   and s.account_id = m.account_id
   and s.revoked_at is null
  join public.extracted_contents e
    on e.source_asset_id = s.id
   and e.account_id = m.account_id
   and e.invalidated_at is null
  where m.account_id = public.la_require_user()
    and m.client_material_key = btrim(coalesce(p_client_material_id, ''))
    and m.lifecycle_status = 'active'
    and s.client_source_version_key is not null
  order by s.source_version desc, e.created_at desc
  limit 1
$$;

create or replace function public.list_material_continuity_v2()
returns table (
  material_id uuid,
  title text,
  client_material_id text,
  source_asset_id uuid,
  client_source_id text,
  source_version integer,
  source_content_hash text,
  source_type text,
  source_name text,
  mime_type text,
  byte_size bigint,
  storage_bucket text,
  storage_path text,
  inline_text text,
  extracted_content_id uuid,
  normalized_text text,
  extraction_method text,
  extraction_method_version text,
  anchors jsonb,
  warnings jsonb,
  material_updated_at timestamptz,
  source_created_at timestamptz
)
language sql
security definer
set search_path = ''
as $$
  select distinct on (m.id)
         m.id,
         m.title,
         m.client_material_key,
         s.id,
         s.client_source_version_key,
         s.source_version,
         s.content_hash,
         s.source_type,
         coalesce(s.source_name, m.title),
         s.mime_type,
         s.byte_size,
         s.storage_bucket,
         s.storage_path,
         s.inline_text,
         e.id,
         e.normalized_text,
         e.method,
         e.method_version,
         e.anchors,
         e.warnings,
         m.updated_at,
         s.created_at
  from public.materials m
  join public.source_assets s
    on s.material_id = m.id
   and s.account_id = m.account_id
   and s.revoked_at is null
  join public.extracted_contents e
    on e.source_asset_id = s.id
   and e.account_id = m.account_id
   and e.invalidated_at is null
  where m.account_id = public.la_require_user()
    and m.client_material_key is not null
    and s.client_source_version_key is not null
    and m.lifecycle_status = 'active'
  order by m.id, s.source_version desc, e.created_at desc
$$;

revoke all on function public.prepare_media_material_continuity(text, text, text, text, text, text, bigint, text),
                       public.finalize_media_material_continuity(
                         text, text, text, text, text, text, text, bigint, text,
                         text, text, text, text, text, jsonb, jsonb
                       ),
                       public.read_material_continuity_v2(text),
                       public.list_material_continuity_v2()
from public, anon, authenticated;

grant execute on function public.prepare_media_material_continuity(text, text, text, text, text, text, bigint, text),
                          public.finalize_media_material_continuity(
                            text, text, text, text, text, text, text, bigint, text,
                            text, text, text, text, text, jsonb, jsonb
                          ),
                          public.read_material_continuity_v2(text),
                          public.list_material_continuity_v2()
to authenticated, service_role;
