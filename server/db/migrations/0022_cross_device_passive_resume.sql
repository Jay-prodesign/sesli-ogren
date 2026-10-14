\set ON_ERROR_STOP on

-- Passive Reader / Listen resume continuity. These rows are navigation state,
-- never learner evidence and never a mastery/readiness signal.
create table public.passive_resume_positions (
  account_id uuid not null references public.accounts(id) on delete cascade,
  material_id uuid not null references public.materials(id) on delete cascade,
  source_asset_id uuid not null references public.source_assets(id) on delete cascade,
  surface text not null check (surface in ('reader', 'listen')),
  reader_progress double precision,
  listen_chunk_index integer,
  revision bigint not null default 1 check (revision >= 1),
  last_client_update_id text not null,
  updated_at timestamptz not null default now(),
  primary key (account_id, material_id, surface),
  check (
    (surface = 'reader'
      and reader_progress is not null
      and reader_progress >= 0.0
      and reader_progress <= 1.0
      and listen_chunk_index is null)
    or
    (surface = 'listen'
      and listen_chunk_index is not null
      and listen_chunk_index >= 0
      and reader_progress is null)
  ),
  check (last_client_update_id ~ '^[A-Za-z0-9_.:-]{8,128}$')
);

create index passive_resume_source_idx
  on public.passive_resume_positions(account_id, source_asset_id, surface);

alter table public.passive_resume_positions enable row level security;
alter table public.passive_resume_positions force row level security;
revoke all on public.passive_resume_positions from anon, authenticated;
grant all on public.passive_resume_positions to service_role;

create policy passive_resume_owner_read on public.passive_resume_positions
for select to authenticated
using ((select auth.uid()) is not null and account_id = (select auth.uid()));

grant select (
  account_id,
  material_id,
  source_asset_id,
  surface,
  reader_progress,
  listen_chunk_index,
  revision,
  updated_at
) on public.passive_resume_positions to authenticated;

