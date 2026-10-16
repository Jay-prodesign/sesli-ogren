-- Privacy-safe first-party product analytics and observability.
--
-- Canonical taxonomy: V0_ANALYTICS_EVENT_CONTRACT_v0.1.
-- Raw learner source text, prompts, generated content and free-text answers
-- have no column or RPC parameter here. Analytics is product evidence only;
-- it never grants entitlement, learning state, mastery or authorization.

create table public.product_events (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  event_id text not null check (event_id ~ '^[A-Za-z0-9_.:-]{12,128}$'),
  event_version integer not null default 1 check (event_version >= 1 and event_version <= 1000),
  event_name text not null check (event_name in (
    'app_opened','session_started',
    'onboarding_started','onboarding_completed',
    'auth_started','auth_success','auth_failed','logout_completed',
    'material_add_started','material_source_selected','material_add_cancelled',
    'material_upload_started','material_uploaded',
    'material_processing_started','material_processing_completed',
    'material_processing_failed','material_processing_retried','material_deleted',
    'artifact_generation_requested','artifact_generation_started',
    'artifact_generation_completed','artifact_generation_failed',
    'artifact_opened','artifact_regeneration_requested',
    'summary_opened','key_concepts_opened','source_evidence_opened',
    'flashcard_session_started','flashcard_revealed',
    'flashcard_response_recorded','flashcard_session_completed',
    'flashcard_session_abandoned','flashcard_set_reopened',
    'quiz_started','quiz_answered','quiz_completed','quiz_abandoned',
    'quiz_retake_started','quiz_result_opened',
    'audio_generation_requested','audio_generation_completed',
    'audio_generation_failed','audio_started','audio_paused','audio_resumed',
    'audio_meaningful_listen','audio_completed',
    'library_opened','material_workspace_opened','material_reopened',
    'artifact_reopened','continue_studying_selected',
    'quota_checked','quota_limit_reached','paywall_viewed',
    'purchase_started','purchase_completed','purchase_failed',
    'purchase_restored','entitlement_changed',
    'settings_opened','privacy_controls_opened',
    'account_deletion_requested','account_deletion_completed','support_opened',
    'generation_job_stuck_detected','generation_job_recovered',
    'network_recovery','deep_link_failed','storage_access_denied',
    'app_error','provider_error','server_error',
    'learning_action_started','learning_action_completed',
    'retrieval_attempted','retrieval_succeeded','retrieval_failed',
    'learner_evidence_recorded','learner_state_changed',
    'next_best_action_selected','recovery_mission_offered',
    'recovery_mission_completed','milestone_reached',
    'meaningful_discovery_shown',
    'reader_session_completed'
  )),
  session_id text not null check (session_id ~ '^[A-Za-z0-9_.:-]{12,128}$'),
  app_version text check (app_version is null or app_version ~ '^[A-Za-z0-9_.:+-]{1,64}$'),
  platform text check (platform is null or platform in ('android','ios','macos','windows','linux','web','unknown')),
  locale text check (locale is null or locale ~ '^[A-Za-z0-9_-]{2,32}$'),
  environment text not null check (environment in ('development','test','staging','production')),
  phase text check (phase is null or phase in ('started','completed','failed','viewed')),
  client_material_id text check (
    client_material_id is null or client_material_id ~ '^[A-Za-z0-9_.:-]{1,128}$'
  ),
  server_material_id uuid references public.materials(id) on delete set null,
  source_version_id text check (
    source_version_id is null or source_version_id ~ '^[A-Za-z0-9_.:-]{1,160}$'
  ),
  artifact_id uuid references public.artifacts(id) on delete set null,
  generation_job_id uuid references public.generation_jobs(id) on delete set null,
  source_type text check (source_type is null or source_type ~ '^[a-z0-9_.:-]{1,64}$'),
  artifact_type text check (artifact_type is null or artifact_type ~ '^[A-Za-z0-9_.:-]{1,64}$'),
  surface text check (
    surface is null or surface in (
      'home','workspace','source_editor','reader','listen','recall',
      'flashcards','quiz','profile','entitlement'
    )
  ),
  capability text check (
    capability is null or capability in (
      'source_processing','summary','explain','focus','explain_back',
      'reader','listen','recall','flashcards','quiz','continuity'
    )
  ),
  outcome_class text check (
    outcome_class is null or outcome_class ~ '^[A-Za-z0-9_.:-]{1,64}$'
  ),
  reason_code text check (
    reason_code is null or reason_code ~ '^[A-Za-z0-9_.:-]{1,96}$'
  ),
  failure_class text check (
    failure_class is null or failure_class ~ '^[A-Za-z0-9_.:-]{1,96}$'
  ),
  rule_version text check (
    rule_version is null or rule_version ~ '^[A-Za-z0-9_.:+-]{1,96}$'
  ),
  policy_version text check (
    policy_version is null or policy_version ~ '^[A-Za-z0-9_.:+-]{1,96}$'
  ),
  feature_config_id text check (
    feature_config_id is null or feature_config_id ~ '^[A-Za-z0-9_.:-]{1,128}$'
  ),
  experiment_id text check (
    experiment_id is null or experiment_id ~ '^[A-Za-z0-9_.:-]{1,128}$'
  ),
  duration_ms integer check (duration_ms is null or duration_ms between 0 and 86400000),
  quantity numeric check (quantity is null or quantity between 0 and 1000000000),
  occurred_at timestamptz not null,
  received_at timestamptz not null default now(),
  unique (account_id, event_id)
);

