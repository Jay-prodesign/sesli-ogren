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

-- Keep the Summary hard guard aligned with the capability-specific access decision.
-- Earlier schema versions counted every queued generation job, which could make
-- Explain/Focus reservations consume Summary capacity.
create or replace function public.request_summary(
  p_material_id uuid,
  p_idempotency_key text,
  p_regenerate boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $request_summary$
declare
  v_user uuid := public.la_require_user();
  v_source uuid;
  v_extracted uuid;
  v_hash text;
  v_fp text;
  v_job public.generation_jobs%rowtype;
  v_limit integer;
  v_used integer;
begin
  select *
    into v_job
  from public.generation_jobs
  where account_id = v_user
    and idempotency_key = p_idempotency_key;

  if found then
    if v_job.material_id <> p_material_id then
      raise exception 'idempotency_key_reused' using errcode = '22023';
    end if;
    return v_job.id;
  end if;

  select s.id, e.id, e.source_content_hash
    into v_source, v_extracted, v_hash
  from public.materials m
  join public.source_assets s
    on s.material_id = m.id
   and s.revoked_at is null
  join public.extracted_contents e
    on e.source_asset_id = s.id
   and e.invalidated_at is null
  where m.id = p_material_id
    and m.account_id = v_user
    and m.lifecycle_status = 'active'
  order by s.source_version desc, e.created_at desc
  limit 1;

  if v_source is null then
    raise exception 'material_not_found' using errcode = 'P0002';
  end if;

  v_fp := public.la_sha256(
    concat_ws(
      '|',
      p_material_id::text,
      v_extracted::text,
      v_hash,
      'SUMMARY',
      public.la_summary_contract()
    )
  );

  if not p_regenerate then
    select *
      into v_job
    from public.generation_jobs
    where account_id = v_user
      and request_fingerprint = v_fp
      and intent = 'initial'
      and state not in ('FAILED_FINAL', 'CANCELLED');

    if found then
      return v_job.id;
    end if;
  end if;

  select coalesce((e.limits ->> 'summary_daily')::integer, 0)
    into v_limit
  from public.entitlements e
  where e.account_id = v_user
    and e.status = 'active';

  select coalesce(q.consumed, 0)
    into v_used
  from public.quota_ledger q
  where q.account_id = v_user
    and q.period_start = current_date
    and q.capability = 'summary';
  v_used := coalesce(v_used, 0);

  if v_used + (
       select count(*)
       from public.generation_jobs j
       where j.account_id = v_user
         and j.target_artifact_type = 'SUMMARY'
         and j.state in ('QUEUED', 'PROCESSING')
         and j.created_at::date = current_date
     ) >= coalesce(v_limit, 0) then
    raise exception 'quota_exceeded' using errcode = 'P0001';
  end if;

  insert into public.generation_jobs (
    account_id,
    material_id,
    capability,
    target_artifact_type,
    source_asset_id,
    extracted_content_id,
    generation_contract,
    idempotency_key,
    request_fingerprint,
    intent
  )
  values (
    v_user,
    p_material_id,
    'structured_generation',
    'SUMMARY',
    v_source,
    v_extracted,
    public.la_summary_contract(),
    p_idempotency_key,
    v_fp,
    case when p_regenerate then 'regenerate' else 'initial' end
  )
  returning * into v_job;

  update public.materials
  set processing_state = 'queued'
  where id = p_material_id;

  return v_job.id;
end;
$request_summary$;

revoke all on function public.entitlement_capability_access(text)
from public, anon;

grant execute on function public.entitlement_capability_access(text)
to authenticated, service_role;
