-- LA-0014: tenant / RLS / storage isolation for every canonical object in the bounded flow.
\set ON_ERROR_STOP on
\set user_a '''b1000000-0000-4000-8000-00000000000a'''
\set user_b '''b1000000-0000-4000-8000-00000000000b'''

create or replace function pg_temp.ok(v boolean, msg text) returns void language plpgsql as $$
begin if v is distinct from true then raise exception 'isolation_assert_failed: %', msg; end if; end $$;

-- Run a statement and require it to fail with the given error text (or any privilege error when '*').
create or replace function pg_temp.denied(stmt text, expected text, msg text) returns void language plpgsql as $$
declare err text;
begin
  begin
    execute stmt;
  exception when others then
    err := sqlerrm;
    if expected <> '*' and position(expected in err) = 0 then
      raise exception 'isolation_assert_failed: % (wrong error: %)', msg, err;
    end if;
    return;
  end;
  raise exception 'isolation_assert_failed: % (statement succeeded)', msg;
end $$;

insert into auth.users (id, email) values (:user_a, 'iso-a@example.test'), (:user_b, 'iso-b@example.test');

-- A creates material, summary; worker completes it.
select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;
select public.create_text_material('A private notes', 'Secret text of user A.') as mat_a \gset
select public.request_summary(:'mat_a', 'iso-a-key-0001') as job_a \gset
reset role;
set role service_role;
select attempt_id, lease_token from public.claim_generation_job(60) \gset
select public.mark_attempt_dispatched(:'attempt_id', :'lease_token', 'fake:deterministic-v1');
select public.complete_generation_attempt(:'attempt_id', :'lease_token',
  '{"summary":"A summary","key_points":[],"language":"en-US"}', 'fake-exec-a', '{}', 1) as art_a \gset
select id as src_a from public.source_assets where material_id = :'mat_a' \gset
select id as ext_a from public.extracted_contents where source_asset_id = :'src_a' \gset
reset role;
-- A stores an object in its own prefix (storage API path convention).
insert into storage.objects (bucket_id, name, owner, owner_id)
values ('study-materials', :user_a || '/' || :'mat_a' || '/source.pdf', :user_a, :user_a);

-- 1. Unauthenticated (anon) gets nothing.
set role anon;
select pg_temp.denied('select * from public.materials', 'permission denied', 'anon cannot read materials');
select pg_temp.denied('select * from public.artifacts', 'permission denied', 'anon cannot read artifacts');
select pg_temp.denied('select * from public.library_items', 'permission denied', 'anon cannot read library');
select pg_temp.denied($$select public.create_text_material('x','y')$$, 'permission denied', 'anon cannot create material');
select pg_temp.denied($$select public.request_summary('$$ || :'mat_a' || $$','anon-key-0001')$$, 'permission denied', 'anon cannot request');
reset role;
-- authenticated role without a subject claim is also rejected by the RPC layer
select set_config('request.jwt.claim.sub', '', false);
set role authenticated;
select pg_temp.denied($$select public.create_text_material('x','y')$$, 'not_authenticated', 'no subject -> not_authenticated');
reset role;

-- 2. User B sees none of A's rows in any canonical table or the library projection.
select set_config('request.jwt.claim.sub', :user_b, false);
set role authenticated;
select pg_temp.ok((select count(*) = 0 from public.materials), 'B: materials empty');
select pg_temp.ok((select count(*) = 0 from public.source_assets), 'B: source_assets empty');
select pg_temp.ok((select count(*) = 0 from public.extracted_contents), 'B: extracted_contents empty');
select pg_temp.ok((select count(*) = 0 from public.generation_jobs), 'B: jobs empty');
select pg_temp.ok((select count(*) = 0 from public.generation_attempts), 'B: attempts empty');
select pg_temp.ok((select count(*) = 0 from public.artifacts), 'B: artifacts empty');
select pg_temp.ok((select count(*) = 0 from public.evidence_refs), 'B: evidence empty');
select pg_temp.ok((select count(*) = 0 from public.usage_events), 'B: usage empty');
select pg_temp.ok((select count(*) = 0 from public.quota_ledger), 'B: quota empty');
select pg_temp.ok((select count(*) = 0 from public.library_items), 'B: library empty');
select pg_temp.ok((select count(*) = 1 from public.accounts), 'B: sees only own account');
-- direct ID substitution also returns nothing
select pg_temp.ok((select count(*) = 0 from public.artifacts where id = :'art_a'), 'B: artifact by id hidden');

