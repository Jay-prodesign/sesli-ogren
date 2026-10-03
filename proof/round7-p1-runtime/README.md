# Round 7 · P1 runtime proof

**Proof only; not production product code.** This Flutter proof validates the cheapest credible
Learning App runtime composition for the source-derived learning world, D/Knot + E/Tilt companions,
semantic companion motion and product-local device speech.

## Current implementation

| Area | Current proof |
| --- | --- |
| Learning world | One renderer consuming the renderer-neutral scene schema; three bounded fixtures |
| Companions | Canonical raster D/Knot + E/Tilt assets selected through one renderer seam |
| Companion states | IDLE, LISTEN, THINK, SPEAK, CORRECT, SUCCESS |
| Motion | Bounded whole-character translate/scale/tilt/squash-stretch; D calm, E slightly more energetic |
| Speech | Product-local `flutter_tts` device speech; no shared Speech Service |
| SPEAK truth | Starts from real playback start callback; settles on completion / stop / error |
| Mouth | Subtle local speech warp; synthetic visual QA PASS |
| Blink | Rejected by visual QA and disabled for V1 |
| Reduced motion | Removes continuous/local animation while preserving the learning loop |
| Fallback | Transcript and content-first learning path remain usable when audio/visual capability fails |
| Native Speech QA | One-tap QA screen checks start → SPEAK → completion and start → stop → stale-callback guard |
| Network | App code makes no content/network request in this proof; TTS is delegated to the installed OS/device engine |

The learning evidence in this proof is deterministic fixture input. There is no production learner
mastery model or speech recognition here.

## Verified evidence

Application/evidence head: `eb9c07285bf3ed201556cb7e60b8de9e561e22b5`.

GitHub Actions run **37140739027** passed:

- repository/bootstrap validation;
- Dart format;
- Flutter analyze;
- Flutter tests;
- P9 visual and motion capture;
- Android profile APK build with `flutter_tts`;
- iOS profile compile without codesigning;
- iOS simulator native `flutter_tts` start/completion/stop integration test using an explicit `tr-TR` probe. The bounded proof fixtures themselves currently own `en-US` voice locale.

The PR workflow checkout SHA for that run is `54a96e776fda7252cb578ec2c2d58ff4cdf5aabd`.
The Android profile APK SHA-256 is `20b4d1d7d5f30252b7510fccd827d3fcad657bc08abad4d1331acf1a60d8f40d`.

Simulator and CI evidence do **not** close the final native-device gate. Physical hardware still has
to confirm actual audibility/fixture-locale voice behavior, the one-tap callback QA result, smooth interaction and
native safe-area/orientation behavior.

## Run

```sh
cd proof/round7-p1-runtime
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter run --profile --dart-define=GIT_SHA=$(git rev-parse HEAD)
```

In the running app, use the **voice icon** to open **Native Speech QA**. The screen must report
`CALLBACK_LIFECYCLE_PASS`; then confirm on the physical device that speech is actually audible in
the fixture-owned expected voice/locale and that portrait/landscape interaction is smooth and unclipped.

For the full physical-device evidence protocol, see [DEVICE_RUN_PROTOCOL.md](DEVICE_RUN_PROTOCOL.md).

## Current design boundary

No layered face rig, extra state PNG family, blink system or secondary poses are admitted while the
current canonical D/E assets and single-master semantic motion satisfy the app. Reopen those only if
physical device evidence identifies a concrete user-visible defect.

`flutter_tts` currently builds and tests successfully on the pinned Flutter toolchain. CI emits
upstream migration warnings about future Kotlin built-in and Swift Package Manager support; those
are compatibility backlog signals, not a current V1 blocker.
