\set ON_ERROR_STOP on

-- Cloud / cross-device continuity starts by giving the existing canonical
-- Material + SourceAsset authority stable client lineage. This is not a
-- parallel sync store: server UUIDs remain canonical server identities while
-- client keys bind the same learner-owned material/source across devices.
alter table public.materials
  add column if not exists client_material_key text;

alter table public.materials
  drop constraint if exists materials_client_material_key_check;
alter table public.materials
  add constraint materials_client_material_key_check
  check (
    client_material_key is null
    or client_material_key ~ '^[A-Za-z0-9_.:-]{8,128}$'
  );

create unique index if not exists materials_account_client_material_key_active
  on public.materials (account_id, client_material_key)
  where client_material_key is not null
    and lifecycle_status = 'active';

alter table public.source_assets
  add column if not exists client_source_version_key text;

alter table public.source_assets
  drop constraint if exists source_assets_client_source_version_key_check;
alter table public.source_assets
  add constraint source_assets_client_source_version_key_check
  check (
    client_source_version_key is null
    or client_source_version_key ~ '^[A-Za-z0-9_.:-]{8,128}$'
  );

create unique index if not exists source_assets_account_client_source_version_key
  on public.source_assets (account_id, client_source_version_key)
  where client_source_version_key is not null;

create or replace function public.ensure_text_material_continuity(
  p_title text,
  p_text text,
  p_client_material_id text,
  p_client_source_id text,
  p_expected_previous_source_id text default null
)
returns table (
  material_id uuid,
  source_asset_id uuid,
  extracted_content_id uuid,
  source_version integer,
  source_content_hash text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := public.la_require_user();
  v_material_key text := btrim(coalesce(p_client_material_id, ''));
  v_source_key text := btrim(coalesce(p_client_source_id, ''));
  v_expected_key text := nullif(btrim(coalesce(p_expected_previous_source_id, '')), '');
  v_title text := btrim(coalesce(p_title, ''));
  v_text text := btrim(coalesce(p_text, ''));
  v_hash text := public.la_sha256(p_text);
  v_material uuid;
  v_source uuid;
  v_extracted uuid;
  v_current_key text;
  v_current_hash text;
  v_current_version integer;
  v_next_version integer;
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
  if length(v_text) = 0 then
    raise exception 'empty_source' using errcode = '22023';
  end if;
  if length(v_text) > 200000 then
    raise exception 'source_too_large' using errcode = '22023';
  end if;

  select m.id
    into v_material
  from public.materials m
  where m.account_id = v_user
    and m.client_material_key = v_material_key
    and m.lifecycle_status = 'active'
  for update;

  if v_material is null then
    select m.id
      into v_material
    from public.materials m
    where m.account_id = v_user
      and m.client_source_key = v_source_key
      and m.lifecycle_status = 'active'
    for update;

    if v_material is not null then
      select s.id, e.id, s.source_version, s.content_hash
        into v_source, v_extracted, v_current_version, v_current_hash
      from public.source_assets s
      join public.extracted_contents e
        on e.source_asset_id = s.id
       and e.account_id = v_user
       and e.invalidated_at is null
      where s.material_id = v_material
        and s.account_id = v_user
        and s.revoked_at is null
      order by s.source_version desc, e.created_at desc
      limit 1
      for update of s;

      if v_source is null or v_current_hash <> v_hash then
        raise exception 'idempotency_key_reused' using errcode = '22023';
      end if;

      update public.materials
         set client_material_key = v_material_key,
             title = v_title,
             updated_at = now()
       where id = v_material
         and account_id = v_user;

      update public.source_assets
         set client_source_version_key = v_source_key
       where id = v_source
         and account_id = v_user
         and (
           client_source_version_key is null
           or client_source_version_key = v_source_key
         );

      if not found then
        raise exception 'source_lineage_conflict' using errcode = 'P0001';
      end if;

      return query
      select v_material, v_source, v_extracted, v_current_version, v_current_hash;
      return;
    end if;

    begin
      insert into public.materials (
        account_id,
        title,
        material_type,
        lifecycle_status,
        processing_state,
        client_material_key,
        client_source_key
      )
      values (
        v_user,
        v_title,
        'text',
        'active',
        'ready',
        v_material_key,
        v_source_key
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

  select s.id,
         e.id,
         s.client_source_version_key,
         s.content_hash,
         s.source_version
    into v_source,
         v_extracted,
         v_current_key,
         v_current_hash,
         v_current_version
  from public.source_assets s
  join public.extracted_contents e
    on e.source_asset_id = s.id
   and e.account_id = v_user
   and e.invalidated_at is null
  where s.material_id = v_material
    and s.account_id = v_user
    and s.revoked_at is null
  order by s.source_version desc, e.created_at desc
  limit 1
  for update of s;

  if v_source is not null and v_current_key = v_source_key then
    if v_current_hash <> v_hash then
      raise exception 'idempotency_key_reused' using errcode = '22023';
    end if;

    update public.materials
       set title = v_title,
           client_source_key = v_source_key,
           processing_state = 'ready',
           updated_at = now()
     where id = v_material
       and account_id = v_user;

    return query
    select v_material, v_source, v_extracted, v_current_version, v_current_hash;
    return;
  end if;

  if v_source is not null and v_current_key is null then
    raise exception 'source_lineage_missing' using errcode = 'P0001';
  end if;

  if v_source is not null then
    if v_expected_key is null or v_expected_key <> v_current_key then
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
  elsif v_expected_key is not null then
    raise exception 'source_conflict' using errcode = 'P0001';
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
    knowledge_class,
    trust_class,
    inline_text,
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
    'pasted_text',
    'LEARNER_OWNED',
    'USER_PROVIDED',
    p_text,
    v_hash,
    'text/plain; charset=utf-8',
    octet_length(p_text),
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
    'pasted_text_identity',
    '1',
    v_text,
    jsonb_build_array(
      jsonb_build_object(
        'startOffset', 0,
        'endOffset', char_length(v_text)
      )
    ),
    '[]'::jsonb,
    v_hash
  )
  returning id into v_extracted;

  update public.materials
     set title = v_title,
         material_type = 'text',
         processing_state = 'ready',
         client_material_key = v_material_key,
         client_source_key = v_source_key,
         updated_at = now()
   where id = v_material
     and account_id = v_user;

  return query
  select v_material, v_source, v_extracted, v_next_version, v_hash;
end;
$$;

create or replace function public.read_material_continuity(
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
  inline_text text,
  extracted_content_id uuid,
  normalized_text text,
  anchors jsonb,
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
         s.inline_text,
         e.id,
         e.normalized_text,
         e.anchors,
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
  order by s.source_version desc, e.created_at desc
  limit 1
$$;

revoke all on function public.ensure_text_material_continuity(text, text, text, text, text),
                       public.read_material_continuity(text)
from public, anon, authenticated;

grant execute on function public.ensure_text_material_continuity(text, text, text, text, text),
                          public.read_material_continuity(text)
to authenticated;

grant execute on function public.ensure_text_material_continuity(text, text, text, text, text),
                          public.read_material_continuity(text)
to service_role;
