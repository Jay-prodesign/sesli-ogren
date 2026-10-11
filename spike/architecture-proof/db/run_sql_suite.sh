#!/usr/bin/env bash
# Apply a migration directory and run a SQL test directory against a fresh
# database on a local Postgres, using supabase_shim.sql for platform surface.
#
# Usage: run_sql_suite.sh <db_name> <migrations_dir> <tests_dir> [report_file]
# Env:   PGHOST (socket dir or host), PGPORT, PGADMIN (superuser, default supabase_admin)
#
# Migrations run as the non-superuser "postgres" role (Supabase-like), so RLS,
# grants and SECURITY DEFINER behave as on hosted Supabase. Each test file runs
# in its own psql session with ON_ERROR_STOP; the script prints PASS/FAIL per
# file and exits non-zero if any migration or test fails.
set -uo pipefail

db="$1"; migrations="$2"; tests="$3"; report="${4:-/dev/stdout}"
admin="${PGADMIN:-supabase_admin}"
here="$(cd "$(dirname "$0")" && pwd)"

psql_admin() { psql -X -q -v ON_ERROR_STOP=1 -U "$admin" "$@"; }
psql_owner() { psql -X -q -v ON_ERROR_STOP=1 -U postgres "$@"; }

psql_admin -d postgres -c "drop database if exists \"$db\" with (force);" >/dev/null
psql_admin -d postgres -c "create database \"$db\";" >/dev/null
psql_admin -d "$db" -f "$here/supabase_shim.sql" >/dev/null
psql_admin -d postgres -c "alter database \"$db\" owner to postgres;" >/dev/null

fail=0; mig_ok=0; mig_total=0
for f in $(ls "$migrations"/*.sql | sort); do
  mig_total=$((mig_total+1))
  if out=$(psql_owner -d "$db" -f "$f" 2>&1); then
    mig_ok=$((mig_ok+1))
  else
    echo "MIGRATION FAIL $(basename "$f"): $(echo "$out" | grep -m1 -E 'ERROR|FATAL')" >>"$report"
    fail=1
  fi
done
echo "migrations: $mig_ok/$mig_total applied" >>"$report"

test_ok=0; test_total=0
if [ -d "$tests" ]; then
  for f in $(ls "$tests"/*.sql 2>/dev/null | sort); do
    test_total=$((test_total+1))
    if out=$(psql_owner -d "$db" -f "$f" 2>&1); then
      test_ok=$((test_ok+1)); echo "PASS $(basename "$f")" >>"$report"
    else
      echo "FAIL $(basename "$f"): $(echo "$out" | grep -m1 -E 'ERROR|FATAL|assert')" >>"$report"
      fail=1
    fi
  done
fi
echo "tests: $test_ok/$test_total passed" >>"$report"
exit $fail
