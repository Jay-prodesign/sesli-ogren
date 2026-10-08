# ACTIVE LA-0040 SOURCE STAGE — IMPLEMENTATION QA GATE (2026-10-08)

**Status:** SPECIFICATION ACCEPTANCE CRITERIA DEFINED / **NOT EXECUTED**. This section supersedes only earlier *how-to-implement* candidate tournament directions. The prior Editorial/Studio/Knowledge visual FAIL is unchanged. Implementation hypothesis: [LA-0040_SOURCE_STAGE_INTERACTION_IMPLEMENTATION_CONTRACT.md](../design/LA-0040_SOURCE_STAGE_INTERACTION_IMPLEMENTATION_CONTRACT.md). No selected winner and no claimed new visual PASS.

**Decision model:** Task Spec Quality PASS → build bounded source-first Flutter interaction → exact-head focused technical tests + real visual evidence → independent visual/perceptual review → protected Founder approval. A missing proof is UNVERIFIED, not PASS. An unresolved BLOCKER/HIGH fails regardless of average score.

## Q0 — Mandatory SPEC gate (before further implementation)

- Contract explicitly identifies learner journey S0–S5, real data authority (`MaterialRecord`, `SourceVersionRecord`, `ExtractedContentRecord`, `RecallPrompt`, `RecallAttemptResult`, `LearnerEvidence`, `LearnerState`, `NextLearningAction`), exact screen/route changes, realistic source display, privacy, rollback, visual grammar, transitions, edge cases, human judgment. Current source contract provides this content, but **feasibility check must verify actual files/fields before coding**.
- No unsupported original PDF rendering, invented page layout, source-selection→question generation, persisted raw answer, fabricated mastery, character redesign, new provider/framework, app-wide makeover or source authority change.
- Gate outcome: **SPECIFIED / PENDING FILE-LEVEL FEASIBILITY CHECK**. Do not call it implementation-complete.

## Q1 — Functional Flutter journey (engineering, automatable)

| ID | Real interaction to test | Exact observable expected behavior | FAIL criterion |
| --- | --- | --- | --- |
| F01 | Existing imported material opens Home → Workspace | Current authorized title, source type, actual normalized text; scroll and one recall action work; other product routes still available | Placeholder/fictional material, mode grid dominates, wrong source or unreachable action |
| F02 | Start Recall after reading | Current learner/source's `RecallPrompt` opens; expected answer and source clause are not visible; keyboard and support actions reachable | Source leak before answer, fake user-select-generated prompt |
| F03 | Submit unaided correct answer | Exactly one canonical evidence/result persists; one retrieval, never mastery; actual correct answer + matching source excerpt displayed; next action reason from persistence | UI-created evidence, made-up score, wrong anchor or premature success |
| F04 | Tap continuation, exit/reopen | Persisted next action and learner/material continuity restored; raw typed response not invented on fresh session | Navigation dead end, missing state, replayed imaginary answer |
| F05 | No imported material, import failure or missing/stale source | Honest intake, safe error/retry or source repair; no cross-learner material contamination | Fictitious sample content claimed as user-owned; stale version silently used |
| F06 | Old production UI without review opt-in | Existing Home/Workspace/Recall/Listen/Explain/Focus/etc work unchanged | Default visual unexpectedly changed, modal callbacks broken |
| F07 | Primary button while busy, repeated submit, close/reenter | Disabled duplicate operation; canonical attempt/evidence idempotence; recoverable return to active attempt | Duplicate learning evidence, data loss or stuck loading |

## Q2 — Truth, privacy and adverse outcomes (hard BLOCKERS)

