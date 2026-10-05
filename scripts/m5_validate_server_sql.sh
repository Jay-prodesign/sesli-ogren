#!/usr/bin/env bash
# M5 checkpoint wrapper: run accepted M4 base migrations + M5 deltas and both
# SQL test suites against one fresh Supabase-like PostgreSQL database.
#
# Usage:
#   bash scripts/m5_validate_server_sql.sh [report_file]
#
# Env:
#   PGHOST, PGPORT, PGADMIN (default supabase_admin)
#
# This script is validation tooling only. It never targets hosted/production DBs.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
harness="$root/spike/architecture-proof/db/run_sql_suite.sh"
base_migrations="$root/spike/architecture-proof/db/migrations"
m5_migrations="$root/server/db/migrations"
base_tests="$root/spike/architecture-proof/db/tests"
m5_tests="$root/server/db/tests"
report="${1:-$root/m5-server-sql-report.txt}"

for path in "$harness" "$base_migrations" "$m5_migrations" "$base_tests" "$m5_tests"; do
  if [ ! -e "$path" ]; then
    echo "missing required SQL validation path: $path" >&2
    exit 2
  fi
done

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/migrations" "$tmp/tests"

copy_unique() {
  local src_dir="$1"
  local dst_dir="$2"
  local kind="$3"
  shopt -s nullglob
  local files=("$src_dir"/*.sql)
  shopt -u nullglob
  if [ "${#files[@]}" -eq 0 ]; then
    echo "no $kind SQL files found in $src_dir" >&2
    exit 2
  fi
  for src in "${files[@]}"; do
    local name
    name="$(basename "$src")"
    if [ -e "$dst_dir/$name" ]; then
      echo "duplicate $kind filename across suites: $name" >&2
      exit 2
    fi
    cp "$src" "$dst_dir/$name"
  done
}

copy_unique "$base_migrations" "$tmp/migrations" "migration"
copy_unique "$m5_migrations" "$tmp/migrations" "migration"
copy_unique "$base_tests" "$tmp/tests" "test"
copy_unique "$m5_tests" "$tmp/tests" "test"

{
  echo "M5 server SQL validation"
  echo "git_head: $(git -C "$root" rev-parse HEAD)"
  echo "postgres_client: $(psql --version)"
  echo "migration_files:"
  find "$tmp/migrations" -maxdepth 1 -type f -name '*.sql' -printf '%f\n' | sort | sed 's/^/  - /'
  echo "test_files:"
  find "$tmp/tests" -maxdepth 1 -type f -name '*.sql' -printf '%f\n' | sort | sed 's/^/  - /'
  echo
} >"$report"

bash "$harness" m5_checkpoint "$tmp/migrations" "$tmp/tests" "$report"

echo "M5 server SQL validation PASS"
echo "report: $report"
cat "$report"
