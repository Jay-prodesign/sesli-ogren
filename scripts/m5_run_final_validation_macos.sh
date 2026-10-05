#!/usr/bin/env bash
# Guarded macOS/iOS half of the single M5 D-072 final validation batch.
# Run only after an actual independent GLS-083 REVIEW_PASS return exists and the
# Flutter 3.47.5 lockfile has been generated/reviewed/committed.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
review_return="$root/docs/qa/M5_GLS083_INDEPENDENT_REVIEW_RETURN.md"
lockfile="$root/app/pubspec.lock"
report="${1:-$root/m5-final-ios-report.txt}"

fail() {
  echo "M5 iOS batch guard FAIL: $*" >&2
  exit 2
}

[ "$(uname -s)" = "Darwin" ] || fail "this runner must execute on macOS"
[ -f "$review_return" ] || fail "missing independent GLS-083 return: $review_return"
grep -Eq '(^|[^A-Z_])REVIEW_PASS([^A-Z_]|$)' "$review_return" || fail "GLS-083 return does not contain REVIEW_PASS"
[ -f "$lockfile" ] || fail "app/pubspec.lock is missing; freeze the Flutter 3.47.5 lockfile first"
[ -n "${SUPABASE_URL:-}" ] || fail "SUPABASE_URL is required"
[ -n "${SUPABASE_PUBLISHABLE_KEY:-}" ] || fail "SUPABASE_PUBLISHABLE_KEY is required"

cd "$root"

{
  echo "M5 final macOS/iOS validation"
  echo "git_head: $(git rev-parse HEAD)"
  echo "git_branch: $(git rev-parse --abbrev-ref HEAD)"
  echo "runtime_candidate: 64579d48bcf9c33f4c709927a0e453349efb7c5b"
  echo "review_return_sha256: $(shasum -a 256 "$review_return" | awk '{print $1}')"
  echo "pubspec_lock_sha256: $(shasum -a 256 "$lockfile" | awk '{print $1}')"
  echo "flutter:"
  flutter --version | sed 's/^/  /'
  echo "dart:"
  dart --version 2>&1 | sed 's/^/  /'
  echo "xcode:"
  xcodebuild -version | sed 's/^/  /'
  echo
} >"$report"

echo "[1/3] dependency reproducibility"
(
  cd app
  flutter pub get
  git diff --exit-code -- pubspec.lock
) | tee -a "$report"

echo "[2/3] iOS profile no-codesign build"
(
  cd app
  flutter build ios --profile --no-codesign \
    --dart-define=SUPABASE_URL="$SUPABASE_URL" \
    --dart-define=SUPABASE_PUBLISHABLE_KEY="$SUPABASE_PUBLISHABLE_KEY"
) | tee -a "$report"

app_bundle="$root/app/build/ios/iphoneos/Runner.app"
[ -d "$app_bundle" ] || fail "Runner.app missing after successful iOS profile build"

echo "[3/3] artifact fingerprint"
{
  echo "ios_profile_app: $app_bundle"
  echo "ios_profile_app_tree_sha256: $(find "$app_bundle" -type f -print0 | sort -z | xargs -0 shasum -a 256 | shasum -a 256 | awk '{print $1}')"
  echo "M5_IOS_BATCH_PASS"
} | tee -a "$report"

echo "report: $report"
