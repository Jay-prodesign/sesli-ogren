# LA-0040 / LA-0039 — Founder FAIL Rework Task Specification

Status: ACTIVE / IN_PROGRESS / PRE-FOUNDER FAIL. This is a controlling extension of LA-0040, **not a new task ID**.
Date: 2026-10-08
Authority: Founder visual FAIL; Learning App D-054, D-068, D-073, D-074, D-075, D-076 and CMD-0002. Other projects consulted only as read-only methodology.
Applies to: PR #13, Flutter app, Home → Workspace → Recall prompt → Recall result; coupled LA-0039.

## Need and actual user outcome
The current running app looks too generic, relies on nested cards and explanatory text, and does not create a strong learning-payoff moment. Student should recognize the material, the truthful current learning state, and a dominant next action in seconds, then complete a real source-grounded Recall and understand what changed, without false mastery.

## In scope
1. Compact experience fidelity contract with observable first 3–5s, 30s and prepared-source 60s traces.
2. Three **substantively different, Flutter-runtime** visual treatment candidates: EDITORIAL (typography and open document plane), STUDIO (immersive action stage and restrained motion), KNOWLEDGE (source-bound causal thread). Same selected material, source, learner state and callbacks; same 390×844 logical-pixel phone captures; four stages per treatment.
3. Canonical source-to-question-to-result-to-next-action presentation. Create one meaningful signature payoff (not unsupported celebration).
4. Deterministic runtime screenshot protocol; adverse outcomes; accessibility and responsive checks.
5. Founder review and bounded follow-through on the selected treatment. No automatic winner from scores.
6. Production quality asset anchor and scoped real-user tests after a candidate direction passes structural and perceptual comparison.

## Out of scope
New learning modes, knowledge graph invention, invented summaries or diagrams, fake concept counts, mastery percent, XP/streaks, general-purpose design engine, new character identity, new provider, new dependencies without approval, production releases, deploy, merge, secrets or cross-project code/assets.

## Immutable inputs and dependencies
- MaterialRecord and active SourceVersion reflect the learner-owned material, never a sample masquerading as their content.
- ExtractedContentRecord normalized source text supplies any displayed actual source.
- LearningContinuation state.kind determines labels; nextAction.reasonText supplies the next recommendation rationale.
- RecallPrompt.promptText from the real RecallLearningService; no constructed answer is shown before commitment.
- RecallAttemptResult outcome, assistance, correctAnswer, sourceExcerpt, state and nextAction are sole authority after submission.
- Passive listening must not increase knowledge mastery. D/Knot visuals must not create evidence.
- Existing state/persistence/security logic and release-device gate remain unchanged.

## Subtasks and acceptance
R1 — Fidelity contract: explicit product promise, context/commit/feedback/repair/resume chain, safe failure and recovery, observable screenshot and 5–10-second runtime clip. REJECT any fictional capability.
R2 — Visual candidates: Home, Workspace, Recall prompt, Result are working widget trees for all three treatments with real store data and original tap actions; no treatment simply recolors another. Baseline UI stays unchanged when review scope is absent.
R3 — Runtime capture: capture 12 named images (three lanes × four stages) using deterministic seeded in-memory repository and an identical Biology/Fotosentez source; verify consistent text, correct independent outcome, visible next action. A longer actual study source is separate stress input.
R4 — Functional QA: Flutter format/analyze, bounded widget/test run, exact-heading navigation, real Recall submit, next-action transition, persistence; answer-exposed / hint / unknown / incorrect / partial must never imply unaided success.
R5 — Resilience QA: 320px and 390px widths, long Turkish material name, lengthy source passage, 1.3x and 1.5x text scale, active keyboard, scroll/touch reachability, high contrast, Reduced Motion (no semantic loss), empty source/retry.
R6 — Perceptual QA: compare captures plus actual transitions (no source-only design PASS), reject generic card-template, childish disconnected companion, weak source/action hierarchy or unreadable result, even if average score passes.
R7 — Decision: current internal VQG PASS is historical only. Present candidate runtime evidence to Founder for explicit APPROVE / CHANGES_REQUIRED / REJECT. If approved, implement on wider product surfaces only as required and run a refreshed visual QA pack.
R8 — Human + release evidence: small 5–8 person uncoached user protocol tests comprehension, result accuracy, spontaneous continuation, replacement reason and return intent. Do not call this market proof. Physical iOS and Android remain mandatory under D-068 for release.

## QA types and evidence required
- Task static: format, analyze, focused tests, review harness compilability; capture test logs with tested commit SHA.
- Truth/security: source identity, isolation, help-used evidence, no fake mastery, callback continuity, no destructive migration.
- Negative outcomes: hint; exposed answer; unknown; incomplete and incorrect answers; stale/missing material; no material (first run); long text; lack of source; interrupted flow.
- Visual: 12 pairwise comparable PNGs + real motion review or label not-tested; no internal CI score used as aesthetic proof.
- Usability/accessibility: color contrast, touch reach, semantics, long Turkish strings, text scaling, Reduced Motion.
- Founder: explicit current-runtime visual disposition; unresolved HIGH/BLOCKER prevents DONE.
- Release only later: real-phone TTS, accessibility, layout, performance, platform testing and live auth remains open.

## Severity and gate outcomes
BLOCKER: fake correctness/mastery, evidence/state change from styling, wrong source, callback dead-end, data leak, protected action.
HIGH: generic template appearance, missing desired first action/payoff, poor Companion integration, visual competition only colors, unreadable/clipped primary interaction.
MEDIUM: bounded typographic/palette adjustment, one non-critical spacing issue. LOW: cosmetic small fix.
Task gates use **FAIL/REWORK**, **CONDITIONAL / HOLD**, **PASS** only after the relevant evidence; no positive score overrides BLOCKER or HIGH.

## Exit and rollback
- **Review-ready**: three real Flutter variants plus 12 verified captures and focused static/widget tests; not a Founder PASS.
- **Visual direction selected**: explicit Founder approval of a runtime treatment and acceptable production asset direction; not full product completion.
- **LA-0040 DONE**: coherent selected direction through needed consumer surfaces, all scoped QA and Founder lock, LA-0039 reconciliation. Without real evidence, label DEFERRED, not PASS.
- Rollback by removing the optional LearningVisualTreatmentScope/candidate wiring; keep current source/learning state and production UI unchanged.
- No new LA task IDs unless scope proves independent and material; when admitted every task requires objective, dependencies, edge cases, acceptance, appropriate QA and DONE proof before implementation.

Linked: docs/design/LA-0040_EXPERIENCE_FIDELITY_CONTRACT.md, docs/qa/LA-0040_VISUAL_QUALITY_GATE.md, docs/agent/commands/CMD-0002.md.
