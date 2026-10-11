-- Sesli Öğren / Learning App — M5 Recall learning-truth delta (LA-0020).
--
-- Requires the accepted M4 canonical core + RPC migrations:
--   spike/architecture-proof/db/migrations/0001_canonical_core.sql
--   spike/architecture-proof/db/migrations/0002_generation_rpcs.sql
--
-- Authority:
--   D-037 bounded evidence-first learning loop
--   D-053/D-054 Recall continuity
--   D-071 M5 Golden Learning Slice admission
--
-- Invariant:
--   authenticated clients may READ their own active learning truth but cannot
--   directly INSERT/UPDATE/DELETE canonical RecallAction, LearnerEvidence or
--   LearnerState rows. Writes occur only through SECURITY DEFINER RPCs.
--
-- This migration is not deployed by this commit.

\set ON_ERROR_STOP on

create table public.recall_actions (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  material_id uuid not null references public.materials(id) on delete cascade,
  source_asset_id uuid not null references public.source_assets(id) on delete cascade,
  extracted_content_id uuid not null references public.extracted_contents(id) on delete cascade,
  prompt_text text not null check (length(btrim(prompt_text)) between 1 and 4000),
  expected_answer text not null check (length(btrim(expected_answer)) between 1 and 300),
  source_anchor jsonb not null default '{}'::jsonb,
  prompt_contract text not null check (prompt_contract = 'recall-cloze-v1'),
  prompt_key text not null check (prompt_key ~ '^[0-9a-f]{64}$'),
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  unique (account_id, prompt_key)
);

create table public.learner_evidence (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  material_id uuid not null references public.materials(id) on delete cascade,
  source_asset_id uuid not null references public.source_assets(id) on delete cascade,
  extracted_content_id uuid not null references public.extracted_contents(id) on delete cascade,
  recall_action_id uuid not null references public.recall_actions(id) on delete cascade,
  attempt_id text not null check (attempt_id ~ '^[A-Za-z0-9_.:-]{8,128}$'),
  response_disposition text not null check (response_disposition in ('answer', 'unknown')),
  outcome text not null
    check (outcome in ('correct', 'helped_correct', 'partial', 'incorrect', 'unknown')),
  help_used boolean not null default false,
  response_digest text not null check (response_digest ~ '^[0-9a-f]{64}$'),
  response_length integer not null check (response_length between 0 and 1000),
  rule_version text not null check (rule_version = 'recall-evidence-v1'),
  invalidated_at timestamptz,
  created_at timestamptz not null default now(),
  unique (account_id, attempt_id)
);

create table public.learner_states (
  account_id uuid not null references public.accounts(id) on delete cascade,
  material_id uuid not null references public.materials(id) on delete cascade,
  source_asset_id uuid not null references public.source_assets(id) on delete cascade,
  extracted_content_id uuid not null references public.extracted_contents(id) on delete cascade,
  state_kind text not null
    check (state_kind in ('not_assessed', 'needs_review', 'developing', 'retrieved_once')),
  evidence_count integer not null check (evidence_count >= 1),
  latest_evidence_id uuid not null references public.learner_evidence(id) on delete cascade,
  rule_version text not null check (rule_version = 'recall-state-v1'),
  updated_at timestamptz not null default now(),
  primary key (account_id, material_id)
);

create index recall_actions_material_idx
  on public.recall_actions (account_id, material_id, source_asset_id, created_at);
create index learner_evidence_material_idx
  on public.learner_evidence (account_id, material_id, source_asset_id, created_at);
create index learner_states_source_idx
  on public.learner_states (account_id, source_asset_id);

alter table public.recall_actions enable row level security;
alter table public.recall_actions force row level security;
alter table public.learner_evidence enable row level security;
alter table public.learner_evidence force row level security;
alter table public.learner_states enable row level security;
alter table public.learner_states force row level security;

revoke all on public.recall_actions, public.learner_evidence, public.learner_states
  from anon, authenticated;

-- Never expose expected_answer or prompt_key to the authenticated client.
grant select (id, account_id, material_id, source_asset_id, extracted_content_id,
              prompt_text, source_anchor, prompt_contract, created_at)
  on public.recall_actions to authenticated;
grant select (id, account_id, material_id, source_asset_id, extracted_content_id,
              recall_action_id, attempt_id, response_disposition, outcome, help_used,
              response_length, rule_version, created_at)
  on public.learner_evidence to authenticated;
grant select on public.learner_states to authenticated;
grant all on public.recall_actions, public.learner_evidence, public.learner_states
  to service_role;

