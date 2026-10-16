-- Versioned beta continuity evidence derived from the existing privacy-safe
-- product event authority. This does not declare beta success or introduce
-- numeric success thresholds. It makes return/reopen semantics reproducible
-- before target-user beta reporting.

create or replace view public.analytics_material_return_v1 as
with study_sessions as (
  select
    e.account_id,
    e.client_material_id,
    e.session_id,
    min(e.occurred_at) as first_activity_at
  from public.product_events e
  where e.event_version = 1
    and e.client_material_id is not null
    and e.event_name in (
      'material_workspace_opened',
      'source_evidence_opened',
      'learning_action_started',
      'retrieval_attempted',
      'flashcard_response_recorded',
      'quiz_answered',
      'audio_started',
      'reader_session_completed'
    )
  group by e.account_id, e.client_material_id, e.session_id
),
ranked as (
  select
    s.*,
    row_number() over (
      partition by s.account_id, s.client_material_id
      order by s.first_activity_at, s.session_id
    ) as session_rank
  from study_sessions s
)
select
  r.account_id,
  r.client_material_id,
  min(r.first_activity_at) filter (where r.session_rank = 1) as first_study_at,
  min(r.first_activity_at) filter (where r.session_rank = 2) as first_return_at,
  count(*)::bigint as study_session_count,
  (count(*) >= 2) as returned_v1
from ranked r
group by r.account_id, r.client_material_id;

create or replace view public.analytics_beta_continuity_v1 as
with meaningful_ranked as (
  select
    s.account_id,
    s.session_id,
    s.first_active_action_at,
    row_number() over (
      partition by s.account_id
      order by s.first_active_action_at, s.session_id
    ) as session_rank
  from public.analytics_meaningful_study_sessions_v1 s
),
meaningful_by_account as (
  select
    m.account_id,
    count(*)::bigint as meaningful_study_session_count,
    min(m.first_active_action_at) filter (where m.session_rank = 2) as first_repeat_meaningful_study_at
  from meaningful_ranked m
  group by m.account_id
),
ready_materials as (
  select
    e.account_id,
    e.client_material_id,
    min(e.occurred_at) as first_ready_at
  from public.product_events e
  where e.event_version = 1
    and e.event_name = 'material_processing_completed'
    and e.client_material_id is not null
  group by e.account_id, e.client_material_id
),
ready_ranked as (
  select
    r.*,
    row_number() over (
      partition by r.account_id
      order by r.first_ready_at, r.client_material_id
    ) as material_rank
  from ready_materials r
),
ready_by_account as (
  select
    r.account_id,
    count(*)::bigint as ready_material_count,
    min(r.first_ready_at) filter (where r.material_rank = 2) as second_material_ready_at
  from ready_ranked r
  group by r.account_id
),
returns_by_account as (
  select
    r.account_id,
    count(*) filter (where r.returned_v1)::bigint as returned_material_count,
    min(r.first_return_at) filter (where r.returned_v1) as first_material_return_at
  from public.analytics_material_return_v1 r
  group by r.account_id
)
select
  a.id as account_id,
  case
    when activation.activated_v1
      then greatest(activation.first_source_ready_at, activation.first_meaningful_study_action_at)
    else null
  end as activated_at,
  coalesce(m.meaningful_study_session_count, 0)::bigint as meaningful_study_session_count,
  m.first_repeat_meaningful_study_at,
  coalesce(r.ready_material_count, 0)::bigint as ready_material_count,
  r.second_material_ready_at,
  coalesce(ret.returned_material_count, 0)::bigint as returned_material_count,
  ret.first_material_return_at
from public.accounts a
left join public.analytics_activation_v1 activation on activation.account_id = a.id
left join meaningful_by_account m on m.account_id = a.id
left join ready_by_account r on r.account_id = a.id
left join returns_by_account ret on ret.account_id = a.id;

revoke all on public.analytics_material_return_v1 from public, anon, authenticated;
revoke all on public.analytics_beta_continuity_v1 from public, anon, authenticated;
grant select on public.analytics_material_return_v1 to service_role;
grant select on public.analytics_beta_continuity_v1 to service_role;
