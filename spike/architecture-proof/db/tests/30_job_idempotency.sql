-- LA-0015: GenerationJob identity, idempotency, attempt lineage, ambiguous dispatch and quota consistency.
\set ON_ERROR_STOP on
\set user_c '''c1000000-0000-4000-8000-00000000000c'''

create or replace function pg_temp.ok(v boolean, msg text) returns void language plpgsql as $$
begin if v is distinct from true then raise exception 'idempotency_assert_failed: %', msg; end if; end $$;
create or replace function pg_temp.denied(stmt text, expected text, msg text) returns void language plpgsql as $$
declare err text;
begin
  begin execute stmt; exception when others then
    err := sqlerrm;
    if position(expected in err) = 0 then raise exception 'idempotency_assert_failed: % (wrong error: %)', msg, err; end if;
    return;
  end;
  raise exception 'idempotency_assert_failed: % (statement succeeded)', msg;
end $$;

-- Fixture isolation: the queue is shared across test files; start from an empty queue.
update public.generation_jobs set state = 'CANCELLED', lease_token = null, lease_expires_at = null
 where state in ('QUEUED', 'PROCESSING');

insert into auth.users (id, email) values (:user_c, 'idem-c@example.test');
select set_config('request.jwt.claim.sub', :user_c, false);
set role authenticated;
select public.create_text_material('Newton', 'F = m a. Kuvvet kütle ile ivmenin çarpımıdır.') as mat \gset

-- 1. Same key twice -> same job.
select public.request_summary(:'mat', 'idem-key-000001') as job1 \gset
select public.request_summary(:'mat', 'idem-key-000001') as job1_again \gset
select pg_temp.ok(:'job1' = :'job1_again', 'same key returns same job');
-- 2. Ordinary repeat with a NEW key (e.g. double tap after reinstall) -> still the same live job.
select public.request_summary(:'mat', 'idem-key-000002') as job1_newkey \gset
select pg_temp.ok(:'job1' = :'job1_newkey', 'same request fingerprint collapses onto the live job');
-- 3. Key reuse against a different material is rejected, not silently mapped.
select public.create_text_material('Other', 'Other text') as mat2 \gset
select pg_temp.denied($$select public.request_summary('$$ || :'mat2' || $$','idem-key-000001')$$, 'idempotency_key_reused', 'key reuse on other material rejected');
select pg_temp.ok((select count(*) = 1 from public.generation_jobs where material_id = :'mat'), 'exactly one job for the material');
reset role;

-- 4. Attempt 1 fails retryably BEFORE dispatch reaches the provider? No: after response known -> retry allowed.
set role service_role;
select attempt_id as att1, lease_token as tok1 from public.claim_generation_job(60) \gset
select public.mark_attempt_dispatched(:'att1', :'tok1', 'fake:deterministic-v1');
select pg_temp.ok(public.fail_generation_attempt(:'att1', :'tok1', 'retryable', 'fake-exec-fail-1') = 'FAILED_RETRYABLE', 'retryable failure');
-- stale token cannot mutate after the attempt ended
select pg_temp.denied($$select public.complete_generation_attempt('$$ || :'att1' || $$','$$ || :'tok1' || $$','{"summary":"x","key_points":[],"language":"tr-TR"}','late',NULL,1)$$, 'stale_lease', 'stale worker rejected');
reset role;
select pg_temp.ok((select budget_effect = 'released' and status = 'failed' from public.generation_attempts where id = :'att1'), 'failed attempt released budget');

-- The worker does not pick up FAILED_RETRYABLE by itself: an explicit user retry is required.
set role service_role;
select pg_temp.ok((select count(*) = 0 from public.claim_generation_job(60)), 'no auto re-dispatch of failed job');
reset role;
set role authenticated;
select pg_temp.ok(public.retry_generation_job(:'job1') = 'QUEUED', 'user retry re-queues');
reset role;

-- 5. Retry creates attempt 2 linked to attempt 1 (predecessor immutable).
set role service_role;
select attempt_id as att2, lease_token as tok2 from public.claim_generation_job(60) \gset
reset role;
select pg_temp.ok((select attempt_number = 2 and predecessor_attempt_id = :'att1'
                   and attempt_idempotency_key = :'job1' || ':2' from public.generation_attempts where id = :'att2'),
                  'attempt 2 linked to attempt 1');
select pg_temp.ok((select status = 'failed' and failure_class = 'retryable' from public.generation_attempts where id = :'att1'),
                  'predecessor unchanged');

-- 6. Ambiguous dispatch: lease expires after dispatch -> never auto-resent, reconciliation required.
set role service_role;
select public.mark_attempt_dispatched(:'att2', :'tok2', 'fake:deterministic-v1');
reset role;
update public.generation_jobs set lease_expires_at = now() - interval '1 second' where id = :'job1';   -- simulate crash
set role service_role;
select pg_temp.ok((select count(*) = 0 from public.claim_generation_job(60)), 'expired dispatched lease is not re-claimed');
reset role;
select pg_temp.ok((select state = 'FAILED_RETRYABLE' and failure_class = 'reconciliation_required' from public.generation_jobs where id = :'job1'),
                  'job waits for reconciliation');
