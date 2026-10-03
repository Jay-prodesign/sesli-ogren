# P1 evidence manifest

Records follow ROUND_7_EVIDENCE_MANIFEST_TEMPLATE_001.

## Latest non-physical evidence

- Verified application/evidence head: `eb9c07285bf3ed201556cb7e60b8de9e561e22b5`
- GitHub Actions run: `37140739027`
- PR workflow checkout/build SHA: `54a96e776fda7252cb578ec2c2d58ff4cdf5aabd`
- Dart format / analyze / Flutter tests: **PASS**
- P9 visual + semantic motion QA: **PASS**
- iOS native `flutter_tts` simulator start/completion/stop lifecycle: **PASS**
- Android profile APK: **PASS**, artifact uploaded
- Android APK SHA-256: `20b4d1d7d5f30252b7510fccd827d3fcad657bc08abad4d1331acf1a60d8f40d`
- iOS profile compile without codesigning: **PASS**

These records reduce implementation uncertainty but do not close R7-06/P9 physical-device evidence.

## Physical device records

| Class | Required evidence | Status |
| --- | --- | --- |
| D1 | Real iPhone: Native Speech QA callback PASS, audible Turkish voice, safe-area/orientation, smooth input/motion, accessibility/performance evidence | NOT_RUN |
| D2 | Representative mid-range Android: same checks + benchmark evidence | NOT_RUN |
| D3 | Lower-end supported Android: same checks + benchmark evidence | NOT_RUN |

A simulator, browser, screenshot or CI build must never be promoted to a physical-device PASS.
