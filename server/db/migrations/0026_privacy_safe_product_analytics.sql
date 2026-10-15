-- Privacy-safe first-party product analytics and observability.
--
-- This is deliberately provider-neutral. Raw learner source text, prompts,
-- generated content and free-text answers have no column or RPC parameter here.
-- Analytics is product evidence only; it never grants entitlement, learning
-- state, mastery or authorization.

create table public.product_events (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  event_id text not null check (event_id ~ '^[A-Za-z0-9_.:-]{12,128}$'),
  schema_version integer not null default 1 check (schema_version = 1),
  session_id text not null check (session_id ~ '^[A-Za-z0-9_.:-]{12,128}$'),
  event_type text not null check (event_type in (
    'runtime_restore',
    'source_ingest',
    'recall_prompt',
    'recall_attempt',
    'continuation_repair',
    'material_opened',
    'reader_session',
    'listen_session',
    'flashcard_review',
    'quiz_answer',
    'entitlement_boundary',
    'continuity_sync'
  )),
  phase text not null check (phase in ('started', 'completed', 'failed', 'viewed')),
  client_material_id text check (
    client_material_id is null or client_material_id ~ '^[A-Za-z0-9_.:-]{1,128}$'
  ),
  server_material_id uuid references public.materials(id) on delete set null,
  source_version_id text check (
    source_version_id is null or source_version_id ~ '^[A-Za-z0-9_.:-]{1,160}$'
  ),
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
    outcome_class is null or outcome_class ~ '^[a-z0-9_.:-]{1,64}$'
  ),
  reason_code text check (
    reason_code is null or reason_code ~ '^[A-Za-z0-9_.:-]{1,96}$'
  ),
  duration_ms integer check (duration_ms is null or duration_ms between 0 and 86400000),
  quantity numeric check (quantity is null or quantity between 0 and 1000000000),
  occurred_at timestamptz not null,
  received_at timestamptz not null default now(),
  unique (account_id, event_id)
);

create index product_events_account_time_idx
  on public.product_events (account_id, occurred_at desc);
create index product_events_type_time_idx
  on public.product_events (event_type, phase, occurred_at desc);
create index product_events_session_idx
  on public.product_events (account_id, session_id, occurred_at);

alter table public.product_events enable row level security;
alter table public.product_events force row level security;
revoke all on table public.product_events from public, anon, authenticated;
grant all on table public.product_events to service_role;

create or replace function public.record_product_event(
  p_event_id text,
  p_schema_version integer,
  p_session_id text,
  p_event_type text,
  p_phase text,
  p_client_material_id text default null,
  p_server_material_id uuid default null,
  p_source_version_id text default null,
  p_surface text default null,
  p_capability text default null,
  p_outcome_class text default null,
  p_reason_code text default null,
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
  if p_schema_version is distinct from 1 then
    raise exception 'unsupported_event_schema' using errcode = '22023';
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

  -- Client clocks are useful for offline replay, but extreme skew must not
  -- distort beta funnels. Preserve up to 30 days of offline history and clamp
  -- implausible timestamps to server receipt time.
  if v_occurred_at < now() - interval '30 days'
     or v_occurred_at > now() + interval '10 minutes' then
    v_occurred_at := now();
  end if;

  insert into public.product_events (
    account_id, event_id, schema_version, session_id, event_type, phase,
    client_material_id, server_material_id, source_version_id, surface,
    capability, outcome_class, reason_code, duration_ms, quantity, occurred_at
  ) values (
    v_user, p_event_id, p_schema_version, p_session_id, p_event_type, p_phase,
    nullif(btrim(p_client_material_id), ''), p_server_material_id,
    nullif(btrim(p_source_version_id), ''), p_surface, p_capability,
    p_outcome_class, nullif(btrim(p_reason_code), ''), p_duration_ms,
    p_quantity, v_occurred_at
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
  text, integer, text, text, text, text, uuid, text, text, text, text, text, integer, numeric, timestamptz
) from public, anon, authenticated;
grant execute on function public.record_product_event(
  text, integer, text, text, text, text, uuid, text, text, text, text, text, integer, numeric, timestamptz
) to authenticated;

-- Versioned product-evidence formulas. Passive reading/listening remains
-- VALUE / CONTINUITY evidence; only admitted active-learning completions
-- qualify a Meaningful Study Session in v1.
create or replace view public.analytics_meaningful_study_sessions_v1 as
select
  e.account_id,
  e.session_id,
  min(e.occurred_at) as first_active_action_at,
  max(e.occurred_at) as last_active_action_at,
  count(*)::bigint as qualified_action_count,
  count(distinct coalesce(e.server_material_id::text, e.client_material_id))::bigint as distinct_material_count
from public.product_events e
where e.phase = 'completed'
  and e.event_type in ('recall_attempt', 'flashcard_review', 'quiz_answer')
group by e.account_id, e.session_id;

create or replace view public.analytics_activation_v1 as
select
  a.id as account_id,
  min(e.occurred_at) filter (
    where e.event_type = 'source_ingest' and e.phase = 'completed'
  ) as first_source_ready_at,
  min(e.occurred_at) filter (
    where e.event_type in ('recall_attempt', 'flashcard_review', 'quiz_answer')
      and e.phase = 'completed'
  ) as first_meaningful_study_action_at,
  (
    min(e.occurred_at) filter (
      where e.event_type = 'source_ingest' and e.phase = 'completed'
    ) is not null
    and
    min(e.occurred_at) filter (
      where e.event_type in ('recall_attempt', 'flashcard_review', 'quiz_answer')
        and e.phase = 'completed'
    ) is not null
  ) as activated_v1
from public.accounts a
left join public.product_events e on e.account_id = a.id
group by a.id;

create or replace view public.analytics_reliability_daily_v1 as
select
  date_trunc('day', e.occurred_at) as day,
  e.event_type,
  e.phase,
  e.outcome_class,
  e.reason_code,
  count(*)::bigint as event_count,
  percentile_cont(0.5) within group (order by e.duration_ms)
    filter (where e.duration_ms is not null) as median_duration_ms
from public.product_events e
group by 1, 2, 3, 4, 5;

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
