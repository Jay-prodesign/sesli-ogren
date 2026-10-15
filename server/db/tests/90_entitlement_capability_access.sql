\set ON_ERROR_STOP on
begin;

\set user_a '''e3000000-0000-4000-8000-000000000001'''
\set user_b '''e3000000-0000-4000-8000-000000000002'''

create or replace function pg_temp.ok(v boolean, msg text)
returns void language plpgsql as $$
begin
  if v is distinct from true then
    raise exception 'entitlement_access_assert_failed: %', msg;
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
      raise exception 'entitlement_access_assert_failed: % (got %)', msg, sqlerrm;
  end;
  raise exception 'entitlement_access_assert_failed: % (statement unexpectedly succeeded)', msg;
end $$;

insert into auth.users (id, email)
values (:user_a, 'entitlement-access@example.test');

update public.entitlements
set limits = limits || '{"summary_daily":1,"explain_daily":2,"focus_daily":2,"explain_back_daily":2}'::jsonb
where account_id = :user_a;

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;

select decision as initial_decision,
       reason as initial_reason,
       consumed::text as initial_consumed,
       reserved::text as initial_reserved,
       limit_value::text as initial_limit
from public.get_capability_access('summary')
\gset

select pg_temp.ok(:'initial_decision' = 'allowed', 'fresh free entitlement must admit configured Summary');
select pg_temp.ok(:'initial_reason' = 'entitled', 'fresh access must be server-entitled');
select pg_temp.ok(
  :'initial_consumed' = '0' and :'initial_reserved' = '0' and :'initial_limit' = '1',
  'RPC must expose authoritative consumed, reserved and limit state'
);

select pg_temp.denied(
  $update public.entitlements set plan = 'premium' where account_id = '$ || :user_a || $'$,
  'permission denied',
  'authenticated client must not self-grant plan changes'
);

select material_id::text as reserved_material_id,
       job_id::text as reserved_job_id
from public.submit_text_summary(
  'Reserved Summary',
  'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür.',
  'entitlement-reserved-summary-a'
)
\gset

select decision as reserved_decision,
       reason as reserved_reason,
       consumed::text as reserved_consumed,
       reserved::text as reserved_count
from public.get_capability_access('summary')
\gset

select pg_temp.ok(:'reserved_decision' = 'denied', 'inflight Summary must reserve the configured capacity');
select pg_temp.ok(:'reserved_reason' = 'quota_reached', 'reserved capacity must use the same authoritative quota reason');
select pg_temp.ok(
  :'reserved_consumed' = '0' and :'reserved_count' = '1',
  'reserved Summary must remain distinguishable from completed usage'
);

reset role;

update public.generation_jobs
set target_artifact_type = 'EXPLAIN'
where id = :'reserved_job_id'::uuid;

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;

select decision as unrelated_decision,
       reserved::text as unrelated_reserved
from public.get_capability_access('summary')
\gset

select pg_temp.ok(
  :'unrelated_decision' = 'allowed' and :'unrelated_reserved' = '0',
  'an unrelated inflight Explain must not consume Summary capacity'
);

select job_id::text as second_summary_job_id
from public.submit_text_summary(
  'Second Summary',
  'Klorofil ışığın soğurulmasına yardım eder.',
  'entitlement-reserved-summary-b'
)
\gset

select pg_temp.ok(
  nullif(:'second_summary_job_id', '') is not null,
  'Summary mutation must ignore unrelated inflight generation when enforcing its own quota'
);

reset role;

insert into public.quota_ledger (account_id, period_start, capability, consumed)
values (:user_a, current_date, 'summary', 1)
on conflict (account_id, period_start, capability)
do update set consumed = excluded.consumed;

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;

select decision as capped_decision,
       reason as capped_reason,
       consumed::text as capped_consumed
from public.get_capability_access('summary')
\gset

select pg_temp.ok(:'capped_decision' = 'denied', 'quota cap must deny another Summary generation');
select pg_temp.ok(:'capped_reason' = 'quota_reached', 'quota denial must remain distinguishable from entitlement denial');
select pg_temp.ok(:'capped_consumed' = '1', 'capability check must not consume another unit');

reset role;

update public.entitlements
set status = 'expired',
    reconciliation_state = 'restore_pending'
where account_id = :user_a;

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;

select decision as restore_decision,
       reason as restore_reason
from public.get_capability_access('focus')
\gset

select pg_temp.ok(:'restore_decision' = 'pending', 'inactive restore must not be misreported as a paywall denial');
select pg_temp.ok(:'restore_reason' = 'restore_pending', 'restore pending state must survive the access boundary');

reset role;

update public.entitlements
set status = 'active',
    reconciliation_state = 'restore_pending'
where account_id = :user_a;

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;

select decision as preserved_decision,
       reason as preserved_reason
from public.get_capability_access('focus')
\gset

select pg_temp.ok(:'preserved_decision' = 'allowed', 'existing valid access must survive a temporary restore reconciliation');
select pg_temp.ok(
  :'preserved_reason' = 'access_preserved_during_reconciliation',
  'preserved access must remain explicitly attributable to reconciliation safety'
);

reset role;

update public.entitlements
set reconciliation_state = 'purchase_pending',
    limits = limits || '{"focus_daily":0}'::jsonb
where account_id = :user_a;

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;

select decision as purchase_decision,
       reason as purchase_reason
from public.get_capability_access('focus')
\gset

select pg_temp.ok(
  :'purchase_decision' = 'pending',
  'an unresolved purchase must not be converted into another upgrade denial'
);
select pg_temp.ok(:'purchase_reason' = 'purchase_pending', 'purchase pending state must survive the access boundary');

reset role;

update public.entitlements
set reconciliation_state = 'verified',
    renewal_state = 'grace_or_retry',
    effective_until = now() - interval '1 hour',
    limits = limits || '{"focus_daily":2}'::jsonb
where account_id = :user_a;

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;

select decision as grace_decision,
       reason as grace_reason
from public.get_capability_access('focus')
\gset

select pg_temp.ok(:'grace_decision' = 'allowed', 'grace access must survive a temporary renewal failure');
select pg_temp.ok(:'grace_reason' = 'grace_access_preserved', 'grace access must be explicitly attributable');

select pg_temp.denied(
  'select * from public.get_capability_access(''made_up_capability'')',
  'unsupported_capability',
  'unknown metering classes must fail closed'
);

reset role;

insert into auth.users (id, email)
values (:user_b, 'entitlement-missing@example.test');

delete from public.entitlements where account_id = :user_b;

select set_config('request.jwt.claim.sub', :user_b, false);
set role authenticated;

select decision as missing_decision,
       reason as missing_reason
from public.get_capability_access('summary')
\gset

select pg_temp.ok(
  :'missing_decision' = 'unavailable',
  'missing entitlement truth must fail closed instead of presenting a paywall'
);
select pg_temp.ok(:'missing_reason' = 'entitlement_missing', 'missing entitlement reason must remain explicit');

reset role;
rollback;
