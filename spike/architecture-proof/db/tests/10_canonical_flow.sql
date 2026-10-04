-- LA-0013: authenticated Material -> SourceAsset -> ExtractedContent -> GenerationJob ->
-- GenerationAttempt -> deterministic Summary -> persistent Summary Artifact -> Library projection.
-- The reopen-from-persistence half lives in 11_canonical_flow_reopen.sql (separate session).
\set ON_ERROR_STOP on
\set user_a '''a1000000-0000-4000-8000-000000000001'''

create or replace function pg_temp.ok(v boolean, msg text) returns void language plpgsql as $$
begin if v is distinct from true then raise exception 'flow_assert_failed: %', msg; end if; end $$;

-- Fixture isolation: the queue is shared across test files; start from an empty queue.
update public.generation_jobs set state = 'CANCELLED', lease_token = null, lease_expires_at = null
 where state in ('QUEUED', 'PROCESSING');

insert into auth.users (id, email) values (:user_a, 'flow-a@example.test');
select pg_temp.ok((select count(*) = 1 from public.accounts where id = :user_a), 'account created for auth user');

-- Authenticated user creates a pasted-text material.
select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;
select public.create_text_material('Hücre Biyolojisi', E'Hücre, canlıların en küçük yapı birimidir.\nMitokondri enerji üretir.') as material_id \gset
select pg_temp.ok((select count(*) = 1 from public.source_assets where material_id = :'material_id'), 'one SourceAsset');
select pg_temp.ok((select count(*) = 1 from public.extracted_contents e join public.source_assets s on s.id = e.source_asset_id
                   where s.material_id = :'material_id'), 'ExtractedContent derived from SourceAsset');
select public.request_summary(:'material_id', 'flow-key-0001') as job_id \gset
select pg_temp.ok((select state = 'QUEUED' from public.generation_jobs where id = :'job_id'), 'job QUEUED');
select pg_temp.ok((select processing_state = 'queued' from public.library_items where material_id = :'material_id'),
                  'library shows queued');
reset role;

-- Worker (service_role) claims, dispatches to the deterministic fake, completes.
set role service_role;
select job_id as claimed_job, attempt_id, lease_token, attempt_idempotency_key, normalized_text
  from public.claim_generation_job(60) \gset
select pg_temp.ok(:'claimed_job' = :'job_id', 'worker claimed the job');
select pg_temp.ok((select state = 'PROCESSING' from public.generation_jobs where id = :'job_id'), 'job PROCESSING');
select public.mark_attempt_dispatched(:'attempt_id', :'lease_token', 'fake:deterministic-v1');
select public.complete_generation_attempt(:'attempt_id', :'lease_token',
  '{"summary":"Hücre en küçük birimdir; mitokondri enerji üretir.","key_points":["hücre","mitokondri"],"language":"tr-TR"}',
  'fake-exec-0001', '{"total_tokens": 42, "cost_class": "fake", "estimated_cost_usd": 0}', 3) as artifact_id \gset
reset role;

-- Persisted Summary Artifact with lineage (not a string on the material row).
select pg_temp.ok((select state = 'SUCCEEDED' from public.generation_jobs where id = :'job_id'), 'job SUCCEEDED');
select pg_temp.ok((select artifact_type = 'SUMMARY' and version = 1 and generation_job_id = :'job_id'
                          and generation_attempt_id = :'attempt_id' and trust_class = 'AI_GENERATED'
                          and content ->> 'summary' like 'Hücre%'
                   from public.artifacts where id = :'artifact_id'), 'Summary is a persistent Artifact with lineage');
select pg_temp.ok((select count(*) = 1 from public.evidence_refs where artifact_id = :'artifact_id'), 'EvidenceRef recorded');
select pg_temp.ok((select count(*) = 1 from public.usage_events where generation_job_id = :'job_id'), 'one UsageEvent');
select pg_temp.ok(not exists (select 1 from information_schema.columns where table_schema = 'public'
                   and table_name = 'materials' and column_name like '%summary%'), 'Material has no summary column');

-- Owner reads through RLS; the library is a projection over canonical rows.
select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;
select pg_temp.ok((select summary_artifact_id = :'artifact_id' and processing_state = 'ready' and summary_version = 1
                   from public.library_items where material_id = :'material_id'), 'library projects the artifact');
reset role;
