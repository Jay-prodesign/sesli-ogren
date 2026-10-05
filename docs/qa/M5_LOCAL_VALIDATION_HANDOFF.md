# M5 Local / Agent Validation Handoff — NO GITHUB ACTIONS

## Authority

- Project: Learning App / Sesli Öğren
- Task: LA-0022
- Runtime candidate: `64579d48bcf9c33f4c709927a0e453349efb7c5b`
- Synthetic review: accepted by Founder for M5 only
- GitHub Actions: **FORBIDDEN for remaining M5 work**
- Merge/release/deploy/paid-provider/secret mutation: Product Owner only

This handoff is for a real local or agent-controlled machine environment
(Codex/Claude/local workstation), not GitHub Actions.

## Required environment

### Linux/Android side
- Git
- Flutter exactly 3.47.5
- Dart from that Flutter SDK
- Java + Android SDK
- Python 3
- PostgreSQL client/server capable of running the existing local Supabase-like
  shim harness
- protected environment variables:
  - `SUPABASE_URL`
  - `SUPABASE_PUBLISHABLE_KEY`

Do not expose or commit those values.

### macOS/iOS side
- macOS
- Xcode
- Flutter exactly 3.47.5
- same committed `app/pubspec.lock`
- same protected client-safe Supabase variables for the profile build

## Step 1 — fresh checkout

```bash
git clone https://github.com/Jay-prodesign/sesli-ogren.git
cd sesli-ogren
git checkout feat/m5-golden-learning-slice
git status --short
cat .flutter-version
flutter --version
```

Required:
- clean worktree;
- `.flutter-version` = `3.47.5`;
- Flutter reports 3.47.5.

Do not upgrade Flutter or dependencies.

## Step 2 — lockfile freeze

At repository root:

```bash
cd app
test ! -e pubspec.lock
flutter pub get
test -s pubspec.lock
git diff -- pubspec.lock
cd ..
```

Review the lockfile for:
- no path/git dependency unexpectedly introduced;
- direct packages remain aligned with `app/pubspec.yaml`;
- no dependency resolution failure;
- no toolchain-version conflict.

Then commit **only** the lockfile:

```bash
git add app/pubspec.lock
git diff --cached --stat
git diff --cached -- app/pubspec.lock
git commit -m "build(m5): freeze Flutter 3.47.5 dependency lock"
```

Record the resulting commit SHA as the final validation head.

Do not commit generated build files, credentials, logs, IDE files or SDK state.

## Step 3 — Linux / Android / SQL / live-auth batch

Set the protected environment variables in the shell without printing them.

Then:

```bash
bash scripts/m5_run_final_validation_linux.sh
```

The guarded runner must perform:
- accepted synthetic review artifact check;
- committed lockfile check;
- one real Supabase anonymous authenticated-session probe;
- repository bootstrap validators;
- `flutter pub get` reproducibility check;
- Dart format check;
- Flutter analyze;
- Flutter tests;
- Android profile APK build;
- APK fingerprint;
- combined M4 + M5 PostgreSQL migration/regression suite.

Do not retry blindly on failure. Stop at the earliest controlling failure and
report it.

## Step 4 — macOS / iOS batch

On a macOS checkout of the **same final validation head**:

```bash
bash scripts/m5_run_final_validation_macos.sh
```

Required:
- same committed lockfile;
- same Flutter 3.47.5 pin;
- iOS profile `--no-codesign` build;
- artifact fingerprint.

Do not claim physical-device evidence from this step. D-068 physical
VoiceOver/TalkBack/device/orientation remains deferred.

## Step 5 — evidence return

Fill:
`docs/qa/M5_FINAL_VALIDATION_RETURN.md`

Attach or record:
- final validation commit SHA;
- Flutter/Dart/Java/Xcode/PostgreSQL versions;
- lockfile SHA-256;
- live Supabase probe safe output only;
- format/analyze/test results;
- SQL report/hash;
- Android APK hash;
- iOS artifact tree hash;
- accessibility runtime evidence that was actually executed;
- warnings/deviations.

Never write:
- Supabase publishable-key value;
- access token;
- refresh token;
- service-role key;
- other credentials.

## Failure handling

Use:
- `BATCH_PASS`
- `CHANGES_REQUIRED`
- `BLOCKED`

If a code/runtime defect is found:
1. stop the batch;
2. report exact failing command and first controlling error;
3. make only the smallest required correction;
4. Brain re-evaluates whether the runtime candidate must be re-frozen and
   whether synthetic review must be repeated before another bounded batch.

Do not silently widen scope.

## Success condition

The executor may report `BATCH_PASS` only when all non-deferred M5 commands
required by the manifest completed successfully on the committed lockfile head.

Brain owns the final M5 PASS / CHANGES_REQUIRED / BLOCKED reconciliation.
