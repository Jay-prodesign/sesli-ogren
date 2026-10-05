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

After the lockfile commit, use a clean checkout of that exact head. Record it as the final M5 validation head; runtime code must still trace back to the reviewed frozen runtime candidate except for any explicitly re-reviewed material fix.

First prove the live anonymous-auth service boundary once. This probe uses only the client-safe project URL/publishable key, creates one anonymous authenticated user/session, verifies the authenticated `/auth/v1/user` subject, hashes the returned user ID for evidence, and never prints tokens/keys:

```bash
python3 scripts/m5_probe_supabase_anonymous_auth.py
```

Do not loop this probe: each successful run creates an anonymous user and Supabase rate-limits anonymous sign-ins.

Then run repository + Flutter/Android validation:

```bash
python3 scripts/validate_bootstrap.py
python3 scripts/test_validate_bootstrap.py

cd app
flutter pub get
git diff --exit-code -- pubspec.lock
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --profile \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="$SUPABASE_PUBLISHABLE_KEY"
```

Run the accepted M4 base + M5 SQL delta in one clean local Supabase-like PostgreSQL lineage:

```bash
cd ..
bash scripts/m5_validate_server_sql.sh
```

The SQL report must show migrations `0001`, `0002`, `0003`, `0004` in lexical order and tests `10`, `11`, `20`, `30`, `40`. Test `40` must execute the RPC-level Recall assistance/isolation regression added at `f00df73…`: unassisted immediate replay/idempotency, hint-only success, answer-exposure non-laundering, assistance monotonicity, cross-user rejection, and no support mutation after submission.

On macOS at the same exact final validation head:

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
- live Supabase anonymous-auth probe returns one authenticated anonymous subject/session without logging credentials/tokens;
- production Flutter bootstrap remains statically mapped from Supabase `currentSession.user` / anonymous `response.user` into `AuthenticatedLearner(LearnerId(user.id))` before `AppRuntime.open`; the profile app boot with real defines must reach the source-entry flow rather than the fail-closed configuration/auth screen.

## Evidence to record

Capture:
- exact branch and head SHA;
- Flutter/Dart/Xcode/Java versions used;
- committed `app/pubspec.lock` SHA;
- each command result;
- test count/result;
- live Supabase auth probe PASS + project host + hashed user-ID fingerprint (never token/key);
- combined SQL migration/test report;
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

## Durable return

Record the single bounded batch in `docs/qa/M5_FINAL_VALIDATION_RETURN.md`. Do not create parallel evidence packets for the same run.


## Guarded execution helpers

After the Founder-accepted synthetic GLS-083 review artifact is present and `app/pubspec.lock` has been generated/reviewed/committed with Flutter 3.47.5, prefer the guarded helpers instead of manually retyping the batch:

Linux/Android + live auth + server SQL:
```bash
bash scripts/m5_run_final_validation_linux.sh
```

macOS/iOS profile no-codesign:
```bash
bash scripts/m5_run_final_validation_macos.sh
```

Both helpers fail closed when the accepted synthetic review artifact or lockfile is missing. They do not create the review return or grant M5 PASS.


## Founder override — no GitHub Actions

GitHub Actions is not an allowed execution path for the remaining M5
checkpoint. Do not create, trigger, rerun, or use Actions jobs as validation
evidence.

Execute the manifest only on an explicit local/agent machine environment with
the pinned Flutter 3.47.5 toolchain. The existing guarded scripts remain the
preferred commands because they fail closed on the accepted synthetic review
artifact and lockfile.

Environment split:
- Linux/local agent: live Supabase auth probe, bootstrap checks, Flutter
  format/analyze/tests, Android profile build, combined PostgreSQL SQL suite.
- macOS/local agent: lockfile reproducibility + iOS profile no-codesign build.

The abandoned lockfile-freeze Actions runs are historical failed preparation
only and must not affect M5 verdict.
