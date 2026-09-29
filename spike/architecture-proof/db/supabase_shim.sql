-- Minimal Supabase platform shim for local Postgres 16 (Architecture Proof test harness).
--
-- Purpose: run donor and Learning App SQL migrations/tests without the Supabase
-- CLI/Docker stack, which are unavailable in this environment. This file is
-- authored for Learning App (not copied from Supabase). It reproduces only the
-- platform surface the migrations depend on:
--   * roles anon / authenticated / service_role, and a non-superuser "postgres"
--     owner role with Supabase-like attributes;
--   * auth.users, auth.uid(), auth.role(), auth.jwt() driven by the same
--     request.jwt.claim* settings PostgREST sets;
--   * storage.buckets / storage.objects with RLS, storage.foldername(),
--     storage.filename();
--   * the pgcrypto extension in schema "extensions".
-- Limitations (recorded as spike debt): no GoTrue, no PostgREST HTTP layer, no
-- storage API/object bytes, no Realtime. RLS, grants and SECURITY DEFINER
-- semantics are real PostgreSQL behaviour.
--
-- Run as a superuser once per fresh database.

\set ON_ERROR_STOP on

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin noinherit bypassrls;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'postgres') then
    create role postgres login createrole createdb replication bypassrls;
  end if;
end
$$;

grant anon, authenticated, service_role to postgres;

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
grant usage on schema extensions to postgres, anon, authenticated, service_role;

-- auth ---------------------------------------------------------------------
create schema if not exists auth;
grant usage on schema auth to postgres, anon, authenticated, service_role;

create table if not exists auth.users (
  id uuid primary key default gen_random_uuid(),
  email text unique,
  raw_user_meta_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
alter table auth.users owner to postgres;

create or replace function auth.uid() returns uuid
language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'
  )::uuid
$$;

create or replace function auth.role() returns text
language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role'
  )
$$;

create or replace function auth.jwt() returns jsonb
language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb
$$;

grant execute on function auth.uid(), auth.role(), auth.jwt()
  to postgres, anon, authenticated, service_role;

-- storage ------------------------------------------------------------------
create schema if not exists storage;
grant usage on schema storage to postgres, anon, authenticated, service_role;

create table if not exists storage.buckets (
  id text primary key,
  name text not null unique,
  owner uuid,
  public boolean not null default false,
  file_size_limit bigint,
  allowed_mime_types text[],
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text references storage.buckets(id),
  name text,
  owner uuid,
  owner_id text,
  metadata jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_accessed_at timestamptz not null default now(),
  unique (bucket_id, name)
);
alter table storage.objects enable row level security;
alter table storage.buckets owner to postgres;
alter table storage.objects owner to postgres;
grant select, insert, update, delete on storage.objects to authenticated, service_role;
grant select on storage.buckets to anon, authenticated, service_role;

create or replace function storage.foldername(name text) returns text[]
language sql immutable as $$
  select (string_to_array(name, '/'))[1:array_length(string_to_array(name, '/'), 1) - 1]
$$;

create or replace function storage.filename(name text) returns text
language sql immutable as $$
  select (string_to_array(name, '/'))[array_length(string_to_array(name, '/'), 1)]
$$;

grant execute on function storage.foldername(text), storage.filename(text)
  to postgres, anon, authenticated, service_role;

-- Private buckets the donor migrations require to pre-exist (as on hosted Supabase).
insert into storage.buckets (id, name, public) values
  ('study-materials', 'study-materials', false),
  ('study-images', 'study-images', false)
on conflict (id) do nothing;

-- public schema is owned by the managed "postgres" role on Supabase.
alter schema public owner to postgres;
grant usage on schema public to anon, authenticated, service_role;
