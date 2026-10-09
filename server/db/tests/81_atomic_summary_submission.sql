-- Quick Recap atomic submission: replay is stable and failed requests leave no orphan material.
\set ON_ERROR_STOP on
\set user_c '''d2000000-0000-4000-8000-00000000000c'''

create or replace function pg_temp.ok(v boolean, msg text) returns void language plpgsql as $$
begin
  if v is distinct from true then raise exception 'atomic_summary_assert_failed: %', msg; end if;
end $$;

create or replace function pg_temp.denied(stmt text, expected text, msg text) returns void language plpgsql as $$
declare err text;
begin
  begin execute stmt;
  exception when others then
    err := sqlerrm;
    if position(expected in err) = 0 then
      raise exception 'atomic_summary_assert_failed: % (wrong error: %)', msg, err;
    end if;
    return;
  end;
  raise exception 'atomic_summary_assert_failed: % (statement succeeded)', msg;
end $$;

update public.generation_jobs
set state = 'CANCELLED', lease_token = null, lease_expires_at = null
where state in ('QUEUED', 'PROCESSING', 'FAILED_RETRYABLE');

insert into auth.users (id, email) values (:user_c, 'atomic-summary@example.test');
select set_config('request.jwt.claim.sub', :user_c, false);
set role authenticated;

select material_id as mat_1, job_id as job_1
from public.submit_text_summary(
  'Atomik kaynak',
  'Bu içerik aynı client source kimliğiyle yalnız bir kez oluşturulmalıdır.',
  'sv_11111111111111111111111111111111'
) \gset

select material_id as mat_2, job_id as job_2
from public.submit_text_summary(
  'Atomik kaynak - yeniden adlandırılmış',
  'Bu içerik aynı client source kimliğiyle yalnız bir kez oluşturulmalıdır.',
  'sv_11111111111111111111111111111111'
) \gset

select pg_temp.ok(:'mat_1' = :'mat_2', 'replay returns the same material');
select pg_temp.ok(:'job_1' = :'job_2', 'replay returns the same job');
select pg_temp.ok(
  (select count(*) = 1 from public.materials where account_id = :user_c),
  'replay creates exactly one material'
);
select pg_temp.ok(
  (select count(*) = 1 from public.generation_jobs where account_id = :user_c),
  'replay creates exactly one generation job'
);

select pg_temp.denied(
  $$select * from public.submit_text_summary(
    'Different content',
    'Aynı client source kimliği farklı içerik için kullanılamaz.',
    'sv_11111111111111111111111111111111'
  )$$,
  'idempotency_key_reused',
  'same client source id cannot be rebound to different content'
);

select pg_temp.denied(
  $select * from public.submit_text_summary('Bad id', 'text', 'bad id with spaces')$,
  'invalid_client_source_id',
  'unsafe client source identity rejected'
);

reset role;
update public.entitlements
set limits = '{"summary_daily": 0}'
where account_id = :user_c;

set role authenticated;
select pg_temp.denied(
  $select * from public.submit_text_summary(
    'Quota blocked',
    'Bu içerik quota hatasında sunucuda yetim material bırakmamalıdır.',
    'sv_22222222222222222222222222222222'
  )$$,
  'quota_exceeded',
  'quota failure propagated'
);

reset role;
select pg_temp.ok(
  (select count(*) = 1 from public.materials where account_id = :user_c),
  'quota failure leaves no orphan material'
);
select pg_temp.ok(
  (select count(*) = 1 from public.source_assets where account_id = :user_c),
  'quota failure leaves no orphan source asset'
);
select pg_temp.ok(
  (select count(*) = 1 from public.generation_jobs where account_id = :user_c),
  'quota failure leaves no orphan job'
);

reset role;
