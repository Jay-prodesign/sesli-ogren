\set ON_ERROR_STOP on

-- Unify cross-device retention timing across Recall, Quiz and Flashcards.
-- Recall remains learner-evidence authoritative on the server. Quiz/Flashcard
-- clients may advance only the retention projection with CAS after first
-- synchronising the current server schedule; they cannot fabricate Recall
-- learner evidence or overwrite a concurrently advanced schedule.

alter table public.retention_schedules
  add column if not exists latest_evidence_kind text,
  add column if not exists latest_event_id text,
  add column if not exists revision bigint not null default 1;

alter table public.retention_schedules
  alter column latest_evidence_id drop not null,
  alter column latest_outcome drop not null;

update public.retention_schedules
set latest_evidence_kind = 'recall',
    latest_event_id = 'recall:' || latest_evidence_id::text
where latest_evidence_id is not null;

alter table public.retention_schedules
  alter column latest_evidence_kind set not null,
  alter column latest_event_id set not null;

alter table public.retention_schedules
  drop constraint if exists retention_schedules_latest_evidence_kind_check;
alter table public.retention_schedules
  add constraint retention_schedules_latest_evidence_kind_check
  check (latest_evidence_kind in ('recall','flashcard','quiz'));

alter table public.retention_schedules
  drop constraint if exists retention_schedules_latest_event_id_check;
alter table public.retention_schedules
  add constraint retention_schedules_latest_event_id_check
  check (length(btrim(latest_event_id)) between 8 and 240);

alter table public.retention_schedules
  drop constraint if exists retention_schedules_revision_check;
alter table public.retention_schedules
  add constraint retention_schedules_revision_check
  check (revision >= 1);

create or replace function public.la_retention_revision_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    new.revision := old.revision + 1;
  else
    new.revision := coalesce(new.revision, 1);
  end if;

  if new.latest_evidence_id is not null then
    if new.latest_outcome is null then
      raise exception 'invalid_retention_recall_projection' using errcode = '22023';
    end if;
    new.latest_evidence_kind := 'recall';
    new.latest_event_id := 'recall:' || new.latest_evidence_id::text;
  else
    if new.latest_evidence_kind not in ('flashcard','quiz') then
      raise exception 'invalid_retention_evidence_kind' using errcode = '22023';
    end if;
    if length(btrim(coalesce(new.latest_event_id, ''))) < 8 then
      raise exception 'invalid_retention_event_id' using errcode = '22023';
    end if;
    new.latest_outcome := null;
  end if;

  return new;
end;
$$;

drop trigger if exists retention_revision_guard on public.retention_schedules;
create trigger retention_revision_guard
before insert or update on public.retention_schedules
for each row execute function public.la_retention_revision_guard();

create or replace function public.read_retention_continuity(
  p_client_material_id text
)
returns table (
  client_material_id text,
  client_source_id text,
  source_anchor jsonb,
  latest_evidence_kind text,
  latest_event_id text,
  latest_outcome_band text,
  reason_code text,
  review_count integer,
  success_streak integer,
  interval_seconds integer,
  due_at timestamptz,
  last_reviewed_at timestamptz,
  policy_version text,
  revision bigint
)
language sql
security definer
set search_path = ''
as $$
  select m.client_material_key,
         s.client_source_version_key,
         jsonb_strip_nulls(
           jsonb_build_object(
             'startOffset', r.source_start,
             'endOffset', r.source_end,
             'pageNumber', nullif(r.page_number, -1)
           )
         ),
         r.latest_evidence_kind,
         r.latest_event_id,
         r.latest_outcome_band,
         r.reason_code,
         r.review_count,
         r.success_streak,
         r.interval_seconds,
         r.due_at,
         r.last_reviewed_at,
         r.policy_version,
         r.revision
  from public.materials m
  join public.source_assets s
    on s.material_id = m.id
   and s.account_id = m.account_id
   and s.revoked_at is null
  join public.retention_schedules r
    on r.account_id = m.account_id
   and r.material_id = m.id
   and r.source_asset_id = s.id
  where m.account_id = public.la_require_user()
    and m.client_material_key = btrim(coalesce(p_client_material_id, ''))
    and m.lifecycle_status = 'active'
    and s.client_source_version_key is not null
  order by r.due_at asc, r.source_start asc, r.source_end asc
$$;

