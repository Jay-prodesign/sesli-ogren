-- Sesli Öğren / Learning App — Architecture Proof canonical core schema (LA-0011).
--
-- One authority per canonical concept (V0_CANONICAL_DATA_CAPABILITY_CONTRACTS_v0.1):
--   accounts (IdentityAccount) · materials (Material) · source_assets (SourceAsset)
--   extracted_contents (ExtractedContent) · generation_jobs (GenerationJob)
--   generation_attempts (GenerationAttempt) · artifacts (Artifact) · evidence_refs (EvidenceRef)
--   usage_events (UsageEvent) · quota_ledger (QuotaLedger) · entitlements (Entitlement)
--   feature_configs (FeatureConfig) · library_items view (LibraryItem — a projection, not a store).
--
-- Provenance (docs/provenance/OPEN_SOURCE_REUSE_REGISTER.md, REUSE-0001/0002):
--   * set_updated_at(): DIRECT-REUSE of MoonlighC/ai-study-buddy@317e21d
--     supabase/migrations/001_initial_schema.sql (MIT, (c) 2026 MoonlighC).
--   * Owner-only RLS policy shape, "(select auth.uid()) is not null and owner = (select auth.uid())",
--     FORCE RLS + narrow SECURITY DEFINER RPCs with explicit relationship checks, attempt
--     dispatch/ambiguity/budget-effect lineage, lease tokens and "{user_id}/{uuid}/file" storage
--     ownership: ADAPTED from MoonlighC migrations 001, 004, 008, 010 (MIT) and re-keyed to the
--     canonical tables. No donor table is reused: public.materials (combined material + source +
--     extraction + summary) and study_generation_operations (second job authority) are
--     deliberately NOT carried over.
-- Donor licence notice (MIT) applies to the adapted portions:
--   Copyright (c) 2026 MoonlighC. Permission is hereby granted, free of charge, to any person
--   obtaining a copy of this software ... (full text: docs/provenance/licenses/MoonlighC-ai-study-buddy-MIT.txt)

\set ON_ERROR_STOP on

-- ---------------------------------------------------------------------------
-- Shared helpers
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.la_sha256(p_text text) returns text
language sql immutable set search_path = '' as $$
  select encode(extensions.digest(convert_to(p_text, 'UTF8'), 'sha256'), 'hex')
$$;