create or replace function public.write_passive_resume_continuity(
  p_client_material_id text,
  p_client_source_id text,
  p_surface text,
  p_reader_progress double precision,
  p_listen_chunk_index integer,
  p_expected_revision bigint,
  p_client_update_id text
)
returns table (
  client_material_id text,
  client_source_id text,
  surface text,
  reader_progress double precision,
  listen_chunk_index integer,
  revision bigint,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := public.la_require_user();
  v_material_key text := btrim(coalesce(p_client_material_id, ''));
  v_source_key text := btrim(coalesce(p_client_source_id, ''));
  v_surface text := btrim(coalesce(p_surface, ''));
  v_update_id text := btrim(coalesce(p_client_update_id, ''));
  v_material uuid;
  v_source uuid;
  v_existing public.passive_resume_positions%rowtype;
begin
  if v_material_key !~ '^[A-Za-z0-9_.:-]{8,128}$'
     or v_source_key !~ '^[A-Za-z0-9_.:-]{8,128}$' then
    raise exception 'invalid_resume_lineage_key' using errcode = '22023';
  end if;
  if v_surface not in ('reader', 'listen') then
    raise exception 'invalid_resume_surface' using errcode = '22023';
  end if;
  if v_update_id !~ '^[A-Za-z0-9_.:-]{8,128}$' then
    raise exception 'invalid_resume_update_id' using errcode = '22023';
  end if;
  if v_surface = 'reader' then
    if p_reader_progress is null
       or p_reader_progress < 0.0
       or p_reader_progress > 1.0
       or p_listen_chunk_index is not null then
      raise exception 'invalid_reader_resume' using errcode = '22023';
    end if;
  else
    if p_listen_chunk_index is null
       or p_listen_chunk_index < 0
       or p_reader_progress is not null then
      raise exception 'invalid_listen_resume' using errcode = '22023';
    end if;
  end if;

  select m.id, s.id
    into v_material, v_source
  from public.materials m
  join public.source_assets s
    on s.material_id = m.id
   and s.account_id = v_user
   and s.revoked_at is null
  join public.extracted_contents e
    on e.source_asset_id = s.id
   and e.account_id = v_user
   and e.invalidated_at is null
  where m.account_id = v_user
    and m.client_material_key = v_material_key
    and m.lifecycle_status = 'active'
    and s.client_source_version_key = v_source_key
  order by s.source_version desc, e.created_at desc
  limit 1;

  if v_material is null or v_source is null then
    raise exception 'resume_source_not_current' using errcode = 'P0002';
  end if;

  select *
    into v_existing
  from public.passive_resume_positions r
  where r.account_id = v_user
    and r.material_id = v_material
    and r.surface = v_surface
  for update;

  if found then
    if v_existing.source_asset_id <> v_source then
      raise exception 'resume_source_conflict' using errcode = 'P0001';
    end if;
    if v_existing.last_client_update_id = v_update_id then
      return query
      select v_material_key,
             v_source_key,
             v_existing.surface,
             v_existing.reader_progress,
             v_existing.listen_chunk_index,
             v_existing.revision,
             v_existing.updated_at;
      return;
    end if;
    if p_expected_revision is null or p_expected_revision <> v_existing.revision then
      raise exception 'resume_revision_conflict' using errcode = 'P0001';
    end if;

    update public.passive_resume_positions r
       set reader_progress = case when v_surface = 'reader' then p_reader_progress else null end,
           listen_chunk_index = case when v_surface = 'listen' then p_listen_chunk_index else null end,
           revision = r.revision + 1,
           last_client_update_id = v_update_id,
           updated_at = now()
     where r.account_id = v_user
       and r.material_id = v_material
       and r.surface = v_surface
     returning * into v_existing;
  else
    if p_expected_revision is not null and p_expected_revision <> 0 then
      raise exception 'resume_revision_conflict' using errcode = 'P0001';
    end if;

    insert into public.passive_resume_positions (
      account_id,
      material_id,
      source_asset_id,
      surface,
      reader_progress,
      listen_chunk_index,
      revision,
      last_client_update_id,
      updated_at
    )
    values (
      v_user,
      v_material,
      v_source,
      v_surface,
      case when v_surface = 'reader' then p_reader_progress else null end,
      case when v_surface = 'listen' then p_listen_chunk_index else null end,
      1,
      v_update_id,
      now()
    )
    returning * into v_existing;
  end if;

  return query
  select v_material_key,
         v_source_key,
         v_existing.surface,
         v_existing.reader_progress,
         v_existing.listen_chunk_index,
         v_existing.revision,
         v_existing.updated_at;
end;
$$;

create or replace function public.read_passive_resume_continuity(
  p_client_material_id text
)
returns table (
  client_material_id text,
  client_source_id text,
  surface text,
  reader_progress double precision,
  listen_chunk_index integer,
  revision bigint,
  updated_at timestamptz
)
language sql
security definer
set search_path = ''
as $$
  select m.client_material_key,
         s.client_source_version_key,
         r.surface,
         r.reader_progress,
         r.listen_chunk_index,
         r.revision,
         r.updated_at
  from public.materials m
  join public.source_assets s
    on s.material_id = m.id
   and s.account_id = m.account_id
   and s.revoked_at is null
  join public.passive_resume_positions r
    on r.account_id = m.account_id
   and r.material_id = m.id
   and r.source_asset_id = s.id
  where m.account_id = public.la_require_user()
    and m.client_material_key = btrim(coalesce(p_client_material_id, ''))
    and m.lifecycle_status = 'active'
    and s.client_source_version_key is not null
  order by r.surface
$$;

create or replace function public.la_drop_passive_resume_for_revoked_source()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.revoked_at is null and new.revoked_at is not null then
    delete from public.passive_resume_positions r
     where r.account_id = new.account_id
       and r.source_asset_id = new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists drop_passive_resume_for_revoked_source on public.source_assets;
create trigger drop_passive_resume_for_revoked_source
after update of revoked_at on public.source_assets
for each row execute function public.la_drop_passive_resume_for_revoked_source();

revoke all on function public.write_passive_resume_continuity(
                         text, text, text, double precision, integer, bigint, text
                       ),
                       public.read_passive_resume_continuity(text),
                       public.la_drop_passive_resume_for_revoked_source()
from public, anon, authenticated;

grant execute on function public.write_passive_resume_continuity(
                           text, text, text, double precision, integer, bigint, text
                         ),
                          public.read_passive_resume_continuity(text)
to authenticated, service_role;

grant execute on function public.la_drop_passive_resume_for_revoked_source()
to service_role;
