# LA-0040 — Experience Fidelity Contract (visual rework)

Status: ACTIVE — design hypotheses and executable review rules, **not Founder approval**
Date: 2026-10-08
Authority: Learning App source-grounded learning loop / current D-054, D-073, D-074, D-075 and CMD-0002. Visual Intelligence was consulted READ-ONLY for method only.

## Promise and single dominant action
Student brings their own learning material. The app makes **what to do next** obvious, helps them actively retrieve/explain the material and shows an honest, source-bound result and one credible continuation. Listening is a contextual consumption path, never independent evidence of competence.

One next action dominates each Home/Workspace/result state. Modes are subordinate, not a four-card catalogue.

## Signature causal chain
Own material -> current immutable SourceVersion -> grounded orientation -> next actionable choice -> unaided/supported Recall attempt -> canonical evidence + state -> source-bound result/comparison -> explainable next action -> durable resume.

The visual UI can show the causal chain; only existing canonical backend contracts may write evidence/state.

## Observable first exposure
- 3–5 seconds: without reading paragraphs, identify the active material, current honest state and one action. A student must see more than interchangeable rectangular cards.
- First 30 seconds: enter the actual Material Workspace and recognize how the visible source relates to the proposed action; support vs active-learning alternatives remain easy to find.
- First 60 seconds with a prepared source: reach a real Recall action, commit an answer and see the source-grounded comparison, bounded feedback and actionable continuation. **60 seconds is an experiential review target, not proof that any current device meets it.**
- Next session: the same learner/material and truthful continuation resume. A passive Listen checkpoint must not turn into mastery.

## Golden comparison corpus and invariants
A. Fixed *small* reference fixture: "Biyoloji — Fotosentez Notları" pasted text, existing trusted test corpus, not a fabricated lesson plan or claim of mastery.
B. A separately admitted longer, real source material for information-density and scroll stress; cannot mark accepted without real source/runtime evidence.
All visual lanes must use the exact same source, text, recorded state and callbacks, same phone viewport and text scale. No mock progress, badges, success percentages, invented concept maps, new curricula, fabricated scores or unsupported previews.

## Three mutually distinguishable treatment hypotheses
- **EDITORIAL / PAGE:** spacious typographic source-first layout, paper and ink, minimal linear next-action signposting. Primary differentiator = calm, readable workbench rather than cards.
- **STUDIO / MOMENTUM:** directional dark signature action stage with a clear source -> act -> result visual thread; supporting modes remain compact. Primary differentiator = focused, energetic learning moment, never gamified reward inflation.
- **KNOWLEDGE / SOURCE THREAD:** source passage and directly associated user action share a spatial/causal rail. Primary differentiator = provenance legibility and knowledge interaction rather than a generic dashboard. Do not draw unsupported knowledge connections.

No treatment wins from static CSS, design docs, mockups or Flutter test automation alone. Each must compile/render as real Flutter widgets, use actual persisted learner data in Home, Workspace and Recall result, preserve every action, and be inspected in representative screenshots and 5–10 second runtime motion clips.

## Result fidelity
- Outcome labels and cues come from actual RecallOutcome/Assistance only.
- A correct independent attempt is not demonstrated mastery.
- Supported, exposed-answer, incorrect, unknown and partial outcomes never receive a fabricated success animation/statement.
- Correct answer and source excerpt are the canonical result's fields; do not generate or infer extra claims.
- Next action reason is the canonical nextAction.reasonText, never a generic reward.
- Runtime motion may communicate transitions, but must respect Reduced Motion and avoid incorrect state persistence.

## Explicit forbidden substitutions
- prebuilt card/grid template as a substitute for a tailored learning environment;
- palette-only candidate differences in the treatment competition;
- a beautiful isolated screen disconnected from its actual neighboring states;
- fake study journey, XP, progress percentages, streaks, rankings or time-complete mastery;
- placeholder art declared as approved production-grade visual assets;
- large generic mascot icon replacing task-specific stateful D/Knot behavior;
- overwriting source/learning business logic for a visual demo;
- another project's UI/character/rights/code used as this product's authority.

## Technical and perceptual acceptance are separate
**Engineering checks**: Dart format, Flutter analyze/test, tap/navigation, source isolation, callback semantics, long Turkish titles, 390 px screen, text scale 1.3 and 1.5, Reduce Motion. Baseline app stays unchanged until a visual treatment is selected.
**Perceptual gate**: real output screenshots and short video on phone width; no nested-card generic texture; one recognizable, emotionally credible source-grounded learning payoff; nonchildish Companion role; visible differentiation vs competent learning apps.
**Fresh-user gate**: uncoached 3s comprehension, first-tap timing, 60s first payoff, outcome comprehension, voluntary next action, friend-retell, replacement reason, next-session desire. Small initial sample n=5–8; document exact observations and do not call them market proof.
**Founder gate**: explicit review of actual runtime visual/treatment winner. Until this happens LA-0039 and LA-0040 remain IN_PROGRESS / visual FAIL.

## Scaffold-expiry rule
Current card treatment and any winning preview candidate remain **PROTOTYPES** unless product-specific perceptual and final asset fidelity pass. No asset/component is promoted solely for passing internal CI or looking tidy. Preserve technical truth, replace failed visual expression.

## Decision next
Build bounded real-runtime A/B/C on existing Learning App Flutter screens; compare before promoting any treatment to production. Avoid a new UI engine, framework, donor module or broad redesign of unrelated account/data surfaces.
