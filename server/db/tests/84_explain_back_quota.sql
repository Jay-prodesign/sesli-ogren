\set ON_ERROR_STOP on
begin;

\set user_a '''e2000000-0000-4000-8000-000000000001'''
\set response_hash_a 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
\set response_hash_b 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'

create or replace function pg_temp.ok(v boolean, msg text)
returns void language plpgsql as $$
begin
  if v is distinct from true then
    raise exception 'explain_back_quota_assert_failed: %', msg;
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
      raise exception 'explain_back_quota_assert_failed: % (got %)', msg, sqlerrm;
  end;
  raise exception 'explain_back_quota_assert_failed: % (statement unexpectedly succeeded)', msg;
end $$;

insert into auth.users (id, email)
values (:user_a, 'explain-quota-a@example.test');

update public.entitlements
set limits = limits || '{"explain_back_daily":1}'::jsonb
where account_id = :user_a;

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;
select public.create_text_material(
  'Explain quota source',
  'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür.'
) as material_a \gset
reset role;

select e.source_content_hash as hash_a
from public.materials m
join public.source_assets s
  on s.material_id = m.id
 and s.revoked_at is null
join public.extracted_contents e
  on e.source_asset_id = s.id
 and e.invalidated_at is null
where m.id = :'material_a'::uuid
\gset

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;
select public.open_explain_back_attempt(
  'explain-quota-attempt-0001',
  :'material_a'::uuid,
  :'hash_a',
  :'response_hash_a',
  48
);
select public.open_explain_back_attempt(
  'explain-quota-attempt-0002',
  :'material_a'::uuid,
  :'hash_a',
  :'response_hash_b',
  52
);
reset role;

set role service_role;
select attempt_id,
       lease_token::text as lease_a
from public.claim_explain_back_attempt(
  :user_a,
  'explain-quota-attempt-0001',
  120
)
\gset
reset role;

select pg_temp.ok(
  :'attempt_id' = 'explain-quota-attempt-0001',
  'first evaluator claim must be admitted'
);

select pg_temp.ok(
  (
    select consumed = 1
    from public.quota_ledger
    where account_id = :user_a
      and period_start = current_date
      and capability = 'explain_back'
  ),
  'first provider-bound claim must reserve exactly one daily unit'
);

set role service_role;
select pg_temp.denied(
  format(
    'select * from public.claim_explain_back_attempt(%L::uuid,%L,120)',
    :user_a,
    'explain-quota-attempt-0002'
  ),
  'quota_exceeded',
  'second provider-bound claim must be blocked at the daily cap'
);
reset role;

select pg_temp.ok(
  (
    select evaluation_state = 'PENDING'
       and evaluation_attempt_count = 0
       and evaluator_dispatch_state = 'not_dispatched'
    from public.explain_back_attempts
    where account_id = :user_a
      and attempt_id = 'explain-quota-attempt-0002'
  ),
  'quota rejection must not partially claim or dispatch the blocked attempt'
);

set role service_role;
select public.mark_explain_back_dispatched(
  :user_a,
  'explain-quota-attempt-0001',
  :'lease_a'::uuid,
  'fetch-chat:test-model'
);
select public.complete_explain_back_attempt(
  :user_a,
  'explain-quota-attempt-0001',
  :'lease_a'::uuid,
  'sufficient',
  'provider:test-quota-0001',
  'Kaynakla uyumlu açıklama.',
  ''
);
select count(*)::text as replay_claims
from public.claim_explain_back_attempt(
  :user_a,
  'explain-quota-attempt-0001',
  120
)
\gset
reset role;

select pg_temp.ok(
  :'replay_claims' = '0',
  'completed replay must not reserve another quota unit'
);
select pg_temp.ok(
  (
    select consumed = 1
    from public.quota_ledger
    where account_id = :user_a
      and period_start = current_date
      and capability = 'explain_back'
  ),
  'completed replay must leave quota consumption unchanged'
);

rollback;
