# LA-0040 Current Visual Audit — 2026-10-07

Status: COMPLETE — CURRENT TREATMENT FAILS VQG-01 FOR TARGET AMBITION
Evidence: representative 390×844 Golden Slice captures from validated branch head plus current public benchmark research.

## Executive finding
The current Premium Active Learning Studio pass is a meaningful improvement over prototype/default Material presentation, but it is **not the ideal final visual direction** for a student-weighted audience and the stated premium/standout ambition.

It is strongest at clarity, trust and restraint. It is weakest at distinctiveness, student desire, visual storytelling, emotional momentum and Workspace craft. The system currently feels closer to a polished productivity/education utility than a memorable learning product.

**Current VQG-01 disposition: FAIL / REDESIGN REQUIRED.**
This is not a technical failure. It is a quality-bar failure.

## Current-state scorecard (1–5)
| Dimension | Score | Finding |
| --- | ---: | --- |
| First-impression desirability | 3.1 | clean and credible; insufficient “I want this” energy |
| Clarity / action hierarchy | 4.2 | strongest dimension; Home primary action is clear |
| Distinctive visual identity | 2.8 | warm paper + indigo is competent but not ownable enough |
| Student-audience fit | 2.7 | reads more general productivity/learning than student-native |
| Emotional energy | 2.6 | calm but too flat across long use |
| Show-don’t-tell | 2.6 | substantial meaning still carried by explanatory copy |
| Learning payoff | 3.6 | Recall result is truthful and clear; emotional reward remains restrained |
| Continuation desire | 3.2 | next action is visible, but product momentum is modest |
| Trust / seriousness | 4.3 | strong; no fake mastery or juvenile reward language |
| Accessibility / resilience | 4.0 | current capture is legible and structurally robust |
| Companion contribution | 3.0 | memorable asset, but visual language is not yet integrated |
| Component / asset scalability | 4.0 | current primitives scale; richer direction must preserve this |

Median is below PASS threshold and multiple critical dimensions are below 3.

## Screen audit

### Home
Strengths:
- current material + next action are quickly legible;
- hero creates a clear primary decision;
- warm neutral canvas supports reading;
- Recall vs Listen distinction is simple.

Weaknesses:
- dominant indigo slab consumes most emotional attention without showing much learning;
- companion is visually richer/glossier than the surrounding flat UI and can feel like an inserted sticker;
- two study-mode cards are tidy but generic;
- little visible evidence of a living study journey, material structure, recent achievement or upcoming learning;
- large empty lower area reduces perceived product richness.

Verdict: **good hierarchy, insufficient desire/identity.**

### Material Workspace
This is the most important visual weakness.

Strengths:
- material identity is visible;
- next active action is dominant;
- learning truth is appropriately bounded.

Weaknesses:
- four near-identical white action cards produce a settings/menu feeling;
- hierarchy below the primary card collapses into repeated rows;
- “Metin • 173 karakter” reads like implementation metadata, not student-facing meaning;
- action descriptions explain capabilities rather than showing what the learner can immediately do;
- no strong material-specific visual structure, study map, session rhythm or learning-state visualization;
- this screen does not yet feel like a destination a student would enjoy returning to.

Verdict: **VQG automatic FAIL — prototype-like Workspace.**

### Recall payoff
Strengths:
- clearest emotional/state surface in the current app;
- success is visible immediately;
- source comparison and next action preserve learning truth;
- D/Knot supports rather than fully owns the result.

Weaknesses:
- still text-dense;
- result does not visually demonstrate “what changed” beyond copy;
- no visual before/after, memory-strength/evidence cue, concept card transformation or session momentum;
- companion + large white space creates a centered “result modal” feeling rather than an integrated learning world;
- CTA remains generic relative to the state transition.

Verdict: **solid foundation, not yet standout payoff.**

## Color-system audit
Current warm paper / dark ink / deep indigo / mint is safe, readable and premium-adjacent. It is not yet sufficiently distinctive or student-energizing to lock as final.

Decision: **EVOLVE, not blindly retain.**

Constraints for next treatment:
- preserve a calm reading canvas;
- introduce a more ownable signature color relationship;
- give active learning, listening/reference, success and attention visibly different but harmonious roles;
- avoid rainbow gamification;
- maintain dark-mode readiness even if dark mode is not in current release scope;
- palette should work with the companion rather than treating character and UI as separate worlds.

## Companion audit
D/Knot is visually memorable, expressive and potentially valuable, but the current glossy/3D-soft blue character contrasts sharply with the restrained flat product UI. That creates a “mascot pasted onto an app” risk.

Current decision: **REOPEN / DO NOT LOCK.**

Most promising hypothesis:
**EVOLVE or REDESIGN D/Knot rather than remove it immediately.**
Keep the core role—recognition, warmth, guidance, truthful feedback—but test:
- simplified silhouette;
- stronger iconic read at 24–64 px;
- palette integrated with product tokens;
- less plush/toy rendering;
- more contemporary editorial/graphic treatment;
- fewer but more meaningful states.

Removal remains a valid competitor in the companion tournament.

## Show-don’t-tell audit
Current UI often tells:
- what Recall does;
- what Explain does;
- why a result counts;
- what the next action means.

The next system should show more through:
- material/concept tiles;
- state chips with real semantic meaning;
- visual comparison between answer and source;
- session path / next-step structure;
- dynamic action previews;
- compact evidence markers;
- progressive disclosure for explanatory caveats.

Rule: no visual may imply more learning certainty than canonical evidence supports.

## Benchmark pattern findings
Patterns worth harvesting independently:
- recent StudyFetch rebrand explicitly targets ambitious students with a calmer, cleaner, more focused look and also redesigned its companion;
- StudyFetch’s study-plan redesign emphasizes always showing the next right thing rather than making the learner choose;
- Duolingo’s recent craft work treats visual consistency as part of how learning feels, not decoration;
- Brilliant centers learning-by-doing and visual interaction;
- Quizlet Learn centers short actionable sessions, active recall and adaptive progression.

Do not copy their layouts, characters, assets or brand expression.

## Product-positioning recommendation
Target emotional blend:
**Focused + Alive + Intelligent + Encouraging + Ownable.**

Avoid two failure modes:
1. sterile premium productivity app;
2. noisy childish gamification.

The likely opportunity is a **Visual Learning Studio** with student momentum:
- calm base canvas;
- stronger signature accents;
- material-specific visual identity;
- action surfaces that preview the learning interaction;
- visible state transformations;
- companion used as a guide/reaction layer, not as decoration.

## P0 before visual lock
1. redesign Workspace information architecture/presentation;
2. run visual-treatment tournament;
3. run companion tournament;
4. evolve palette from “safe indigo education” to an ownable system;
5. redesign Recall payoff around visible state change and next-step momentum;
6. define show-don’t-tell primitives;
7. re-capture Golden Slice and rerun VQG-01.

## P1
- Home richness / material journey;
- Listen visual continuity;
- Library/Progress expressive state language;
- empty/loading/error states;
- motion/haptic craft.

## P2
- optional decorative/editorial asset expansion only after P0/P1 prove a role.

## Conclusion
Current implementation should remain a **validated engineering baseline**, not a final design lock. LA-0039 must not close on visual quality. LA-0040 now owns the visual-direction decision and can supersede current palette/companion treatment after tournament evidence.
