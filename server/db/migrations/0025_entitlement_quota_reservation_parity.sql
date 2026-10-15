-- Entitlement parity: align read-only access decisions with server quota reservations.
--
-- A queued/processing generation already occupies capacity until it completes
-- or is released. The client must see the same authoritative decision as the
-- mutation RPC, while completed usage remains distinguishable from reserved
-- inflight work.

drop function if exists public.get_capability_access(text);

create function public.get_capability_access(p_capability text)
returns table (
  capability text,
  decision text,
  reason text,
  plan text,
  entitlement_status text,
  reconciliation_state text,
  renewal_state text,
  period_start date,
  consumed integer,
  reserved integer,
  limit_value integer,
  effective_until timestamptz,
  last_authoritative_verification_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := public.la_require_user();
  v_capability text := lower(btrim(coalesce(p_capability, '')));
  v_limit_key text;
  v_target_artifact_type text;
  v_ent public.entitlements%rowtype;
  v_used integer := 0;
  v_reserved integer := 0;
  v_limit integer := 0;
  v_effectively_active boolean := false;
begin
  v_limit_key := case v_capability
    when 'summary' then 'summary_daily'
    when 'explain' then 'explain_daily'
    when 'grounded_explain' then 'explain_daily'
    when 'focus' then 'focus_daily'
    when 'explain_back' then 'explain_back_daily'
    else null
  end;

  if v_limit_key is null then
    raise exception 'unsupported_capability' using errcode = '22023';
  end if;

  if v_capability = 'grounded_explain' then
    v_capability := 'explain';
  end if;

  v_target_artifact_type := case v_capability
    when 'summary' then 'SUMMARY'
    when 'explain' then 'EXPLAIN'
    when 'focus' then 'FOCUS_HELP'
    else null
  end;

  select e.*
    into v_ent
  from public.entitlements e
  where e.account_id = v_user;

  if not found then
    return query select
      v_capability,
      'unavailable'::text,
      'entitlement_missing'::text,
      'unknown'::text,
      'missing'::text,
      'verified'::text,
      'none'::text,
      current_date,
      0,
      0,
      0,
      null::timestamptz,
      null::timestamptz;
    return;
  end if;

  begin
    v_limit := greatest(coalesce((v_ent.limits ->> v_limit_key)::integer, 0), 0);
  exception
    when invalid_text_representation then
      v_limit := 0;
  end;

  select coalesce(q.consumed, 0)
    into v_used
  from public.quota_ledger q
  where q.account_id = v_user
    and q.period_start = current_date
    and q.capability = v_capability;

  v_used := coalesce(v_used, 0);

  if v_target_artifact_type is not null then
    select count(*)::integer
      into v_reserved
    from public.generation_jobs j
    where j.account_id = v_user
      and j.target_artifact_type = v_target_artifact_type
      and j.state in ('QUEUED', 'PROCESSING')
      and j.created_at::date = current_date;
  end if;

  v_reserved := coalesce(v_reserved, 0);
  v_effectively_active :=
    v_ent.status = 'active'
    and (
      v_ent.effective_until is null
      or v_ent.effective_until > now()
      or v_ent.renewal_state = 'grace_or_retry'
    );

  if v_effectively_active then
    if v_limit > 0 and v_used + v_reserved < v_limit then
      return query select
        v_capability,
        'allowed'::text,
        case
          when v_ent.reconciliation_state in ('purchase_pending', 'restore_pending', 'reconciliation_error')
            then 'access_preserved_during_reconciliation'::text
          when v_ent.renewal_state = 'grace_or_retry'
            then 'grace_access_preserved'::text
          when v_ent.renewal_state = 'cancelled_future_expiry'
            then 'active_until_expiry'::text
          else 'entitled'::text
        end,
        v_ent.plan, v_ent.status, v_ent.reconciliation_state, v_ent.renewal_state,
        current_date, v_used, v_reserved, v_limit, v_ent.effective_until,
        v_ent.last_authoritative_verification_at;
      return;
    end if;

    if v_ent.reconciliation_state in ('purchase_pending', 'restore_pending') then
      return query select
        v_capability, 'pending'::text, v_ent.reconciliation_state,
        v_ent.plan, v_ent.status, v_ent.reconciliation_state, v_ent.renewal_state,
        current_date, v_used, v_reserved, v_limit, v_ent.effective_until,
        v_ent.last_authoritative_verification_at;
      return;
    end if;

    if v_ent.reconciliation_state = 'reconciliation_error' then
      return query select
        v_capability, 'unavailable'::text, 'reconciliation_error'::text,
        v_ent.plan, v_ent.status, v_ent.reconciliation_state, v_ent.renewal_state,
        current_date, v_used, v_reserved, v_limit, v_ent.effective_until,
        v_ent.last_authoritative_verification_at;
      return;
    end if;

    return query select
      v_capability,
      'denied'::text,
      case when v_limit <= 0 then 'capability_not_entitled'::text else 'quota_reached'::text end,
      v_ent.plan, v_ent.status, v_ent.reconciliation_state, v_ent.renewal_state,
      current_date, v_used, v_reserved, v_limit, v_ent.effective_until,
      v_ent.last_authoritative_verification_at;
    return;
  end if;

  if v_ent.reconciliation_state in ('purchase_pending', 'restore_pending') then
    return query select
      v_capability, 'pending'::text, v_ent.reconciliation_state,
      v_ent.plan, v_ent.status, v_ent.reconciliation_state, v_ent.renewal_state,
      current_date, v_used, v_reserved, v_limit, v_ent.effective_until,
      v_ent.last_authoritative_verification_at;
    return;
  end if;

  if v_ent.reconciliation_state = 'reconciliation_error' then
    return query select
      v_capability, 'unavailable'::text, 'reconciliation_error'::text,
      v_ent.plan, v_ent.status, v_ent.reconciliation_state, v_ent.renewal_state,
      current_date, v_used, v_reserved, v_limit, v_ent.effective_until,
      v_ent.last_authoritative_verification_at;
    return;
  end if;

  return query select
    v_capability, 'denied'::text, 'entitlement_inactive'::text,
    v_ent.plan, v_ent.status, v_ent.reconciliation_state, v_ent.renewal_state,
    current_date, v_used, v_reserved, v_limit, v_ent.effective_until,
    v_ent.last_authoritative_verification_at;
end
$$;

revoke all on function public.get_capability_access(text) from public, anon, authenticated;
grant execute on function public.get_capability_access(text) to authenticated;

create or replace function public.request_summary(
  p_material_id uuid,
  p_idempotency_key text,
  p_regenerate boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
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
  select * into v_job
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
    select * into v_job
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

  if coalesce(v_used, 0) + (
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
end
$$;

revoke all on function public.request_summary(uuid, text, boolean) from public, anon;
grant execute on function public.request_summary(uuid, text, boolean) to authenticated, service_role;
