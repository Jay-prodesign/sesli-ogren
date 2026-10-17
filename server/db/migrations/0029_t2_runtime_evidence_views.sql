-- Step 17 / Gate T2 runtime evidence projection.
-- Thresholds remain unfrozen; this view exposes measured dogfood evidence only.

create or replace view public.analytics_processing_reliability_daily_v1 as
select
  date_trunc('day', e.occurred_at) as day,
  e.environment,
  count(*) filter (where e.event_name = 'material_processing_started')::bigint as started_count,
  count(*) filter (where e.event_name = 'material_processing_completed')::bigint as completed_count,
  count(*) filter (where e.event_name = 'material_processing_failed')::bigint as failed_count,
  count(*) filter (where e.event_name = 'material_processing_retried')::bigint as retry_count,
  case
    when count(*) filter (
      where e.event_name in ('material_processing_completed','material_processing_failed')
    ) = 0 then null
    else
      (count(*) filter (where e.event_name = 'material_processing_completed'))::numeric
      /
      (count(*) filter (
        where e.event_name in ('material_processing_completed','material_processing_failed')
      ))::numeric
  end as terminal_success_rate,
  percentile_cont(0.5) within group (order by e.duration_ms)
    filter (
      where e.duration_ms is not null
        and e.event_name in ('material_processing_completed','material_processing_failed')
    ) as p50_duration_ms,
  percentile_cont(0.95) within group (order by e.duration_ms)
    filter (
      where e.duration_ms is not null
        and e.event_name in ('material_processing_completed','material_processing_failed')
    ) as p95_duration_ms
from public.product_events e
where e.event_version = 1
  and e.event_name in (
    'material_processing_started',
    'material_processing_completed',
    'material_processing_failed',
    'material_processing_retried'
  )
group by 1, 2;
