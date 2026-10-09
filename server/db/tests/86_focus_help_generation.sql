\set ON_ERROR_STOP on
begin;

\set user_a '''f1000000-0000-4000-8000-000000000001'''

create or replace function pg_temp.ok(v boolean, msg text)
returns void language plpgsql as $$
begin
  if v is distinct from true then
    raise exception 'focus_help_assert_failed: %', msg;
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
      raise exception 'focus_help_assert_failed: % (got %)', msg, sqlerrm;
  end;
  raise exception 'focus_help_assert_failed: % (statement unexpectedly succeeded)', msg;
end $$;

insert into auth.users (id, email)
values (:user_a, 'focus-help@example.test');

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;

select public.ensure_text_material(
  'Focus source',
  'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür. Bitki karbondioksit ve su kullanır.',
  'sv_focus_help_0001'
) as material_a \gset

select e.source_content_hash as hash_a
from public.materials m
join public.source_assets s
  on s.material_id = m.id
 and s.revoked_at is null
join public.extracted_contents e
  on e.source_asset_id = s.id
 and e.invalidated_at is null
where m.id = :'material_a'::uuid
\gset

select public.request_focus_help(
  :'material_a'::uuid,
  :'hash_a',
  'Karbondioksit bu süreçte nasıl kullanılır?',
  'direct_explanation',
  'focus:request:0001'
) as job_a \gset

select public.request_focus_help(
  :'material_a'::uuid,
  :'hash_a',
  'Karbondioksit bu süreçte nasıl kullanılır?',
  'direct_explanation',
  'focus:request:0001'
) as job_replay \gset

select pg_temp.ok(
  :'job_a' = :'job_replay',
  'same Focus request must replay the same durable job'
);

select pg_temp.denied(
  format(
    'select public.request_focus_help(%L::uuid,%L,%L,%L,%L)',
    :'material_a',
    :'hash_a',
    'Işık enerjisinin rolü nedir?',
    'direct_explanation',
    'focus:request:0001'
  ),
  'idempotency_key_reused',
  'same idempotency key must not bind to another question'
);

reset role;

select pg_temp.ok(
  (
    select target_artifact_type = 'FOCUS_HELP'
       and generation_contract = public.la_focus_contract()
       and request_context ->> 'question' = 'Karbondioksit bu süreçte nasıl kullanılır?'
       and request_context ->> 'help_kind' = 'direct_explanation'
    from public.generation_jobs
    where id = :'job_a'::uuid
  ),
  'Focus job must retain the bounded request context before completion'
);

set role service_role;
select attempt_id as attempt_a, lease_token as lease_a
from public.claim_generation_job_by_id(:'job_a'::uuid, 120)
\gset

select public.mark_attempt_dispatched(
  :'attempt_a'::uuid,
  :'lease_a'::uuid,
  'fake:focus-v1'
);

select public.complete_focus_generation_attempt(
  :'attempt_a'::uuid,
  :'lease_a'::uuid,
  '{"response":"Bitki karbondioksiti organik madde üretiminde karbon kaynağı olarak kullanır.","key_points":["Karbondioksit kaynak metinde sürecin girdilerinden biridir."],"language":"tr-TR"}'::jsonb,
  'fake-focus-provider',
  '{"total_tokens":35,"cost_class":"test"}'::jsonb,
  9
) as artifact_a
\gset
reset role;

select pg_temp.ok(
  (
    select artifact_type = 'FOCUS_HELP'
    from public.artifacts
    where id = :'artifact_a'::uuid
  ),
  'Focus completion must create a FOCUS_HELP artifact'
);

select pg_temp.ok(
  (
    select state = 'SUCCEEDED'
       and not (request_context ? 'question')
       and request_context ? 'question_digest'
       and request_context ->> 'help_kind' = 'direct_explanation'
    from public.generation_jobs
    where id = :'job_a'::uuid
  ),
  'successful Focus job must drop plaintext question but preserve replay identity'
);

select pg_temp.ok(
  (
    select consumed = 1
    from public.quota_ledger
    where account_id = :user_a
      and period_start = current_date
      and capability = 'focus'
  ),
  'Focus completion must consume exactly one daily unit'
);

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;

select content ->> 'response' as response_text
from public.read_focus_help(
  :'job_a'::uuid,
  :'hash_a'
)
\gset

select public.request_focus_help(
  :'material_a'::uuid,
  :'hash_a',
  'Karbondioksit bu süreçte nasıl kullanılır?',
  'direct_explanation',
  'focus:request:0001'
) as job_after_success
\gset

reset role;

select pg_temp.ok(
  :'response_text' like 'Bitki karbondioksiti%',
  'Focus read must return the exact job artifact'
);
select pg_temp.ok(
  :'job_after_success' = :'job_a',
  'completed Focus replay must survive plaintext minimization'
);

rollback;
