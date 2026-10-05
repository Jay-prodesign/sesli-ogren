# M5 Checkpoint — Single Bounded Validation Manifest

This is the **only planned runtime/build validation batch** for the M5 checkpoint under D-072. It is not a routine per-commit CI workflow.

## Preconditions

Run only after:
1. feature implementation is frozen;
2. static checkpoint review has no known code-level blocker;
3. GLS-083 independent review findings that affect compilation/runtime semantics are resolved;
4. exact branch/head to validate is recorded.


## Existing workflow non-equivalence

Do not use historical green workflows as substitutes for the M5 batch:
- `.github/workflows/flutter-proof.yml` validates only `spike/architecture-proof/client`;
- `.github/workflows/round7-p1-proof.yml` validates only `proof/round7-p1-runtime`;
- `.github/workflows/bootstrap-validation.yml` validates only the repository control plane.

None resolves `app/pubspec.lock`, runs the production-shaped `app/` tests/builds, validates the M5 Supabase-authenticated bootstrap, or executes the M5 server SQL delta. Historical success from those workflows is supporting lineage evidence only, never M5 checkpoint PASS evidence.

## Required environment

- Repository: `Jay-prodesign/sesli-ogren`
- Branch: `feat/m5-golden-learning-slice`
- Flutter: exact value from repository `.flutter-version` (currently `3.47.5`)
- Supported Android toolchain for Flutter 3.47.5
- macOS/Xcode environment for the iOS no-codesign compile
- clean checkout; no undocumented machine-local source or dependency override
- Supabase project with anonymous auth enabled for this bounded M5 validation
- `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` supplied as protected build-time values; never committed

## Phase A — resolve and freeze dependencies

From repository root:

```bash
cd app
flutter pub get
test -f pubspec.lock
cd ..
git status --short
```

The generated `app/pubspec.lock` must be reviewed against `app/pubspec.yaml` and `docs/provenance/OPEN_SOURCE_REUSE_REGISTER.md`, then committed **before** the final frozen-head validation run.

Do not manually fabricate or copy a lockfile from another project.

## Phase B — frozen-head validation

After the lockfile commit, use a clean checkout of that exact head.

```bash
python3 scripts/validate_bootstrap.py
python3 scripts/test_validate_bootstrap.py

cd app
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --profile \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="$SUPABASE_PUBLISHABLE_KEY"
```

On macOS at the same exact frozen head:

```bash
cd app
flutter pub get
flutter build ios --profile --no-codesign \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="$SUPABASE_PUBLISHABLE_KEY"
```

## Required focused test coverage

The full `flutter test` run must include, at minimum:
- source text idempotency and supersession;
- malformed/oversized PDF and real two-page PDF extraction;
- tenant-isolation negatives;
- help/answer-exposure semantics;
- direct-store fabricated-assistance/state rejection;
- active Recall attempt invariants;
- answer exposure surviving close/reopen;
- conflicting replay/idempotent replay;
- stale-source cleanup;
- delete/tombstone behavior;
- continuation repair and close/reopen;
- v2→current and v5→v6 migration preservation;
- Reduced Motion/widget flow;
- privacy-safe operational telemetry lineage;
- production bootstrap fails closed with no Supabase config;
- configured runtime establishes a real Supabase authenticated session and maps its user ID into `AuthenticatedLearner` before opening local learning data.

## Evidence to record

Capture:
- exact branch and head SHA;
- Flutter/Dart/Xcode/Java versions used;
- committed `app/pubspec.lock` SHA;
- each command result;
- test count/result;
- Android profile APK build result;
- iOS profile no-codesign build result;
- representative durations already emitted by the admitted flow where available;
- any warning/deprecation materially relevant to supported runtime;
- no claim of physical-device PASS.

## Failure rule

If any blocking command fails:
- do **not** repeatedly rerun Actions;
- classify the failure;
- correct the earliest controlling code/config contract;
- freeze a new head;
- rerun only the affected local/bounded checkpoint evidence necessary to establish a credible verdict.

## D-068 boundary

This batch does not replace:
- physical iPhone validation;
- representative physical Android validation;
- final speech/audibility/device-performance/orientation checks.

Those remain at final mobile-readiness.
