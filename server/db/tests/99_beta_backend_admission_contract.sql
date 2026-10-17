\set ON_ERROR_STOP on
begin;

create or replace function pg_temp.ok(v boolean, msg text)
returns void language plpgsql as $$
begin
  if v is distinct from true then
    raise exception 'beta_backend_admission_assert_failed: %', msg;
  end if;
end $$;

-- Step 17 live beta admission must not proceed on a partially promoted schema.
-- This file is intentionally structural: behavior remains covered by the
-- migration-specific canonical tests that run before it.

select pg_temp.ok(
  to_regprocedure('public.delete_material(uuid)') is not null,
  '0017 material erasure RPC must exist'
);

select pg_temp.ok(
  exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='materials'
      and column_name='client_material_key'
  )
  and exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='source_assets'
      and column_name='client_source_version_key'
  ),
  '0018 cross-device material/source lineage columns must exist'
);

select pg_temp.ok(
  exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='ensure_text_material_continuity'
  )
  and exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='create_recall_continuity_action'
  ),
  '0018-0019 material and Recall continuity RPCs must exist'
);

select pg_temp.ok(
  to_regclass('public.retention_schedules') is not null
  and exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='read_recall_retention_continuity'
  ),
  '0020 Recall retention authority must exist'
);

select pg_temp.ok(
  exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='prepare_media_material_continuity'
  )
  and exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='read_material_continuity_v2'
  ),
  '0021 original-media continuity RPCs must exist'
);

select pg_temp.ok(
  to_regclass('public.passive_resume_positions') is not null
  and exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='write_passive_resume_continuity'
  ),
  '0022 passive resume continuity must exist'
);

select pg_temp.ok(
  exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='retention_schedules'
      and column_name='revision'
  )
  and exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='write_retention_continuity'
  ),
  '0023 unified retention CAS contract must exist'
);

select pg_temp.ok(
  exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='entitlements'
      and column_name='reconciliation_state'
  )
  and exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='entitlements'
      and column_name='last_authoritative_verification_at'
  )
  and to_regprocedure('public.get_capability_access(text)') is not null,
  '0024-0025 entitlement and quota authority must exist'
);

select pg_temp.ok(
  to_regclass('public.product_events') is not null
  and to_regprocedure(
    'public.record_product_event(text,integer,text,text,text,text,text,text,text,text,uuid,text,uuid,uuid,text,text,text,text,text,text,text,text,text,text,text,integer,numeric,timestamp with time zone)'
  ) is not null,
  '0026 privacy-safe product event authority must exist'
);

select pg_temp.ok(
  to_regclass('public.analytics_meaningful_study_sessions_v1') is not null
  and to_regclass('public.analytics_activation_v1') is not null
  and to_regclass('public.analytics_reliability_daily_v1') is not null
  and to_regclass('public.analytics_ai_cost_latency_daily_v1') is not null,
  '0026 v1 activation/reliability/cost projections must exist'
);

select pg_temp.ok(
  to_regclass('public.analytics_material_return_v1') is not null
  and to_regclass('public.analytics_beta_continuity_v1') is not null,
  '0027 beta continuity projections must exist'
);

select pg_temp.ok(
  exists (
    select 1
    from pg_policies
    where schemaname='storage'
      and tablename='objects'
      and policyname='la_permanent_users_only'
  )
  and exists (
    select 1
    from pg_policies
    where schemaname='public'
      and tablename='product_events'
      and policyname='la_permanent_users_only'
  ),
  '0028 permanent-user restrictive RLS boundary must exist'
);

select pg_temp.ok(
  pg_get_functiondef('public.la_require_user()'::regprocedure)
    like '%anonymous_not_allowed%',
  '0028 canonical RPC admission must reject anonymous Auth JWTs'
);

select pg_temp.ok(
  (
    select relrowsecurity and relforcerowsecurity
    from pg_class
    where oid='public.product_events'::regclass
  )
  and (
    select relrowsecurity and relforcerowsecurity
    from pg_class
    where oid='public.retention_schedules'::regclass
  )
  and (
    select relrowsecurity and relforcerowsecurity
    from pg_class
    where oid='public.passive_resume_positions'::regclass
  ),
  'beta evidence and continuity tables must keep forced RLS'
);

rollback;
