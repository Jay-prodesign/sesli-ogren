\set ON_ERROR_STOP on
begin;

create or replace function pg_temp.ok(v boolean, msg text)
returns void language plpgsql as $$
begin
  if v is distinct from true then
    raise exception 't2_runtime_metrics_assert_failed: %', msg;
  end if;
end $$;

select pg_temp.ok(
  to_regclass('public.analytics_processing_reliability_daily_v1') is not null,
  'processing reliability projection must exist before T2 dogfood'
);

select pg_temp.ok(
  to_regclass('public.analytics_ai_cost_latency_daily_v2') is not null,
  'AI latency v2 projection must exist before T2 dogfood'
);

select pg_temp.ok(
  exists (
    select 1
    from information_schema.columns
    where table_schema='public'
      and table_name='analytics_processing_reliability_daily_v1'
      and column_name='p95_duration_ms'
  ),
  'processing reliability projection must expose p95 duration'
);

select pg_temp.ok(
  exists (
    select 1
    from information_schema.columns
    where table_schema='public'
      and table_name='analytics_ai_cost_latency_daily_v2'
      and column_name='p95_latency_ms'
  ),
  'AI latency v2 projection must expose p95 latency'
);

select pg_temp.ok(
  exists (
    select 1
    from information_schema.columns
    where table_schema='public'
      and table_name='analytics_processing_reliability_daily_v1'
      and column_name='terminal_success_rate'
  ),
  'processing reliability projection must expose measured terminal success rate'
);

select pg_temp.ok(
  exists (
    select 1
    from information_schema.columns
    where table_schema='public'
      and table_name='analytics_ai_cost_latency_daily_v2'
      and column_name='terminal_success_rate'
  ),
  'AI latency v2 projection must expose measured terminal success rate'
);

rollback;
