\set ON_ERROR_STOP on

-- Server-authoritative Recall continuity for authenticated cross-device use.
-- Reuses recall_actions / recall_attempt_sessions / learner_evidence /
-- learner_states. No second learning-truth authority is introduced.

create or replace function public.create_recall_continuity_action(
  p_client_material_id text,
  p_source_anchor jsonb default null
)
returns table (
  action_id uuid,
  prompt_text text,
  source_anchor jsonb,
  prompt_contract text,
  client_material_id text,
  client_source_id text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := public.la_require_user();
  v_material uuid;
  v_material_key text := btrim(coalesce(p_client_material_id, ''));
  v_source uuid;
  v_source_key text;
  v_extracted uuid;
  v_text text;
  v_sentence text;
  v_answer text;
  v_sentence_start integer;
  v_sentence_end integer;
  v_word_start integer;
  v_prompt text;
  v_prompt_key text;
  v_anchor_start integer;
  v_anchor_end integer;
  v_action public.recall_actions%rowtype;
begin
  if v_material_key !~ '^[A-Za-z0-9_.:-]{8,128}$' then
    raise exception 'invalid_client_material_id' using errcode = '22023';
  end if;

  select m.id,
         s.id,
         s.client_source_version_key,
         e.id,
         e.normalized_text
    into v_material,
         v_source,
         v_source_key,
         v_extracted,
         v_text
  from public.materials m
  join public.source_assets s
    on s.material_id = m.id
   and s.account_id = v_user
   and s.revoked_at is null
  join public.extracted_contents e
    on e.source_asset_id = s.id
   and e.account_id = v_user
   and e.invalidated_at is null
  where m.account_id = v_user
    and m.client_material_key = v_material_key
    and m.lifecycle_status = 'active'
    and s.client_source_version_key is not null
  order by s.source_version desc, e.created_at desc
  limit 1;

  if v_material is null or v_source_key is null then
    raise exception 'material_not_found' using errcode = 'P0002';
  end if;

  if p_source_anchor is not null then
    begin
      v_anchor_start := (p_source_anchor ->> 'startOffset')::integer;
      v_anchor_end := (p_source_anchor ->> 'endOffset')::integer;
    exception
      when others then
        raise exception 'invalid_source_anchor' using errcode = '22023';
    end;
    if v_anchor_start < 0
       or v_anchor_end <= v_anchor_start
       or v_anchor_end > char_length(v_text) then
      raise exception 'invalid_source_anchor' using errcode = '22023';
    end if;

    v_sentence_start := v_anchor_start;
    v_sentence_end := v_anchor_end;
    v_sentence := btrim(substring(v_text from v_sentence_start + 1 for v_sentence_end - v_sentence_start));
    if char_length(v_sentence) < 20 then
      raise exception 'recall_source_too_sparse' using errcode = 'P0001';
    end if;

    -- btrim can move the actual bounded sentence start.
    v_sentence_start := strpos(v_text, v_sentence) - 1;
    v_sentence_end := v_sentence_start + char_length(v_sentence);
    if v_sentence_start < 0 then
      raise exception 'recall_prompt_build_failed' using errcode = 'P0001';
    end if;
  else
    v_text := left(v_text, 2400);
    v_sentence := btrim(substring(v_text from '([^.!?]{20,}[.!?]?)'));
    if v_sentence is null or char_length(v_sentence) < 20 then
      raise exception 'recall_source_too_sparse' using errcode = 'P0001';
    end if;
    v_sentence_start := strpos(v_text, v_sentence) - 1;
    v_sentence_end := v_sentence_start + char_length(v_sentence);
  end if;

  select word
    into v_answer
  from (
    select (m)[1] as word,
           strpos(v_sentence, (m)[1]) as word_pos
    from regexp_matches(v_sentence, '([A-Za-zÇĞİÖŞÜçğıöşü]{5,})', 'g') as m
  ) words
  where public.la_recall_normalize(word) not in (
    'ancak','bunun','daha','fakat','gibi','için','ile','olan','olarak',
    'sonra','şekilde','veya','çünkü','during','especially','however',
    'therefore','usually','the','that','this','with','from'
  )
  order by char_length(word) desc, word_pos
  limit 1;

  if v_answer is null then
    raise exception 'recall_source_too_sparse' using errcode = 'P0001';
  end if;

  v_word_start := strpos(v_sentence, v_answer);
  if v_word_start <= 0 then
    raise exception 'recall_prompt_build_failed' using errcode = 'P0001';
  end if;

  v_prompt := overlay(v_sentence placing '_____' from v_word_start for char_length(v_answer));
  v_prompt_key := public.la_sha256(concat_ws(
    '|',
    v_extracted::text,
    'recall-cloze-v1',
    v_sentence_start::text,
    v_answer
  ));

  insert into public.recall_actions (
    account_id,
    material_id,
    source_asset_id,
    extracted_content_id,
    prompt_text,
    expected_answer,
    source_anchor,
    prompt_contract,
    prompt_key
  )
  values (
    v_user,
    v_material,
    v_source,
    v_extracted,
    v_prompt,
    v_answer,
    jsonb_build_object(
      'startOffset', v_sentence_start,
      'endOffset', v_sentence_end
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
  client_material_id := v_material_key;
  client_source_id := v_source_key;
  return next;
end;
$$;

create or replace function public.open_recall_continuity_attempt(
  p_action_id uuid,
  p_attempt_id text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := public.la_require_user();
  v_action public.recall_actions%rowtype;
  v_session public.recall_attempt_sessions%rowtype;
begin
  if p_attempt_id is null or p_attempt_id !~ '^[A-Za-z0-9_.:-]{8,128}$' then
    raise exception 'invalid_attempt_id' using errcode = '22023';
  end if;

  select a.*
    into v_action
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
    and a.revoked_at is null;

  if not found then
    raise exception 'recall_action_not_found_or_stale' using errcode = 'P0002';
  end if;

  insert into public.recall_attempt_sessions(
    account_id,
    attempt_id,
    recall_action_id,
    assistance
  )
  values(v_user, p_attempt_id, p_action_id, 'none')
  on conflict(account_id, attempt_id) do nothing;

  select *
    into v_session
  from public.recall_attempt_sessions
  where account_id = v_user
    and attempt_id = p_attempt_id;

  if not found
     or v_session.recall_action_id <> p_action_id
     or v_session.submitted_at is not null then
    raise exception 'attempt_id_reused' using errcode = '22023';
  end if;

  return v_session.assistance;
end;
$$;

create or replace function public.submit_recall_continuity_attempt(
  p_action_id uuid,
  p_attempt_id text,
  p_response_disposition text,
  p_answer text default ''
)
returns table (
  evidence_id uuid,
  outcome text,
  state_kind text,
  evidence_count integer,
  next_reason_code text,
  assistance text,
  response_digest text,
  response_length integer,
  evidence_rule_version text,
  evidence_created_at timestamptz,
  normalized_response text,
  correct_answer text,
  source_excerpt text,
  client_material_id text,
  client_source_id text,
  action_prompt text,
  source_anchor jsonb
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := public.la_require_user();
  v_evidence_id uuid;
  v_outcome text;
  v_state text;
  v_count integer;
  v_reason text;
begin
  select r.evidence_id,
         r.outcome,
         r.state_kind,
         r.evidence_count,
         r.next_reason_code
    into v_evidence_id,
         v_outcome,
         v_state,
         v_count,
         v_reason
  from public.submit_recall_attempt(
    p_action_id,
    p_attempt_id,
    p_response_disposition,
    p_answer
  ) r;

  return query
  select ev.id,
         ev.outcome,
         st.state_kind,
         st.evidence_count,
         v_reason,
         ev.assistance,
         ev.response_digest,
         ev.response_length,
         ev.rule_version,
         ev.created_at,
         case
           when p_response_disposition = 'unknown' then ''
           else public.la_recall_normalize(p_answer)
         end,
         a.expected_answer,
         substring(
           ec.normalized_text
           from ((a.source_anchor ->> 'startOffset')::integer + 1)
           for (
             (a.source_anchor ->> 'endOffset')::integer
             - (a.source_anchor ->> 'startOffset')::integer
           )
         ),
         m.client_material_key,
         s.client_source_version_key,
         a.prompt_text,
         a.source_anchor
  from public.learner_evidence ev
  join public.recall_actions a
    on a.id = ev.recall_action_id
   and a.account_id = v_user
  join public.materials m
    on m.id = ev.material_id
   and m.account_id = v_user
   and m.lifecycle_status = 'active'
  join public.source_assets s
    on s.id = ev.source_asset_id
   and s.account_id = v_user
   and s.revoked_at is null
  join public.extracted_contents ec
    on ec.id = ev.extracted_content_id
   and ec.account_id = v_user
   and ec.invalidated_at is null
  join public.learner_states st
    on st.account_id = v_user
   and st.material_id = ev.material_id
   and st.latest_evidence_id = ev.id
  where ev.id = v_evidence_id
    and ev.account_id = v_user
    and ev.invalidated_at is null
    and m.client_material_key is not null
    and s.client_source_version_key is not null;
end;
$$;

create or replace function public.read_latest_recall_continuity(
  p_client_material_id text
)
returns table (
  evidence_id uuid,
  attempt_id text,
  action_id uuid,
  outcome text,
  state_kind text,
  evidence_count integer,
  assistance text,
  response_digest text,
  response_length integer,
  evidence_rule_version text,
  evidence_created_at timestamptz,
  correct_answer text,
  source_excerpt text,
  client_material_id text,
  client_source_id text,
  action_prompt text,
  source_anchor jsonb
)
language sql
security definer
set search_path = ''
as $$
  select ev.id,
         ev.attempt_id,
         ev.recall_action_id,
         ev.outcome,
         st.state_kind,
         st.evidence_count,
         ev.assistance,
         ev.response_digest,
         ev.response_length,
         ev.rule_version,
         ev.created_at,
         a.expected_answer,
         substring(
           ec.normalized_text
           from ((a.source_anchor ->> 'startOffset')::integer + 1)
           for (
             (a.source_anchor ->> 'endOffset')::integer
             - (a.source_anchor ->> 'startOffset')::integer
           )
         ),
         m.client_material_key,
         s.client_source_version_key,
         a.prompt_text,
         a.source_anchor
  from public.materials m
  join public.source_assets s
    on s.material_id = m.id
   and s.account_id = m.account_id
   and s.revoked_at is null
  join public.learner_states st
    on st.account_id = m.account_id
   and st.material_id = m.id
   and st.source_asset_id = s.id
  join public.learner_evidence ev
    on ev.id = st.latest_evidence_id
   and ev.account_id = m.account_id
   and ev.invalidated_at is null
  join public.recall_actions a
    on a.id = ev.recall_action_id
   and a.account_id = m.account_id
   and a.revoked_at is null
  join public.extracted_contents ec
    on ec.id = ev.extracted_content_id
   and ec.account_id = m.account_id
   and ec.invalidated_at is null
  where m.account_id = public.la_require_user()
    and m.client_material_key = btrim(coalesce(p_client_material_id, ''))
    and m.lifecycle_status = 'active'
    and s.client_source_version_key is not null
  limit 1
$$;

revoke all on function public.create_recall_continuity_action(text, jsonb),
                       public.open_recall_continuity_attempt(uuid, text),
                       public.submit_recall_continuity_attempt(uuid, text, text, text),
                       public.read_latest_recall_continuity(text)
from public, anon, authenticated;

grant execute on function public.create_recall_continuity_action(text, jsonb),
                          public.open_recall_continuity_attempt(uuid, text),
                          public.submit_recall_continuity_attempt(uuid, text, text, text),
                          public.read_latest_recall_continuity(text)
to authenticated, service_role;
