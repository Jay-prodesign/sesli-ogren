# Learning App V0 — Product architecture and production order
Status: implementation contract; preserve existing product truth, source/evidence semantics and backend contracts. This document supersedes historical screen-driven visual experiments for task selection, not functional code.

## Canonical learning loop
MATERIAL / INTENT → UNDERSTAND / CONSUME → ACTIVE LEARNING → LEARNER EVIDENCE → TRUTHFUL FEEDBACK → NEXT USEFUL ACTION → RESUME / RETURN.

No listening, reading, completion animation or AI prose alone establishes mastery. Current Flutter file boundaries are implementation history, not UX authority.

## Complete product and state map
Each row defines learner question; primary job; regions/blocks; required truth; actions and destination. States are contextual, not all valid for every screen.

| Screen | Learner question and primary job | Regions / blocks | Truth and states | Actions → next |
|---|---|---|---|---|
| First run / account entry | How do I begin safely? Authenticate and establish ownership | identity, account entry, privacy/recovery | signed out, loading, failed, interrupted | sign in → Home; recovery → entry |
| Empty Home | What can I learn from? Begin with a real source | source intake, concise explanation, account nav | zero accessible materials, loading, offline/error | PDF/paste → acquisition |
| Returning Home | Where was I and what is useful next? Continue | active material, real continuation, one next action, recent sources | persisted material/version/continuation; stale, loading, interrupted | resume → Workspace/Reader/Recall; library → Library |
| Source acquisition | How do I add my material? Obtain source | PDF picker, paste input, limits, submit | real bytes/text, ownership, constraints; empty/invalid/offline | import → processing; cancel → Home |
| Import processing / error | Did my source become usable? Recover honestly | processing status, typed failure, retry/text fallback | no material on failed ingest; oversized, image-only, parse, interrupted | success → Workspace; retry/fallback → acquisition |
| Material Workspace | How will I study this source? Center the source | material identity/version, source preview, contextual study actions | material + current SourceVersion; updated/stale/offline | read → Reader; listen → Listen; recall → Recall |
| Reader | What does the source actually say? Consume | provenance masthead, selectable real text, position, contextual action | normalized source text, version, persisted position; empty/unavailable/updated | recall → Recall; return → Workspace |
| Listen | Can I consume this source by ear? Listen without implying learning | source identity, playback, transport, resume | source-bound audio and playback position; loading/unavailable/interrupted | pause/resume; recall → Recall; Workspace |
| Recall | Can I retrieve without seeing the source? Commit evidence | prompt, source-hidden attempt input, unknown/hint, commit | current prompt/source version; unassisted, hinted, unknown, interrupted | submit/unknown → Result; back → Workspace |
| Recall Result | What did I say versus what does source say? Interpret | attempt, source evidence, grounded interpretation, next action | committed LearnerEvidence, source excerpt/version, correct/partial/incorrect/unknown/hinted/unavailable | justified next → Reader/Recall/Workspace |
| Focus | What should I work on now? Bound attention | source-bound focus target, session controls, exit | actual session state; interrupted/unavailable | finish/exit → Workspace |
| Quick Recap | What should I review quickly? Source-grounded recap | material identity, bounded recap, provenance, follow-up | source-bound generated content, loading/error, version invalidation | read/recall → Reader/Recall |
| Explain | What does this passage mean? Clarify with provenance | selected source, explanation, source relation | source-bound explanation; unavailable/partial context | return source → Reader; test → Recall |
| Explain-back | Can I explain it in my own words? Commit explanation | prompt, response, evidence feedback, follow-up | committed response and evaluator state; assisted/unknown/error | result → grounded feedback; Recall/Reader |
| Library | Which materials do I own? Reopen | search/list, source identity, recency, empty/error | owned material/version; loading/offline | select → Workspace; add → acquisition |
| Progress | What evidence of learning exists? Review | evidence history, source context, honest summary | persisted LearnerEvidence/LearnerState only; empty/stale/error | reopen → Workspace/Result |
| Profile | Who am I here? Manage account | identity, usage/settings/data links | authenticated account; loading/error | account/settings/usage/data |
| Account/settings/usage/data | What can I control and what is used? Account safety | preferences, verified limits/usage, export/delete/sign-out recovery | backend-authenticated values, no invented limits; offline/error/confirmed destructive outcomes | save/return → Profile; sign out → Entry |

### Cross-cutting state applicability
- **loading / empty / unavailable / offline / server-failed**: any data-dependent surface where applicable; never substitute fabricated source or progress.
- **stale-source / updated-source**: Workspace, Reader, Listen, Recall, Result, recap, explain, explain-back and continuation; retain historical evidence but invalidate source-bound active work as required by canonical contracts.
- **interrupted / resumed**: import, consumption, active learning and continuation where persistence permits; never claim resumed if no persisted cursor.
- **hinted / unknown / answer-exposed / incorrect / partial / correct**: Recall/Result and corresponding evidence displays only; exposure or assistance must never be labeled independent retrieval.
- **answer-exposed** is a post-commit result condition, never an active Recall presentation.

