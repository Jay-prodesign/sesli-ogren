# CURRENT HANDOFF

## Active bounded evidence program

| Field | Value |
| --- | --- |
| Mission | **ROUND7_COMPANION_RUNTIME_EVIDENCE** |
| State | **ACTIVE — P9 NON-PHYSICAL TECH CLOSURE / FOUNDER VISUAL GATE PREP** |
| Executor | ChatGPT as Founder-authorized bounded engineering delegate; Claude may resume after fresh-read |
| Product | Sesli Öğren / Learning App |
| Branch | `feat/round7-companion-production-sequence-v2` |
| Delivery | Draft PR #8, stacked and unmerged |
| Purpose | Close the admitted Round 7 non-physical companion/runtime evidence, honor D-068 final-install sequencing, and reach the Founder Product/Visual gate without admitting M2/Golden Learning Slice implementation |
| Current result | Synthetic visual/layout/motion QA PASS; Android profile build PASS; iOS no-codesign compile PASS; iOS native flutter_tts simulator lifecycle PASS; one-tap Native Speech QA ready; blink rejected/removed; mouth warp PASS |
| Remaining gate | Exact-head PR #8 CI + Founder Product/Visual PASS for pre-M5 admission. Physical iOS/Android audibility/accessibility/performance/orientation is deferred under D-068 to final mobile-readiness before release-candidate/public-release claims. |
| Companion cursor | `docs/agent/ROUND7_COMPANION_CURRENT_CURSOR.json` |
| Companion status | `docs/agent/ROUND7_COMPANION_ASSET_STATUS.json` |

### Authority reconciliation

- Repository Bootstrap is **DONE / BOOTSTRAP_PASS** on sibling draft PR #1.
- Architecture Proof is **DONE / ARCHITECTURE_PROOF_PASS / GO_ADAPT** at reviewed head
  `0327d2e5b854df1c9923c65ed88f77151cfe9eed` on sibling draft PR #2.
- Those sibling PRs remain unmerged; this branch therefore records their accepted outcomes without copying their full task/evidence trees.
- The active Round 7 branch is evidence work only. It does **not** admit the Golden Learning Slice.
- **D-068:** real-phone installation is deliberately deferred until the app is otherwise complete enough for final device/mobile-readiness validation. Physical evidence remains mandatory before release but is explicitly bounded for pre-M5 sequencing.

### Lean execution rule

Do not create new companion art, state-PNG grids, layered rig infrastructure, or generic animation systems while the
current canonical D/E assets satisfy the proof. Reopen those areas only if physical native-device evidence reveals a
specific problem that cannot be fixed locally.

## Staged / NOT EXECUTABLE

| Field | Value |
| --- | --- |
| Handoff | **M5_GOLDEN_LEARNING_SLICE_HANDOFF_NOT_ISSUED** |
| State | **NOT_EXECUTABLE** |
| Gate | Exact-head Round 7 non-physical technical closure + Founder Product/Visual PASS + canonical fresh-read + explicit Brain admission. D-068 bounds physical device/voice/accessibility execution to final mobile-readiness. |
| Rule | No M2/Golden Learning Slice implementation starts from this Round 7 evidence branch. |

## Protected actions

Merge, release, deploy, paid providers, credentials/secrets, production mutation and licensing changes remain Product Owner gates.


## Device execution priority

- **D1 iPhone:** DEFERRED_TO_FINAL_MOBILE_READINESS under D-068.
- **D2 mid-range Android:** DEFERRED_TO_FINAL_MOBILE_READINESS_WHEN_HARDWARE_AVAILABLE.
- **D3 lower-end Android:** DEFERRED_TO_FINAL_MOBILE_READINESS_WHEN_HARDWARE_AVAILABLE.
- The full physical matrix remains mandatory before release-candidate/public-release claims; it is not today's implementation blocker.
- Current executable order: exact-head PR #8 CI → non-install Founder Product/Visual PASS → canonical fresh-read → explicit M5 admission.
