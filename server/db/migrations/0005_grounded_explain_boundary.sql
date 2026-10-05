-- LA-0025 — client-safe grounded Explain boundary over the accepted generation authority.
--
-- This delta does not create a second generation store or provider path. It binds
-- the existing summary.v1 job/artifact authority to an exact current source hash
-- before a client may request or read generated interpretation.

\set ON_ERROR_STOP on

create or replace function public.request_grounded_explain(
  p_material_id uuid,
  p_source_content_hash text,
  p_idempotency_key text
)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := public.la_require_user();
  v_current_hash text;
begin
  select e.source_content_hash into v_current_hash
  from public.materials m
  join public.source_assets s on s.material_id = m.id and s.revoked_at is null
  join public.extracted_contents e on e.source_asset_id = s.id and e.invalidated_at is null
  where m.id = p_material_id
    and m.account_id = v_user
    and m.lifecycle_status = 'active'
  order by s.source_version desc, e.created_at desc
  limit 1;

  if v_current_hash is null then
    raise exception 'material_not_found' using errcode = 'P0002';
  end if;
  if v_current_hash <> p_source_content_hash then
    raise exception 'stale_source' using errcode = 'P0001';
  end if;

  return public.request_summary(p_material_id, p_idempotency_key, false);
end;
$$;

create or replace function public.read_grounded_explain(
  p_material_id uuid,
  p_source_content_hash text
)
returns table (
  artifact_id uuid,
  source_content_hash text,
  content jsonb,
  provider_execution_ref text,
  created_at timestamptz
)
language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := public.la_require_user();
begin
  return query
  select a.id,
         e.source_content_hash,
         a.content,
         ga.provider_execution_ref,
         a.created_at
  from public.artifacts a
  join public.generation_jobs j on j.id = a.generation_job_id
  join public.extracted_contents e on e.id = j.extracted_content_id
  join public.generation_attempts ga on ga.id = a.generation_attempt_id
  where a.account_id = v_user
    and a.material_id = p_material_id
    and a.artifact_type = 'SUMMARY'
    and a.status = 'available'
    and e.invalidated_at is null
    and e.source_content_hash = p_source_content_hash
    and j.generation_contract = public.la_summary_contract()
  order by a.version desc
  limit 1;
end;
$$;

revoke all on function public.request_grounded_explain(uuid, text, text),
                       public.read_grounded_explain(uuid, text)
  from public, anon;
grant execute on function public.request_grounded_explain(uuid, text, text),
                          public.read_grounded_explain(uuid, text)
  to authenticated;