| ID | Input/path | Required result |
| --- | --- | --- |
| T01 | Unknown / `Bilmiyorum` | No independent success; acknowledge no answer and use canonical next action. |
| T02 | Hint then correct | Display **helped correct** and assistance, not unaided retrieval. |
| T03 | `Yanıtı göster` then submit | Mark **answer exposed**, never label the prefilled answer as the learner's independent response. |
| T04 | Incorrect and partial | Accurate corresponding canonical outcome; no generic celebratory victory. |
| T05 | User typed answer visible in result in SAME mounted session | It is only transient UI data. It is NOT duplicated to analytics, persistent profiles, local events or replayed after restart. Unknown/revealed variants must be labelled distinctly. |
| T06 | Source anchor missing/out of bounds, source version changes | No false source-highlight; fall back to plain excerpt when valid or honest no-reference error. No answer from another source/version/learner. |
| T07 | Passive listen or character animation | No mastery/readiness/evidence changes. |
| T08 | App interruption, fresh result restoration | Only durable authorized evidence, state and next action resume. Do not pretend transient response was persisted. |

Any incorrect outcome/provenance/assistance handling = **BLOCKER**, even if visuals otherwise impress.

## Q3 — Visual architecture and signature payoff (mandatory human+runtime)

- **V01 Composition break:** new workspace cannot be described mainly as heading→explanatory copy→large colored card→CTA. The source is the dominant readable work surface; compact material identity and action relationship are visible without a wall of introductory prose.
- **V02 Learning action legibility:** at initial glance, a first-time learner can locate their actual source and a meaningful Recall action. Prompt concealment and grounded post-answer reveal communicate source→attempt→feedback in motion, not mere page change.
- **V03 Earned feedback:** without name/logo, the result screen shows a truthful meaningful relationship between typed response/assistance, literal source anchor and specific next action. A still image and reduced-motion version also work.
- **V04 Character integrity:** D/Knot contributes to relevant action or is absent. Pasted/stretched low-quality mascot art = HIGH.
- **V05 Production craft:** no huge unused void coupled with a giant text block, inconsistent app chrome, arbitrary nested card family, generic AI-app marketing gradients, stretched source excerpt, duplicated headings or visual reliance on labels; strong typographic rhythm across all states.
- **V06 Independent comparator:** display a same-viewport side-by-side of previously rejected screen(s) and candidate real Flutter screens; a credible reviewer can state a **structural** difference rather than palette/typography changes. Original product/user values remain.
- **V07 Signature only where truthful:** source-fold and anchored reveal reflect actual on-screen state. If new design looks conventional/generic even after source integration, **RETURN TO DESIGN**, not auto-pick Studio or randomly iterate colors.
- **Evidence:** actual Flutter screenshot at 390px, 5–10s route interaction clip where possible, inspect in context (keyboard/source scroll/transition) and record observed deficiencies. Unit tests do not automatically PASS V01–V07. Founder review stays FAIL until explicit new judgment.

## Q4 — Mobile resilience, accessibility, and asset fidelity

| ID | Exact test | Threshold / PASS evidence |
| --- | --- | --- |
| A01 | 390×844, 320×~700 mobile logical sizes and real long Turkish material title | Source remains readable, all core actions accessible by scrolling, no visual clip/RenderFlex overflow |
| A02 | 1.3× and 1.5× text scale on source, Recall and result | Complete question, typed answer, support actions, source proof and next action reachable; no fixed-height clipping |
| A03 | >=5,000-char authorized source with newlines, Turkish I/İ/ı/ş/ğ and PDF normalized text | Scroll responsive, source version/anchor correct, no fake original PDF pages or unverified derived summaries |
| A04 | Keyboard open, safe-area, screen reader semantics/focus order, back navigation | Submit/unknown/hint/support remain discoverable, no source behind active unaided prompt, no obscured focused input |
| A05 | Color contrast and touch | Normal text ≥4.5:1, large text ≥3:1, meaningful UI non-text contrast ≥3:1; target interactive regions **designed** ≥44–48 logical px when feasible; labels do not rely solely on color (based on WCAG 2.2 concepts) |
| A06 | Reduced Motion / no-animation setting | State semantics, source conceal/reveal and focus remain clear; no motion-only explanation |
| A07 | Actual D/Knot asset or other signature asset | Confirm repo license/provenance, resolution, states, integration and contextual QA. Generated/reference art by itself = NOT production ready |
| A08 | Dynamic source update, missing excerpt, very short source and selection/copy | Honest empty/fallback/warnings; no crashes, content leakage or misleading source highlight |