select pg_temp.ok((select dispatch_state = 'dispatch_unknown' and budget_effect = 'reserved' from public.generation_attempts where id = :'att2'),
                  'ambiguous attempt keeps budget reserved');
set role authenticated;
select pg_temp.denied($$select public.retry_generation_job('$$ || :'job1' || $$')$$, 'reconciliation_required', 'user cannot blind-retry ambiguous dispatch');
reset role;

-- 7. Reconciliation from the provider record: provider DID complete -> finalize without re-sending.
set role service_role;
select pg_temp.ok(public.reconcile_generation_attempt(:'att2', true,
  '{"summary":"Kuvvet = kütle × ivme.","key_points":["F=ma"],"language":"tr-TR"}', 'fake-exec-2',
  '{"total_tokens": 30}') = 'SUCCEEDED', 'reconciled to success');
select pg_temp.denied($$select public.reconcile_generation_attempt('$$ || :'att2' || $$', true, '{"summary":"dup","key_points":[],"language":"tr-TR"}')$$, 'nothing_to_reconcile', 'second reconciliation rejected');
reset role;
select pg_temp.ok((select count(*) = 1 from public.artifacts where generation_job_id = :'job1'), 'exactly one artifact for the job');
select pg_temp.ok((select count(*) = 2 from public.generation_attempts where job_id = :'job1'), 'two attempts in lineage');
select pg_temp.ok((select count(*) = 1 from public.usage_events where generation_job_id = :'job1'), 'one billable usage event for the job');
select pg_temp.ok((select consumed = 1 from public.quota_ledger where account_id = :user_c and capability = 'summary'), 'quota consumed once');

-- 8. After success, the same ordinary request returns the succeeded job (no second generation).
select set_config('request.jwt.claim.sub', :user_c, false);
set role authenticated;
select public.request_summary(:'mat', 'idem-key-000003') as job_after \gset
select pg_temp.ok(:'job_after' = :'job1', 'post-success request reuses job');
-- 9. Explicit regeneration is a distinct intent: new job, new version, old artifact superseded.
select public.request_summary(:'mat', 'idem-key-regen-01', true) as job_regen \gset
select pg_temp.ok(:'job_regen' <> :'job1', 'regeneration creates a new job');
reset role;
set role service_role;
select job_id as rj, attempt_id as att3, lease_token as tok3 from public.claim_generation_job(60) \gset
select public.mark_attempt_dispatched(:'att3', :'tok3', 'fake:deterministic-v1');
select public.complete_generation_attempt(:'att3', :'tok3',
  '{"summary":"F = m·a (v2)","key_points":["F=ma"],"language":"tr-TR"}', 'fake-exec-3', '{"total_tokens": 31}', 2) as art_v2 \gset
-- duplicate completion (e.g. worker retry of the RPC call) cannot create a second artifact
select pg_temp.denied($$select public.complete_generation_attempt('$$ || :'att3' || $$','$$ || :'tok3' || $$','{"summary":"dup","key_points":[],"language":"tr-TR"}','dup',NULL,1)$$, 'stale_lease', 'duplicate completion rejected');
reset role;
select pg_temp.ok((select version = 2 and status = 'available' from public.artifacts where id = :'art_v2'), 'v2 available');
select pg_temp.ok((select count(*) = 1 from public.artifacts where material_id = :'mat' and status = 'superseded' and version = 1), 'v1 superseded');
select pg_temp.ok((select consumed = 2 from public.quota_ledger where account_id = :user_c and capability = 'summary'), 'regeneration consumed quota');

-- 10. Lease expired BEFORE dispatch -> safe automatic re-run with a new linked attempt.
set role authenticated;
select public.request_summary(:'mat2', 'idem-key-mat2-01') as job2 \gset
reset role;
set role service_role;
select attempt_id as att4, lease_token as tok4 from public.claim_generation_job(60) \gset
reset role;
update public.generation_jobs set lease_expires_at = now() - interval '1 second' where id = :'job2';
set role service_role;
select attempt_id as att5 from public.claim_generation_job(60) \gset
reset role;
select pg_temp.ok((select status = 'abandoned' and budget_effect = 'released' from public.generation_attempts where id = :'att4'), 'undispatched attempt abandoned');
select pg_temp.ok((select predecessor_attempt_id = :'att4' and attempt_number = 2 from public.generation_attempts where id = :'att5'), 're-run linked');
set role service_role;
select pg_temp.denied($$select public.mark_attempt_dispatched('$$ || :'att4' || $$','$$ || :'tok4' || $$','x')$$, 'stale_lease', 'old lease cannot dispatch');
reset role;

-- 11. Quota: server-authoritative limit blocks new billable requests.
update public.entitlements set limits = '{"summary_daily": 2}' where account_id = :user_c;
set role authenticated;
select public.create_text_material('Third', 'Third text') as mat3 \gset
select pg_temp.denied($$select public.request_summary('$$ || :'mat3' || $$','idem-key-mat3-01')$$, 'quota_exceeded', 'quota enforced server-side');
reset role;
