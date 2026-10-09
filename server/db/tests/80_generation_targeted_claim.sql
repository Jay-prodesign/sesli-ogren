-- Quick Recap: targeted worker claims cannot drain a different queued job.
\set ON_ERROR_STOP on
\set user_a '''d1000000-0000-4000-8000-00000000000a'''
\set user_b '''d1000000-0000-4000-8000-00000000000b'''

create or replace function pg_temp.ok(v boolean, msg text) returns void language plpgsql as $$
begin
  if v is distinct from true then raise exception 'targeted_claim_assert_failed: %', msg; end if;
end $$;

create or replace function pg_temp.denied(stmt text, expected text, msg text) returns void language plpgsql as $$
declare err text;
begin
  begin execute stmt;
  exception when others then
    err := sqlerrm;
    if position(expected in err) = 0 then
      raise exception 'targeted_claim_assert_failed: % (wrong error: %)', msg, err;
    end if;
    return;
  end;
  raise exception 'targeted_claim_assert_failed: % (statement succeeded)', msg;
end $$;

update public.generation_jobs
set state = 'CANCELLED', lease_token = null, lease_expires_at = null
where state in ('QUEUED', 'PROCESSING');

insert into auth.users (id, email)
values (:user_a, 'target-a@example.test'), (:user_b, 'target-b@example.test');

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;
select public.create_text_material('A', 'A kaynağı yalnız A kullanıcısına aittir.') as mat_a \gset
select public.request_summary(:'mat_a', 'targeted-a-0001') as job_a \gset
reset role;

select set_config('request.jwt.claim.sub', :user_b, false);
set role authenticated;
select public.create_text_material('B', 'B kaynağı yalnız B kullanıcısına aittir.') as mat_b \gset
select public.request_summary(:'mat_b', 'targeted-b-0001') as job_b \gset
reset role;

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;
select pg_temp.denied(
  $$select * from public.claim_generation_job_by_id('$$ || :'job_a' || $$', 60)$$,
  'permission denied',
  'authenticated client cannot claim worker lease'
);
reset role;

set role service_role;
select job_id as claimed_b, attempt_id as att_b, lease_token as tok_b
from public.claim_generation_job_by_id(:'job_b', 60) \gset
select pg_temp.ok(:'claimed_b' = :'job_b', 'exact B job claimed');
reset role;

select pg_temp.ok(
  (select state = 'QUEUED' and attempt_count = 0 from public.generation_jobs where id = :'job_a'),
  'A remains queued'
);

set role service_role;
select public.mark_attempt_dispatched(:'att_b', :'tok_b', 'fake:targeted');
select public.complete_generation_attempt(
  :'att_b',
  :'tok_b',
  '{"summary":"B özeti","key_points":["B"],"language":"tr-TR"}',
  'fake-b',
  '{"total_tokens":10}',
  1
);
select pg_temp.ok(
  (select count(*) = 0 from public.claim_generation_job_by_id(:'job_b', 60)),
  'succeeded job cannot be claimed twice'
);
reset role;

set role service_role;
select job_id as claimed_a, attempt_id as att_a, lease_token as tok_a
from public.claim_generation_job_by_id(:'job_a', 60) \gset
select pg_temp.ok(:'claimed_a' = :'job_a', 'exact A job claimed');
select public.mark_attempt_dispatched(:'att_a', :'tok_a', 'fake:targeted');
select public.complete_generation_attempt(
  :'att_a',
  :'tok_a',
  '{"summary":"A özeti","key_points":["A"],"language":"tr-TR"}',
  'fake-a',
  '{"total_tokens":10}',
  1
);
reset role;

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;
select public.create_text_material('A2', 'İkinci A kaynağı.') as mat_a2 \gset
select public.request_summary(:'mat_a2', 'targeted-a-0002') as job_a2 \gset
reset role;

set role service_role;
select attempt_id as att_a2_1
from public.claim_generation_job_by_id(:'job_a2', 60) \gset
reset role;

update public.generation_jobs
set lease_expires_at = now() - interval '1 second'
where id = :'job_a2';

set role service_role;
select attempt_id as att_a2_2
from public.claim_generation_job_by_id(:'job_a2', 60) \gset
reset role;

select pg_temp.ok(
  (select status = 'abandoned' and budget_effect = 'released'
   from public.generation_attempts where id = :'att_a2_1'),
  'undispatched expired attempt abandoned'
);
select pg_temp.ok(
  (select predecessor_attempt_id = :'att_a2_1' and attempt_number = 2
   from public.generation_attempts where id = :'att_a2_2'),
  'targeted recovery preserves attempt lineage'
);

select set_config('request.jwt.claim.sub', :user_b, false);
set role authenticated;
select public.create_text_material('B2', 'İkinci B kaynağı.') as mat_b2 \gset
select public.request_summary(:'mat_b2', 'targeted-b-0002') as job_b2 \gset
reset role;

set role service_role;
select attempt_id as att_b2, lease_token as tok_b2
from public.claim_generation_job_by_id(:'job_b2', 60) \gset
select public.mark_attempt_dispatched(:'att_b2', :'tok_b2', 'fake:targeted');
reset role;

update public.generation_jobs
set lease_expires_at = now() - interval '1 second'
where id = :'job_b2';

set role service_role;
select pg_temp.ok(
  (select count(*) = 0 from public.claim_generation_job_by_id(:'job_b2', 60)),
  'dispatched expired job not resent'
);
reset role;

select pg_temp.ok(
  (select state = 'FAILED_RETRYABLE' and failure_class = 'reconciliation_required'
   from public.generation_jobs where id = :'job_b2'),
  'ambiguous targeted job requires reconciliation'
);