create or replace function public.write_retention_continuity(
  p_client_material_id text,
  p_client_source_id text,
  p_source_anchor jsonb,
  p_evidence_kind text,
  p_outcome_band text,
  p_latest_event_id text,
  p_review_count integer,
  p_success_streak integer,
  p_last_reviewed_at timestamptz,
  p_expected_revision bigint default null
)
returns table (
  client_material_id text,
  client_source_id text,
  source_anchor jsonb,
  latest_evidence_kind text,
  latest_event_id text,
  latest_outcome_band text,
  reason_code text,
  review_count integer,
  success_streak integer,
  interval_seconds integer,
  due_at timestamptz,
  last_reviewed_at timestamptz,
  policy_version text,
  revision bigint
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := public.la_require_user();
  v_material public.materials%rowtype;
  v_source_id uuid;
  v_text text;
  v_existing public.retention_schedules%rowtype;
  v_start integer;
  v_end integer;
  v_page integer;
  v_reason text;
  v_interval integer;
  v_expected_review integer;
  v_expected_streak integer;
begin
  if p_evidence_kind not in ('flashcard','quiz') then
    raise exception 'invalid_retention_evidence_kind' using errcode = '22023';
  end if;
  if p_outcome_band not in ('independent_retrieval','supported_retrieval','repair_needed','unassessed') then
    raise exception 'invalid_retention_outcome_band' using errcode = '22023';
  end if;
  if (p_evidence_kind = 'flashcard' and p_outcome_band not in ('supported_retrieval','repair_needed'))
     or (p_evidence_kind = 'quiz' and p_outcome_band not in ('independent_retrieval','repair_needed','unassessed')) then
    raise exception 'invalid_retention_evidence_outcome' using errcode = '22023';
  end if;
  if p_latest_event_id is null
     or length(btrim(p_latest_event_id)) < 8
     or length(p_latest_event_id) > 240
     or p_latest_event_id not like (p_evidence_kind || ':%') then
    raise exception 'invalid_retention_event_id' using errcode = '22023';
  end if;
  if p_review_count is null or p_review_count < 1
     or p_success_streak is null or p_success_streak < 0
     or p_last_reviewed_at is null then
    raise exception 'invalid_retention_counts' using errcode = '22023';
  end if;

  begin
    v_start := (p_source_anchor ->> 'startOffset')::integer;
    v_end := (p_source_anchor ->> 'endOffset')::integer;
    v_page := coalesce((p_source_anchor ->> 'pageNumber')::integer, -1);
  exception
    when others then
      raise exception 'invalid_retention_anchor' using errcode = '22023';
  end;
  if v_start < 0 or v_end <= v_start then
    raise exception 'invalid_retention_anchor' using errcode = '22023';
  end if;

  select m.*
    into v_material
  from public.materials m
  where m.account_id = v_user
    and m.client_material_key = btrim(coalesce(p_client_material_id, ''))
    and m.lifecycle_status = 'active'
  for update;
  if not found then
    raise exception 'material_not_found' using errcode = 'P0001';
  end if;

  select s.id, e.normalized_text
    into v_source_id, v_text
  from public.source_assets s
  join public.extracted_contents e
    on e.account_id = s.account_id
   and e.source_asset_id = s.id
   and e.invalidated_at is null
  where s.account_id = v_user
    and s.material_id = v_material.id
    and s.client_source_version_key = btrim(coalesce(p_client_source_id, ''))
    and s.revoked_at is null
  order by e.created_at desc
  limit 1
  for update of s;
  if not found then
    raise exception 'stale_source' using errcode = 'P0001';
  end if;
  if v_end > char_length(v_text) then
    raise exception 'invalid_retention_anchor' using errcode = '22023';
  end if;

  select *
    into v_existing
  from public.retention_schedules
  where account_id = v_user
    and source_asset_id = v_source_id
    and source_start = v_start
    and source_end = v_end
    and page_number = v_page
  for update;

  if found and v_existing.latest_event_id = p_latest_event_id then
    if v_existing.latest_evidence_kind <> p_evidence_kind
       or v_existing.latest_outcome_band <> p_outcome_band
       or v_existing.review_count <> p_review_count
       or v_existing.success_streak <> p_success_streak
       or v_existing.last_reviewed_at <> p_last_reviewed_at then
      raise exception 'retention_event_conflict' using errcode = 'P0001';
    end if;
    return query
    select m.client_material_key,
           s.client_source_version_key,
           jsonb_strip_nulls(jsonb_build_object(
             'startOffset', v_existing.source_start,
             'endOffset', v_existing.source_end,
             'pageNumber', nullif(v_existing.page_number, -1)
           )),
           v_existing.latest_evidence_kind,
           v_existing.latest_event_id,
           v_existing.latest_outcome_band,
           v_existing.reason_code,
           v_existing.review_count,
           v_existing.success_streak,
           v_existing.interval_seconds,
           v_existing.due_at,
           v_existing.last_reviewed_at,
           v_existing.policy_version,
           v_existing.revision
    from public.materials m
    join public.source_assets s on s.id = v_source_id
    where m.id = v_material.id;
    return;
  end if;

  if found then
    if p_expected_revision is null or p_expected_revision <> v_existing.revision then
      raise exception 'retention_revision_conflict' using errcode = 'P0001';
    end if;
    if p_last_reviewed_at < v_existing.last_reviewed_at then
      raise exception 'retention_event_out_of_order' using errcode = 'P0001';
    end if;
    v_expected_review := v_existing.review_count + 1;
    v_expected_streak := case
      when p_outcome_band = 'independent_retrieval' then v_existing.success_streak + 1
      else 0
    end;
  else
    if p_expected_revision is not null then
      raise exception 'retention_revision_conflict' using errcode = 'P0001';
    end if;
    v_expected_review := 1;
    v_expected_streak := case when p_outcome_band = 'independent_retrieval' then 1 else 0 end;
  end if;

  if p_review_count <> v_expected_review or p_success_streak <> v_expected_streak then
    raise exception 'invalid_retention_progression' using errcode = '22023';
  end if;

  v_reason := case p_outcome_band
    when 'independent_retrieval' then 'INDEPENDENT_RETRIEVAL_OBSERVED'
    when 'supported_retrieval' then 'SUPPORTED_OR_PARTIAL_RETRIEVAL'
    when 'repair_needed' then 'RETRIEVAL_REPAIR_NEEDED'
    else 'NO_POSITIVE_RETENTION_EVIDENCE'
  end;
  v_interval := case p_outcome_band
    when 'independent_retrieval' then case
      when p_success_streak <= 1 then 86400
      when p_success_streak = 2 then 259200
      when p_success_streak = 3 then 604800
      when p_success_streak = 4 then 1209600
      else 2592000
    end
    when 'supported_retrieval' then 43200
    when 'repair_needed' then 600
    else 0
  end;

  insert into public.retention_schedules (
    account_id,
    material_id,
    source_asset_id,
    source_start,
    source_end,
    page_number,
    latest_evidence_id,
    latest_outcome,
    latest_evidence_kind,
    latest_event_id,
    latest_outcome_band,
    reason_code,
    review_count,
    success_streak,
    interval_seconds,
    due_at,
    last_reviewed_at,
    policy_version
  )
  values (
    v_user,
    v_material.id,
    v_source_id,
    v_start,
    v_end,
    v_page,
    null,
    null,
    p_evidence_kind,
    p_latest_event_id,
    p_outcome_band,
    v_reason,
    p_review_count,
    p_success_streak,
    v_interval,
    p_last_reviewed_at + make_interval(secs => v_interval),
    p_last_reviewed_at,
    'retention-v1'
  )
  on conflict (account_id, source_asset_id, source_start, source_end, page_number)
  do update set
    latest_evidence_id = null,
    latest_outcome = null,
    latest_evidence_kind = excluded.latest_evidence_kind,
    latest_event_id = excluded.latest_event_id,
    latest_outcome_band = excluded.latest_outcome_band,
    reason_code = excluded.reason_code,
    review_count = excluded.review_count,
    success_streak = excluded.success_streak,
    interval_seconds = excluded.interval_seconds,
    due_at = excluded.due_at,
    last_reviewed_at = excluded.last_reviewed_at,
    policy_version = excluded.policy_version;

  return query
  select m.client_material_key,
         s.client_source_version_key,
         jsonb_strip_nulls(jsonb_build_object(
           'startOffset', r.source_start,
           'endOffset', r.source_end,
           'pageNumber', nullif(r.page_number, -1)
         )),
         r.latest_evidence_kind,
         r.latest_event_id,
         r.latest_outcome_band,
         r.reason_code,
         r.review_count,
         r.success_streak,
         r.interval_seconds,
         r.due_at,
         r.last_reviewed_at,
         r.policy_version,
         r.revision
  from public.retention_schedules r
  join public.materials m on m.id = r.material_id and m.account_id = r.account_id
  join public.source_assets s on s.id = r.source_asset_id and s.account_id = r.account_id
  where r.account_id = v_user
    and r.source_asset_id = v_source_id
    and r.source_start = v_start
    and r.source_end = v_end
    and r.page_number = v_page;
end;
$$;

revoke all on function public.la_retention_revision_guard(),
                       public.read_retention_continuity(text),
                       public.write_retention_continuity(text, text, jsonb, text, text, text, integer, integer, timestamptz, bigint)
from public, anon, authenticated;

grant execute on function public.read_retention_continuity(text),
                          public.write_retention_continuity(text, text, jsonb, text, text, text, integer, integer, timestamptz, bigint)
to authenticated, service_role;

grant execute on function public.la_retention_revision_guard()
to service_role;