create policy recall_actions_owner_read on public.recall_actions
for select to authenticated
using (
  (select auth.uid()) is not null
  and account_id = (select auth.uid())
  and revoked_at is null
  and exists (
    select 1 from public.materials m
    where m.id = material_id
      and m.account_id = (select auth.uid())
      and m.lifecycle_status = 'active'
  )
);

create policy learner_evidence_owner_read on public.learner_evidence
for select to authenticated
using (
  (select auth.uid()) is not null
  and account_id = (select auth.uid())
  and invalidated_at is null
  and exists (
    select 1 from public.materials m
    where m.id = material_id
      and m.account_id = (select auth.uid())
      and m.lifecycle_status = 'active'
  )
);

create policy learner_states_owner_read on public.learner_states
for select to authenticated
using (
  (select auth.uid()) is not null
  and account_id = (select auth.uid())
  and exists (
    select 1 from public.materials m
    where m.id = material_id
      and m.account_id = (select auth.uid())
      and m.lifecycle_status = 'active'
  )
);

create or replace function public.la_recall_normalize(p_value text)
returns text
language sql immutable set search_path = ''
as $$
  select regexp_replace(
    lower(translate(coalesce(p_value, ''), 'İI', 'iı')),
    '[^a-zçğıöşü0-9]+',
    '',
    'g'
  )
$$;

create or replace function public.la_recall_distance_le_one(p_left text, p_right text)
returns boolean
language plpgsql immutable set search_path = ''
as $$
declare
  a text := coalesce(p_left, '');
  b text := coalesce(p_right, '');
  la integer := char_length(a);
  lb integer := char_length(b);
  i integer := 1;
  j integer := 1;
  edits integer := 0;
begin
  if abs(la - lb) > 1 then return false; end if;

  while i <= la and j <= lb loop
    if substr(a, i, 1) = substr(b, j, 1) then
      i := i + 1;
      j := j + 1;
    else
      edits := edits + 1;
      if edits > 1 then return false; end if;
      if la = lb then
        i := i + 1;
        j := j + 1;
      elsif la > lb then
        i := i + 1;
      else
        j := j + 1;
      end if;
    end if;
  end loop;

  if i <= la or j <= lb then edits := edits + 1; end if;
  return edits <= 1;
end;
$$;

create or replace function public.la_recall_state_for_outcome(p_outcome text)
returns text
language sql immutable set search_path = ''
as $$
  select case p_outcome
    when 'correct' then 'retrieved_once'
    when 'helped_correct' then 'developing'
    when 'partial' then 'developing'
    when 'incorrect' then 'needs_review'
    when 'unknown' then 'not_assessed'
    else 'not_assessed'
  end
$$;

create or replace function public.la_recall_next_reason(p_state text)
returns text
language sql immutable set search_path = ''
as $$
  select case p_state
    when 'retrieved_once' then 'UNASSISTED_RETRIEVAL_CORRECT'
    when 'developing' then 'PARTIAL_OR_HELPED_RETRIEVAL'
    when 'not_assessed' then 'NO_EVALUABLE_RETRIEVAL'
    else 'RETRIEVAL_NOT_ESTABLISHED'
  end
$$;

create or replace function public.create_recall_action(p_material_id uuid)
returns table (
  action_id uuid,
  prompt_text text,
  source_anchor jsonb,
  prompt_contract text,
  material_id uuid,
  source_asset_id uuid,
  extracted_content_id uuid
)
language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := public.la_require_user();
  v_source uuid;
  v_extracted uuid;
  v_text text;
  v_sentence text;
  v_answer text;
  v_sentence_start integer;
  v_word_start integer;
  v_prompt text;
  v_prompt_key text;
  v_action public.recall_actions%rowtype;
