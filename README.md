# Sesli Öğren

Engineering repository for **Sesli Öğren**, internally tracked as the **Learning App** project.

> **Current state:** M0 Repository Bootstrap and M1 Architecture Proof are accepted. The active stacked branch
> `feat/round7-companion-production-sequence-v2` / draft PR #8 carries a bounded **Round 7 companion/runtime evidence program**.
> It contains a real Flutter proof with canonical D/Knot and E/Tilt assets, semantic companion motion,
> product-local device TTS, Android/iOS build evidence, responsive phone QA and synthetic visual/motion QA.
> **M2 / Golden Learning Slice implementation is still NOT_EXECUTABLE** until its controlling admission gates close.

## Branch / evidence topology

- `main` remains the untouched initial base.
- PR #1 `chore/repository-bootstrap`: BOOTSTRAP_PASS, draft/unmerged.
- PR #2 `spike/v0-architecture-proof`: ARCHITECTURE_PROOF_PASS / GO_ADAPT, draft/unmerged.
- Round 7 proof branches are stacked evidence branches; the active companion branch is PR #8.
- Merge, release and deployment remain Product Owner protected actions.

## Current Round 7 proof

The active Flutter proof is under [`proof/round7-p1-runtime/`](proof/round7-p1-runtime/).

Verified on the current evidence line:

- canonical D/Knot + E/Tilt raster identities;
- V1 limbless anatomy: 0 arms / 0 hands / 0 legs / 0 feet;
- semantic states: IDLE / LISTEN / THINK / SPEAK / CORRECT / SUCCESS;
- responsive companion sizing for phone portrait + compact landscape;
- bounded D/E motion language, with E intentionally more energetic than D;
- product-local device TTS and playback-driven SPEAK lifecycle;
- local mouth warp PASS; synthetic blink rejected and removed;
- Flutter format/analyze/tests PASS;
- Android profile APK build PASS;
- iOS profile compile without codesign PASS;
- synthetic phone visual + multi-frame motion QA PASS.

The remaining companion gate is **physical native-device QA** for real TTS/audio behavior, native safe-area/orientation,
and real-device smoothness. This gate cannot be truthfully closed by browser or CI evidence alone.

## Where truth lives

| Concern | Source of truth |
| --- | --- |
| Product intent, scope, decisions, lifecycle gates | Private Learning App canonical governance set |
| Engineering state, code, QA evidence | This repository and the active stacked branch |
| Companion execution cursor | `docs/agent/ROUND7_COMPANION_CURRENT_CURSOR.json` |
| Companion asset/runtime status | `docs/agent/ROUND7_COMPANION_ASSET_STATUS.json` |

This repository is **public**. Private governance text is not copied here beyond approved titles / decision references.

## Validation

Repository control plane:

```sh
python3 scripts/validate_bootstrap.py
python3 scripts/test_validate_bootstrap.py
```

Round 7 Flutter proof:

```sh
cd proof/round7-p1-runtime
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

Phone web preview is generated **on demand** with the free Cloudflare Quick Tunnel workflow; it is a visual/flow QA
surface, not a substitute for final native-device validation.

## Licensing

No repository-wide license has been granted. Existing third-party reuse/dependency obligations remain governed by the
project provenance register and accepted architecture decisions.
