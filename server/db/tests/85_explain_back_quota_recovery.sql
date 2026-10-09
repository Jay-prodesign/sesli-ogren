\set ON_ERROR_STOP on
begin;

\set user_a '''e3000000-0000-4000-8000-000000000001'''
\set response_hash_a 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'

create or replace function pg_temp.ok(v boolean, msg text)
returns void language plpgsql as $$
begin
  if v is distinct from true then
    raise exception 'explain_back_quota_recovery_assert_failed: %', msg;
  end if;
end $$;

create or replace function pg_temp.denied(stmt text, expected text, msg text)
returns void language plpgsql as $$
begin
  begin
    execute stmt;
  exception
    when others then
      if position(expected in sqlerrm) > 0 then return; end if;
      raise exception 'explain_back_quota_recovery_assert_failed: % (got %)', msg, sqlerrm;
  end;
  raise exception 'explain_back_quota_recovery_assert_failed: % (statement unexpectedly succeeded)', msg;
end $$;

insert into auth.users (id, email)
values (:user_a, 'explain-quota-recovery@example.test');

update public.entitlements
set limits = limits || '{"explain_back_daily":1}'::jsonb
where account_id = :user_a;

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;
select public.create_text_material(
  'Explain quota recovery source',
  'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür.'
) as material_a \gset
reset role;

select e.source_content_hash as hash_a
from public.materials m
join public.source_assets s
  on s.material_id = m.id and s.revoked_at is null
join public.extracted_contents e
  on e.source_asset_id = s.id and e.invalidated_at is null
where m.id = :'material_a'::uuid
\gset

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;
select public.open_explain_back_attempt(
  'quota-recovery-attempt-0001',
  :'material_a'::uuid,
  :'hash_a',
  :'response_hash_a',
  48
);
reset role;

set role service_role;
select lease_token::text as lease_a
from public.claim_explain_back_attempt(
  :user_a,
  'quota-recovery-attempt-0001',
  15
)
\gset
reset role;

select pg_temp.ok(
  (
    select consumed = 1
    from public.quota_ledger
    where account_id = :user_a
      and period_start = current_date
      and capability = 'explain_back'
  ),
  'first claim reserves one unit'
);

update public.explain_back_attempts
set evaluation_lease_expires_at = now() - interval '1 second'
where account_id = :user_a
  and attempt_id = 'quota-recovery-attempt-0001';

set role service_role;
select lease_token::text as lease_b
from public.claim_explain_back_attempt(
  :user_a,
  'quota-recovery-attempt-0001',
  120
)
\gset
reset role;

select pg_temp.ok(
  :'lease_b' <> :'lease_a',
  'expired pre-dispatch retry gets a new lease'
);

select pg_temp.ok(
  (
    select consumed = 1
    from public.quota_ledger
    where account_id = :user_a
      and period_start = current_date
      and capability = 'explain_back'
  ),
  'expired pre-dispatch reservation is released before retry re-reserves'
);

select pg_temp.ok(
  (
    select evaluation_attempt_count = 2
       and evaluation_state = 'PROCESSING'
       and evaluator_dispatch_state = 'not_dispatched'
       and evaluation_quota_reserved
    from public.explain_back_attempts
    where account_id = :user_a
      and attempt_id = 'quota-recovery-attempt-0001'
  ),
  'retry remains a single active reserved attempt'
);

set role service_role;
select public.mark_explain_back_dispatched(
  :user_a,
  'quota-recovery-attempt-0001',
  :'lease_b'::uuid,
  'fetch-chat:test-model'
);
select public.fail_explain_back_attempt(
  :user_a,
  'quota-recovery-attempt-0001',
  :'lease_b'::uuid,
  'retryable',
  'provider:test-retryable'
);
select pg_temp.denied(
  format(
    'select * from public.claim_explain_back_attempt(%L::uuid,%L,120)',
    :user_a,
    'quota-recovery-attempt-0001'
  ),
  'quota_exceeded',
  'a real dispatched provider attempt keeps its daily quota charge'
);
reset role;

select pg_temp.ok(
  (
    select consumed = 1
    from public.quota_ledger
    where account_id = :user_a
      and period_start = current_date
      and capability = 'explain_back'
  ),
  'known provider dispatch remains charged'
);

rollback;
