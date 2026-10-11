-- LA-0034 — authenticated account-deletion intent.
-- Hard deletion of Auth user + Storage objects remains in the server-only Edge Function.
\set ON_ERROR_STOP on

create or replace function public.request_account_deletion()
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_requested_at timestamptz := now();
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  update public.accounts
     set status = 'deletion_requested',
         updated_at = v_requested_at
   where id = v_user
     and status in ('active', 'deletion_requested');

  if not found then
    raise exception 'account_not_found' using errcode = 'P0002';
  end if;

  update public.generation_jobs
     set state = 'CANCELLED',
         failure_class = 'account_deletion_requested',
         lease_token = null,
         lease_expires_at = null,
         completed_at = coalesce(completed_at, v_requested_at)
   where account_id = v_user
     and state in ('QUEUED', 'PROCESSING', 'FAILED_RETRYABLE');

  return v_requested_at;
end;
$$;

revoke all on function public.request_account_deletion() from public, anon, authenticated;
grant execute on function public.request_account_deletion() to authenticated;
