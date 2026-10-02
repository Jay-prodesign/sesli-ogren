# Round 7 · P1 runtime proof (Flutter Widgets + CustomPaint)

**Proof only; not product code.** This isolated proof answers one question from
ROUND_7_P1_RUNTIME_PROOF_SPEC_001: can the cheapest credible runtime composition carry the Round 7
Companion and source-derived learning world? That composition is standard Flutter Widgets plus
CustomPaint, with no Rive, Lottie, Flame, network or generative dependency.

## Authority and isolation

| Item | Value |
| --- | --- |
| Spec | ROUND_7_P1_RUNTIME_PROOF_SPEC_001 (Drive, by title) |
| Supporting authority | ROUND_7_PROOF_FIXTURES_AND_SCENE_PROTOCOL_v0.1<br>ROUND_7_EXECUTABLE_PROOF_MATRIX_001 (bounded source fixtures, renderer-neutral scene schema, concrete fixtures, cross-domain jury)<br>ROUND_7_ONE_FLOW_INTERACTION_CONTRACT_001<br>ROUND_7_RUNTIME_BENCHMARK_AND_EVIDENCE_MATRIX_v0.1<br>ROUND_7_EVIDENCE_MANIFEST_TEMPLATE_001 |
| Direction | Founder instruction, 2026-09-30: execute P1 on `proof/round7-companion-runtime` |
| Branch / base | `proof/round7-companion-runtime`, created by Brain from `chore/repository-bootstrap` at `433c26c` |
| Firewall | M4 / PR #2 (`spike/v0-architecture-proof`) is untouched. Excluded: M5 admission, merge, deploy, release, TTS, paid provider, billing, admin |
| Task / register IDs | **None allocated here.** This branch forks from the bootstrap line, so `LA-####`, `CMD`/`RET` and `REUSE-####` numbers allocated here would collide with M4's. Brain allocates canonical IDs on integration. Provenance is recorded locally in [PROVENANCE.md](PROVENANCE.md) |

## What is implemented

| Spec item | Implementation |
| --- | --- |
| One reusable renderer consuming the renderer-neutral scene schema | `lib/src/scene/scene_schema.dart` (schema and validation)<br>`lib/src/render/world_painter.dart` (one `CustomPainter`, primitives NODE/PATH/GROUP/PARTITION/PAIR/TRACE/FOCUS_MARK, layout grammars FLOW/PARTITION/TRACE chosen by `layout_hint`) |
| Three bounded fixtures | `assets/fixtures/*.json`: R7-SRC-BIO-001, R7-SRC-FRA-001, R7-SRC-PRO-001, all v1.0. Copy is derived only from the bounded source text |
| Companion D/Knot (provisional) | `lib/src/render/companion_painter.dart`: two interlaced loops and two offset attention marks. This is a **runtime proxy** for measuring state-rendering cost and legibility, not the Founder-selected identity or final art |
| Six states | IDLE, LISTEN, THINK, SPEAK, CORRECT, SUCCESS. A text state label is always shown. CORRECT has two tones (supportive attention for PARTIAL, supportive correction for MISCONCEPTION) |
| Evidence branches | STRONG, PARTIAL, MISCONCEPTION, UNKNOWN. Each has a different reason code, world stage, Companion state and next action (`lib/src/flow/flow_engine.dart`) |
| Degradation | FULL, REDUCED, SIMPLE, NEUTRAL, CONTENT (text-only relations, no canvas). World or Companion asset failure is simulated and records `R_FALLBACK_CAPABILITY` |
| Reduced motion / muted audio | The OS "disable animations" setting and an in-app switch stop all continuous animation. Without audio, SPEAK is never shown and a transcript is always visible. Voice is **simulated** (timed transcript, no TTS) |
| No network | Fixtures are bundled assets. Nothing is fetched at runtime |
| Instrumentation | In-app T1–T11 runner (`lib/src/bench/`) records: build mode, commit SHA (`--dart-define=GIT_SHA`), Flutter/Dart version, platform/OS, refresh rate, DPR, Dart-main-to-first-frame, fixture asset bytes, per-scenario frame build/raster p50/p90/p99/max, frames over the frame budget, RSS memory samples, and live animation-controller counts. `integration_test/` + `test_driver/` add Flutter's timeline summary on a device |

Deterministic proof logic only. Evidence classes come from simulated learner responses, labelled
as such in the UI. There is no learner model, no mastery store and no speech recognition. Nothing
here is a production learner-state authority (one-flow contract §0/§19).

## How to run

```sh
cd proof/round7-p1-runtime
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test                      # unit/widget tests, incl. the T1–T11 functional runner
flutter run --profile --dart-define=GIT_SHA=$(git rev-parse HEAD)   # interactive proof on a device
```

For physical-device benchmark evidence (R7-06), see [DEVICE_RUN_PROTOCOL.md](DEVICE_RUN_PROTOCOL.md).
For the recorded evidence and open items, see [EVIDENCE_MANIFEST.md](EVIDENCE_MANIFEST.md).

CI (`.github/workflows/round7-p1-proof.yml`) runs:
- the checks above;
- a profile APK build stamped with the commit SHA, uploaded as an artifact for D2/D3;
- an empty-app baseline APK, for the package delta;
- an iOS profile compile without codesigning.

## Final Engineering Test (D-029): P1 composition

| # | Question | Answer |
| --- | --- | --- |
| 1 | Necessary now? | Yes. R7-06 needs a real runtime slice before any runtime lock. |
| 2 | Simplest credible? | Yes. It uses Flutter SDK widgets and CustomPaint only, with zero runtime dependencies beyond the SDK. |
| 3 | Secure by default? | Yes. There is no network, no credentials and no generated content. |
| 4 | Understandable? | Yes. There is one world painter, one Companion painter, a schema and a small state machine. |
| 5 | Testable? | Yes. Tests cover the schema, jury rules, branches, tiers, accessibility guidelines and the T1–T11 runner. |
| 6 | Observable? | Yes. Frame timings, RSS, reason codes and events are recorded per scenario. |
| 7 | Replaceable? | Yes. The scene schema is renderer-neutral. A P2 Rive/Lottie Companion would replace only `KnotPainter`. |
| 8 | Privacy? | N/A. There is no learner data; responses are simulated. |
| 9 | Operational cost? | Minimal. Fixture assets are 17.9 KB. The measured APK delta is recorded by CI. |
| 10 | Tomorrow? | Yes. It does not lock production schema or runtime, and the escalation path to P2/P3 stays open on evidence. |

**Open (declared):** device performance is unproven until D1/D2/D3 evidence exists (R7-06).


## R7-07A native TTS capture mode

The chained proof branch `proof/round7-native-tts-capture` adds a non-production capture surface for physical-device native Turkish TTS evidence. The capture UI activates only with `--dart-define=R7_NATIVE_TTS_CAPTURE=true`; this branch is a separate R7-07A evidence build and must not be used as the R7-06 bound runtime build.

The private canonical A-L corpus is supplied at runtime and is not committed. Capture is fail-closed for a detected simulator/emulator or an active network path, records device/OS/engine/voice plus audio/input SHA-256 and generation timing, writes one schema-v2 sample JSON per A-L item plus a capture manifest, and keeps provider-usage cost separate from device/operational cost. This capture build does not replace the R7-06 bound runtime build `ec84e603a67a8fd286e5c57c2a808d62d5c5cd6d`; R7-06 evidence must continue to use its exact bound build.
