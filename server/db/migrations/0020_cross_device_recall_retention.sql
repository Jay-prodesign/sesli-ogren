\set ON_ERROR_STOP on

-- Canonical Recall retention projection for cross-device continuity.
-- Schedules advance only from committed learner_evidence; passive source/Tutor
-- consumption cannot create or advance retention truth.
create table public.retention_schedules (
  account_id uuid not null references public.accounts(id) on delete cascade,
  material_id uuid not null references public.materials(id) on delete cascade,
  source_asset_id uuid not null references public.source_assets(id) on delete cascade,
  source_start integer not null,
  source_end integer not null,
  page_number integer not null default -1,
  latest_evidence_id uuid not null references public.learner_evidence(id) on delete cascade,
  latest_outcome text not null
    check (latest_outcome in ('correct','helped_correct','answer_exposed','partial','incorrect','unknown')),
  latest_outcome_band text not null
    check (latest_outcome_band in ('independent_retrieval','supported_retrieval','repair_needed','unassessed')),
  reason_code text not null,
  review_count integer not null check (review_count >= 1),
  success_streak integer not null check (success_streak >= 0),
  interval_seconds integer not null check (interval_seconds >= 0),
  due_at timestamptz not null,
  last_reviewed_at timestamptz not null,
  policy_version text not null check (policy_version = 'retention-v1'),
  primary key (account_id, source_asset_id, source_start, source_end, page_number),
  check (source_start >= 0 and source_end > source_start)
);

create unique index retention_schedules_latest_evidence_unique
  on public.retention_schedules (account_id, latest_evidence_id);

create index retention_schedules_due_idx
  on public.retention_schedules (account_id, due_at, material_id);

alter table public.retention_schedules enable row level security;
alter table public.retention_schedules force row level security;
revoke all on public.retention_schedules from anon, authenticated;
grant all on public.retention_schedules to service_role;

create policy retention_schedules_owner_read on public.retention_schedules
for select to authenticated
using ((select auth.uid()) is not null and account_id = (select auth.uid()));

grant select (
  account_id,
  material_id,
  source_asset_id,
  source_start,
  source_end,
  page_number,
  latest_evidence_id,
  latest_outcome,
  latest_outcome_band,
  reason_code,
  review_count,
  success_streak,
  interval_seconds,
  due_at,
  last_reviewed_at,
  policy_version
) on public.retention_schedules to authenticated;

create or replace function public.la_advance_recall_retention(p_evidence_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_evidence public.learner_evidence%rowtype;
  v_action public.recall_actions%rowtype;
  v_start integer;
  v_end integer;
  v_page integer;
  v_existing public.retention_schedules%rowtype;
  v_band text;
  v_reason text;
  v_streak integer;
  v_interval integer;
begin
  select *
    into v_evidence
  from public.learner_evidence
  where id = p_evidence_id;

  if not found or v_evidence.invalidated_at is not null then
    return;
  end if;

  select *
    into v_action
  from public.recall_actions
  where id = v_evidence.recall_action_id
    and account_id = v_evidence.account_id;

  if not found then
    raise exception 'retention_action_missing' using errcode = 'P0001';
  end if;

  begin
    v_start := (v_action.source_anchor ->> 'startOffset')::integer;
    v_end := (v_action.source_anchor ->> 'endOffset')::integer;
    v_page := coalesce((v_action.source_anchor ->> 'pageNumber')::integer, -1);
  exception
    when others then
      raise exception 'retention_anchor_invalid' using errcode = 'P0001';
  end;

  if v_start < 0 or v_end <= v_start then
    raise exception 'retention_anchor_invalid' using errcode = 'P0001';
  end if;

  select *
    into v_existing
  from public.retention_schedules
  where account_id = v_evidence.account_id
    and source_asset_id = v_evidence.source_asset_id
    and source_start = v_start
    and source_end = v_end
    and page_number = v_page
  for update;

  if found and v_existing.latest_evidence_id = v_evidence.id then
    return;
  end if;
  if found and v_evidence.created_at < v_existing.last_reviewed_at then
    raise exception 'retention_event_out_of_order' using errcode = 'P0001';
  end if;

  v_band := case v_evidence.outcome
    when 'correct' then 'independent_retrieval'
    when 'helped_correct' then 'supported_retrieval'
    when 'partial' then 'supported_retrieval'
    when 'incorrect' then 'repair_needed'
    else 'unassessed'
  end;

  v_reason := case v_band
    when 'independent_retrieval' then 'INDEPENDENT_RETRIEVAL_OBSERVED'
    when 'supported_retrieval' then 'SUPPORTED_OR_PARTIAL_RETRIEVAL'
    when 'repair_needed' then 'RETRIEVAL_REPAIR_NEEDED'
    else 'NO_POSITIVE_RETENTION_EVIDENCE'
  end;

  v_streak := case
    when v_band = 'independent_retrieval' then coalesce(v_existing.success_streak, 0) + 1
    else 0
  end;

  v_interval := case v_band
    when 'independent_retrieval' then case
      when v_streak <= 1 then 86400
      when v_streak = 2 then 259200
      when v_streak = 3 then 604800
      when v_streak = 4 then 1209600
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
    v_evidence.account_id,
    v_evidence.material_id,
    v_evidence.source_asset_id,
    v_start,
    v_end,
    v_page,
    v_evidence.id,
    v_evidence.outcome,
    v_band,
    v_reason,
    coalesce(v_existing.review_count, 0) + 1,
    v_streak,
    v_interval,
    v_evidence.created_at + make_interval(secs => v_interval),
    v_evidence.created_at,
    'retention-v1'
  )
  on conflict (account_id, source_asset_id, source_start, source_end, page_number)
  do update set
    latest_evidence_id = excluded.latest_evidence_id,
    latest_outcome = excluded.latest_outcome,
    latest_outcome_band = excluded.latest_outcome_band,
    reason_code = excluded.reason_code,
    review_count = excluded.review_count,
    success_streak = excluded.success_streak,
    interval_seconds = excluded.interval_seconds,
    due_at = excluded.due_at,
    last_reviewed_at = excluded.last_reviewed_at,
    policy_version = excluded.policy_version;
