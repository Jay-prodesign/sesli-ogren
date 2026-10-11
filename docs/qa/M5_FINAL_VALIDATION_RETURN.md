# M5 Final Validation Return

> Founder-accepted synthetic GLS-083 review is the M5 review evidence. External independence is waived for LA-0022/M5 only.
> This return records the bounded checkpoint evidence and does not by itself grant M5 PASS.

## Identity

- Runtime candidate reviewed by GLS-083: `64579d48bcf9c33f4c709927a0e453349efb7c5b`
- GLS-083 disposition: `PASS_FOUNDER_WAIVER / SYNTHETIC_ACCEPTED`
- Flutter/Android validated app head: `72494bec8525f37a9fed8a6b6f38d60033b57e08`
- Platform validation head: `17773e631e3dc1ae28dd1a4656e0509309083923`
- Branch: `feat/m5-golden-learning-slice`
- Validation date: 2026-10-05
- Executor/environment: GitHub-hosted Ubuntu + macOS runners; local Codex evidence used only for earlier formatting/analyzer corrections.

## Toolchain

- Flutter: 3.47.5 — PASS
- Dart: 3.13.4 — PASS
- Android profile toolchain: PASS
- Xcode: 26.6 — PASS
- PostgreSQL: 16 — PASS

## Live Supabase anonymous-auth evidence

Command:

```bash
python3 scripts/m5_probe_supabase_anonymous_auth.py
```

- Result: `BLOCKED_MISSING_PROTECTED_CLIENT_VALUES`
- `SUPABASE_URL`: absent from validation environment
- `SUPABASE_PUBLISHABLE_KEY`: absent from validation environment
- Project host: NOT_AVAILABLE
- Anonymous authenticated user/session verified: NOT_RUN
- User-ID SHA-256 prefix: NOT_AVAILABLE
- Keys/tokens logged: FALSE
- Notes: Only client-safe project URL + publishable key are permitted. Service-role credentials are prohibited.

## Repository control plane

- Final-head bootstrap validator: NOT_RERUN_IN_FINAL_M5_BATCH
- Final-head bootstrap validator unit tests: NOT_RERUN_IN_FINAL_M5_BATCH
- Deviation: this does not control the current disposition because live auth is already the unresolved non-physical blocker; do not spend another Actions run solely for duplicate evidence.

## Flutter dependency reproducibility

- `flutter pub get`: PASS
- committed lockfile reproducibility: PASS
- unexpected dependency/provenance change: NONE OBSERVED
- Flutter/Android Actions run: `37334117375`

## Flutter static + test evidence

- format: PASS
- `flutter analyze`: PASS
- `flutter test`: PASS — 39 tests
- real PDF engine probe: PASS — 2 pages + expected text
- Android profile APK: PASS — 94.0 MB
- PDFium packaged in APK: PASS
- APK SHA-256: `04e2294ba054c5ed20eb2509f50b76d94759e8f9692e1555e69a14261f7d0b74`

Focused coverage:
- source idempotency/supersession: PASS
- PDF ingest/provenance contract: PASS
- real native PDF extraction: PASS via pdfrx_engine native-assets probe
- tenant isolation: PASS
- assistance / answer-exposure integrity: PASS
- direct-store fabricated state rejection: PASS
- active-attempt continuity: PASS
- idempotent/conflicting replay: PASS
- stale-source/delete/tombstone behavior: PASS
- continuation repair/reopen: PASS
- Reduced Motion/widget flow: PASS in automated surface
- privacy-safe telemetry: PASS
- missing-auth-config fail-closed: PASS

## Server SQL evidence

Command:

```bash
bash scripts/m5_validate_server_sql.sh m5-server-sql-report.txt
```

- Result: PASS
- Actions run: `37337837569`
- Tests: 5/5 PASS
- `10_canonical_flow.sql`: PASS
- `11_canonical_flow_reopen.sql`: PASS
- `20_tenant_isolation.sql`: PASS
- `30_job_idempotency.sql`: PASS
- `40_recall_learning_truth.sql`: PASS
- RPC unassisted replay/idempotency: PASS
- hinted exact answer → helped_correct/developing: PASS
- answer exposure → answer_exposed/not_assessed: PASS
- assistance monotonicity: PASS
- cross-user reveal/submit rejection: PASS
- submitted-attempt support mutation rejection: PASS
- uploaded report artifact ID: `11357231937`
- uploaded report ZIP SHA-256: `01f40d5dde24baa25aa9db3510bee0815b213ae10c0e0afa0bf2dd2918703368`

## Android profile evidence

- Build/result: PASS
- Artifact: `build/app/outputs/flutter-apk/app-profile.apk`
- SHA-256: `04e2294ba054c5ed20eb2509f50b76d94759e8f9692e1555e69a14261f7d0b74`
- Real Supabase defines supplied: NO — protected client values absent
- Authenticated source-entry boot: NOT_RUN / BLOCKED_BY_LIVE_AUTH_CONFIG
- Missing-config fail-closed screen: PASS

## iOS profile no-codesign evidence

- Build/result: PASS
- Artifact: `build/ios/iphoneos/Runner.app` — 34.4 MB
- app fingerprint SHA-256: `74a5eaafa081fc64a33ade9575f4ac49f53bbd51b21834a8c92f1f1b9003f9b7`
- Xcode: 26.6
- Real Supabase defines supplied: NO — protected client values absent
- Expected warning: codesigning disabled for profile validation
- Material build warnings: NONE OBSERVED

## Accessibility runtime evidence

- Reduced Motion automated behavior: PASS
- Physical VoiceOver/TalkBack: `DEFERRED_D068`
- Physical performance/orientation/speech: `DEFERRED_D068`
- No release-candidate/public-release PASS may be claimed until D-068 physical checks are completed.

## Remaining blockers

1. Live Supabase anonymous-auth proof using only client-safe `SUPABASE_URL` + `SUPABASE_PUBLISHABLE_KEY`.
2. Physical-device validation remains deferred under D-068 and is not a blocker to this non-physical checkpoint, but is mandatory before release.

## Batch disposition

`BLOCKED` — solely on the remaining live-auth configuration/evidence gate.

## M5 verdict input

`M5_NOT_YET_PASS — NON_PHYSICAL_IMPLEMENTATION/BUILD/SQL EVIDENCE PASS; LIVE AUTH EVIDENCE BLOCKED BY MISSING CLIENT-SAFE CONFIG.`

Do not broaden product scope. Resolve the live-auth gate next. Once it passes, Brain may issue the M5 checkpoint verdict; D-068 physical-device work remains a later mandatory release gate.
