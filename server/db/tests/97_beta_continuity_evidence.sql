\set ON_ERROR_STOP on
begin;

\set user_a '''e7000000-0000-4000-8000-000000000001'''

create or replace function pg_temp.ok(v boolean, msg text)
returns void language plpgsql as $$
begin
  if v is distinct from true then
    raise exception 'beta_continuity_assert_failed: %', msg;
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
      raise exception 'beta_continuity_assert_failed: % (got %)', msg, sqlerrm;
  end;
  raise exception 'beta_continuity_assert_failed: % (statement unexpectedly succeeded)', msg;
end $$;

insert into auth.users (id, email)
values (:user_a, 'beta-continuity@example.test');

insert into public.materials (id, account_id, title, material_type, processing_state)
values
  ('e7111111-1111-4111-8111-111111111111', :user_a, 'Material A', 'text', 'ready'),
  ('e7222222-2222-4222-8222-222222222222', :user_a, 'Material B', 'text', 'ready');

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;

-- First ready material and first meaningful study session.
select public.record_product_event(
  p_event_id => 'evt.beta.ready.a.0001',
  p_event_version => 1,
  p_event_name => 'material_processing_completed',
  p_session_id => 'session.beta.first.0001',
  p_environment => 'test',
  p_phase => 'completed',
  p_client_material_id => 'material_beta_a',
  p_server_material_id => 'e7111111-1111-4111-8111-111111111111',
  p_surface => 'source_editor',
  p_capability => 'source_processing',
  p_occurred_at => now() - interval '3 days'
);

select public.record_product_event(
  p_event_id => 'evt.beta.workspace.a.0001',
  p_event_version => 1,
  p_event_name => 'material_workspace_opened',
  p_session_id => 'session.beta.first.0001',
  p_environment => 'test',
  p_phase => 'completed',
  p_client_material_id => 'material_beta_a',
  p_server_material_id => 'e7111111-1111-4111-8111-111111111111',
  p_surface => 'workspace',
  p_occurred_at => now() - interval '3 days' + interval '1 minute'
);

select public.record_product_event(
  p_event_id => 'evt.beta.retrieval.a.0001',
  p_event_version => 1,
  p_event_name => 'retrieval_succeeded',
  p_session_id => 'session.beta.first.0001',
  p_environment => 'test',
  p_phase => 'completed',
  p_client_material_id => 'material_beta_a',
  p_server_material_id => 'e7111111-1111-4111-8111-111111111111',
  p_surface => 'recall',
  p_capability => 'recall',
  p_outcome_class => 'correct',
  p_occurred_at => now() - interval '3 days' + interval '2 minutes'
);

-- Same material returns in another session and performs fresh retrieval.
select public.record_product_event(
  p_event_id => 'evt.beta.workspace.a.0002',
  p_event_version => 1,
  p_event_name => 'material_workspace_opened',
  p_session_id => 'session.beta.return.0002',
  p_environment => 'test',
  p_phase => 'completed',
  p_client_material_id => 'material_beta_a',
  p_server_material_id => 'e7111111-1111-4111-8111-111111111111',
  p_surface => 'workspace',
  p_occurred_at => now() - interval '2 days'
);

-- Repeating activity inside the same return session must not invent another
-- material-return session.
select public.record_product_event(
  p_event_id => 'evt.beta.reader.a.0002',
  p_event_version => 1,
  p_event_name => 'reader_session_completed',
  p_session_id => 'session.beta.return.0002',
  p_environment => 'test',
  p_phase => 'completed',
  p_client_material_id => 'material_beta_a',
  p_server_material_id => 'e7111111-1111-4111-8111-111111111111',
  p_surface => 'reader',
  p_capability => 'reader',
  p_occurred_at => now() - interval '2 days' + interval '1 minute'
);

select public.record_product_event(
  p_event_id => 'evt.beta.retrieval.a.0002',
  p_event_version => 1,
  p_event_name => 'retrieval_failed',
  p_session_id => 'session.beta.return.0002',
  p_environment => 'test',
  p_phase => 'completed',
  p_client_material_id => 'material_beta_a',
  p_server_material_id => 'e7111111-1111-4111-8111-111111111111',
  p_surface => 'recall',
  p_capability => 'recall',
  p_outcome_class => 'gap_detected',
  p_occurred_at => now() - interval '2 days' + interval '2 minutes'
);

