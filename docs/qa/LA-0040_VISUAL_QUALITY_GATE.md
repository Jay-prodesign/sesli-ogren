> **CURRENT FOUNDER FAIL OVERRIDE (2026-10-08):** Founder rejected the actual LA-0040 runtime screenshot packet. Historical internal PASS remains a record, not visual sign-off. Current external/product gate = **FAIL / CHANGES_REQUIRED**. To repair, apply the explicit acceptance matrix in [LA-0040_FOUNDER_FAIL_REWORK_SPEC.md](../exec-plans/LA-0040_FOUNDER_FAIL_REWORK_SPEC.md), and the rework evidence additions below. No repeat internal score can overrule Founder FAIL.

# LA-0040 Visual Quality Gate (VQG-01)

Status: ACTIVE
Applies to: LA-0040 and final LA-0039 visual disposition.
Decision: FAIL / CONDITIONAL_PASS / PASS / PASS_PLUS.

## Purpose
Prevent a technically correct but visually generic product from being treated as release-ready. This gate measures product desirability, student fit, visual identity, show-don't-tell quality, truthful learning payoff and sustainable craft.

## Automatic FAIL / RETURN conditions
Any unresolved item below fails the gate:
1. **Generic identity** — representative screens could plausibly belong to an unrelated template app after logo/title removal.
2. **Weak 3–5 second impression** — a first-time student cannot quickly perceive a desirable learning product and the next meaningful action.
3. **Prototype-like Workspace** — the main material screen reads primarily as a repeated-card menu instead of a coherent learning environment.
4. **Companion mismatch** — character treatment feels childish, low-fidelity, generic, visually disconnected or competes with learning content.
5. **Over-text / under-visual** — important state/action/payoff is explained mostly through paragraphs when hierarchy, interaction or visual state could show it.
6. **Weak payoff** — a successful active-learning result is not immediately legible, emotionally satisfying and truthfully bounded.
7. **Weak continuation desire** — key screens do not make the next action or reason to return feel concrete.
8. **Accessibility regression** — contrast, text scale, Reduced Motion, touch-target or semantic resilience materially worsens.
9. **Decorative inflation** — visual energy comes mainly from gradients, blobs, illustrations or animation without an experience role.
10. **Unsustainable asset burden** — routine content would require expensive bespoke art without proven user value.

## Scored dimensions
Score each 1–5:
- First-impression desirability
- Clarity / action hierarchy
- Distinctive visual identity
- Student-audience fit
- Emotional energy without distraction
- Show-don't-tell quality
- Learning payoff quality
- Continuation desire
- Trust / seriousness
- Accessibility / long-session resilience
- Companion contribution
- Component / asset scalability

Scale:
1 = structurally poor
2 = visibly weak
3 = adequate but ordinary
4 = strong commercial quality
5 = standout / memorable

## Thresholds
### FAIL
- any automatic FAIL condition unresolved; or
- any critical dimension <3; or
- median <3.5.

### CONDITIONAL_PASS
- no automatic FAIL;
- all critical dimensions >=3;
- median >=3.5;
- bounded P1 polish remains.

### PASS
- no automatic FAIL;
- all critical dimensions >=4 except at most one 3.5-equivalent judgment;
- median >=4;
- Golden Slice feels coherent, intentional and commercially strong.

### PASS_PLUS
- PASS conditions;
- visual identity, student desirability, payoff and continuation are each standout;
- at least one representative screen is memorable without relying on title/logo;
- no obvious structural craft ceiling remains.

Critical dimensions: first impression, identity, student fit, show-don't-tell, payoff, continuation, accessibility.

## Required review sequence
1. Home
2. Material Workspace
3. Recall prompt
4. Recall payoff
5. Listen
6. Explain / Focus
7. Library / Progress
8. Profile + shared states
9. Whole-product Golden Slice

## 3–5 second gate
Reviewer should answer without coaching:
- What kind of product is this?
- What material am I working with?
- What is the most important thing to do now?
- Does it look like a product I would willingly keep on my phone?

## 10 second gate
Reviewer should explain:
- why this is more than PDF/TTS;
- how the app wants them to learn;
- what makes the product feel different;
- what to do next.

