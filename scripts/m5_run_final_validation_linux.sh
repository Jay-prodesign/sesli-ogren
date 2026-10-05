#!/usr/bin/env bash
# Guarded Linux/Android half of the single M5 D-072 final validation batch.
# Run only after an actual independent GLS-083 REVIEW_PASS return exists and the
# Flutter 3.47.5 lockfile has been generated/reviewed/committed.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
review_return="$root/docs/qa/M5_GLS083_INDEPENDENT_REVIEW_RETURN.md"
lockfile="$root/app/pubspec.lock"
report="${1:-$root/m5-final-linux-report.txt}"

fail() {
  echo "M5 final batch guard FAIL: $*" >&2
  exit 2
}

[ -f "$review_return" ] || fail "missing independent GLS-083 return: $review_return"
grep -Eq '(^|[^A-Z_])REVIEW_PASS([^A-Z_]|$)' "$review_return" || fail "GLS-083 return does not contain REVIEW_PASS"
[ -f "$lockfile" ] || fail "app/pubspec.lock is missing; freeze the Flutter 3.47.5 lockfile first"

[ -n "${SUPABASE_URL:-}" ] || fail "SUPABASE_URL is required"
[ -n "${SUPABASE_PUBLISHABLE_KEY:-}" ] || fail "SUPABASE_PUBLISHABLE_KEY is required"

cd "$root"

{
  echo "M5 final Linux/Android validation"
  echo "git_head: $(git rev-parse HEAD)"
  echo "git_branch: $(git rev-parse --abbrev-ref HEAD)"
  echo "runtime_candidate: e576ca177ff8872cbbfc4f127eb016cefa7f611c"
  echo "review_return_sha256: $(sha256sum "$review_return" | awk '{print $1}')"
  echo "pubspec_lock_sha256: $(sha256sum "$lockfile" | awk '{print $1}')"
  echo "flutter:"
  flutter --version | sed 's/^/  /'
  echo "dart:"
  dart --version 2>&1 | sed 's/^/  /'
  echo "java:"
  java -version 2>&1 | sed 's/^/  /'
  echo "python:"
  python3 --version 2>&1 | sed 's/^/  /'
  echo "psql:"
  psql --version 2>&1 | sed 's/^/  /'
  echo
} >"$report"

echo "[1/7] live anonymous auth probe"
python3 scripts/m5_probe_supabase_anonymous_auth.py | tee -a "$report"

echo "[2/7] bootstrap validators"
python3 scripts/validate_bootstrap.py | tee -a "$report"
python3 scripts/test_validate_bootstrap.py | tee -a "$report"

echo "[3/7] dependency reproducibility"
(
  cd app
  flutter pub get
  git diff --exit-code -- pubspec.lock
) | tee -a "$report"

echo "[4/7] format"
(
  cd app
  dart format --output=none --set-exit-if-changed .
) | tee -a "$report"

echo "[5/7] analyze + tests"
(
  cd app
  flutter analyze
  flutter test
) | tee -a "$report"

echo "[6/7] Android profile build"
(
  cd app
  flutter build apk --profile \
    --dart-define=SUPABASE_URL="$SUPABASE_URL" \
    --dart-define=SUPABASE_PUBLISHABLE_KEY="$SUPABASE_PUBLISHABLE_KEY"
) | tee -a "$report"

apk="$root/app/build/app/outputs/flutter-apk/app-profile.apk"
[ -f "$apk" ] || fail "profile APK missing after successful build"
{
  echo "android_profile_apk: $apk"
  echo "android_profile_apk_sha256: $(sha256sum "$apk" | awk '{print $1}')"
} | tee -a "$report"

echo "[7/7] combined M4+M5 SQL migration/regression suite"
bash scripts/m5_validate_server_sql.sh "$root/m5-server-sql-report.txt" | tee -a "$report"
{
  echo "server_sql_report_sha256: $(sha256sum "$root/m5-server-sql-report.txt" | awk '{print $1}')"
  echo "M5_LINUX_ANDROID_BATCH_PASS"
} | tee -a "$report"

echo "report: $report"