-- Second material becomes usable, but passive creation alone is not a
-- meaningful study session.
select public.record_product_event(
  p_event_id => 'evt.beta.ready.b.0001',
  p_event_version => 1,
  p_event_name => 'material_processing_completed',
  p_session_id => 'session.beta.secondmaterial.0003',
  p_environment => 'test',
  p_phase => 'completed',
  p_client_material_id => 'material_beta_b',
  p_server_material_id => 'e7222222-2222-4222-8222-222222222222',
  p_surface => 'source_editor',
  p_capability => 'source_processing',
  p_occurred_at => now() - interval '1 day'
);

select public.record_product_event(
  p_event_id => 'evt.beta.workspace.b.0001',
  p_event_version => 1,
  p_event_name => 'material_workspace_opened',
  p_session_id => 'session.beta.secondmaterial.0003',
  p_environment => 'test',
  p_phase => 'completed',
  p_client_material_id => 'material_beta_b',
  p_server_material_id => 'e7222222-2222-4222-8222-222222222222',
  p_surface => 'workspace',
  p_occurred_at => now() - interval '1 day' + interval '1 minute'
);

-- Duplicate delivery is idempotent and must not inflate the repeat-session
-- metric.
select public.record_product_event(
  p_event_id => 'evt.beta.retrieval.a.0002',
  p_event_version => 1,
  p_event_name => 'retrieval_failed',
  p_session_id => 'session.beta.return.0002',
  p_environment => 'test',
  p_phase => 'completed',
  p_client_material_id => 'material_beta_a',
  p_server_material_id => 'e7111111-1111-4111-8111-111111111111',
  p_surface => 'recall',
  p_capability => 'recall',
  p_outcome_class => 'gap_detected',
  p_occurred_at => now() - interval '2 days' + interval '2 minutes'
);

reset role;

select study_session_count::text as material_a_sessions,
       returned_v1::text as material_a_returned,
       (first_return_at is not null)::text as material_a_has_return
from public.analytics_material_return_v1
where account_id = :user_a
  and client_material_id = 'material_beta_a'
\gset

select pg_temp.ok(
  :'material_a_sessions' = '2'
  and :'material_a_returned' = 'true'
  and :'material_a_has_return' = 'true',
  'same material activity across two distinct sessions must produce one truthful return checkpoint'
);

select study_session_count::text as material_b_sessions,
       returned_v1::text as material_b_returned
from public.analytics_material_return_v1
where account_id = :user_a
  and client_material_id = 'material_beta_b'
\gset

select pg_temp.ok(
  :'material_b_sessions' = '1' and :'material_b_returned' = 'false',
  'a newly created material in one session must not be mislabeled as a return'
);

select
  (activated_at is not null)::text as activated,
  meaningful_study_session_count::text as meaningful_sessions,
  (first_repeat_meaningful_study_at is not null)::text as has_repeat_meaningful,
  ready_material_count::text as ready_materials,
  (second_material_ready_at is not null)::text as has_second_material,
  returned_material_count::text as returned_materials,
  (first_material_return_at is not null)::text as has_material_return
from public.analytics_beta_continuity_v1
where account_id = :user_a
\gset

select pg_temp.ok(
  :'activated' = 'true'
  and :'meaningful_sessions' = '2'
  and :'has_repeat_meaningful' = 'true'
  and :'ready_materials' = '2'
  and :'has_second_material' = 'true'
  and :'returned_materials' = '1'
  and :'has_material_return' = 'true',
  'beta continuity v1 must separate activation, repeat meaningful study, second material, and same-material return'
);

set role authenticated;
select pg_temp.denied(
  'select * from public.analytics_beta_continuity_v1',
  'permission denied',
  'beta evidence projections must remain internal product evidence rather than client authority'
);
reset role;

rollback;
