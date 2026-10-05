# M5 Final Validation Return

> Fill only after GLS-083 returns REVIEW_PASS and the final lockfile head is frozen.
> This file records the single bounded D-072 checkpoint batch; it is not a new gate.

## Identity

- Runtime candidate reviewed by GLS-083: `64579d48bcf9c33f4c709927a0e453349efb7c5b`
- GLS-083 disposition: PENDING
- Final validation head: PENDING
- Branch: `feat/m5-golden-learning-slice`
- `app/pubspec.lock` blob/commit SHA: PENDING
- Validation date: PENDING
- Executor/environment: PENDING

## Toolchain

- Flutter: PENDING
- Dart: PENDING
- Java: PENDING
- Android toolchain: PENDING
- Xcode/macOS: PENDING
- PostgreSQL/psql: PENDING

## Live Supabase anonymous-auth evidence

Command:

```bash
python3 scripts/m5_probe_supabase_anonymous_auth.py
```

- Result: PENDING
- Project host: PENDING
- Anonymous authenticated user/session verified: PENDING
- User-ID SHA-256 prefix: PENDING
- Keys/tokens logged: MUST_BE_FALSE
- Anonymous sign-ins enabled: PENDING
- Notes: PENDING

Do not record access tokens, refresh tokens, publishable key values, service-role
keys, or other secrets in this artifact.

## Repository control plane

- `python3 scripts/validate_bootstrap.py`: PENDING
- `python3 scripts/test_validate_bootstrap.py`: PENDING

## Flutter dependency reproducibility

- `flutter pub get`: PENDING
- `git diff --exit-code -- app/pubspec.lock` after resolution: PENDING
- Unexpected dependency/provenance change: PENDING

## Flutter static + test evidence

- `dart format --output=none --set-exit-if-changed .`: PENDING
- `flutter analyze`: PENDING
- `flutter test`: PENDING
- Test count / failures / skips: PENDING

Required focused coverage disposition:
- source idempotency/supersession: PENDING
- malformed/oversized + real PDF extraction: PENDING
- tenant isolation: PENDING
- assistance / answer-exposure integrity: PENDING
- direct-store fabricated state/assistance rejection: PENDING
- active-attempt continuity: PENDING
- idempotent/conflicting replay: PENDING
- stale-source/delete/tombstone behavior: PENDING
- continuation repair/reopen: PENDING
- migrations: PENDING
- Reduced Motion/widget flow: PENDING
- privacy-safe telemetry: PENDING
- missing-auth-config fail-closed: PENDING

## Server SQL evidence

Command:

```bash
bash scripts/m5_validate_server_sql.sh
```

- Result: PENDING
- Migration order observed: PENDING
- Expected: `0001`, `0002`, `0003`, `0004`
- Test files observed: PENDING
- Expected: `10`, `11`, `20`, `30`, `40`
- RPC unassisted immediate replay/idempotency: PENDING
- RPC hinted exact answer → helped_correct/developing: PENDING
- RPC answer exposure → answer_exposed/not_assessed: PENDING
- RPC answer-exposure monotonicity across later hint: PENDING
- RPC cross-user reveal/submit rejection: PENDING
- RPC submitted-attempt hint/answer mutation rejection: PENDING
- Report path/hash: PENDING

## Android profile evidence

- Build command/result: PENDING
- Artifact path/hash: PENDING
- Real Supabase defines supplied via protected environment: PENDING
- Profile app boot reaches authenticated source-entry flow: PENDING
- Fail-closed auth/config screen absent with valid configuration: PENDING

## iOS profile no-codesign evidence

- Build command/result: PENDING
- Real Supabase defines supplied via protected environment: PENDING
- Xcode warnings materially relevant to supported runtime: PENDING

## Accessibility runtime evidence

- Reduced Motion runtime behavior: PENDING
- Large-text/layout check in bounded non-physical environment: PENDING
- Semantic labels/tree where automatable: PENDING
- Physical VoiceOver/TalkBack: DEFERRED_D068 — do not claim PASS here

## Warnings / deviations

PENDING

## Remaining blockers

PENDING

## Batch disposition

Use one:

- `BATCH_PASS`
- `CHANGES_REQUIRED`
- `BLOCKED`

Disposition: PENDING

## M5 verdict input

This return does not itself grant M5 PASS. Brain reconciles it with:
- GLS-083 independent review;
- M5 acceptance matrix;
- Product/Learning/Creative/accessibility dispositions;
- D-068 deferred physical-device boundary.

Recommended checkpoint verdict input: PENDING
