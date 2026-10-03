# CURRENT HANDOFF

## Active bounded evidence program

| Field | Value |
| --- | --- |
| Mission | **ROUND7_COMPANION_RUNTIME_EVIDENCE** |
| State | **ACTIVE — P9 PHYSICAL NATIVE DEVICE GATE** |
| Executor | ChatGPT as Founder-authorized bounded engineering delegate; Claude may resume after fresh-read |
| Product | Sesli Öğren / Learning App |
| Branch | `feat/round7-companion-production-sequence-v2` |
| Delivery | Draft PR #8, stacked and unmerged |
| Purpose | Close the already-admitted Round 7 companion/runtime evidence without admitting M2/Golden Learning Slice implementation |
| Current result | Synthetic visual/layout/motion QA PASS; Android profile build PASS; iOS no-codesign compile PASS; iOS native flutter_tts simulator lifecycle PASS; one-tap Native Speech QA ready; blink rejected/removed; mouth warp PASS |
| Remaining gate | Physical audibility/Turkish voice behavior + physical Native Speech QA callback PASS + real-device smoothness/input + native safe-area/orientation |
| Companion cursor | `docs/agent/ROUND7_COMPANION_CURRENT_CURSOR.json` |
| Companion status | `docs/agent/ROUND7_COMPANION_ASSET_STATUS.json` |

### Authority reconciliation

- Repository Bootstrap is **DONE / BOOTSTRAP_PASS** on sibling draft PR #1.
- Architecture Proof is **DONE / ARCHITECTURE_PROOF_PASS / GO_ADAPT** at reviewed head
  `0327d2e5b854df1c9923c65ed88f77151cfe9eed` on sibling draft PR #2.
- Those sibling PRs remain unmerged; this branch therefore records their accepted outcomes without copying their full task/evidence trees.
- The active Round 7 branch is evidence work only. It does **not** admit the Golden Learning Slice.

### Lean execution rule

Do not create new companion art, state-PNG grids, layered rig infrastructure, or generic animation systems while the
current canonical D/E assets satisfy the proof. Reopen those areas only if physical native-device evidence reveals a
specific problem that cannot be fixed locally.

## Staged / NOT EXECUTABLE

| Field | Value |
| --- | --- |
| Handoff | **M5_GOLDEN_LEARNING_SLICE_HANDOFF_NOT_ISSUED** |
| State | **NOT_EXECUTABLE** |
| Gate | Controlling Product/Visual + Round 7 physical device/voice/accessibility evidence, canonical fresh-read, explicit Brain admission |
| Rule | No M2/Golden Learning Slice implementation starts from this Round 7 evidence branch. |

## Protected actions

Merge, release, deploy, paid providers, credentials/secrets, production mutation and licensing changes remain Product Owner gates.


## Device execution priority

- **D1 iPhone:** ACTIVE now. Run the physical Native Speech QA + audibility/orientation/smoothness checks.
- **D2 mid-range Android:** DEFERRED_UNTIL_DEVICE_AVAILABLE.
- **D3 lower-end Android:** DEFERRED_UNTIL_DEVICE_AVAILABLE.
- Android unavailability must not block today's D1 evidence work.
- The full R7-06 cross-device matrix remains OPEN until D1+D2+D3 are eventually recorded.