begin
  select s.id, e.id, e.normalized_text
    into v_source, v_extracted, v_text
  from public.materials m
  join public.source_assets s
    on s.material_id = m.id
   and s.account_id = v_user
   and s.revoked_at is null
  join public.extracted_contents e
    on e.source_asset_id = s.id
   and e.account_id = v_user
   and e.invalidated_at is null
  where m.id = p_material_id
    and m.account_id = v_user
    and m.lifecycle_status = 'active'
  order by s.source_version desc, e.created_at desc
  limit 1;

  if v_source is null then
    raise exception 'material_not_found' using errcode = 'P0002';
  end if;

  v_text := left(v_text, 2400);
  v_sentence := btrim(substring(v_text from '([^.!?]{20,}[.!?]?)'));
  if v_sentence is null or length(v_sentence) < 20 then
    raise exception 'recall_source_too_sparse' using errcode = 'P0001';
  end if;

  select word into v_answer
  from (
    select (m)[1] as word
    from regexp_matches(v_sentence, '([A-Za-zÇĞİÖŞÜçğıöşü]{5,})', 'g') as m
  ) words
  where public.la_recall_normalize(word) not in (
    'ancak','bunun','daha','fakat','gibi','için','ile','olan','olarak',
    'sonra','şekilde','veya','çünkü','the','that','this','with','from'
  )
  order by char_length(word) desc, strpos(v_sentence, word)
  limit 1;

  if v_answer is null then
    raise exception 'recall_source_too_sparse' using errcode = 'P0001';
  end if;

  v_sentence_start := strpos(v_text, v_sentence);
  v_word_start := strpos(v_sentence, v_answer);
  if v_sentence_start <= 0 or v_word_start <= 0 then
    raise exception 'recall_prompt_build_failed' using errcode = 'P0001';
  end if;

  v_prompt := overlay(
    v_sentence placing '_____'
    from v_word_start for char_length(v_answer)
  );
  v_prompt_key := public.la_sha256(concat_ws(
    '|',
    v_extracted::text,
    'recall-cloze-v1',
    v_sentence_start::text,
    v_answer
  ));

  insert into public.recall_actions (
    account_id, material_id, source_asset_id, extracted_content_id,
    prompt_text, expected_answer, source_anchor, prompt_contract, prompt_key
  )
  values (
    v_user, p_material_id, v_source, v_extracted,
    v_prompt, v_answer,
    jsonb_build_object(
      'startOffset', v_sentence_start - 1,
      'endOffset', v_sentence_start - 1 + char_length(v_sentence)
    ),
    'recall-cloze-v1',
    v_prompt_key
  )
  on conflict (account_id, prompt_key) do update
    set prompt_key = excluded.prompt_key
  returning * into v_action;

  action_id := v_action.id;
  prompt_text := v_action.prompt_text;
  source_anchor := v_action.source_anchor;
  prompt_contract := v_action.prompt_contract;
  material_id := v_action.material_id;
  source_asset_id := v_action.source_asset_id;
  extracted_content_id := v_action.extracted_content_id;
  return next;
end;
$$;

create or replace function public.submit_recall_attempt(
  p_action_id uuid,
  p_attempt_id text,
  p_response_disposition text,
  p_answer text default '',
  p_hint_used boolean default false
)
returns table (
  evidence_id uuid,
  outcome text,
  state_kind text,
  evidence_count integer,
  next_reason_code text
)
language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := public.la_require_user();
  v_action public.recall_actions%rowtype;
  v_existing public.learner_evidence%rowtype;
  v_normalized text;
  v_expected text;
  v_outcome text;
  v_digest text;
  v_state text;
  v_count integer;
  v_evidence uuid;
