\set ON_ERROR_STOP on
begin;

\set user_a '''e6000000-0000-4000-8000-000000000001'''
\set user_b '''e6000000-0000-4000-8000-000000000002'''

create or replace function pg_temp.ok(v boolean, msg text)
returns void language plpgsql as $$
begin
  if v is distinct from true then
    raise exception 'product_analytics_assert_failed: %', msg;
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
      raise exception 'product_analytics_assert_failed: % (got %)', msg, sqlerrm;
  end;
  raise exception 'product_analytics_assert_failed: % (statement unexpectedly succeeded)', msg;
end $$;

insert into auth.users (id, email)
values
  (:user_a, 'analytics-a@example.test'),
  (:user_b, 'analytics-b@example.test');

insert into public.materials (id, account_id, title, material_type, processing_state)
values
  ('e6111111-1111-4111-8111-111111111111', :user_a, 'A material', 'text', 'ready'),
  ('e6222222-2222-4222-8222-222222222222', :user_b, 'B material', 'text', 'ready');

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;

select public.record_product_event(
  p_event_id => 'evt.analytics.source.0001',
  p_event_version => 1,
  p_event_name => 'material_processing_completed',
  p_session_id => 'session.analytics.0001',
  p_environment => 'test',
  p_app_version => 'test-1',
  p_platform => 'linux',
  p_locale => 'tr_TR',
  p_phase => 'completed',
  p_client_material_id => 'material_client_a',
  p_server_material_id => 'e6111111-1111-4111-8111-111111111111',
  p_source_version_id => 'source_version_a',
  p_source_type => 'pasted_text',
  p_surface => 'source_editor',
  p_capability => 'source_processing',
  p_outcome_class => 'ready',
  p_reason_code => 'source_ready',
  p_duration_ms => 420,
  p_quantity => 1,
  p_occurred_at => now() - interval '2 minutes'
) as source_event_id \gset

select public.record_product_event(
  p_event_id => 'evt.analytics.recall.0001',
  p_event_version => 1,
  p_event_name => 'retrieval_succeeded',
  p_session_id => 'session.analytics.0001',
  p_environment => 'test',
  p_app_version => 'test-1',
  p_platform => 'linux',
  p_locale => 'tr_TR',
  p_phase => 'completed',
  p_client_material_id => 'material_client_a',
  p_server_material_id => 'e6111111-1111-4111-8111-111111111111',
  p_source_version_id => 'source_version_a',
  p_surface => 'recall',
  p_capability => 'recall',
  p_outcome_class => 'correct',
  p_reason_code => 'next_useful_action',
  p_rule_version => 'recall-rule-v1',
  p_policy_version => 'retention-v1',
  p_duration_ms => 850,
  p_quantity => 1,
  p_occurred_at => now() - interval '1 minute'
) as recall_event_id \gset

select public.record_product_event(
  p_event_id => 'evt.analytics.recall.0001',
  p_event_version => 1,
  p_event_name => 'retrieval_succeeded',
  p_session_id => 'session.analytics.0001',
  p_environment => 'test',
  p_phase => 'completed',
  p_client_material_id => 'material_client_a',
  p_server_material_id => 'e6111111-1111-4111-8111-111111111111',
  p_source_version_id => 'source_version_a',
  p_surface => 'recall',
  p_capability => 'recall',
  p_outcome_class => 'correct',
  p_reason_code => 'next_useful_action',
  p_duration_ms => 850,
  p_quantity => 1,
  p_occurred_at => now() - interval '1 minute'
) as recall_duplicate_id \gset

select pg_temp.ok(
  :'recall_event_id' = :'recall_duplicate_id',
  'duplicate event id must resolve idempotently to the original row'
);

select pg_temp.denied(
  'select * from public.product_events',
  'permission denied',
  'authenticated client must not read the internal analytics table directly'
);

select pg_temp.denied(
  $$select public.record_product_event(
    p_event_id => 'evt.analytics.cross.0001',
    p_event_version => 1,
    p_event_name => 'material_workspace_opened',
    p_session_id => 'session.analytics.0001',
    p_environment => 'test',
    p_phase => 'completed',
    p_client_material_id => 'material_client_b',
    p_server_material_id => 'e6222222-2222-4222-8222-222222222222',
    p_surface => 'workspace',
    p_quantity => 1
  )$$,
  'material_not_found',
  'an analytics event must not bind another account material'
);

select pg_temp.denied(
  $$select public.record_product_event(
    p_event_id => 'evt.analytics.invalid.0001',
    p_event_version => 1,
    p_event_name => 'raw_answer_text',
    p_session_id => 'session.analytics.0001',
    p_environment => 'test'
  )$$,
  'product_events_event_name_check',
  'canonical event allowlist must reject arbitrary content-bearing event names'
);

reset role;

select count(*)::text as stored_event_count
from public.product_events
where account_id = :user_a
\gset

select pg_temp.ok(
  :'stored_event_count' = '2',
  'idempotent retry must not duplicate the analytics row'
);

select count(*)::text as test_environment_count
from public.product_events
where account_id = :user_a
  and environment = 'test'
\gset

select pg_temp.ok(
  :'test_environment_count' = '2',
  'test events must remain explicitly separable from production'
);

select qualified_action_count::text as qualified_action_count,
       distinct_material_count::text as distinct_material_count
from public.analytics_meaningful_study_sessions_v1
where account_id = :user_a
  and session_id = 'session.analytics.0001'
\gset

select pg_temp.ok(
  :'qualified_action_count' = '1' and :'distinct_material_count' = '1',
  'Meaningful Study Session v1 must count retrieval without treating material processing as learning evidence'
);

select activated_v1::text as activated_v1,
       (first_source_ready_at is not null)::text as has_source_ready,
       (first_meaningful_study_action_at is not null)::text as has_study_action
from public.analytics_activation_v1
where account_id = :user_a
\gset

select pg_temp.ok(
  :'activated_v1' = 'true' and :'has_source_ready' = 'true' and :'has_study_action' = 'true',
  'activation v1 must require both usable source and meaningful active-learning action'
);

select pg_temp.ok(
  not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'product_events'
      and column_name in (
        'source_text','prompt','response_text','answer_text','content',
        'filename','email'
      )
  ),
  'analytics schema must have no raw learner-content or unnecessary identity column'
);

rollback;
