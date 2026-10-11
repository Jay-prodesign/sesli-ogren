\set ON_ERROR_STOP on
begin;

create or replace function pg_temp.assert_true(condition boolean, msg text)
returns void language plpgsql as $$
begin
  if condition is distinct from true then
    raise exception 'explain_back_contract_assert_failed: %', msg;
  end if;
end $$;

select pg_temp.assert_true(
  to_regclass('public.explain_back_attempts') is not null,
  'Explain-back attempt authority missing'
);

select pg_temp.assert_true(
  coalesce((
    select c.relrowsecurity and c.relforcerowsecurity
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'explain_back_attempts'
  ), false),
  'Explain-back attempts must use forced RLS'
);

select pg_temp.assert_true(
  to_regprocedure('public.open_explain_back_attempt(text,uuid,text,text,integer)') is not null,
  'open_explain_back_attempt missing'
);
select pg_temp.assert_true(
  to_regprocedure('public.read_explain_back_attempt(text)') is not null,
  'read_explain_back_attempt missing'
);

select pg_temp.assert_true(
  has_function_privilege(
    'authenticated',
    'public.open_explain_back_attempt(text,uuid,text,text,integer)',
    'EXECUTE'
  ),
  'authenticated must execute open_explain_back_attempt'
);
select pg_temp.assert_true(
  not has_function_privilege(
    'anon',
    'public.open_explain_back_attempt(text,uuid,text,text,integer)',
    'EXECUTE'
  ),
  'anon must not execute open_explain_back_attempt'
);
select pg_temp.assert_true(
  has_function_privilege(
    'authenticated',
    'public.read_explain_back_attempt(text)',
    'EXECUTE'
  ),
  'authenticated must execute read_explain_back_attempt'
);
select pg_temp.assert_true(
  not has_function_privilege(
    'anon',
    'public.read_explain_back_attempt(text)',
    'EXECUTE'
  ),
  'anon must not execute read_explain_back_attempt'
);

select pg_temp.assert_true(
  coalesce((
    select is_nullable = 'YES'
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'explain_back_attempts'
      and column_name = 'evaluation_kind'
  ), false),
  'evaluation_kind must allow explicit unevaluated state'
);
select pg_temp.assert_true(
  coalesce((
    select is_nullable = 'YES'
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'explain_back_attempts'
      and column_name = 'evaluated_at'
  ), false),
  'evaluated_at must allow explicit unevaluated state'
);

rollback;