## Screen contract schema
Every implementation screen specifies SCREEN → LEARNER QUESTION → PRIMARY JOB → REGIONS → BLOCKS → DATA/LEARNING TRUTH → STATES → ACTIONS → NEXT SCREEN. Rows above are minimum contracts; region and block hierarchy below governs composition.

## Block trees and shared shell
All surfaces: background/surface → shell/navigation → primary learning region → supporting regions → blocks → content/data slots → actions → overlays/states.

- Home: shell → active material/empty intake → genuine continuation + primary next action → recent material destinations → navigation.
- Workspace: shell + source identity/version → **real source stage** → context-dependent learning actions → source update/recovery.
- Reader/Listen: source masthead → text or audio primary stage → transport/position → optional contextual active-learning action.
- Recall: source identity (without answer) → prompt → hidden-source attempt → hint/unknown/commit → interruption recovery.
- Result: committed attempt → **exact source evidence and version** → bounded interpretation → justified next action → return.
- Library/Progress: owned materials/evidence as primary content, not decorative KPI cards.
- Utility: authenticated identity/data controls, safe confirmation and recovery.

Global shell: stable Home/Library/Progress/Profile destinations where appropriate; context-specific back and source masthead within study flows; one dominant action per state; reusable type scale, spacing, accessible touch targets, sheets/dialogs, loading/empty/error and reduced-motion grammar. Pulse / Focus / Signal Aqua / Volt are global semantic roles, never screen-specific decorative themes. D/Knot is a contextual feedback slot, not a replacement for source evidence.

## Learning block truth contract
For each important block record: block_id, learner_question, source_data, source_version_requirement, learner_evidence_requirement, allowed_claim, forbidden_claim, visual_role, interaction, success_state, hinted_assisted_state, unknown_error_state, next_action.

| block_id | source / evidence requirements | allowed / forbidden claims | visual role and states | next |
|---|---|---|---|---|
| home.continuation | persisted material, current version and continuation | show real resumable action / never invented lesson progress | dominant live material; empty/stale/recovery | Workspace/Reader/Recall |
| reader.source | actual normalized source and version | source text only / no fabricated headings or PDF layout | primary selectable reading plane; unavailable/updated | Recall/Workspace |
| recall.attempt | current source-bound prompt; no source shown until commitment | record answer/hint/unknown / never infer mastery from intent | focused prompt and input; hinted/unknown/interrupted | Result |
| result.comparison | committed attempt + exact source excerpt/version + canonical evaluation | bounded correct/partial/incorrect/unknown/hinted claim / no unsupported mastery | spatial attempt↔source comparison; unavailable evaluation stays unresolved | reasoned Reader/Recall/Workspace |
| progress.evidence | persisted learner evidence and state | historical evidence with assistance/version context / no fake score or streak | factual history; empty/stale | source or result |
| companion.feedback | canonical evaluation state and D/Knot asset slot | earned encouragement or unresolved state / never falsely celebrate error | subordinate emotional feedback; reduced motion | next grounded action |

## Four separate production concerns
A. Product shell: navigation, typography, common controls, overlays.
B. Learning interactions: reading, listening, retrieval, explanation.
C. Learning truth/data: Material, SourceVersion, LearnerEvidence, LearnerState, continuation.
D. Identity/assets: canonical D/Knot, iconography, motion. New assets require SCREEN → BLOCK → STATE → EXPERIENCE ROLE → SLOT; source title/text/excerpt/version and learner attempt are primary visual assets.

## Golden Journey acceptance
Empty/Returning Home → add/open actual PDF/text → Workspace → Reader → source-hidden Recall → user commits answer (including unknown/hinted semantics) → source-grounded Result with exact evidence and truthful classification → reasoned next action → Home/resume. Verify current source version, recovery and persistence; never display source during active retrieval or imply mastery from consumption.

## Production dependencies
1. Validate screen map against actual routes and backend contracts; preserve working behavior.
2. Implement one global shell and independently renderable screen families, without generic framework rewrite.
3. Complete golden journey end-to-end; verify real Flutter render + functional truth.
4. Extend source, consumption, active-learning, evidence, retention and utility families.
5. Place Focus/Quick Recap/Explain/Explain-back only at justified learner needs.
6. Production polish and milestone QA. No merge, release, deploy, spend or destructive data action without authorization.

Task selection: highest-priority incomplete learner journey → required screen → missing contract/block/data state → component/asset → implementation → rendered/functional verification → next dependency. P0/P1 truth, privacy/security, data loss, crash and broken navigation can interrupt.
