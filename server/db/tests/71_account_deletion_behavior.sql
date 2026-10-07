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

create or replace function pg_temp.assert_true(condition boolean, msg text)
returns void language plpgsql as $
begin
  if condition is distinct from true then
    raise exception 'account_delete_assert_failed: %', msg;
  end if;
end $;

select pg_temp.assert_true(
  coalesce((select status = 'deletion_requested' from public.accounts where id = :user_a), false),
  'account status did not become deletion_requested'
);
select pg_temp.assert_true(
  coalesce((select state = 'CANCELLED' from public.generation_jobs where id = :'job_a'), false),
  'queued job was not cancelled'
);

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;
select pg_temp.denied(
  $$select public.create_text_material('blocked', 'new work must not start')$$,
  'account_inactive',
  'deletion-requested account cannot start new user work'
);
reset role;

select pg_temp.assert_true(
  coalesce((select status = 'active' from public.accounts where id = :user_b), false),
  'other learner changed state'
);

rollback;
