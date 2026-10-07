\set ON_ERROR_STOP on
begin;

select plan(4);

select has_function(
  'public',
  'request_account_deletion',
  array[]::text[],
  'authenticated deletion intent boundary exists'
);
select function_privs_are(
  'public', 'request_account_deletion', array[]::text[],
  'authenticated', array['EXECUTE'],
  'authenticated may request deletion for its own session'
);
select function_privs_are(
  'public', 'request_account_deletion', array[]::text[],
  'anon', array[]::text[],
  'anonymous cannot request account deletion'
);
select function_returns(
  'public', 'request_account_deletion', array[]::text[],
  'timestamp with time zone',
  'deletion intent returns its server timestamp'
);

select * from finish();
rollback;
