\set ON_ERROR_STOP on
begin;

\set user_a '''fa000000-0000-4000-8000-000000000001'''
\set user_b '''fa000000-0000-4000-8000-000000000002'''

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
values
  (:user_a, 'entitlement-access-a@example.test'),
  (:user_b, 'entitlement-access-b@example.test');

update public.entitlements
set limits = limits || '{"summary_daily":1,"explain_daily":2,"focus_daily":1,"explain_back_daily":1}'::jsonb
where account_id in (:user_a, :user_b);

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;

select pg_temp.ok(
  (
    select decision = 'allowed'
       and reason_code = 'allowed'
       and limit_value = 1
       and consumed = 0
       and reserved = 0
       and remaining = 1
    from public.entitlement_capability_access('summary')
  ),
  'fresh Summary allowance must be server-authoritatively available'
);

select public.create_text_material(
  'Entitlement source A',
  'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür.'
) as material_a \gset

select public.request_summary(:'material_a'::uuid, 'entitlement-summary-a-0001') as job_a \gset

select pg_temp.ok(
  (
    select decision = 'blocked'
       and reason_code = 'quota_reached'
       and limit_value = 1
       and consumed = 0
       and reserved = 1
       and remaining = 0
    from public.entitlement_capability_access('summary')
  ),
  'queued Summary must reserve the final visible allowance without consuming it twice'
);

select pg_temp.ok(
  (
    select decision = 'allowed'
       and limit_value = 2
       and remaining = 2
    from public.entitlement_capability_access('explain')
  ),
  'independent capability meters must not inherit Summary reservation'
);

select pg_temp.ok(
  (
    select decision = 'unavailable'
       and reason_code = 'capability_not_configured'
    from public.entitlement_capability_access('future_tutor')
  ),
  'unknown capabilities must fail closed without inventing an upgrade state'
);

reset role;

select set_config('request.jwt.claim.sub', :user_b, false);
set role authenticated;
select pg_temp.ok(
  (
    select decision = 'allowed'
       and consumed = 0
       and reserved = 0
       and remaining = 1
    from public.entitlement_capability_access('summary')
  ),
  'quota and reservation state must remain account scoped'
);
reset role;

update public.entitlements
set status = 'expired'
where account_id = :user_a;

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;
select pg_temp.ok(
  (
    select decision = 'blocked'
       and reason_code = 'entitlement_inactive'
       and entitlement_status = 'expired'
    from public.entitlement_capability_access('focus')
  ),
  'inactive entitlement must block new costly capability use'
);
reset role;

update public.entitlements
set status = 'active',
    limits = jsonb_set(limits, '{focus_daily}', '0'::jsonb)
where account_id = :user_a;

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;
select pg_temp.ok(
  (
    select decision = 'blocked'
       and reason_code = 'capability_not_entitled'
       and limit_value = 0
    from public.entitlement_capability_access('focus')
  ),
  'zero configured allowance must be an explicit capability denial'
);
reset role;

update public.entitlements
set limits = jsonb_set(limits, '{summary_daily}', '0'::jsonb)
where account_id = :user_b;

select set_config('request.jwt.claim.sub', :user_b, false);
set role authenticated;
select public.create_text_material(
  'Entitlement source B',
  'Klorofil ışığın soğurulmasına yardım eder.'
) as material_b \gset

select pg_temp.denied(
  format(
    'select public.request_summary(%L::uuid,%L)',
    :'material_b',
    'entitlement-summary-b-0001'
  ),
  'quota_exceeded',
  'client-visible access decision must not replace the server hard quota guard'
);
reset role;

rollback;
