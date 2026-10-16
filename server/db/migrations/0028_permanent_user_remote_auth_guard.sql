-- Step 17 beta-backend admission hardening.
--
-- Sesli Öğren intentionally keeps guest learning device-local. Remote learning
-- authority is reserved for permanent Auth identities (currently email OTP).
-- Supabase anonymous Auth users use the authenticated Postgres role, so relying
-- on role membership alone would accidentally admit them to owner RLS/RPCs if
-- anonymous sign-in were enabled at the project level.

-- Do not provision canonical Learning App account/entitlement state for future
-- anonymous Auth users. Existing permanent-user behavior is unchanged.
create or replace function public.la_create_account_for_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(new.is_anonymous, false) then
    return new;
  end if;

  insert into public.accounts (id)
  values (new.id)
  on conflict (id) do nothing;

  insert into public.entitlements (account_id)
  values (new.id)
  on conflict (account_id) do nothing;

  return new;
end;
$$;

-- SECURITY DEFINER product RPCs converge on this admission helper. Reject an
-- anonymous JWT even if a legacy/misconfigured account row already exists.
create or replace function public.la_require_user()
returns uuid
language plpgsql
stable
set search_path = ''
as $$
declare
  v uuid := auth.uid();
  v_is_anonymous boolean := coalesce(
    nullif(auth.jwt() ->> 'is_anonymous', '')::boolean,
    false
  );
begin
  if v is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  if v_is_anonymous then
    raise exception 'anonymous_not_allowed' using errcode = '28000';
  end if;

  if not exists (
    select 1
    from public.accounts a
    where a.id = v
      and a.status = 'active'
  ) then
    raise exception 'account_inactive' using errcode = '28000';
  end if;

  return v;
end;
$$;

-- Owner RLS policies use the authenticated role. Add one restrictive guard to
-- every current RLS-enabled public table so anonymous Auth JWTs cannot inherit
-- direct authenticated reads/writes. Missing is_anonymous on older test JWTs
-- is treated as permanent for backwards-compatible deterministic tests.
do $$
declare
  r record;
begin
  for r in
    select n.nspname as schema_name, c.relname as table_name
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind in ('r', 'p')
      and c.relrowsecurity
  loop
    execute format(
      'drop policy if exists la_permanent_users_only on %I.%I',
      r.schema_name,
      r.table_name
    );

    execute format(
      'create policy la_permanent_users_only on %I.%I as restrictive for all to authenticated using (coalesce(nullif(auth.jwt() ->> ''is_anonymous'', '''')::boolean, false) is false) with check (coalesce(nullif(auth.jwt() ->> ''is_anonymous'', '''')::boolean, false) is false)',
      r.schema_name,
      r.table_name
    );
  end loop;
end
$$;

-- Private source storage is outside public schema and needs the same explicit
-- permanent-user boundary.
drop policy if exists la_permanent_users_only on storage.objects;
create policy la_permanent_users_only
on storage.objects
as restrictive
for all
to authenticated
using (
  coalesce(nullif(auth.jwt() ->> 'is_anonymous', '')::boolean, false) is false
)
with check (
  coalesce(nullif(auth.jwt() ->> 'is_anonymous', '')::boolean, false) is false
);
