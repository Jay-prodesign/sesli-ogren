\set ON_ERROR_STOP on
begin;

\set user_a '''f3000000-0000-4000-8000-000000000001'''

create or replace function pg_temp.ok(v boolean, msg text)
returns void language plpgsql as $$
begin
  if v is distinct from true then
    raise exception 'focus_replay_assert_failed: %', msg;
  end if;
end $$;

insert into auth.users (id, email)
values (:user_a, 'focus-replay@example.test');

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;

select public.ensure_text_material(
  'Focus replay source',
  'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür. Bitki karbondioksit ve su kullanır.',
  'sv_focus_replay_0001'
) as material_a \gset

select e.source_content_hash as hash_a
from public.materials m
join public.source_assets s on s.material_id = m.id and s.revoked_at is null
join public.extracted_contents e on e.source_asset_id = s.id and e.invalidated_at is null
where m.id = :'material_a'::uuid
\gset

select public.request_focus_help(
  :'material_a'::uuid,
  :'hash_a',
  'Karbondioksit bu süreçte nasıl kullanılır?',
  'direct_explanation',
  'focus:replay:first'
) as job_first \gset
reset role;

set role service_role;
select attempt_id as attempt_first, lease_token as lease_first
from public.claim_generation_job_by_id(:'job_first'::uuid, 120)
\gset
select public.mark_attempt_dispatched(:'attempt_first'::uuid, :'lease_first'::uuid, 'fake:focus-replay');
select public.complete_focus_generation_attempt(
  :'attempt_first'::uuid,
  :'lease_first'::uuid,
  '{"response":"İlk Focus yanıtı.","key_points":["Karbondioksit kaynakta bir girdidir."],"language":"tr-TR"}'::jsonb,
  'fake:first',
  '{"total_tokens":10,"cost_class":"test"}'::jsonb,
  5
);
reset role;

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;
select public.request_focus_help(
  :'material_a'::uuid,
  :'hash_a',
  'Işık enerjisi neye dönüşür?',
  'hint',
  'focus:replay:second'
) as job_second \gset
reset role;

set role service_role;
select attempt_id as attempt_second, lease_token as lease_second
from public.claim_generation_job_by_id(:'job_second'::uuid, 120)
\gset
select public.mark_attempt_dispatched(:'attempt_second'::uuid, :'lease_second'::uuid, 'fake:focus-replay');
select public.complete_focus_generation_attempt(
  :'attempt_second'::uuid,
  :'lease_second'::uuid,
  '{"response":"İkinci Focus yanıtı.","key_points":["Işık enerjisi kimyasal enerjiye dönüşür."],"language":"tr-TR"}'::jsonb,
  'fake:second',
  '{"total_tokens":11,"cost_class":"test"}'::jsonb,
  6
);
reset role;

select pg_temp.ok(
  (
    select count(*) = 1
    from public.artifacts
    where generation_job_id = :'job_first'::uuid
      and artifact_type = 'FOCUS_HELP'
      and status = 'superseded'
  ),
  'newer Focus help may supersede the earlier artifact in latest projections'
);

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;

select content ->> 'response' as first_response
from public.read_focus_help(:'job_first'::uuid, :'hash_a')
\gset

select public.request_focus_help(
  :'material_a'::uuid,
  :'hash_a',
  'Karbondioksit bu süreçte nasıl kullanılır?',
  'direct_explanation',
  'focus:replay:first'
) as replayed_job
\gset

reset role;

select pg_temp.ok(
  :'replayed_job' = :'job_first',
  'idempotent Focus replay must return the original job after a newer question'
);
select pg_temp.ok(
  :'first_response' = 'İlk Focus yanıtı.',
  'exact-job Focus replay must read its superseded immutable artifact'
);

rollback;
