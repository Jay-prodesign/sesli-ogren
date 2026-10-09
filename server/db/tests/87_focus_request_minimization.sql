\set ON_ERROR_STOP on
begin;

\set user_a '''f2000000-0000-4000-8000-000000000001'''

create or replace function pg_temp.ok(v boolean, msg text)
returns void language plpgsql as $$
begin
  if v is distinct from true then
    raise exception 'focus_request_minimization_assert_failed: %', msg;
  end if;
end $$;

insert into auth.users (id, email)
values (:user_a, 'focus-minimization@example.test');

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;

select public.ensure_text_material(
  'Focus minimization source',
  'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür. Bitki karbondioksit ve su kullanır.',
  'sv_focus_minimize_0001'
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
  'Güvenli retry için soru metni gerekli mi?',
  'direct_explanation',
  'focus:minimize:safe-retry'
) as job_retry \gset

select public.request_focus_help(
  :'material_a'::uuid,
  :'hash_a',
  'Final hata sonrası soru neden tutulmasın?',
  'direct_explanation',
  'focus:minimize:final'
) as job_final \gset

select public.request_focus_help(
  :'material_a'::uuid,
  :'hash_a',
  'Belirsiz provider sonucu yeniden gönderilmeli mi?',
  'direct_explanation',
  'focus:minimize:ambiguous'
) as job_ambiguous \gset

select public.request_focus_help(
  :'material_a'::uuid,
  :'hash_a',
  'Materyal silinince soru metni kalmalı mı?',
  'hint',
  'focus:minimize:cancel'
) as job_cancel \gset

reset role;

set role service_role;

select attempt_id as retry_attempt, lease_token as retry_lease
from public.claim_generation_job_by_id(:'job_retry'::uuid, 120)
\gset
select public.mark_attempt_dispatched(
  :'retry_attempt'::uuid,
  :'retry_lease'::uuid,
  'fake:focus-minimize'
);
select public.fail_generation_attempt(
  :'retry_attempt'::uuid,
  :'retry_lease'::uuid,
  'retryable',
  'provider:known-retryable'
);

select attempt_id as final_attempt, lease_token as final_lease
from public.claim_generation_job_by_id(:'job_final'::uuid, 120)
\gset
select public.mark_attempt_dispatched(
  :'final_attempt'::uuid,
  :'final_lease'::uuid,
  'fake:focus-minimize'
);
select public.fail_generation_attempt(
  :'final_attempt'::uuid,
  :'final_lease'::uuid,
  'final',
  'provider:known-final'
);

select attempt_id as ambiguous_attempt, lease_token as ambiguous_lease
from public.claim_generation_job_by_id(:'job_ambiguous'::uuid, 120)
\gset
select public.mark_attempt_dispatched(
  :'ambiguous_attempt'::uuid,
  :'ambiguous_lease'::uuid,
  'fake:focus-minimize'
);
select public.fail_generation_attempt(
  :'ambiguous_attempt'::uuid,
  :'ambiguous_lease'::uuid,
  'ambiguous',
  null
);

reset role;

select pg_temp.ok(
  (
    select state = 'FAILED_RETRYABLE'
       and failure_class = 'retryable'
       and request_context ? 'question'
       and request_context ? 'question_digest'
    from public.generation_jobs
    where id = :'job_retry'::uuid
  ),
  'safe retry keeps plaintext only while a resend may still be required'
);

select pg_temp.ok(
  (
    select state = 'FAILED_FINAL'
       and not (request_context ? 'question')
       and request_context ? 'question_digest'
       and request_context ? 'help_kind'
    from public.generation_jobs
    where id = :'job_final'::uuid
  ),
  'final failure removes plaintext question'
);

select pg_temp.ok(
  (
    select state = 'FAILED_RETRYABLE'
       and failure_class = 'reconciliation_required'
       and not (request_context ? 'question')
       and request_context ? 'question_digest'
    from public.generation_jobs
    where id = :'job_ambiguous'::uuid
  ),
  'ambiguous provider outcome removes plaintext because blind resend is forbidden'
);

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;
select public.delete_material(:'material_a'::uuid);
reset role;

select pg_temp.ok(
  (
    select state = 'CANCELLED'
       and not (request_context ? 'question')
       and request_context ? 'question_digest'
    from public.generation_jobs
    where id = :'job_cancel'::uuid
  ),
  'material deletion cancels queued Focus work and removes plaintext question'
);

select pg_temp.ok(
  (
    select state = 'CANCELLED'
       and not (request_context ? 'question')
    from public.generation_jobs
    where id = :'job_retry'::uuid
  ),
  'later cancellation also minimizes a previously retryable Focus question'
);

rollback;
