\set ON_ERROR_STOP on

-- Material deletion is a user-content erasure boundary, not only a visibility tombstone.
-- Keep the minimal material tombstone plus aggregate usage/quota records, but remove
-- learner-provided source text, derived AI artifacts, generation payload links, Recall
-- truth tied to the deleted source, and Explain-back content through existing cascades.
create or replace function public.delete_material(p_material_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := public.la_require_user();
  v_lifecycle text;
begin
  select lifecycle_status
    into v_lifecycle
  from public.materials
  where id = p_material_id
    and account_id = v_user
  for update;

  if not found then
    raise exception 'material_not_found' using errcode = 'P0002';
  end if;

  -- Idempotent replay for the owner: the sensitive content is already gone.
  if v_lifecycle = 'deleted' then
    return;
  end if;

  update public.materials
     set title = 'Deleted material',
         lifecycle_status = 'deleted',
         processing_state = 'none',
         deleted_at = now()
   where id = p_material_id;

  -- Artifacts reference jobs/attempts without delete cascades, so remove
  -- generated content before deleting execution/source records.
  delete from public.artifacts
   where material_id = p_material_id
     and account_id = v_user;

  -- Usage events deliberately survive for quota/cost accounting; their
  -- generation foreign keys are ON DELETE SET NULL.
  delete from public.generation_jobs
   where material_id = p_material_id
     and account_id = v_user;

  -- This cascades extracted text, Recall actions/evidence/state and
  -- Explain-back attempts bound to the deleted source.
  delete from public.source_assets
   where material_id = p_material_id
     and account_id = v_user;
end;
$$;

revoke all on function public.delete_material(uuid) from public, anon;
grant execute on function public.delete_material(uuid) to authenticated, service_role;