end;
$$;

create or replace function public.la_retention_after_recall_evidence()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.la_advance_recall_retention(new.id);
  return new;
end;
$$;

drop trigger if exists advance_recall_retention_after_evidence on public.learner_evidence;
create trigger advance_recall_retention_after_evidence
after insert on public.learner_evidence
for each row execute function public.la_retention_after_recall_evidence();

-- Backfill existing committed evidence in chronological order so deployment
-- does not silently reset a learner's already-observed retention history.
do $$
declare
  item record;
begin
  for item in
    select id
    from public.learner_evidence
    where invalidated_at is null
    order by created_at asc, id asc
  loop
    perform public.la_advance_recall_retention(item.id);
  end loop;
end
$$;

create or replace function public.read_recall_retention_continuity(
  p_client_material_id text
)
returns table (
  client_material_id text,
  client_source_id text,
  source_anchor jsonb,
  latest_evidence_id uuid,
  latest_outcome text,
  latest_outcome_band text,
  reason_code text,
  review_count integer,
  success_streak integer,
  interval_seconds integer,
  due_at timestamptz,
  last_reviewed_at timestamptz,
  policy_version text
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
         r.latest_evidence_id,
         r.latest_outcome,
         r.latest_outcome_band,
         r.reason_code,
         r.review_count,
         r.success_streak,
         r.interval_seconds,
         r.due_at,
         r.last_reviewed_at,
         r.policy_version
  from public.materials m
  join public.source_assets s
    on s.material_id = m.id
   and s.account_id = m.account_id
   and s.revoked_at is null
  join public.retention_schedules r
    on r.account_id = m.account_id
   and r.material_id = m.id
   and r.source_asset_id = s.id
  join public.learner_evidence ev
    on ev.id = r.latest_evidence_id
   and ev.account_id = m.account_id
   and ev.invalidated_at is null
  where m.account_id = public.la_require_user()
    and m.client_material_key = btrim(coalesce(p_client_material_id, ''))
    and m.lifecycle_status = 'active'
    and s.client_source_version_key is not null
  order by r.due_at asc, r.source_start asc, r.source_end asc
$$;

revoke all on function public.la_advance_recall_retention(uuid),
                       public.la_retention_after_recall_evidence(),
                       public.read_recall_retention_continuity(text)
from public, anon, authenticated;

grant execute on function public.read_recall_retention_continuity(text)
to authenticated, service_role;

grant execute on function public.la_advance_recall_retention(uuid),
                          public.la_retention_after_recall_evidence()
to service_role;
