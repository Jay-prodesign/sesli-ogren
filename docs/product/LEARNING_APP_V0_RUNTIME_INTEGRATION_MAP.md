# V0 screen-to-runtime integration map

This is the implementation bridge for [LEARNING_APP_V0_PRODUCT_ARCHITECTURE.md](./LEARNING_APP_V0_PRODUCT_ARCHITECTURE.md), not authority derived from old Flutter layouts. Source of truth: current branch feat/full-product-shell-continuity, PR #13.

| Learner surface | Existing runtime entry / owning implementation | Integration requirement |
|---|---|---|
| Account / first run | sesli_ogren_app.dart; account_entry_screen.dart; first_run_onboarding.dart | Authentication and safe runtime opening before Home |
| Empty / returning Home | product_shell_screen.dart; living_study_desk_home.dart | Separate empty intake from genuine material continuation; one dominant action |
| PDF / pasted text and processing | learning_slice_screen.dart; source_ingest_service.dart; pdf_text_extractor.dart | Preserve typed ingest failures, source ownership and text fallback |
| Workspace | material_workspace_screen.dart | Real source and current version before secondary tools |
| Reader | source_reader_screen.dart | Selectable real normalized text, saved position, contextual Recall |
| Listen | listen_screen.dart | Playback/resume is consumption, not retrieval evidence |
| Recall and Result | learning_slice_screen.dart; recall_learning_service.dart | Keep source hidden until commitment; canonical evidence before outcome |
| Focus | focus_screen.dart | Source-bound focus with explicit return |
| Quick Recap | quick_recap_screen.dart | Source version and duplicate-generation safety |
| Explain | explain_screen.dart | Bounded source-grounded explanation |
| Explain-back | explain_back_screen.dart | Assisted/evaluator/unavailable distinctions |
| Library | product_shell_screen.dart | Owned sources and reopen |
| Progress | progress_surface.dart | Evidence-backed state, never inferred mastery |
| Profile/account/usage/data | profile_surface.dart; account gateways | Authenticated limits, recovery, deletion/sign-out boundaries |
| Product identity/shell | app_theme.dart; companion_view.dart; product_shell_screen.dart | Shared navigation, semantic colors, D/Knot tied to truth |

## Current architectural mismatch
- learning_slice_screen.dart owns source acquisition and recall/result phases. This is a historical implementation boundary, not a requirement that these share one screen layout. Decompose only when it improves independent screen rendering without disrupting persisted evidence.
- product_shell_screen.dart owns Home and Library alongside navigation. Extract reusable navigation and material identity presentation only when actual independent family implementation requires it.
- living_study_desk_home.dart, atelier_learning_surfaces.dart and la0040_visual_treatments.dart remain implementation/reference code; do not use historical treatment names as design authority.
- MaterialWorkspaceScreen currently exposes multiple tools. Re-rank based on material state and primary next useful action; do not remove functioning source-bound routes before golden journey parity is verified.
- SourceReaderScreen already protects the real text stage and source-hidden Recall handoff. Preserve this behavior while unifying shell.
- Workspace feedback mapping must never use a correctness-coded D/Knot expression for needsReview; current branch maps it to think.

## Integration sequence
1. Preserve app entry, authenticated ownership and current data contracts; map each route to screen contract and state.
2. Define shared source identity and evidence presentation slots from real Material/SourceVersion/LearnerEvidence values. Do not fabricate text or metrics.
3. Consolidate navigation, recovery, progress and contextual actions in the existing shell without generic framework rewrite.
4. Integrate Home → intake/open → Workspace → Reader → Recall → Result → next action → return/resume as a single testable journey.
5. Validate source-hidden boundary, current-version invalidation, hinted/unknown/incorrect/partial/correct and offline/error recovery.
6. Expand Listen, Focus, Recap, Explain and Explain-back in context; preserve Profile/Library/Progress truth.
7. Render actual Flutter screens, inspect and repair visual/functional problems as one meaningful milestone.

## Explicit non-goals
No new model, mascot, decorative visual tournament, backend schema redesign, new framework, artificial progress, release or deploy. This map does not assert that the runtime integration or QA is complete.
