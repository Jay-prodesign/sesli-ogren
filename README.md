# Sesli Öğren

Engineering repository for **Sesli Öğren**, internally tracked as the **Learning App** project.

> **Current state:** M5 Golden Learning Slice has passed and the repository is now on the bounded post-M5 full-product implementation line. Draft PR #13 (`feat/full-product-shell-continuity`) carries the authenticated Home/Library shell, real material/continuation routing, and product-local Listen work. Release/deployment remain separately gated.

## Branch / evidence topology

- `main` remains the untouched initial base.
- PR #1 `chore/repository-bootstrap`: BOOTSTRAP_PASS, draft/unmerged.
- PR #2 `spike/v0-architecture-proof`: ARCHITECTURE_PROOF_PASS / GO_ADAPT, draft/unmerged.
- Round 7 proof branches remain historical/technical evidence; PR #8 is not the current product implementation selector.
- PR #13 `feat/full-product-shell-continuity` is the current bounded post-M5 implementation line.
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

This repository is currently **public but unlicensed**; public visibility is not an open-source grant. Private governance text is not copied here beyond approved titles / decision references.

## AKILTA first-party relationship

Company canonical authority classifies Learning App / Sesli Öğren as **AKILTA_FIRST_PARTY (AKP-0002)**. AKILTA is the parent technology-company brand; product authority remains local to Learning App / Sesli Öğren. This does **not** make the product an AKILTA OS module and does not imply shared database, credentials, billing, identity, checkout, website, AI runtime, or release authority.

The product inherits the current **AKILTA First-Party Product Contract** and **AKILTA IP, Licensing, Third-Party & Donor Reuse Policy** at company-policy level. Product-specific roadmap, architecture, execution state, data/authorization, release truth and repository decisions remain product-owned. Cross-product shared infrastructure is evidence-gated; product completion must not wait for hypothetical AKILTA integration.

Source-visibility note: current AKILTA company policy defaults first-party engineering source to private/proprietary, but explicitly forbids silently changing existing public repositories or prior grants. This repository therefore remains in its existing public/unlicensed posture until a product-local, evidence-backed visibility/distribution decision is made; no license grant is created by this note.

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

## Licensing / source posture

No open-source or repository-wide public license has been granted. First-party source and original product material are proprietary; see [PROPRIETARY_NOTICE.md](PROPRIETARY_NOTICE.md). Repository visibility is not a license grant.

Third-party dependencies and incorporated material remain governed by their own licenses/terms. Release-time notices/SBOM or equivalent dependency evidence must be generated from the actual shipping dependency set; this repository notice does not override third-party rights.