begin
  if p_attempt_id is null
     or p_attempt_id !~ '^[A-Za-z0-9_.:-]{8,128}$' then
    raise exception 'invalid_attempt_id' using errcode = '22023';
  end if;
  if p_response_disposition not in ('answer', 'unknown') then
    raise exception 'invalid_response_disposition' using errcode = '22023';
  end if;

  select a.* into v_action
  from public.recall_actions a
  join public.materials m
    on m.id = a.material_id
   and m.account_id = v_user
   and m.lifecycle_status = 'active'
  join public.source_assets s
    on s.id = a.source_asset_id
   and s.account_id = v_user
   and s.revoked_at is null
  join public.extracted_contents e
    on e.id = a.extracted_content_id
   and e.account_id = v_user
   and e.invalidated_at is null
  where a.id = p_action_id
    and a.account_id = v_user
    and a.revoked_at is null
  for update of a;

  if not found then
    raise exception 'recall_action_not_found_or_stale' using errcode = 'P0002';
  end if;

  v_normalized := case
    when p_response_disposition = 'unknown' then ''
    else public.la_recall_normalize(p_answer)
  end;
  if char_length(v_normalized) > 1000 then
    raise exception 'recall_answer_too_large' using errcode = '22023';
  end if;

  v_expected := public.la_recall_normalize(v_action.expected_answer);
  v_outcome := case
    when p_response_disposition = 'unknown' or v_normalized = '' then 'unknown'
    when v_normalized = v_expected and p_hint_used then 'helped_correct'
    when v_normalized = v_expected then 'correct'
    when char_length(v_expected) >= 5
      and public.la_recall_distance_le_one(v_normalized, v_expected) then 'partial'
    else 'incorrect'
  end;
  v_digest := public.la_sha256(v_normalized);

  select * into v_existing
  from public.learner_evidence
  where account_id = v_user and attempt_id = p_attempt_id
  for update;

  if found then
    if v_existing.recall_action_id <> p_action_id
       or v_existing.response_disposition <> p_response_disposition
       or v_existing.help_used <> p_hint_used
       or v_existing.response_digest <> v_digest then
      raise exception 'attempt_id_reused' using errcode = '22023';
    end if;

    select s.state_kind, s.evidence_count
      into state_kind, evidence_count
    from public.learner_states s
    where s.account_id = v_user
      and s.material_id = v_action.material_id;

    if state_kind is null then
      raise exception 'learner_state_missing' using errcode = 'P0001';
    end if;

    evidence_id := v_existing.id;
    outcome := v_existing.outcome;
    next_reason_code := public.la_recall_next_reason(state_kind);
    return next;
    return;
  end if;

  insert into public.learner_evidence (
    account_id, material_id, source_asset_id, extracted_content_id,
    recall_action_id, attempt_id, response_disposition, outcome, help_used,
    response_digest, response_length, rule_version
  )
  values (
    v_user, v_action.material_id, v_action.source_asset_id,
    v_action.extracted_content_id, v_action.id, p_attempt_id,
    p_response_disposition, v_outcome, p_hint_used, v_digest,
    char_length(v_normalized), 'recall-evidence-v1'
  )
  returning id into v_evidence;

  v_state := public.la_recall_state_for_outcome(v_outcome);
  select count(*)::integer into v_count
  from public.learner_evidence e
  where e.account_id = v_user
    and e.material_id = v_action.material_id
    and e.source_asset_id = v_action.source_asset_id
    and e.invalidated_at is null;

  insert into public.learner_states (
    account_id, material_id, source_asset_id, extracted_content_id,
    state_kind, evidence_count, latest_evidence_id, rule_version, updated_at
  )
  values (
    v_user, v_action.material_id, v_action.source_asset_id,
    v_action.extracted_content_id, v_state, v_count, v_evidence,
    'recall-state-v1', now()
  )
  on conflict (account_id, material_id) do update set
    source_asset_id = excluded.source_asset_id,
    extracted_content_id = excluded.extracted_content_id,
    state_kind = excluded.state_kind,
    evidence_count = excluded.evidence_count,
    latest_evidence_id = excluded.latest_evidence_id,
    rule_version = excluded.rule_version,
    updated_at = excluded.updated_at;

  evidence_id := v_evidence;
  outcome := v_outcome;
  state_kind := v_state;
  evidence_count := v_count;
  next_reason_code := public.la_recall_next_reason(v_state);
  return next;
end;
$$;

create or replace function public.la_invalidate_learning_truth_for_material()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if old.lifecycle_status = 'active' and new.lifecycle_status = 'deleted' then
    update public.recall_actions
      set revoked_at = coalesce(revoked_at, now())
      where material_id = new.id and account_id = new.account_id;
    update public.learner_evidence
      set invalidated_at = coalesce(invalidated_at, now())
      where material_id = new.id and account_id = new.account_id;
    delete from public.learner_states
      where material_id = new.id and account_id = new.account_id;
  end if;
  return new;
end;
$$;

create trigger invalidate_learning_truth_on_material_delete
after update of lifecycle_status on public.materials
for each row execute function public.la_invalidate_learning_truth_for_material();

create or replace function public.la_invalidate_learning_truth_for_source()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if old.revoked_at is null and new.revoked_at is not null then
    update public.recall_actions
      set revoked_at = coalesce(revoked_at, now())
      where source_asset_id = new.id and account_id = new.account_id;
    update public.learner_evidence
      set invalidated_at = coalesce(invalidated_at, now())
      where source_asset_id = new.id and account_id = new.account_id;
    delete from public.learner_states
      where source_asset_id = new.id and account_id = new.account_id;
  end if;
  return new;
end;
$$;

create trigger invalidate_learning_truth_on_source_revoke
after update of revoked_at on public.source_assets
for each row execute function public.la_invalidate_learning_truth_for_source();

revoke all on function public.la_recall_normalize(text),
                       public.la_recall_distance_le_one(text, text),
                       public.la_recall_state_for_outcome(text),
                       public.la_recall_next_reason(text),
                       public.create_recall_action(uuid),
                       public.submit_recall_attempt(uuid, text, text, text, boolean),
                       public.la_invalidate_learning_truth_for_material(),
                       public.la_invalidate_learning_truth_for_source()
  from public, anon, authenticated;

grant execute on function public.create_recall_action(uuid),
                          public.submit_recall_attempt(uuid, text, text, text, boolean)
  to authenticated;

grant execute on function public.la_recall_normalize(text),
                          public.la_recall_distance_le_one(text, text),
                          public.la_recall_state_for_outcome(text),
                          public.la_recall_next_reason(text)
  to service_role;
