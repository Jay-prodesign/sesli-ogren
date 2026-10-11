-- LA-0026 — source-bound Explain-back attempt/evidence authority.
--
-- This migration intentionally does NOT perform semantic evaluation in SQL and
-- does not select an AI provider. It creates the server-owned persistence
-- boundary that a separately authorized evaluator may complete.

\set ON_ERROR_STOP on

create table public.explain_back_attempts (
  account_id uuid not null references public.accounts(id) on delete cascade,
  attempt_id text not null check (attempt_id ~ '^[A-Za-z0-9_.:-]{8,128}$'),
  material_id uuid not null references public.materials(id) on delete cascade,
  source_asset_id uuid not null references public.source_assets(id) on delete cascade,
  extracted_content_id uuid not null references public.extracted_contents(id) on delete cascade,
  source_content_hash text not null,
  response_digest text not null check (response_digest ~ '^[0-9a-f]{64}$'),
  response_length integer not null check (response_length between 1 and 2000),
  evaluation_kind text check (evaluation_kind in ('sufficient', 'gap_detected', 'not_evaluable')),
  evaluator_ref text,
  feedback text,
  targeted_repair text,
  created_at timestamptz not null default now(),
  evaluated_at timestamptz,
  primary key (account_id, attempt_id),
  check (
    (evaluation_kind is null and evaluator_ref is null and evaluated_at is null)
    or
    (evaluation_kind is not null and evaluator_ref is not null and evaluated_at is not null)
  )
);

alter table public.explain_back_attempts enable row level security;
alter table public.explain_back_attempts force row level security;
revoke all on public.explain_back_attempts from anon, authenticated;
grant select (
  attempt_id, material_id, source_content_hash, response_digest,
  response_length, evaluation_kind, evaluator_ref, feedback,
  targeted_repair, created_at, evaluated_at
) on public.explain_back_attempts to authenticated;
grant all on public.explain_back_attempts to service_role;

create policy explain_back_attempts_owner_read on public.explain_back_attempts
for select to authenticated
using ((select auth.uid()) is not null and account_id = (select auth.uid()));

create or replace function public.open_explain_back_attempt(
  p_attempt_id text,
  p_material_id uuid,
  p_source_content_hash text,
  p_response_digest text,
  p_response_length integer
)
returns text
language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := public.la_require_user();
  v_source public.source_assets%rowtype;
  v_extracted public.extracted_contents%rowtype;
  v_existing public.explain_back_attempts%rowtype;
begin
  if p_attempt_id is null or p_attempt_id !~ '^[A-Za-z0-9_.:-]{8,128}$' then
    raise exception 'invalid_attempt_id' using errcode = '22023';
  end if;
  if p_response_digest is null or p_response_digest !~ '^[0-9a-f]{64}$' then
    raise exception 'invalid_response_digest' using errcode = '22023';
  end if;
  if p_response_length is null or p_response_length < 1 or p_response_length > 2000 then
    raise exception 'invalid_response_length' using errcode = '22023';
  end if;

  select s.* into v_source
  from public.materials m
  join public.source_assets s
    on s.material_id = m.id
   and s.account_id = v_user
   and s.revoked_at is null
  where m.id = p_material_id
    and m.account_id = v_user
    and m.lifecycle_status = 'active'
  order by s.source_version desc
  limit 1;

  if not found then
    raise exception 'material_not_found' using errcode = 'P0002';
  end if;

  select e.* into v_extracted
  from public.extracted_contents e
  where e.source_asset_id = v_source.id
    and e.account_id = v_user
    and e.invalidated_at is null
  order by e.created_at desc
  limit 1;

  if not found then
    raise exception 'source_unavailable' using errcode = 'P0002';
  end if;
  if v_extracted.source_content_hash <> p_source_content_hash then
    raise exception 'stale_source' using errcode = 'P0001';
  end if;

  insert into public.explain_back_attempts (
    account_id, attempt_id, material_id, source_asset_id,
    extracted_content_id, source_content_hash, response_digest, response_length
  ) values (
    v_user, p_attempt_id, p_material_id, v_source.id,
    v_extracted.id, v_extracted.source_content_hash, p_response_digest, p_response_length
  )
  on conflict (account_id, attempt_id) do nothing;

  select * into v_existing
  from public.explain_back_attempts
  where account_id = v_user and attempt_id = p_attempt_id;

  if v_existing.material_id <> p_material_id
     or v_existing.source_content_hash <> p_source_content_hash
     or v_existing.response_digest <> p_response_digest
     or v_existing.response_length <> p_response_length then
    raise exception 'attempt_id_reused' using errcode = '22023';
  end if;

  return v_existing.attempt_id;
end;
$$;

create or replace function public.read_explain_back_attempt(p_attempt_id text)
returns table (
  attempt_id text,
  material_id uuid,
  source_content_hash text,
  response_digest text,
  response_length integer,
  evaluation_kind text,
  evaluator_ref text,
  feedback text,
  targeted_repair text,
  created_at timestamptz,
  evaluated_at timestamptz
)
language sql security definer set search_path = '' as $$
  select a.attempt_id, a.material_id, a.source_content_hash,
         a.response_digest, a.response_length, a.evaluation_kind,
         a.evaluator_ref, a.feedback, a.targeted_repair,
         a.created_at, a.evaluated_at
  from public.explain_back_attempts a
  where a.account_id = public.la_require_user()
    and a.attempt_id = p_attempt_id
$$;

revoke all on function public.open_explain_back_attempt(text, uuid, text, text, integer),
                       public.read_explain_back_attempt(text)
  from public, anon;
grant execute on function public.open_explain_back_attempt(text, uuid, text, text, integer),
                          public.read_explain_back_attempt(text)
  to authenticated;
