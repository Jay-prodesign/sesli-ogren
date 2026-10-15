\set ON_ERROR_STOP on
begin;

\set user_a '''e3000000-0000-4000-8000-000000000001'''

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
       limit_value::text as initial_limit
from public.get_capability_access('summary')
\gset

select pg_temp.ok(:'initial_decision' = 'allowed', 'fresh free entitlement must admit configured Summary');
select pg_temp.ok(:'initial_reason' = 'entitled', 'fresh access must be server-entitled');
select pg_temp.ok(:'initial_consumed' = '0' and :'initial_limit' = '1', 'RPC must expose authoritative usage and limit');

select pg_temp.denied(
  $$update public.entitlements set plan = 'premium' where account_id = '$$ || :user_a || $$'$$,
  'permission denied',
  'authenticated client must not self-grant plan changes'
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

select pg_temp.denied(
  $$select * from public.get_capability_access('made_up_capability')$$,
  'unsupported_capability',
  'unknown metering classes must fail closed'
);

reset role;
rollback;
