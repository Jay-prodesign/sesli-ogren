\set ON_ERROR_STOP on
begin;

\set permanent_user '''e8000000-0000-4000-8000-000000000001'''
\set anonymous_user '''e8000000-0000-4000-8000-000000000002'''

create or replace function pg_temp.ok(v boolean, msg text)
returns void language plpgsql as $$
begin
  if v is distinct from true then
    raise exception 'permanent_user_guard_assert_failed: %', msg;
  end if;
end $$;

create or replace function pg_temp.denied(stmt text, expected text, msg text)
returns void language plpgsql as $$
begin
  begin
    execute stmt;
  exception
    when others then
      if position(expected in sqlerrm) > 0 then
        return;
      end if;
      raise exception 'permanent_user_guard_assert_failed: % (got %)', msg, sqlerrm;
  end;
  raise exception 'permanent_user_guard_assert_failed: % (statement unexpectedly succeeded)', msg;
end $$;

-- Permanent email-backed Auth users still receive the canonical remote account.
insert into auth.users (id, email, is_anonymous)
values (:permanent_user, 'permanent-user@example.test', false);

select pg_temp.ok(
  exists (select 1 from public.accounts where id = :permanent_user)
  and exists (select 1 from public.entitlements where account_id = :permanent_user),
  'permanent Auth users must still receive canonical account and entitlement rows'
);

select set_config('request.jwt.claim.sub', :permanent_user, false);
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', :permanent_user,
    'role', 'authenticated',
    'is_anonymous', false
  )::text,
  false
);
set role authenticated;

select pg_temp.ok(
  public.la_require_user() = :permanent_user::uuid,
  'permanent Auth JWT must remain admitted to remote learning RPCs'
);

reset role;

-- Device-local guest use must not silently become a remote anonymous account.
insert into auth.users (id, email, is_anonymous)
values (:anonymous_user, null, true);

select pg_temp.ok(
  not exists (select 1 from public.accounts where id = :anonymous_user),
  'anonymous Auth signup must not create a canonical remote learner account'
);

select pg_temp.ok(
  not exists (select 1 from public.entitlements where account_id = :anonymous_user),
  'anonymous Auth signup must not create a server entitlement'
);

-- Simulate a legacy/misconfigured anonymous user that already acquired an
-- account row: JWT admission and direct RLS access must still fail closed.
insert into public.accounts (id) values (:anonymous_user) on conflict (id) do nothing;
insert into public.entitlements (account_id)
values (:anonymous_user) on conflict (account_id) do nothing;

insert into public.feature_configs (key, enabled)
values ('beta.permanent_user_guard', true);

select set_config('request.jwt.claim.sub', :anonymous_user, false);
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', :anonymous_user,
    'role', 'authenticated',
    'is_anonymous', true
  )::text,
  false
);
set role authenticated;

select pg_temp.denied(
  'select public.la_require_user()',
  'anonymous_not_allowed',
  'anonymous Auth JWT must be rejected by the canonical RPC admission helper'
);

select pg_temp.ok(
  not exists (
    select 1 from public.accounts where id = :anonymous_user
  ),
  'anonymous Auth JWT must not directly read even its legacy account row'
);

select pg_temp.ok(
  not exists (
    select 1 from public.feature_configs where key = 'beta.permanent_user_guard'
  ),
  'anonymous Auth JWT must not inherit global authenticated feature-config reads'
);

select pg_temp.denied(
  $$insert into storage.objects (bucket_id, name)
    values (
      'study-materials',
      'e8000000-0000-4000-8000-000000000002/e8333333-3333-4333-8333-333333333333/sample.pdf'
    )$$,
  'row-level security',
  'anonymous Auth JWT must not write private study-material storage'
);

reset role;
rollback;