create index product_events_account_time_idx
  on public.product_events (account_id, occurred_at desc);
create index product_events_name_time_idx
  on public.product_events (event_name, event_version, occurred_at desc);
create index product_events_session_idx
  on public.product_events (account_id, session_id, occurred_at);

alter table public.product_events enable row level security;
alter table public.product_events force row level security;
revoke all on table public.product_events from public, anon, authenticated;
grant all on table public.product_events to service_role;

create or replace function public.record_product_event(
  p_event_id text,
  p_event_version integer,
  p_event_name text,
  p_session_id text,
  p_environment text,
  p_app_version text default null,
  p_platform text default null,
  p_locale text default null,
  p_phase text default null,
  p_client_material_id text default null,
  p_server_material_id uuid default null,
  p_source_version_id text default null,
  p_artifact_id uuid default null,
  p_generation_job_id uuid default null,
  p_source_type text default null,
  p_artifact_type text default null,
  p_surface text default null,
  p_capability text default null,
  p_outcome_class text default null,
  p_reason_code text default null,
  p_failure_class text default null,
  p_rule_version text default null,
  p_policy_version text default null,
  p_feature_config_id text default null,
  p_experiment_id text default null,
  p_duration_ms integer default null,
  p_quantity numeric default null,
  p_occurred_at timestamptz default now()
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := public.la_require_user();
  v_id uuid;
  v_occurred_at timestamptz := coalesce(p_occurred_at, now());
begin
  if p_event_id is null or p_event_id !~ '^[A-Za-z0-9_.:-]{12,128}$' then
    raise exception 'invalid_event_id' using errcode = '22023';
  end if;
  if p_event_version is null or p_event_version < 1 or p_event_version > 1000 then
    raise exception 'unsupported_event_version' using errcode = '22023';
  end if;
  if p_session_id is null or p_session_id !~ '^[A-Za-z0-9_.:-]{12,128}$' then
    raise exception 'invalid_session_id' using errcode = '22023';
  end if;

  if p_server_material_id is not null and not exists (
    select 1
    from public.materials m
    where m.id = p_server_material_id
      and m.account_id = v_user
  ) then
    raise exception 'material_not_found' using errcode = 'P0002';
  end if;

  if p_artifact_id is not null and not exists (
    select 1
    from public.artifacts a
    where a.id = p_artifact_id
      and a.account_id = v_user
  ) then
    raise exception 'artifact_not_found' using errcode = 'P0002';
  end if;

  if p_generation_job_id is not null and not exists (
    select 1
    from public.generation_jobs j
    where j.id = p_generation_job_id
      and j.account_id = v_user
  ) then
    raise exception 'generation_job_not_found' using errcode = 'P0002';
  end if;

  -- occurred_at is the original product occurrence for offline replay.
  -- Clamp extreme skew so one broken client clock cannot poison beta reports.
  if v_occurred_at < now() - interval '30 days'
     or v_occurred_at > now() + interval '10 minutes' then
    v_occurred_at := now();
  end if;

  insert into public.product_events (
    account_id, event_id, event_version, event_name, session_id,
    app_version, platform, locale, environment, phase,
    client_material_id, server_material_id, source_version_id,
    artifact_id, generation_job_id, source_type, artifact_type,
    surface, capability, outcome_class, reason_code, failure_class,
    rule_version, policy_version, feature_config_id, experiment_id,
    duration_ms, quantity, occurred_at
  ) values (
    v_user, p_event_id, p_event_version, p_event_name, p_session_id,
    nullif(btrim(p_app_version), ''), p_platform, nullif(btrim(p_locale), ''),
    p_environment, p_phase,
    nullif(btrim(p_client_material_id), ''), p_server_material_id,
    nullif(btrim(p_source_version_id), ''), p_artifact_id, p_generation_job_id,
    p_source_type, p_artifact_type, p_surface, p_capability,
    p_outcome_class, nullif(btrim(p_reason_code), ''),
    nullif(btrim(p_failure_class), ''), nullif(btrim(p_rule_version), ''),
    nullif(btrim(p_policy_version), ''), nullif(btrim(p_feature_config_id), ''),
    nullif(btrim(p_experiment_id), ''), p_duration_ms, p_quantity, v_occurred_at
  )
  on conflict (account_id, event_id) do nothing
  returning id into v_id;

  if v_id is null then
    select e.id into v_id
    from public.product_events e
    where e.account_id = v_user
      and e.event_id = p_event_id;
  end if;

  return v_id;
end
$$;

revoke all on function public.record_product_event(
  text, integer, text, text, text, text, text, text, text, text, uuid, text,
  uuid, uuid, text, text, text, text, text, text, text, text, text, text, text,
  integer, numeric, timestamptz
) from public, anon, authenticated;
grant execute on function public.record_product_event(
  text, integer, text, text, text, text, text, text, text, text, uuid, text,
  uuid, uuid, text, text, text, text, text, text, text, text, text, text, text,
  integer, numeric, timestamptz
) to authenticated;

-- Versioned product-evidence formulas. Passive reading/listening remains
-- VALUE / CONTINUITY evidence; only admitted active-learning facts qualify a
-- Meaningful Study Session in v1.
create or replace view public.analytics_meaningful_study_sessions_v1 as
select
  e.account_id,
  e.session_id,
  min(e.occurred_at) as first_active_action_at,
  max(e.occurred_at) as last_active_action_at,
  count(*)::bigint as qualified_action_count,
  count(distinct coalesce(e.server_material_id::text, e.client_material_id))::bigint as distinct_material_count
from public.product_events e
where e.event_version = 1
  and e.event_name in (
    'retrieval_succeeded','retrieval_failed',
    'flashcard_response_recorded','quiz_answered'
  )
group by e.account_id, e.session_id;

create or replace view public.analytics_activation_v1 as
select
  a.id as account_id,
  min(e.occurred_at) filter (
    where e.event_version = 1
      and e.event_name = 'material_processing_completed'
  ) as first_source_ready_at,
  min(e.occurred_at) filter (
    where e.event_version = 1
      and e.event_name in (
        'retrieval_succeeded','retrieval_failed',
        'flashcard_response_recorded','quiz_answered'
      )
  ) as first_meaningful_study_action_at,
  (
    min(e.occurred_at) filter (
      where e.event_version = 1
        and e.event_name = 'material_processing_completed'
    ) is not null
    and
    min(e.occurred_at) filter (
      where e.event_version = 1
        and e.event_name in (
          'retrieval_succeeded','retrieval_failed',
          'flashcard_response_recorded','quiz_answered'
        )
    ) is not null
  ) as activated_v1
from public.accounts a
left join public.product_events e on e.account_id = a.id
group by a.id;

create or replace view public.analytics_reliability_daily_v1 as
select
  date_trunc('day', e.occurred_at) as day,
  e.environment,
  e.event_name,
  e.event_version,
  e.failure_class,
  e.reason_code,
  count(*)::bigint as event_count,
  percentile_cont(0.5) within group (order by e.duration_ms)
    filter (where e.duration_ms is not null) as median_duration_ms
from public.product_events e
where e.event_name in (
  'material_processing_failed','artifact_generation_failed',
  'generation_job_stuck_detected','generation_job_recovered',
  'network_recovery','deep_link_failed','storage_access_denied',
  'app_error','provider_error','server_error'
)
group by 1, 2, 3, 4, 5, 6;

create or replace view public.analytics_ai_cost_latency_daily_v1 as
select
  date_trunc('day', a.started_at) as day,
  j.target_artifact_type,
  count(*)::bigint as attempt_count,
  count(*) filter (where a.status = 'succeeded')::bigint as succeeded_attempts,
  count(*) filter (where a.status = 'failed')::bigint as failed_attempts,
  percentile_cont(0.5) within group (order by a.latency_ms)
    filter (where a.latency_ms is not null) as median_latency_ms,
  coalesce(sum(u.estimated_cost_usd), 0)::numeric as estimated_cost_usd
from public.generation_attempts a
join public.generation_jobs j on j.id = a.job_id
left join public.usage_events u on u.generation_attempt_id = a.id
group by 1, 2;

revoke all on public.analytics_meaningful_study_sessions_v1 from public, anon, authenticated;
revoke all on public.analytics_activation_v1 from public, anon, authenticated;
revoke all on public.analytics_reliability_daily_v1 from public, anon, authenticated;
revoke all on public.analytics_ai_cost_latency_daily_v1 from public, anon, authenticated;
grant select on public.analytics_meaningful_study_sessions_v1 to service_role;
grant select on public.analytics_activation_v1 to service_role;
grant select on public.analytics_reliability_daily_v1 to service_role;
grant select on public.analytics_ai_cost_latency_daily_v1 to service_role;
