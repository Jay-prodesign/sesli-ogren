#!/usr/bin/env bash
# For each SQL test, find the migration step(s) at which it passes, by
# snapshotting a template database after every migration.
# Usage: find_test_migration_step.sh <migrations_dir> <tests_dir> [test names...]
# Env: PGHOST, PGPORT, PGADMIN (default supabase_admin)
set -uo pipefail
migrations="$1"; tests="$2"; shift 2
admin="${PGADMIN:-supabase_admin}"
here="$(cd "$(dirname "$0")" && pwd)"
psql_admin() { psql -X -q -v ON_ERROR_STOP=1 -U "$admin" "$@"; }

mapfile -t migs < <(ls "$migrations"/*.sql | sort)
psql_admin -d postgres -c "drop database if exists step_build with (force);" >/dev/null 2>&1
psql_admin -d postgres -c "create database step_build;" >/dev/null
psql_admin -d step_build -f "$here/supabase_shim.sql" >/dev/null
psql_admin -d postgres -c "alter database step_build owner to postgres;" >/dev/null
for i in "${!migs[@]}"; do
  n=$((i+1))
  psql -X -q -v ON_ERROR_STOP=1 -U postgres -d step_build -f "${migs[$i]}" >/dev/null 2>&1 || echo "build step $n failed"
  psql_admin -d postgres -c "drop database if exists step_$n with (force);" >/dev/null 2>&1
  psql_admin -d postgres -c "create database step_$n template step_build owner postgres;" >/dev/null
done

names=("$@"); [ ${#names[@]} -eq 0 ] && mapfile -t names < <(ls "$tests"/*.sql | xargs -n1 basename)
for t in "${names[@]}"; do
  passing=()
  for n in $(seq 1 ${#migs[@]}); do
    psql_admin -d postgres -c "drop database if exists step_try with (force);" >/dev/null 2>&1
    psql_admin -d postgres -c "create database step_try template step_$n owner postgres;" >/dev/null
    if psql -X -q -v ON_ERROR_STOP=1 -U postgres -d step_try -f "$tests/$t" >/dev/null 2>&1; then
      passing+=("$n")
    fi
  done
  echo "$t: passes at migration steps [${passing[*]:-none}] of ${#migs[@]}"
done
