-- Quick Recap: atomically create/reuse a server text material and request its initial summary.
-- One RPC transaction prevents orphan materials when the client loses a response between
-- material creation and generation-job creation.
\set ON_ERROR_STOP on

create or replace function public.submit_text_summary(
  p_title text,
  p_text text,
  p_client_source_id text
)
returns table (material_id uuid, job_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := public.la_require_user();
  v_client_source_id text := btrim(coalesce(p_client_source_id, ''));
  v_idempotency_key text;
  v_expected_hash text := public.la_sha256(p_text);
  v_existing_material_id uuid;
  v_existing_job_id uuid;
  v_existing_hash text;
  v_material uuid;
  v_job uuid;
begin
  if v_client_source_id !~ '^[A-Za-z0-9_.:-]{8,96}$' then
    raise exception 'invalid_client_source_id' using errcode = '22023';
  end if;

  v_idempotency_key := 'summary:source:' || v_client_source_id;

  select j.material_id, j.id, s.content_hash
    into v_existing_material_id, v_existing_job_id, v_existing_hash
  from public.generation_jobs j
  join public.source_assets s on s.id = j.source_asset_id
  where j.account_id = v_user
    and j.idempotency_key = v_idempotency_key
  limit 1;

  if found then
    if v_existing_hash <> v_expected_hash then
      raise exception 'idempotency_key_reused' using errcode = '22023';
    end if;
    return query select v_existing_material_id, v_existing_job_id;
    return;
  end if;

  begin
    v_material := public.create_text_material(p_title, p_text);
    v_job := public.request_summary(v_material, v_idempotency_key, false);
  exception
    when unique_violation then
      select j.material_id, j.id, s.content_hash
        into v_existing_material_id, v_existing_job_id, v_existing_hash
      from public.generation_jobs j
      join public.source_assets s on s.id = j.source_asset_id
      where j.account_id = v_user
        and j.idempotency_key = v_idempotency_key
      limit 1;

      if not found then raise; end if;
      if v_existing_hash <> v_expected_hash then
        raise exception 'idempotency_key_reused' using errcode = '22023';
      end if;
      return query select v_existing_material_id, v_existing_job_id;
      return;
  end;

  return query select v_material, v_job;
end;
$$;

revoke all on function public.submit_text_summary(text, text, text)
from public, anon;

grant execute on function public.submit_text_summary(text, text, text)
to authenticated, service_role;