-- 3. B cannot write directly to any table (no table write grants for clients).
select pg_temp.denied($$update public.materials set title = 'pwn' where id = '$$ || :'mat_a' || $$'$$, 'permission denied', 'B: direct update denied');
select pg_temp.denied($$delete from public.artifacts where id = '$$ || :'art_a' || $$'$$, 'permission denied', 'B: direct delete denied');
select pg_temp.denied($$insert into public.materials (account_id,title,material_type) values ('$$ || :user_a || $$','x','text')$$, 'permission denied', 'B: forge row for A denied');

-- 4. B cannot act on A's objects through RPCs; errors are non-revealing (same as nonexistent).
select pg_temp.denied($$select public.request_summary('$$ || :'mat_a' || $$','b-steal-key-01')$$, 'material_not_found', 'B: request on A material');
select pg_temp.denied($$select public.request_summary(gen_random_uuid(),'b-random-key-1')$$, 'material_not_found', 'B: nonexistent material same error');
select pg_temp.denied($$select public.retry_generation_job('$$ || :'job_a' || $$')$$, 'job_not_found', 'B: retry A job');
select pg_temp.denied($$select public.delete_material('$$ || :'mat_a' || $$')$$, 'material_not_found', 'B: delete A material');
-- idempotency key namespaces are per account: B reusing A's key does not reveal A's job
select public.create_text_material('B notes', 'B text') as mat_b \gset
select public.request_summary(:'mat_b', 'iso-a-key-0001') as job_b \gset
select pg_temp.ok(:'job_b' <> :'job_a', 'B: same key string yields B''s own job');

-- 5. Worker RPCs are not callable by clients.
select pg_temp.denied('select * from public.claim_generation_job(60)', 'permission denied', 'B: cannot claim jobs');
select pg_temp.denied($$select public.complete_generation_attempt('$$ || :'attempt_id' || $$','$$ || :'lease_token' || $$','{}','x','{}',1)$$, 'permission denied', 'B: cannot complete attempts');
select pg_temp.denied($$select public.reconcile_generation_attempt('$$ || :'attempt_id' || $$',true)$$, 'permission denied', 'B: cannot reconcile');

-- 6. Storage: the object path does not grant access; B cannot read, write into, or delete A's prefix.
select pg_temp.ok((select count(*) = 0 from storage.objects), 'B: cannot list A objects');
select pg_temp.denied($$insert into storage.objects (bucket_id,name,owner) values ('study-materials','$$ || :user_a || '/' || :'mat_a' || $$/evil.pdf','$$ || :user_b || $$')$$, 'row-level security', 'B: cannot write into A prefix');
delete from storage.objects where name like :user_a || '%';
reset role;
select pg_temp.ok((select count(*) = 1 from storage.objects where name like :user_a || '%'), 'A object survived B delete attempt');

-- 7. Secret boundary: no client-callable function returns provider credentials; no secret-like columns exist.
select pg_temp.ok(not exists (select 1 from information_schema.columns where table_schema = 'public'
                   and column_name ~* '(api_key|secret|password|token)$' and column_name <> 'lease_token'), 'no secret columns');
select pg_temp.ok(not has_column_privilege('authenticated', 'public.generation_jobs', 'lease_token', 'UPDATE'), 'client cannot set lease token');

-- 8. Deletion revokes derived access for the owner too.
select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;
select pg_temp.ok((select count(*) = 1 from public.artifacts where id = :'art_a'), 'A: artifact visible before delete');
select public.delete_material(:'mat_a');
select pg_temp.ok((select count(*) = 0 from public.materials where id = :'mat_a'), 'A: material gone after delete');
select pg_temp.ok((select count(*) = 0 from public.artifacts where id = :'art_a'), 'A: artifact inaccessible after delete');
select pg_temp.ok((select count(*) = 0 from public.source_assets where id = :'src_a'), 'A: source revoked');
select pg_temp.ok((select count(*) = 0 from public.extracted_contents where id = :'ext_a'), 'A: extraction invalidated');
select pg_temp.ok((select count(*) = 0 from public.library_items where material_id = :'mat_a'), 'A: library entry gone');
select pg_temp.denied($$select public.request_summary('$$ || :'mat_a' || $$','after-delete-01')$$, 'material_not_found', 'A: cannot generate from deleted material');
reset role;
