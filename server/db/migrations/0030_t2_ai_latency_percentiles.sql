-- Gate T2 AI runtime evidence projection.
-- Thresholds remain unfrozen; this view exposes measured dogfood evidence only.

create or replace view public.analytics_ai_cost_latency_daily_v2 as
with usage_by_attempt as (
  select
    u.generation_attempt_id,
    coalesce(sum(u.estimated_cost_usd), 0)::numeric as estimated_cost_usd
  from public.usage_events u
  where u.generation_attempt_id is not null
  group by u.generation_attempt_id
)
select
  date_trunc('day', a.started_at) as day,
  j.target_artifact_type,
  count(*)::bigint as attempt_count,
  count(*) filter (where a.status = 'succeeded')::bigint as succeeded_attempts,
  count(*) filter (where a.status = 'failed')::bigint as failed_attempts,
  count(*) filter (where a.status = 'abandoned')::bigint as abandoned_attempts,
  case
    when count(*) filter (
      where a.status in ('succeeded','failed','abandoned')
    ) = 0 then null
    else
      (count(*) filter (where a.status = 'succeeded'))::numeric
      /
      (count(*) filter (
        where a.status in ('succeeded','failed','abandoned')
      ))::numeric
  end as terminal_success_rate,
  percentile_cont(0.5) within group (order by a.latency_ms)
    filter (where a.latency_ms is not null) as p50_latency_ms,
  percentile_cont(0.95) within group (order by a.latency_ms)
    filter (where a.latency_ms is not null) as p95_latency_ms,
  coalesce(sum(u.estimated_cost_usd), 0)::numeric as estimated_cost_usd
from public.generation_attempts a
join public.generation_jobs j on j.id = a.job_id
left join usage_by_attempt u on u.generation_attempt_id = a.id
group by 1, 2;