## 60 second gate
With prepared material:
- reach one meaningful active-learning action;
- receive a truthful result;
- understand what changed / did not change;
- see one obvious next action;
- feel a concrete reason to continue.

## Show-don't-tell gate
For every important explanatory paragraph ask:
“Could this meaning be shown through state, hierarchy, interaction, visual comparison or progressive disclosure instead?”
If yes and copy is carrying the product, mark for redesign.

## Companion gate
Companion earns its place only if it materially improves one or more:
- warmth
- recognition
- guidance
- feedback legibility
- emotional payoff
- continuity

It must not:
- infantilize the product;
- dominate task content;
- manufacture learning success;
- demand excessive asset production.

Disposition must be KEEP / EVOLVE / REDESIGN / REMOVE.

## High-school student-desire gate
Primary reviewer frame: Turkish high-school learner, grades 9–12 / approx. 14–18.

A passing treatment should feel:
- current and self-chosen, not school-admin/corporate;
- alive enough for a tired teen to re-engage, not noisy;
- encouraging and peer-respectful, not teacherly/patronizing;
- premium, not luxury-formal;
- focused, not sterile;
- expressive, not toy-like.

## Final evidence
- scored current-state audit;
- scored treatment tournament;
- companion disposition;
- stress/red-team report;
- representative winning-treatment visuals;
- no unresolved BLOCKER/HIGH;
- Founder visual disposition.

Founder visual approval is protected and required before DONE.

## 2026-10-08 corrective runtime quality gates

**Q0 — Specification admission:** Every material Learning App task and subtask must have an implementation-ready spec (objective, boundaries, dependencies, exact acceptance criteria, error paths and QA/evidence plan) *before* broader coding. Existing task specs may be extended; never open empty tasks or duplicate QA layers for optics. LA-0040 current rework spec is linked above.

**Q1 — Engineering (hard gate):** Flutter format and analyze, focused widget tests on exact head, 12 real runtime comparison renders (editorial/studio/knowledge × Home/Workspace/Recall prompt/Result), same viewport and exact same learner/source/answer, correct callbacks and source/evidence immutability. Any error = FAIL regardless of visuals. No source code inspection alone passes it.

**Q2 — Truth (hard gate):** initial null/not-assessed state, independent correct, hint-correct, answer-exposed, unknown, incorrect and partial outcomes produce appropriate non-mastery feedback; nextAction.reasonText is the canonical stored text. No fabricated diagrams, source content, counts, percentages, navigation or learning events. PASS requires behavior-level assertions, not copy review.

**Q3 — Real visual distinction:** A/B/C must differ in composition/typographic architecture/relationship of source-to-action-to-payoff, not primarily palette. Score identical screen captures without product name. Repeated nested cards, text wall, generic component kits, unrelated mascot sticker, weak causal payoff or lack of primary hierarchy are automatic HIGH returns even with aggregate score ≥4.

**Q4 — Accessibility, stress and interaction:** 320/390 logical-pixel width, long Turkish titles, 1.3×/1.5× scaling, focused input/keyboard and scroll-to-CTA, touch target reachability, semantics/contrast, Reduced Motion; fail on clipped control, sole-color learning meaning or inaccessible reading order. D-068 physical-device evidence remains a separate release gate.

**Q5 — Founder perceptual lock:** exact-head screenshots plus actual runtime interaction/motion review; Founder explicitly chooses/rejects treatment and companion integration. User evidence may inform; internal VQG PASS or automated screenshot generation is **not** Founder PASS. LA-0040/LA-0039 remain IN_PROGRESS until resolved.

**Q6 — Real users + commercial readiness (later):** uncoached n=5–8 initial small-sample user observation, 3–5s comprehension, first action, prepared-source 60s value, honest result interpretation, spontaneous next action and replacement reason, plus real phone/platform QA before release. No simulated users or screenshots treated as empirical retention/revenue proof.

**QA disposition ledger:** Q0=SPECIFIED; Q1=UNVERIFIED until current exact-head tests; Q2=UNVERIFIED; Q3=UNVERIFIED; Q4=UNVERIFIED; Q5=FOUNDER FAIL; Q6=NOT EXECUTED. Do not mark any gate PASS absent actual evidence. Preserve previous technical PASS independently as previous-head history.
