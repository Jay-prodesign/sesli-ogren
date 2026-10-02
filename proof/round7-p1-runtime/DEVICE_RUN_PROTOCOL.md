# P1 physical-device run protocol (R7-06)

R7-06 stays **OPEN** until D1, D2 and D3 physical-device runs are recorded, each with the exact
commit and build provenance. Emulators, simulators, browsers and CI runners cannot close it.

## Device matrix (record exact models before running)

| Class | Requirement | Model / OS / refresh | Status |
| --- | --- | --- | --- |
| D1 | Current target iPhone (physical) | _to record_ | NOT_RUN |
| D2 | Mid-range Android (physical) | _to record_ | NOT_RUN |
| D3 | Lower-end supported Android (physical) | _to record_ | NOT_RUN |

## Build

Use the commit under review, profile mode, with the SHA stamped into the app.

- **Android (D2/D3).** Either download the CI artifact `r7-p1-proof-profile-apk-<sha>` from the
  `round7-p1-proof` run for that commit (its `size-report.txt` contains the APK sha256), or build locally:
  `flutter build apk --profile --dart-define=GIT_SHA=<sha>`.
  Install it with `adb install -r r7-p1-proof-profile-<sha>.apk`.
- **iOS (D1).** Needs a Mac with Xcode and an Apple signing identity. A Windows machine cannot
  build or sign iOS. CI only proves that the app compiles for iOS (`--no-codesign`). Build with
  `flutter run --profile --dart-define=GIT_SHA=<sha> -d <iphone>`.

## Run A: automated timeline (preferred, host connected)

```sh
cd proof/round7-p1-runtime
flutter drive --profile --driver=test_driver/perf_driver.dart \
  --target=integration_test/p1_device_benchmark_test.dart \
  --dart-define=GIT_SHA=<sha> -d <device-id>
```

This produces two files:
- `build/p1_timeline.timeline_summary.json`: Flutter's own frame build/raster percentiles, missed-frame counts and shader/cache statistics.
- `build/p1_report.json`: the T1–T11 functional checks, per-scenario frame timings and RSS samples.

## Run B: on-device, no host tooling

1. Launch the profile build.
2. Tap the speed icon, then **Run T1–T11**. The run takes about 4 minutes with 30 soak cycles.
3. **Copy report JSON**, or capture it from the device log:
   - Android: `adb logcat -s flutter | grep R7P1_REPORT`. The chunks are compact JSON; concatenate them in index order.
   - iOS: the Xcode console, same prefix.

## Scenarios (both runs)

| ID | Scenario |
| --- | --- |
| T1 | Launch / open proof surface (Dart-main-to-first-frame recorded; OS cold start measured separately, see below) |
| T2 | Biology world; Companion IDLE→SPEAK→LISTEN→THINK |
| T3 | STRONG → continue/deepen |
| T4 | PARTIAL → target the missing relation |
| T5 | MISCONCEPTION → corrective teaching → smaller repair check |
| T6 | UNKNOWN / interruption → retry, no weakness inference |
| T7 | Switch Biology→Fractions→Professional |
| T8 | FULL→REDUCED→SIMPLE→NEUTRAL→CONTENT (per-tier frames and paint work) |
| T9 | Reduced motion |
| T10 | Audio unavailable |
| T11 | 30 repeated full cycles: jank trend, RSS trend, animation-controller leak check |

## Also record by hand (not observable from inside the app)

- **OS cold start.** Force-stop the app, then run `adb shell am start -W -n com.sesliogren.proof.r7_p1_runtime_proof/.MainActivity` and read `TotalTime`, three times. On iOS, measure launch to first frame with Instruments.
- **Memory.** Android Studio or `adb shell dumpsys meminfo com.sesliogren.proof.r7_p1_runtime_proof` at baseline, after world load and after T11. On iOS, use the Xcode memory gauge.
- **Thermal / battery.** Note warnings or throttling during a 10-minute interactive session.
- **Pause/resume (B09).** Background the app mid-teach and mid-challenge, then return. The step and Companion state must be intact.
- **Accessibility (B15).** Test at the largest system font size with TalkBack / VoiceOver: challenge and actions must be reachable, and the world and Companion must be announced.
- **Refresh rate.** Record the device refresh rate. On 90/120 Hz devices, record whether the rate is fixed or adaptive.

## Evidence completeness validator

After collecting the raw P1 report and the manual physical-device observations,
copy `DEVICE_EVIDENCE_TEMPLATE.json` to a per-device evidence JSON and fill every
field. Then run:

```sh
python3 tool/validate_device_evidence.py \
  --report build/p1_report.json \
  --evidence build/device-evidence-D2.json
```

The validator fails closed on missing provenance, SHA mismatch, incomplete T1–T11,
a soak shorter than 30 cycles, controller leaks, missing cold-start/memory
observations, unresolved fallback checks, and PASS records that still report
repeated visible jank, unbounded memory growth or thermal blockers. D1 PASS also
requires VoiceOver evidence.

This is **completeness validation only**. It cannot close R7-06, substitute for
physical-device execution, decide whether measured values are acceptable, or
replace the D1/D2/D3 final review. TalkBack coverage across Android devices remains
a matrix-level review requirement.

## Evidence record per device

For each run, fill a row in [EVIDENCE_MANIFEST.md](EVIDENCE_MANIFEST.md) with:
- the build SHA;
- the device model, OS and refresh rate;
- the build mode (profile);
- the raw file locations;
- the result: PASS, CHANGE_REQUIRED or REJECT.

Also persist the raw files to Learning App Drive (Round 7 durable-artifact rule). Screenshots and
video support the evidence but cannot stand in for timing data.