Physical iOS and Android device/speech/performance/voice accessibility are **separately required before release under D-068**. Simulator/widget screenshots cannot waive them.

## Q5 — Evidence-backed first-user comprehension and independent product review

- With a genuinely usable runtime, recruit an initially small **n=5–8 uncoached priority-segment** group. Show 3–5s Home/reader exposure, ask them to name the material and next action **without prompting**, observe first tap, source→Recall→result within a prepared-material 60s target, ask what feedback means and why they might return. Record actual utterances, hesitations, errors and observed steps, not synthetic survey numbers.
- If two or more in a five-person initial sample cannot identify the material/action, or multiple repeat the same critical misinterpretation of assisted evidence, treat as **REDESIGN**, not a “passing average”. Low n is formative evidence, not a statistically reliable retention/conversion forecast.
- Blind competitive/product-fit check: describe new screenshot with branding concealed; is the source-based *reason to use this over a generic summary/audio app* perceptible in action and supported by the real build? Avoid claimed “unique” features without actual comparison.
- Founder must personally ACCEPT/CHANGES_REQUIRED/REJECT the **actual updated runtime**. No design concept, README, percentage, internal automated score or this document substitutes for that protected decision.

## Q6 — Completion, fail path, and exact status

- **SPEC Q0:** authored; feasibility verification pending.
- **ENGINEERING Q1 / TRUTH Q2 / VISUAL Q3 / STRESS Q4 / USERS Q5:** all **NOT RUN** for the *new Source Stage hypothesis*. Previous code-run PASS belongs to rejected treatment prototypes and remains only an engineering baseline.
- **LA-0040 DONE:** only after Q0–Q5 applicable gates, explicit Founder visual approval, selected experience applied to required consumer surfaces and LA-0039 reconciled. D-068 final physical-device/release checks remain separate.
- **Recovery:** if Q3 FAIL, do not polish buttons/colors; return to interaction contract and revise the real source→Recall→feedback behavior. Discard candidate by removing opt-in review wiring; preserve store/evidence schema and baseline routes.

---

> **ACTIVE 2026-10-08 FOUNDER SECOND FAIL — STRUCTURAL REJECTION:** Founder reviewed the latest real Flutter 12-screen packet and **rejected Editorial, Studio and Knowledge altogether.** Any previous "Studio refinement lead", "three meaningful UX variants" or future intent to select among them is superseded. Status of LA-0040/LA-0039 = **DESIGN FAIL / IN_PROGRESS**. Technical CI/capture success remains historical technical PASS only. The controlling new acceptance is not better colors or labels; it is a distinct source-centered, interaction-first learning experience.

### Immediate hard FAIL gates for next LA-0040 visual work

1. **Same skeleton**: Home/Workspace/Recall/Result are still primarily heading→body text→rectangular card→CTA, even if colors, sizes, typography or decoration change.
2. **No perceptible study action**: user only navigates pages while meaningful source work, attempted recall or comparison is not felt as an interaction.
3. **No material hierarchy**: source title/material text is a small incidental content field rather than the real object of the work.
4. **No earned visual payoff**: outcome looks like generic success copy and a next button; visual comparison/feedback has no credible, observable consequence.
5. **Mascot pasted-on**: D/Knot simply fills empty space or adds charm, with no useful role/relationship to learning state. Omit where not relevant; no unauthorized redesign.
6. **Prototypical layout**: awkward unused mobile area, unbalanced dense copy, mismatched navigation/chrome, unreadable hierarchy, overly generic presentation.
7. **Untruthful aesthetics**: fabricated progress, mastery, source maps, points, motivational promise or icons unsupported by canonical evidence.

**Admission/spec gate:** use the bounded revised LA-0040 second-FAIL task spec (S1–S7); do not create another task or a fourth color treatment. **Implementation gate:** prove interaction through actual Flutter behavior using learner-owned source + canonical Recall outcome, with 320/390px, long real Turkish material, text scaling, keyboard, unknown/hint/reveal/error and reduced-motion paths. **Human gate:** original Founder visual FAIL stands until Founder explicitly approves a new runtime, regardless of test scores or reviewer rankings.

---

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