-- ---------------------------------------------------------------------------
-- IdentityAccount
-- ---------------------------------------------------------------------------
create table public.accounts (
  id uuid primary key references auth.users(id) on delete cascade,
  locale text not null default 'tr-TR' check (locale ~ '^[a-z]{2}-[A-Z]{2}$'),
  status text not null default 'active' check (status in ('active', 'deletion_requested', 'deleted')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.la_create_account_for_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.accounts (id) values (new.id) on conflict (id) do nothing;
  insert into public.entitlements (account_id) values (new.id) on conflict (account_id) do nothing;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Entitlement / FeatureConfig / QuotaLedger (server-authoritative seams)
-- ---------------------------------------------------------------------------
create table public.entitlements (
  account_id uuid primary key references public.accounts(id) on delete cascade,
  plan text not null default 'free' check (plan in ('free', 'premium', 'tester')),
  status text not null default 'active' check (status in ('active', 'expired', 'revoked')),
  effective_from timestamptz not null default now(),
  effective_until timestamptz,
  limits jsonb not null default '{"summary_daily": 20}'::jsonb,
  provider_ref text,
  updated_at timestamptz not null default now()
);

create trigger la_create_account after insert on auth.users
for each row execute function public.la_create_account_for_user();

create table public.feature_configs (
  key text primary key check (key ~ '^[a-z0-9_.]{3,64}$'),
  enabled boolean not null default false,
  rollout jsonb not null default '{}'::jsonb,
  min_version text,
  params jsonb not null default '{}'::jsonb,
  version integer not null default 1,
  updated_at timestamptz not null default now()
);

create table public.quota_ledger (
  account_id uuid not null references public.accounts(id) on delete cascade,
  period_start date not null,
  capability text not null,
  consumed integer not null default 0 check (consumed >= 0),
  primary key (account_id, period_start, capability)
);

-- ---------------------------------------------------------------------------
-- Material / SourceAsset / ExtractedContent
-- ---------------------------------------------------------------------------
create table public.materials (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  title text not null check (length(btrim(title)) between 1 and 300),
  material_type text not null check (material_type in ('text', 'pdf', 'image')),
  lifecycle_status text not null default 'active' check (lifecycle_status in ('active', 'deleted')),
  processing_state text not null default 'none'
    check (processing_state in ('none', 'queued', 'processing', 'ready', 'failed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  check ((lifecycle_status = 'deleted') = (deleted_at is not null))
);

create table public.source_assets (
  id uuid primary key default gen_random_uuid(),
  material_id uuid not null references public.materials(id) on delete cascade,
  account_id uuid not null references public.accounts(id) on delete cascade,
  source_type text not null check (source_type in ('pasted_text', 'pdf', 'image')),
  knowledge_class text not null default 'LEARNER_OWNED'
    check (knowledge_class in ('LEARNER_OWNED', 'TRUSTED_PLATFORM')),
  trust_class text not null default 'USER_PROVIDED' check (trust_class in ('USER_PROVIDED', 'AUTHORITATIVE')),
  storage_bucket text,
  storage_path text,
  inline_text text check (inline_text is null or length(inline_text) <= 200000),
  content_hash text not null check (content_hash ~ '^[0-9a-f]{64}$'),
  mime_type text,
  byte_size bigint check (byte_size is null or byte_size >= 0),
  source_version integer not null default 1 check (source_version >= 1),
  extraction_status text not null default 'pending' check (extraction_status in ('pending', 'extracted', 'failed')),
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  -- exactly one content location; stored objects live under "{account_id}/{material_id}/..."
  check ((inline_text is not null) <> (storage_path is not null)),
  check (storage_path is null or (storage_bucket is not null
         and split_part(storage_path, '/', 1) = account_id::text
         and split_part(storage_path, '/', 2) = material_id::text))
);

create table public.extracted_contents (
  id uuid primary key default gen_random_uuid(),
  source_asset_id uuid not null references public.source_assets(id) on delete cascade,
  account_id uuid not null references public.accounts(id) on delete cascade,
  method text not null,
  method_version text not null,
  normalized_text text not null check (length(normalized_text) between 1 and 200000),
  anchors jsonb not null default '[]'::jsonb,
  warnings jsonb not null default '[]'::jsonb,
  source_content_hash text not null,
  invalidated_at timestamptz,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- GenerationJob / GenerationAttempt  (the single generation authority)
-- ---------------------------------------------------------------------------
create table public.generation_jobs (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  material_id uuid not null references public.materials(id) on delete cascade,
  capability text not null check (capability = 'structured_generation'),
  target_artifact_type text not null check (target_artifact_type in ('SUMMARY')),
  source_asset_id uuid not null references public.source_assets(id) on delete cascade,
  extracted_content_id uuid not null references public.extracted_contents(id) on delete cascade,
  generation_contract text not null,
  idempotency_key text not null check (idempotency_key ~ '^[A-Za-z0-9_.:-]{8,128}$'),
  request_fingerprint text not null check (request_fingerprint ~ '^[0-9a-f]{64}$'),
  intent text not null default 'initial' check (intent in ('initial', 'regenerate')),
  state text not null default 'QUEUED' check (state in
    ('QUEUED', 'PROCESSING', 'SUCCEEDED', 'PARTIAL', 'FAILED_RETRYABLE', 'FAILED_FINAL', 'CANCELLED')),
  failure_class text,
  active_attempt_id uuid,
  attempt_count integer not null default 0 check (attempt_count >= 0),
  max_attempts integer not null default 3 check (max_attempts between 1 and 10),
  lease_token uuid,
  lease_expires_at timestamptz,
  created_at timestamptz not null default now(),
  started_at timestamptz,
  completed_at timestamptz,
  updated_at timestamptz not null default now(),
  unique (account_id, idempotency_key)
);
-- An ordinary (non-regeneration) request for the same material/source/contract collapses onto one live job.
create unique index generation_jobs_one_live_initial
  on public.generation_jobs (account_id, request_fingerprint)
  where intent = 'initial' and state not in ('FAILED_FINAL', 'CANCELLED');

create table public.generation_attempts (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.generation_jobs(id) on delete cascade,
  account_id uuid not null references public.accounts(id) on delete cascade,
  attempt_number integer not null check (attempt_number >= 1),
  predecessor_attempt_id uuid references public.generation_attempts(id),
  attempt_idempotency_key text not null unique,
  adapter_ref text,
  provider_execution_ref text,
  dispatch_state text not null default 'not_dispatched'
    check (dispatch_state in ('not_dispatched', 'dispatched', 'dispatch_unknown', 'response_known')),
  status text not null default 'running' check (status in ('running', 'succeeded', 'failed', 'abandoned')),
  budget_effect text not null default 'reserved' check (budget_effect in ('reserved', 'consumed', 'released')),
  failure_class text,
  latency_ms integer check (latency_ms is null or latency_ms >= 0),
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  unique (job_id, attempt_number)
);
alter table public.generation_jobs
  add constraint generation_jobs_active_attempt_fk
  foreign key (active_attempt_id) references public.generation_attempts(id);

-- ---------------------------------------------------------------------------
-- Artifact / EvidenceRef / UsageEvent
-- ---------------------------------------------------------------------------
create table public.artifacts (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  material_id uuid not null references public.materials(id) on delete cascade,
  artifact_type text not null check (artifact_type in ('SUMMARY')),
  version integer not null check (version >= 1),
  generation_job_id uuid not null unique references public.generation_jobs(id),
  generation_attempt_id uuid not null references public.generation_attempts(id),
  content jsonb not null,
  content_schema_version integer not null default 1,
  generation_settings jsonb not null default '{}'::jsonb,
  trust_class text not null default 'AI_GENERATED' check (trust_class = 'AI_GENERATED'),
  status text not null default 'available' check (status in ('available', 'superseded', 'deleted')),
  supersedes_artifact_id uuid references public.artifacts(id),
  created_at timestamptz not null default now(),
  unique (material_id, artifact_type, version)
);

create table public.evidence_refs (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  artifact_id uuid not null references public.artifacts(id) on delete cascade,
  source_asset_id uuid not null references public.source_assets(id) on delete cascade,
  extracted_content_id uuid references public.extracted_contents(id) on delete cascade,
  anchor jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table public.usage_events (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  capability text not null,
  generation_job_id uuid references public.generation_jobs(id) on delete set null,
  generation_attempt_id uuid references public.generation_attempts(id) on delete set null,
  quantity numeric not null check (quantity >= 0),
  unit text not null,
  cost_class text not null,
  estimated_cost_usd numeric check (estimated_cost_usd is null or estimated_cost_usd >= 0),
  idempotency_key text not null unique,
  created_at timestamptz not null default now()
);

create index materials_account_idx on public.materials (account_id, updated_at desc);
create index source_assets_material_idx on public.source_assets (material_id);
create index extracted_contents_source_idx on public.extracted_contents (source_asset_id);
create index generation_jobs_queue_idx on public.generation_jobs (state, created_at);
create index generation_jobs_material_idx on public.generation_jobs (material_id);
create index generation_attempts_job_idx on public.generation_attempts (job_id);
create index artifacts_material_idx on public.artifacts (material_id, artifact_type, version desc);
create index usage_events_account_idx on public.usage_events (account_id, created_at desc);

create trigger set_accounts_updated_at before update on public.accounts
for each row execute function public.set_updated_at();
create trigger set_materials_updated_at before update on public.materials
for each row execute function public.set_updated_at();
create trigger set_generation_jobs_updated_at before update on public.generation_jobs
for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- LibraryItem: product projection over canonical rows (no second store)
-- ---------------------------------------------------------------------------
create view public.library_items with (security_invoker = true) as
select m.id as material_id,
       m.account_id,
       m.title,
       m.material_type,
       m.processing_state,
       m.updated_at,
       a.id as summary_artifact_id,
       a.version as summary_version,
       a.created_at as summary_created_at
from public.materials m
left join lateral (
  select x.id, x.version, x.created_at
  from public.artifacts x
  where x.material_id = m.id and x.artifact_type = 'SUMMARY' and x.status = 'available'
  order by x.version desc limit 1
) a on true
where m.lifecycle_status = 'active';

-- ---------------------------------------------------------------------------
-- Row-level security: owner read-only for clients; all writes via RPCs below
-- ---------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['accounts','entitlements','feature_configs','quota_ledger','materials',
    'source_assets','extracted_contents','generation_jobs','generation_attempts','artifacts',
    'evidence_refs','usage_events'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('alter table public.%I force row level security', t);
    execute format('revoke all on table public.%I from anon, authenticated', t);
  end loop;
end
$$;

grant select on public.accounts, public.entitlements, public.feature_configs, public.quota_ledger,
  public.materials, public.source_assets, public.extracted_contents, public.generation_jobs,
  public.generation_attempts, public.artifacts, public.evidence_refs, public.usage_events
  to authenticated;
grant select on public.library_items to authenticated;
revoke all on public.library_items from anon;
grant all on all tables in schema public to service_role;

create policy accounts_owner_read on public.accounts for select to authenticated
  using ((select auth.uid()) is not null and id = (select auth.uid()));
create policy entitlements_owner_read on public.entitlements for select to authenticated
  using ((select auth.uid()) is not null and account_id = (select auth.uid()));
create policy feature_configs_read on public.feature_configs for select to authenticated
  using ((select auth.uid()) is not null);
create policy quota_owner_read on public.quota_ledger for select to authenticated
  using ((select auth.uid()) is not null and account_id = (select auth.uid()));
create policy materials_owner_read on public.materials for select to authenticated
  using ((select auth.uid()) is not null and account_id = (select auth.uid()) and lifecycle_status = 'active');
create policy source_assets_owner_read on public.source_assets for select to authenticated
  using ((select auth.uid()) is not null and account_id = (select auth.uid()) and revoked_at is null);
create policy extracted_owner_read on public.extracted_contents for select to authenticated
  using ((select auth.uid()) is not null and account_id = (select auth.uid()) and invalidated_at is null);
create policy jobs_owner_read on public.generation_jobs for select to authenticated
  using ((select auth.uid()) is not null and account_id = (select auth.uid()));
create policy attempts_owner_read on public.generation_attempts for select to authenticated
  using ((select auth.uid()) is not null and account_id = (select auth.uid()));
create policy artifacts_owner_read on public.artifacts for select to authenticated
  using ((select auth.uid()) is not null and account_id = (select auth.uid()) and status <> 'deleted');
create policy evidence_owner_read on public.evidence_refs for select to authenticated
  using ((select auth.uid()) is not null and account_id = (select auth.uid()));
create policy usage_owner_read on public.usage_events for select to authenticated
  using ((select auth.uid()) is not null and account_id = (select auth.uid()));

-- Storage: private objects only under "{auth.uid()}/{material uuid}/{file}" (ADAPTED from donor 004).
create policy la_source_objects_insert on storage.objects for insert to authenticated
with check (
  bucket_id = 'study-materials'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and coalesce(array_length(storage.foldername(name), 1), 0) = 2
  and (storage.foldername(name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  and btrim(storage.filename(name)) <> ''
);
create policy la_source_objects_read on storage.objects for select to authenticated
using (
  bucket_id = 'study-materials'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and coalesce(array_length(storage.foldername(name), 1), 0) = 2
);
create policy la_source_objects_delete on storage.objects for delete to authenticated
using (
  bucket_id = 'study-materials'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
