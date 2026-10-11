\set ON_ERROR_STOP on

-- Focus help is keyed by its exact durable job. A newer Focus question may
-- supersede the older artifact for "latest" projections, but idempotent replay
-- of the older job must still be able to read its own immutable result.
create or replace function public.read_focus_help(
  p_job_id uuid,
  p_source_content_hash text
)
returns table (
  artifact_id uuid,
  source_content_hash text,
  content jsonb,
  provider_execution_ref text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := public.la_require_user();
  v_material uuid;
  v_current_hash text;
begin
  select j.material_id
    into v_material
  from public.generation_jobs j
  where j.id = p_job_id
    and j.account_id = v_user
    and j.generation_contract = public.la_focus_contract()
    and j.target_artifact_type = 'FOCUS_HELP';

  if v_material is null then
    raise exception 'job_not_found' using errcode = 'P0002';
  end if;

  select e.source_content_hash
    into v_current_hash
  from public.materials m
  join public.source_assets s
    on s.material_id = m.id
   and s.revoked_at is null
  join public.extracted_contents e
    on e.source_asset_id = s.id
   and e.invalidated_at is null
  where m.id = v_material
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
    and a.generation_job_id = p_job_id
    and a.artifact_type = 'FOCUS_HELP'
    and a.status in ('available', 'superseded')
    and e.invalidated_at is null
    and e.source_content_hash = p_source_content_hash
    and j.generation_contract = public.la_focus_contract()
  limit 1;
end;
$$;

revoke all on function public.read_focus_help(uuid, text)
from public, anon, authenticated;
grant execute on function public.read_focus_help(uuid, text)
to authenticated;
