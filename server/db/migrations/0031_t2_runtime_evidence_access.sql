-- Internal T2 evidence projections are service-role only.

alter view public.analytics_processing_reliability_daily_v1
set (security_invoker = true);

alter view public.analytics_ai_cost_latency_daily_v2
set (security_invoker = true);

revoke all on public.analytics_processing_reliability_daily_v1
from public, anon, authenticated;

revoke all on public.analytics_ai_cost_latency_daily_v2
from public, anon, authenticated;

grant select on public.analytics_processing_reliability_daily_v1
to service_role;

grant select on public.analytics_ai_cost_latency_daily_v2
to service_role;
