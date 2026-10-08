# LA-0040 — Internal visual/experience jury (blocking)

Status: **FAIL — do not send to founder for approval**. This is a quality gate, not a substitute for founder direction lock. Keep PR #13 unmerged.

## Observed failures (2026-10-08, actual Flutter contact sheet)

1. **Home clipped**: bottom persistent CTA obscures the companion's next-step explanation. Critical information is not fully visible at 390×844. BLOCKER.
2. **D/Knot reduced to sticker**: tiny static-looking character in Recall/Result; state changes are not visually legible and character does not participate in the interaction. BLOCKER.
3. **Reader = text dump**: no strong reading hierarchy, focus treatment or convincing transition from source to learning. BLOCKER.
4. **Recall = ordinary form**: question in a rounded card, generic input and stacked buttons. The source-hidden retrieval task has little emotional or spatial distinction. BLOCKER.
5. **Result = repetitive template**: correct/unknown/hinted layouts nearly identical, although claims are semantically distinct; response and source comparison not sufficiently experiential. BLOCKER.
6. **Brand and visual craft**: generic stacked rounded cards, weak source→recall visual continuity, inconsistent chrome, overly small labels, limited depth and hierarchy. BLOCKER.
7. **Evidence limitation**: golden snapshots verify pixels, not real-device feel, animations, text scaling, touch targets, accessibility, learner comprehension, first-minute appeal or genuine user retention. No claim of user-tested quality.

## Internal PASS gate — all mandatory, no averaging away blockers

- **Functional truth**: source and learner answers are real runtime values; no fake scores, citations, progress, or mastery; source remains hidden until answer; assistance accurately changes outcome; actions actually work.
- **First glance**: at 390×844, both empty and populated Home communicate the product's distinctive learning promise, obvious next action, and recognizable character without generic document-manager styling.
- **Companion**: canonical D/Knot, clearly visible at real rendered sizes, purposefully reacts to actual state, and feels physically integrated with source/Recall/Result rather than pasted on. Respect reduced motion.
- **Flow craft**: Reader→Recall→Result feels like one deliberate learning experience, with an intentional source conceal/reveal and strong source-vs-answer hierarchy; no interchangeable generic cards.
- **Content resilience**: test short/long Turkish titles, empty/long source, long prompt/answer, six outcomes, keyboard open, 200% text scale, 390×844 and narrow screen; no clipped content, inaccessible action, render overflow, or obscured scroll region.
- **Visual system**: legible contrast, stable type hierarchy, spacing, alignment, clear tap affordances, coherent navigation, and meaningful motion.
- **Review evidence**: real Flutter renders for Home empty/populated, Reader, Recall, all six Result outcomes; screenshot comparison and reviewer notes; functional tests and CI green; device QA for Android and iOS where available.
- **Jury rule**: any blocker or unverified mandatory gate = FAIL/NOT READY; fix, regenerate and rerun. Do not present failing screenshots or intermediate candidates to founder as ready. When all internal gates pass, label **INTERNAL PASS / FOUNDER APPROVAL PENDING**. Never claim founder-approved or device-tested without evidence.

## Execution

1. Preserve existing truth/domain layer; redesign the four surfaces as a single composition rather than one-off cosmetics.
2. Make a complete, coherent batch; no micro-commits and no repeated Dart-format CI churn. Run formatter before pushing.
3. Run functional and visual CI; inspect actual captures, not just artifact existence.
4. If failed, record exact blocker and iterate internally. Founder only sees internally PASS candidate with verified screenshots, behavior and remaining limitations.
5. PR #13 remains unmerged until explicit founder approval.
