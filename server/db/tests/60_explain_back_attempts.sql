\set ON_ERROR_STOP on
begin;

select plan(10);

select has_table('public', 'explain_back_attempts', 'Explain-back attempt authority exists');
select row_security_active('public.explain_back_attempts', 'Explain-back attempts use RLS');

select has_function(
  'public',
  'open_explain_back_attempt',
  array['text', 'uuid', 'text', 'text', 'integer'],
  'authenticated client can open a bounded source-bound attempt'
);
select has_function(
  'public',
  'read_explain_back_attempt',
  array['text'],
  'authenticated client can read its attempt state'
);

select function_privs_are(
  'public', 'open_explain_back_attempt',
  array['text', 'uuid', 'text', 'text', 'integer'],
  'authenticated', array['EXECUTE'],
  'authenticated may open Explain-back attempts'
);
select function_privs_are(
  'public', 'open_explain_back_attempt',
  array['text', 'uuid', 'text', 'text', 'integer'],
  'anon', array[]::text[],
  'anonymous cannot open Explain-back attempts'
);
select function_privs_are(
  'public', 'read_explain_back_attempt',
  array['text'],
  'authenticated', array['EXECUTE'],
  'authenticated may read its Explain-back attempt'
);
select function_privs_are(
  'public', 'read_explain_back_attempt',
  array['text'],
  'anon', array[]::text[],
  'anonymous cannot read Explain-back attempts'
);

select col_is_null(
  'public', 'explain_back_attempts', 'evaluation_kind',
  'new attempts may remain explicitly unevaluated'
);
select col_is_null(
  'public', 'explain_back_attempts', 'evaluated_at',
  'unevaluated attempts do not pretend to have evaluation evidence'
);

select * from finish();
rollback;
