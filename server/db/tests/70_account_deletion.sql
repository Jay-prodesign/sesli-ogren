\set ON_ERROR_STOP on
begin;

create or replace function pg_temp.assert_true(condition boolean, msg text)
returns void language plpgsql as $$
begin
  if condition is distinct from true then
    raise exception 'account_delete_contract_assert_failed: %', msg;
  end if;
end $$;

select pg_temp.assert_true(
  to_regprocedure('public.request_account_deletion()') is not null,
  'authenticated deletion intent boundary missing'
);
select pg_temp.assert_true(
  has_function_privilege('authenticated', 'public.request_account_deletion()', 'EXECUTE'),
  'authenticated must execute request_account_deletion'
);
select pg_temp.assert_true(
  not has_function_privilege('anon', 'public.request_account_deletion()', 'EXECUTE'),
  'anon must not execute request_account_deletion'
);
select pg_temp.assert_true(
  pg_get_function_result('public.request_account_deletion()'::regprocedure)
    = 'timestamp with time zone',
  'request_account_deletion must return server timestamp'
);

rollback;
