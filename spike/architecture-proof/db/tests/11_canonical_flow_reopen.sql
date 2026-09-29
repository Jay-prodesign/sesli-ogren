-- LA-0013 reopen: a new psql session (new connection, no session state from test 10) reopens the
-- material and its Summary Artifact purely from persisted canonical rows.
\set ON_ERROR_STOP on
\set user_a '''a1000000-0000-4000-8000-000000000001'''
\if :{?fixture_out}
\else
  \set fixture_out /dev/null
\endif

create or replace function pg_temp.ok(v boolean, msg text) returns void language plpgsql as $$
begin if v is distinct from true then raise exception 'reopen_assert_failed: %', msg; end if; end $$;

select set_config('request.jwt.claim.sub', :user_a, false);
set role authenticated;
select pg_temp.ok((select count(*) = 1 from public.library_items where title = 'Hücre Biyolojisi'
                   and processing_state = 'ready' and summary_artifact_id is not null), 'library entry survives reconnect');
select pg_temp.ok((select a.content ->> 'summary' = 'Hücre en küçük birimdir; mitokondri enerji üretir.'
                          and a.content -> 'key_points' = '["hücre","mitokondri"]'::jsonb
                   from public.library_items l join public.artifacts a on a.id = l.summary_artifact_id
                   where l.title = 'Hücre Biyolojisi'), 'artifact content reopened from persistence');
select pg_temp.ok((select count(*) = 1 from public.generation_attempts at
                   join public.generation_jobs j on j.id = at.job_id
                   join public.materials m on m.id = j.material_id
                   where m.title = 'Hücre Biyolojisi' and at.status = 'succeeded'), 'attempt lineage readable by owner');
-- Emit the owner-visible rows as JSON for the Dart client contract test (fixture capture).
\o :fixture_out
select json_build_object(
  'library_item', (select row_to_json(l) from public.library_items l where l.title = 'Hücre Biyolojisi'),
  'artifact', (select row_to_json(a) from public.artifacts a join public.library_items l
               on l.summary_artifact_id = a.id where l.title = 'Hücre Biyolojisi'),
  'job', (select json_build_object('id', j.id, 'material_id', j.material_id, 'state', j.state,
                  'failure_class', j.failure_class, 'attempt_count', j.attempt_count,
                  'target_artifact_type', j.target_artifact_type, 'created_at', j.created_at,
                  'completed_at', j.completed_at)
          from public.generation_jobs j join public.materials m on m.id = j.material_id
          where m.title = 'Hücre Biyolojisi'));
\o
reset role;
