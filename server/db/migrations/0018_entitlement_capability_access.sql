-- Authoritative, side-effect-free capability access decision for monetization UX.
-- Existing generation/evaluator RPCs remain the hard enforcement boundary.
\set ON_ERROR_STOP on

create or replace function public.entitlement_capability_access(p_capability text)
returns table (
  capability text,
  decision text,
  reason_code text,
  plan text,
  entitlement_status text,
  period_start date,
  limit_value integer,
  consumed integer,
  reserved integer,
  remaining integer,
  effective_until timestamptz,
  entitlement_updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := public.la_require_user();
  v_capability text := lower(btrim(coalesce(p_capability, '')));
  v_entitlement public.entitlements%rowtype;
  v_limit integer;
  v_consumed integer := 0;
  v_reserved integer := 0;
  v_target_artifact_type text;
begin
  if v_capability not in ('summary', 'explain', 'focus', 'explain_back') then
    return query
    select v_capability, 'unavailable', 'capability_not_configured',
           null::text, null::text, current_date,
           null::integer, 0, 0, null::integer, null::timestamptz, null::timestamptz;
    return;
  end if;

  select e.*
    into v_entitlement
  from public.entitlements e
  where e.account_id = v_user;

  if not found then
    return query
    select v_capability, 'blocked', 'entitlement_missing',
           null::text, null::text, current_date,
           null::integer, 0, 0, 0, null::timestamptz, null::timestamptz;
    return;
  end if;

  if v_entitlement.status <> 'active'
     or v_entitlement.effective_from > now()
     or (v_entitlement.effective_until is not null and v_entitlement.effective_until <= now()) then
    return query
    select v_capability, 'blocked', 'entitlement_inactive',
           v_entitlement.plan, v_entitlement.status, current_date,
           null::integer, 0, 0, 0, v_entitlement.effective_until, v_entitlement.updated_at;
    return;
  end if;

  v_limit := case v_capability
    when 'summary' then (v_entitlement.limits ->> 'summary_daily')::integer
    when 'explain' then coalesce(
      (v_entitlement.limits ->> 'explain_daily')::integer,
      (v_entitlement.limits ->> 'summary_daily')::integer
    )
    when 'focus' then coalesce(
      (v_entitlement.limits ->> 'focus_daily')::integer,
      (v_entitlement.limits ->> 'explain_daily')::integer,
      (v_entitlement.limits ->> 'summary_daily')::integer
    )
    when 'explain_back' then coalesce(
      (v_entitlement.limits ->> 'explain_back_daily')::integer,
      (v_entitlement.limits ->> 'explain_daily')::integer,
      (v_entitlement.limits ->> 'summary_daily')::integer
    )
  end;

  if v_limit is null then
    return query
    select v_capability, 'unavailable', 'capability_not_configured',
           v_entitlement.plan, v_entitlement.status, current_date,
           null::integer, 0, 0, null::integer, v_entitlement.effective_until, v_entitlement.updated_at;
    return;
  end if;

  select q.consumed
    into v_consumed
  from public.quota_ledger q
  where q.account_id = v_user
    and q.period_start = current_date
    and q.capability = v_capability;
  v_consumed := coalesce(v_consumed, 0);

  if v_capability = 'summary' then
    v_target_artifact_type := 'SUMMARY';
  elsif v_capability = 'explain' then
    v_target_artifact_type := 'EXPLAIN';
  elsif v_capability = 'focus' then
    v_target_artifact_type := 'FOCUS_HELP';
  end if;

  if v_target_artifact_type is not null then
    select count(*)::integer
      into v_reserved
    from public.generation_jobs j
    where j.account_id = v_user
      and j.target_artifact_type = v_target_artifact_type
      and j.state in ('QUEUED', 'PROCESSING')
      and j.created_at::date = current_date;
  end if;

  if v_limit <= 0 then
    return query
    select v_capability, 'blocked', 'capability_not_entitled',
           v_entitlement.plan, v_entitlement.status, current_date,
           v_limit, v_consumed, v_reserved, 0, v_entitlement.effective_until, v_entitlement.updated_at;
    return;
  end if;

  if v_consumed + v_reserved >= v_limit then
    return query
    select v_capability, 'blocked', 'quota_reached',
           v_entitlement.plan, v_entitlement.status, current_date,
           v_limit, v_consumed, v_reserved, 0, v_entitlement.effective_until, v_entitlement.updated_at;
    return;
  end if;

  return query
  select v_capability, 'allowed', 'allowed',
         v_entitlement.plan, v_entitlement.status, current_date,
         v_limit, v_consumed, v_reserved,
         greatest(v_limit - v_consumed - v_reserved, 0),
         v_entitlement.effective_until, v_entitlement.updated_at;
end;
$$;

revoke all on function public.entitlement_capability_access(text)
from public, anon;

grant execute on function public.entitlement_capability_access(text)
to authenticated, service_role;
