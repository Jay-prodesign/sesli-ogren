\set ON_ERROR_STOP on

-- LA-0025 structural contract checks. Behavioral auth/source checks run in the
-- bounded PostgreSQL harness where the accepted Supabase auth shim is present.

do $$
begin
  if to_regprocedure('public.request_grounded_explain(uuid,text,text)') is null then
    raise exception 'request_grounded_explain_missing';
  end if;
  if to_regprocedure('public.read_grounded_explain(uuid,text)') is null then
    raise exception 'read_grounded_explain_missing';
  end if;
end
$$;

-- Client boundary must remain authenticated-only.
do $$
begin
  if has_function_privilege('anon', 'public.request_grounded_explain(uuid,text,text)', 'EXECUTE') then
    raise exception 'anon_must_not_request_explain';
  end if;
  if has_function_privilege('anon', 'public.read_grounded_explain(uuid,text)', 'EXECUTE') then
    raise exception 'anon_must_not_read_explain';
  end if;
  if not has_function_privilege('authenticated', 'public.request_grounded_explain(uuid,text,text)', 'EXECUTE') then
    raise exception 'authenticated_request_missing';
  end if;
  if not has_function_privilege('authenticated', 'public.read_grounded_explain(uuid,text)', 'EXECUTE') then
    raise exception 'authenticated_read_missing';
  end if;
end
$$;
