\set ON_ERROR_STOP on
begin;

\set user_a '''e1000000-0000-4000-8000-000000000001'''
\set user_b '''e1000000-0000-4000-8000-000000000002'''
\set response_hash 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'

create or replace function pg_temp.ok(v boolean, msg text)
returns void language plpgsql as $$
begin
  if v is distinct from true then
    raise exception 'explain_back_evaluator_assert_failed: %', msg;
  end if;
end $$;

insert into auth.users (id, email) values
  (:user_a, 'explain-eval-a@example.test'),
  (:user_b, 'explain-eval-b@example.test');

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;
select public.create_text_material(
  'Explain evaluator source',
  'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür.'
) as material_a \gset
reset role;

select e.source_content_hash as hash_a
from public.materials m
join public.source_assets s on s.material_id = m.id and s.revoked_at is null
join public.extracted_contents e on e.source_asset_id = s.id and e.invalidated_at is null
where m.id = :'material_a'::uuid
\gset

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;
select public.open_explain_back_attempt(
  'explain-eval-attempt-0001',
  :'material_a'::uuid,
  :'hash_a',
  :'response_hash',
  48
);
reset role;

select pg_temp.ok(
  not has_function_privilege(
    'authenticated',
    'public.claim_explain_back_attempt(uuid,text,integer)',
    'EXECUTE'
  ),
  'authenticated role must not claim evaluator work'
);

set role service_role;
select count(*)::text as wrong_owner_claims
from public.claim_explain_back_attempt(
  :user_b,
  'explain-eval-attempt-0001',
  120
)
\gset
reset role;

select pg_temp.ok(
  :'wrong_owner_claims' = '0',
  'another account must not claim the attempt'
);

set role service_role;
select attempt_id,
       lease_token::text as eval_lease,
       source_text,
       source_content_hash,
       response_digest
from public.claim_explain_back_attempt(
  :user_a,
  'explain-eval-attempt-0001',
  120
)
\gset
reset role;

select pg_temp.ok(
  :'attempt_id' = 'explain-eval-attempt-0001',
  'exact attempt was not claimed'
);
select pg_temp.ok(
  :'source_text' like 'Fotosentez%',
  'claim did not return grounded source text'
);
select pg_temp.ok(
  :'source_content_hash' = :'hash_a',
  'claim source hash changed'
);
select pg_temp.ok(
  :'response_digest' = :'response_hash',
  'claim response digest changed'
);

set role service_role;
select public.mark_explain_back_dispatched(
  :user_a,
  'explain-eval-attempt-0001',
  :'eval_lease'::uuid,
  'fetch-chat:test-model'
);
select public.complete_explain_back_attempt(
  :user_a,
  'explain-eval-attempt-0001',
  :'eval_lease'::uuid,
  'gap_detected',
  'provider:test-eval-0001',
  'Temel ilişki doğru, ancak enerji dönüşümünün sonucu eksik.',
  'Işık enerjisinin kimyasal enerji biçiminde depolandığını açıkça belirt.'
);
reset role;

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;
select evaluation_kind, evaluator_ref, feedback, targeted_repair
from public.read_explain_back_attempt('explain-eval-attempt-0001')
\gset
reset role;

select pg_temp.ok(
  :'evaluation_kind' = 'gap_detected',
  'evaluated kind not persisted'
);
select pg_temp.ok(
  :'evaluator_ref' = 'provider:test-eval-0001',
  'evaluator ref not persisted'
);
select pg_temp.ok(
  :'feedback' like 'Temel ilişki%',
  'feedback not persisted'
);
select pg_temp.ok(
  :'targeted_repair' like 'Işık enerjisinin%',
  'targeted repair not persisted'
);

set role service_role;
select count(*)::text as duplicate_claims
from public.claim_explain_back_attempt(
  :user_a,
  'explain-eval-attempt-0001',
  120
)
\gset
reset role;

select pg_temp.ok(
  :'duplicate_claims' = '0',
  'successful evaluation must not be claimed twice'
);

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;
select public.open_explain_back_attempt(
  'explain-eval-attempt-0002',
  :'material_a'::uuid,
  :'hash_a',
  repeat('b', 64),
  52
);
reset role;

set role service_role;
select lease_token::text as ambiguous_lease
from public.claim_explain_back_attempt(
  :user_a,
  'explain-eval-attempt-0002',
  120
)
\gset
select public.mark_explain_back_dispatched(
  :user_a,
  'explain-eval-attempt-0002',
  :'ambiguous_lease'::uuid,
  'fetch-chat:test-model'
);
select public.fail_explain_back_attempt(
  :user_a,
  'explain-eval-attempt-0002',
  :'ambiguous_lease'::uuid,
  'ambiguous',
  null
) as ambiguous_state
\gset
reset role;

select pg_temp.ok(
  :'ambiguous_state' = 'RECONCILIATION_REQUIRED',
  'ambiguous provider outcome must require reconciliation'
);

select pg_temp.ok(
  (
    select evaluation_state = 'RECONCILIATION_REQUIRED'
       and evaluator_dispatch_state = 'dispatch_unknown'
       and evaluation_kind is null
    from public.explain_back_attempts
    where account_id = :user_a
      and attempt_id = 'explain-eval-attempt-0002'
  ),
  'ambiguous outcome must not create learning evaluation'
);

set role service_role;
select count(*)::text as ambiguous_reclaims
from public.claim_explain_back_attempt(
  :user_a,
  'explain-eval-attempt-0002',
  120
)
\gset
reset role;

select pg_temp.ok(
  :'ambiguous_reclaims' = '0',
  'ambiguous attempt must never auto-resend'
);

select pg_temp.ok(
  not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'explain_back_attempts'
      and column_name in ('response_text', 'response_plaintext', 'learner_response')
  ),
  'learner response plaintext must not be persisted'
);

rollback;
