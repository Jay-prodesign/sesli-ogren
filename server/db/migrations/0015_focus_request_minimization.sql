\set ON_ERROR_STOP on

-- Focus questions are retained only while the exact job may still need a safe
-- provider retry. Once a job is terminal, cancelled, or requires provider-side
-- reconciliation instead of resend, plaintext learner questions are no longer
-- needed and must be removed from durable request_context.
create or replace function public.la_minimize_focus_request_context()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.generation_contract = 'focus.v1'
     and new.request_context ? 'question'
     and (
       new.state in ('SUCCEEDED', 'FAILED_FINAL', 'CANCELLED')
       or (
         new.state = 'FAILED_RETRYABLE'
         and new.failure_class = 'reconciliation_required'
       )
     ) then
    new.request_context := new.request_context - 'question';
  end if;
  return new;
end;
$$;

drop trigger if exists minimize_focus_request_context
on public.generation_jobs;

create trigger minimize_focus_request_context
before update on public.generation_jobs
for each row
execute function public.la_minimize_focus_request_context();

revoke all on function public.la_minimize_focus_request_context()
from public, anon, authenticated;
