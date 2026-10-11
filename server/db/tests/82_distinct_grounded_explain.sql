-- Summary and Explain must be distinct jobs/artifacts over the same grounded source.
\set ON_ERROR_STOP on
begin;

\set user_x '''d5000000-0000-4000-8000-000000000001'''

create or replace function pg_temp.ok(v boolean, msg text)
returns void language plpgsql as $$
begin
  if v is distinct from true then
    raise exception 'distinct_explain_assert_failed: %', msg;
  end if;
end $$;

insert into auth.users (id, email)
values (:user_x, 'distinct-explain@example.test');

select set_config('request.jwt.claim.sub', :user_x, false);
set role authenticated;

select public.ensure_text_material(
  'Grounded source',
  'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür.',
  'sv_distinct_explain_0001'
) as material_x \gset

select e.source_content_hash as hash_x
from public.materials m
join public.source_assets s
  on s.material_id = m.id
 and s.revoked_at is null
join public.extracted_contents e
  on e.source_asset_id = s.id
 and e.invalidated_at is null
where m.id = :'material_x'::uuid
\gset

select public.request_summary(
  :'material_x'::uuid,
  'summary:distinct-explain-0001',
  false
) as summary_job \gset

select public.request_grounded_explain(
  :'material_x'::uuid,
  :'hash_x',
  'explain:distinct-explain-0001'
) as explain_job \gset

reset role;

select pg_temp.ok(
  :'summary_job' <> :'explain_job',
  'Summary and Explain must not collapse onto one job'
);
select pg_temp.ok(
  (
    select target_artifact_type = 'SUMMARY'
       and generation_contract = public.la_summary_contract()
    from public.generation_jobs
    where id = :'summary_job'::uuid
  ),
  'Summary job contract changed'
);
select pg_temp.ok(
  (
    select target_artifact_type = 'EXPLAIN'
       and generation_contract = public.la_explain_contract()
    from public.generation_jobs
    where id = :'explain_job'::uuid
  ),
  'Explain job is not distinct'
);

set role service_role;
select attempt_id as explain_attempt, lease_token as explain_lease
from public.claim_generation_job_by_id(:'explain_job'::uuid, 120)
\gset

select public.mark_attempt_dispatched(
  :'explain_attempt'::uuid,
  :'explain_lease'::uuid,
  'fake:explain-v1'
);

select public.complete_explain_generation_attempt(
  :'explain_attempt'::uuid,
  :'explain_lease'::uuid,
  '{"explanation":"Fotosentezde ışık enerjisi, bitkinin daha sonra kullanabileceği kimyasal enerji biçiminde depolanır.","key_points":["Işık enerji girdisidir","Enerji kimyasal biçimde depolanır"],"language":"tr-TR"}'::jsonb,
  'fake-explain-provider',
  '{"total_tokens":42,"cost_class":"test"}'::jsonb,
  12
) as explain_artifact
\gset
reset role;

select pg_temp.ok(
  (
    select artifact_type = 'EXPLAIN'
    from public.artifacts
    where id = :'explain_artifact'::uuid
  ),
  'Explain completion did not create an EXPLAIN artifact'
);
select pg_temp.ok(
  (
    select state = 'QUEUED'
    from public.generation_jobs
    where id = :'summary_job'::uuid
  ),
  'Completing Explain must not consume the Summary job'
);

select set_config('request.jwt.claim.sub', :user_x, false);
set role authenticated;

select content ->> 'explanation' as explanation_text
from public.read_grounded_explain(
  :'material_x'::uuid,
  :'hash_x'
)
\gset

reset role;

select pg_temp.ok(
  :'explanation_text' like 'Fotosentezde%',
  'Grounded Explain read did not return the EXPLAIN artifact'
);

rollback;
