-- Monetization / entitlement journey: server-authoritative capability access.
--
-- Provider/store selection and prices remain deliberately deferred. This
-- migration extends the canonical entitlement record with provider-neutral
-- reconciliation metadata and exposes one read-only access decision RPC.
-- Existing generation RPCs remain the final quota authority.

alter table public.entitlements
  add column if not exists reconciliation_state text not null default 'verified',
  add column if not exists renewal_state text not null default 'none',
  add column if not exists external_purchase_ref text,
  add column if not exists last_authoritative_verification_at timestamptz;

alter table public.entitlements
  drop constraint if exists entitlements_reconciliation_state_check;
alter table public.entitlements
  add constraint entitlements_reconciliation_state_check
  check (reconciliation_state in ('verified', 'purchase_pending', 'restore_pending', 'reconciliation_error'));

alter table public.entitlements
  drop constraint if exists entitlements_renewal_state_check;
alter table public.entitlements
  add constraint entitlements_renewal_state_check
  check (renewal_state in ('none', 'grace_or_retry', 'cancelled_future_expiry'));

update public.entitlements
set last_authoritative_verification_at = coalesce(last_authoritative_verification_at, updated_at)
where status = 'active'
  and last_authoritative_verification_at is null;

create or replace function public.get_capability_access(p_capability text)
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
  v_ent public.entitlements%rowtype;
  v_used integer := 0;
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

  select e.*
    into v_ent
  from public.entitlements e
  where e.account_id = v_user;

  if not found then
    return query select
      v_capability,
      'denied'::text,
      'entitlement_missing'::text,
      'unknown'::text,
      'missing'::text,
      'verified'::text,
      'none'::text,
      current_date,
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
  v_effectively_active :=
    v_ent.status = 'active'
    and (v_ent.effective_until is null or v_ent.effective_until > now());

  if v_effectively_active then
    if v_limit <= 0 then
      return query select
        v_capability, 'denied'::text, 'capability_not_entitled'::text,
        v_ent.plan, v_ent.status, v_ent.reconciliation_state, v_ent.renewal_state,
        current_date, v_used, v_limit, v_ent.effective_until,
        v_ent.last_authoritative_verification_at;
      return;
    elsif v_used >= v_limit then
      return query select
        v_capability, 'denied'::text, 'quota_reached'::text,
        v_ent.plan, v_ent.status, v_ent.reconciliation_state, v_ent.renewal_state,
        current_date, v_used, v_limit, v_ent.effective_until,
        v_ent.last_authoritative_verification_at;
      return;
    else
      return query select
        v_capability,
        'allowed'::text,
        case
          when v_ent.reconciliation_state in ('restore_pending', 'reconciliation_error')
            then 'access_preserved_during_reconciliation'::text
          when v_ent.renewal_state = 'grace_or_retry'
            then 'grace_access_preserved'::text
          when v_ent.renewal_state = 'cancelled_future_expiry'
            then 'active_until_expiry'::text
          else 'entitled'::text
        end,
        v_ent.plan, v_ent.status, v_ent.reconciliation_state, v_ent.renewal_state,
        current_date, v_used, v_limit, v_ent.effective_until,
        v_ent.last_authoritative_verification_at;
      return;
    end if;
  end if;

  if v_ent.reconciliation_state in ('purchase_pending', 'restore_pending') then
    return query select
      v_capability, 'pending'::text, v_ent.reconciliation_state,
      v_ent.plan, v_ent.status, v_ent.reconciliation_state, v_ent.renewal_state,
      current_date, v_used, v_limit, v_ent.effective_until,
      v_ent.last_authoritative_verification_at;
    return;
  end if;

  if v_ent.reconciliation_state = 'reconciliation_error' then
    return query select
      v_capability, 'unavailable'::text, 'reconciliation_error'::text,
      v_ent.plan, v_ent.status, v_ent.reconciliation_state, v_ent.renewal_state,
      current_date, v_used, v_limit, v_ent.effective_until,
      v_ent.last_authoritative_verification_at;
    return;
  end if;

  return query select
    v_capability, 'denied'::text, 'entitlement_inactive'::text,
    v_ent.plan, v_ent.status, v_ent.reconciliation_state, v_ent.renewal_state,
    current_date, v_used, v_limit, v_ent.effective_until,
    v_ent.last_authoritative_verification_at;
end
$$;

revoke all on function public.get_capability_access(text) from public, anon, authenticated;
grant execute on function public.get_capability_access(text) to authenticated;
