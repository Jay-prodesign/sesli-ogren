\set ON_ERROR_STOP on
begin;

-- LA-0026 behavioral regression for source-bound Explain-back attempts.
\set user_a '''c3000000-0000-4000-8000-000000000001'''
\set user_b '''c3000000-0000-4000-8000-000000000002'''

create or replace function pg_temp.denied(stmt text, expected text, msg text)
returns void language plpgsql as $$
declare err text;
begin
  begin execute stmt;
  exception when others then
    err := sqlerrm;
    if position(expected in err) = 0 then
      raise exception 'explain_back_assert_failed: % (wrong error: %)', msg, err;
    end if;
    return;
  end;
  raise exception 'explain_back_assert_failed: % (statement succeeded)', msg;
end $$;

insert into auth.users (id, email) values
  (:user_a, 'explain-back-a@example.test'),
  (:user_b, 'explain-back-b@example.test');

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;
select public.create_text_material(
  'Explain-back source',
  'Fotosentez ışık enerjisinin kimyasal enerjiye dönüşmesine yardımcı olur.'
) as material_a \gset
reset role;

select e.source_content_hash as hash_a
from public.materials m
join public.source_assets s on s.material_id = m.id and s.revoked_at is null
join public.extracted_contents e on e.source_asset_id = s.id and e.invalidated_at is null
where m.id = :'material_a' \gset

\set response_hash 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'

-- Exact current source opens an unevaluated attempt.
select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;
select public.open_explain_back_attempt(
  'explain-back-attempt-0001', :'material_a', :'hash_a',
  :'response_hash', 42
) as attempt_a \gset
select public.open_explain_back_attempt(
  'explain-back-attempt-0001', :'material_a', :'hash_a',
  :'response_hash', 42
) as attempt_replay \gset
select * from public.read_explain_back_attempt('explain-back-attempt-0001') \gset
reset role;

do $$
begin
  if :'attempt_a' <> :'attempt_replay' then
    raise exception 'explain_back_assert_failed: idempotent replay changed attempt';
  end if;
  if :'evaluation_kind' <> '' or :'evaluator_ref' <> '' then
    raise exception 'explain_back_assert_failed: unevaluated attempt pretended to have evidence';
  end if;
end $$;

-- Same attempt id with changed response is a conflicting replay.
select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;
select pg_temp.denied(
  format(
    'select public.open_explain_back_attempt(%L,%L::uuid,%L,%L,%s)',
    'explain-back-attempt-0001', :'material_a', :'hash_a',
    repeat('b',64), 43
  ),
  'attempt_id_reused',
  'conflicting replay rejected'
);
reset role;

-- Stale source is rejected before an attempt can be persisted.
select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;
select pg_temp.denied(
  format(
    'select public.open_explain_back_attempt(%L,%L::uuid,%L,%L,%s)',
    'explain-back-attempt-stale', :'material_a', repeat('0',64),
    :'response_hash', 42
  ),
  'stale_source',
  'stale source rejected'
);
reset role;

-- Another learner cannot open an attempt for user A's material and cannot read
-- user A's attempt through the security-definer read boundary.
select set_config('request.jwt.claim.sub', :user_b, false);
set role authenticated;
select pg_temp.denied(
  format(
    'select public.open_explain_back_attempt(%L,%L::uuid,%L,%L,%s)',
    'explain-back-attempt-other', :'material_a', :'hash_a',
    :'response_hash', 42
  ),
  'material_not_found',
  'cross-account open rejected'
);
select count(*) as cross_read_count
from public.read_explain_back_attempt('explain-back-attempt-0001') \gset
reset role;

do $$
begin
  if :'cross_read_count'::integer <> 0 then
    raise exception 'explain_back_assert_failed: cross-account read returned rows';
  end if;
end $$;

rollback;
