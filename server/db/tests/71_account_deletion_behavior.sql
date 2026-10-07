\set ON_ERROR_STOP on
begin;

\set user_a '''d4000000-0000-4000-8000-000000000001'''
\set user_b '''d4000000-0000-4000-8000-000000000002'''

create or replace function pg_temp.denied(stmt text, expected text, msg text)
returns void language plpgsql as $$
declare err text;
begin
  begin execute stmt;
  exception when others then
    err := sqlerrm;
    if position(expected in err) = 0 then
      raise exception 'account_delete_assert_failed: % (wrong error: %)', msg, err;
    end if;
    return;
  end;
  raise exception 'account_delete_assert_failed: % (statement succeeded)', msg;
end $$;

insert into auth.users (id, email) values
  (:user_a, 'delete-a@example.test'),
  (:user_b, 'delete-b@example.test');

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;
select public.create_text_material(
  'Delete account source',
  'Bu kaynak hesap silme davranışını sınamak için oluşturuldu.'
) as material_a \gset
select public.request_summary(:'material_a', 'delete-account-summary-0001', false) as job_a \gset
select public.request_account_deletion() as requested_at \gset
select public.request_account_deletion() as requested_again_at \gset
reset role;

do $$
declare
  v_status text;
  v_job_state text;
begin
  select status into v_status from public.accounts where id = :user_a;
  if v_status <> 'deletion_requested' then
    raise exception 'account_delete_assert_failed: account status is %', v_status;
  end if;

  select state into v_job_state from public.generation_jobs where id = :'job_a';
  if v_job_state <> 'CANCELLED' then
    raise exception 'account_delete_assert_failed: queued job state is %', v_job_state;
  end if;
end $$;

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;
select pg_temp.denied(
  $$select public.create_text_material('blocked', 'new work must not start')$$,
  'account_inactive',
  'deletion-requested account cannot start new user work'
);
reset role;

do $$
declare v_status text;
begin
  select status into v_status from public.accounts where id = :user_b;
  if v_status <> 'active' then
    raise exception 'account_delete_assert_failed: other learner changed state';
  end if;
end $$;

rollback;
