# LA-0040 — Actual Flutter Runtime Treatment Review (2026-10-08)

**Status:** TECHNICAL REVIEW PACK PASS / VISUAL CHANGES_REQUIRED; LA-0039 and LA-0040 remain IN_PROGRESS. No Founder visual sign-off, merge, deploy, release or production treatment selection.

## Examined actual runtime and exact evidence

- Implementation HEAD: `6884a30186d50e7f207b0d9f304d92aa768ea078`, working PR #13 on `feat/full-product-shell-continuity`. Default unscoped production appearance remains unchanged.
- All three Flutter treatments were captured from the same persisted learner/local store, user-provided-style fixed Biology photosynthesis source, actual Recall engine prompt, submitted answer, genuine evidence/state/nextAction. 390 × 844 logical-pixel captures.
- Screens for each lane: Home, Material Workspace, Recall prompt, Recall result. **12 real Flutter images** in the `la0039-visual-review` artifact of [capture run 37746170869](https://github.com/Jay-prodesign/sesli-ogren/actions/runs/37746170869). Each comes from the same action navigation (Home→Workspace→Recall) rather than isolated static concepts.
- Test additionally traverses the same learner/material's **unknown** and **hinted-correct** attempts; actual stored evidence is asserted, and both must not display unaided success. Stale AnimatedSwitcher phase identities surfaced as a real runtime failure on an earlier attempt; corrected by attempt+phase-specific switcher keys and retested in the successful capture run.
- Exact-head CI: [product bounded 37746178036](https://github.com/Jay-prodesign/sesli-ogren/actions/runs/37746178036) **SUCCESS**, [bootstrap 37746177990](https://github.com/Jay-prodesign/sesli-ogren/actions/runs/37746177990) **SUCCESS**, [account deletion 37746178004](https://github.com/Jay-prodesign/sesli-ogren/actions/runs/37746178004) **SUCCESS**, visual capture **SUCCESS**. No Flutter analyzer/format issue remains at this examined HEAD.

## Qualitative first-view comparison — no invented user scores

| Lane | What real captures support | Critical visual shortfall | Direction |
| --- | --- | --- | --- |
| EDITORIAL | Readable, calmer page and source; little nested-card texture; primary action stays identifiable | Looks like a respectable generic notes/document app; weak student desire, brand memory and experiential payoff; too typographic | **HOLD** as calm readability reference, not winner |
| STUDIO | Strongest immediate dominant action; active study stage and clear next action; real persisted Recall result is legible; source text now highlights the exact canonical answer | Dark rounded action panel remains a generic component; D/Knot often still appears as a sticker, and source/action/result do not yet form one exceptionally memorable learning moment | **PRIMARY REFINEMENT LEAD**, hypothesis only |
| KNOWLEDGE | Source/state/next-action rails visibly express provenance and truth; canonical answer is highlighted inside real source excerpt | Repeated dense text makes first-glance feel like an explanatory dashboard; need stronger information design without inventing a concept graph or learning relationships | **SELECTIVE BORROW** from source-grounded proof, not winner |

The comparison **does not** justify declaring any lane world-class or Founder approved. Prefer one bounded Studio-led refinement with Knowledge's grounded answer proof, then reassess actual screenshots instead of multiplying UI treatments.

## Experience Fidelity / Visual Gate verdict

- **Q0 Spec admission:** PASS. Detailed corrective task spec, error cases, evidence and rollback in `docs/exec-plans/LA-0040_FOUNDER_FAIL_REWORK_SPEC.md`; project-level task admission standard updated.
- **Q1 Engineering + 12 comparison captures:** PASS on exact HEAD, but these tests do not prove perceived quality. Existing default behavior remains intact without review scope. Real navigation and source-grounded answer/unknown/hint checks exercised.
- **Q2 Learning truth:** PASS for the exercised independent/unknown/hinted paths; incomplete for answer-exposed/incorrect/partial and stale-version adversarial cases in this candidate-specific UI. Canonical learning engine's separate regression coverage is not the same as verifying every presentation outcome.
- **Q3 Visual desirability and 3–5s identity:** **FAIL / REWORK.** Every lane remains too generic and text-heavy. Studio is relatively strongest but still fails the signed-off commercial design bar. Visual PASS is not inferable from screenshot generation.
- **Q4 Stress / access:** PARTIAL. Existing previous visual baseline stress (narrow viewport, 1.3× / 1.5×) is not sufficient proof for new candidates. Need 320px, longer real source, real long Turkish text, keyboard/touch reachability and Reduced Motion on chosen candidate. Physical iOS/Android remains D-068 release gate.
- **Q5 Founder:** EXISTING FOUNDER VISUAL FAIL; no new approval requested or recorded. No final companion/visual lock.
- **Q6 Fresh learner / 7-30 day return / creative economics:** NOT RUN. Do not report plausible results as user findings.

## Next actual implementation cursor, not an audit treadmill

1. Focus Studio R5 only while retaining Editorial/Knowledge as reversible benchmarks. Make material→recall→grounded-result feel like one memorable source-specific experience rather than four polished yet detached screens; put D/Knot in an earned learning function, not as a decoration. Preserve bounded success/assistance semantics.
2. Upgrade representative study material beyond the tiny 20-word photosynthesis fixture using a legitimate longer source, then review real device-width screenshots. Do not fabricate source-linked conceptual relations or progress to make screens attractive.
3. Execute candidate-specific negative truth+stress/reduced-motion tests at the smallest sufficient coverage, record actual flaws and fix. Then conduct true human 3–5s/60s/continuation observation before product-level visual PASS. Need a real phone before release as already required; not now by default.
4. Present actual *revised* candidate to Founder for protected visual disposition; expand to unrelated app surfaces only after direction earns it.

**Scope and provenance:** No Visual Intelligence source code, assets, project decision authority, or protected expression was copied. Only reusable experience methodology influenced the locally implemented comparison. No speculative engine, provider or new commercial dependency introduced.

