\set ON_ERROR_STOP on

begin;

-- LA-0025 behavioral regression over the accepted M4 generation authority.
\set user_a '''c2000000-0000-4000-8000-000000000001'''
\set user_b '''c2000000-0000-4000-8000-000000000002'''

create or replace function pg_temp.denied(stmt text, expected text, msg text)
returns void language plpgsql as $$
declare err text;
begin
  begin execute stmt;
  exception when others then
    err := sqlerrm;
    if position(expected in err) = 0 then
      raise exception 'explain_assert_failed: % (wrong error: %)', msg, err;
    end if;
    return;
  end;
  raise exception 'explain_assert_failed: % (statement succeeded)', msg;
end $$;

insert into auth.users (id, email) values
  (:user_a, 'explain-a@example.test'),
  (:user_b, 'explain-b@example.test');

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;
select public.create_text_material(
  'Explain source',
  'Fotosentez ışık enerjisinin kimyasal enerjiye dönüşmesine yardımcı olur.'
) as material_a \gset
reset role;

select e.source_content_hash as hash_a
from public.materials m
join public.source_assets s on s.material_id = m.id and s.revoked_at is null
join public.extracted_contents e on e.source_asset_id = s.id and e.invalidated_at is null
where m.id = :'material_a' \gset

-- Exact current source hash is accepted and repeated requests collapse onto
-- the same existing generation job through the canonical request_summary seam.
select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;
select public.request_grounded_explain(
  :'material_a', :'hash_a', 'explain-boundary-0001'
) as job_a \gset
select public.request_grounded_explain(
  :'material_a', :'hash_a', 'explain-boundary-0001'
) as job_replay \gset
reset role;

select case
  when :'job_a' = :'job_replay' then 'true'
  else 'false'
end as replay_ok \gset
\if :replay_ok
\else
  \echo 'explain_assert_failed: idempotent replay changed job'
  \quit 1
\endif

-- A stale digest must fail before a generation request can be accepted.
select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;
select pg_temp.denied(
  format('select public.request_grounded_explain(%L::uuid,%L,%L)',
    :'material_a', repeat('0',64), 'explain-boundary-stale'),
  'stale_source',
  'stale source rejected'
);
reset role;

-- Another authenticated learner cannot request or read this material.
select set_config('request.jwt.claim.sub', :user_b, false);
set role authenticated;
select pg_temp.denied(
  format('select public.request_grounded_explain(%L::uuid,%L,%L)',
    :'material_a', :'hash_a', 'explain-boundary-other-user'),
  'material_not_found',
  'cross-account request rejected'
);
select pg_temp.denied(
  format('select * from public.read_grounded_explain(%L::uuid,%L)',
    :'material_a', :'hash_a'),
  'material_not_found',
  'cross-account read rejected'
);
reset role;

rollback;
