# LA-0040 — Premium Product Final Jury / Internal PASS Contract

**Owner instruction 2026-10-08:** Do not send FAIL or partially validated UI to founder as an approval candidate. This document is the internal standard; a passing engineering workflow alone is NOT product PASS. PR #13 stays unmerged without founder approval.

## North-star jury question

**Would this feel like a premium learning product capable of competing for a large commercial market — and would its first-time learner actually want to start, finish one meaningful learning loop, and return?**

A million-dollar business is a commercial hypothesis, **not** a visual score, guaranteed revenue, or claim of market fit. Validate demand, conversion, retention, and unit economics separately with real users.

## Mandatory juries — ALL must pass

### J1: 0–3 seconds / immediate legibility
- Can a stranger identify what they do here and why it matters without an explanation?
- Is there a compelling single visual focal point and obvious action, not a generic PDF/document dashboard?
- Does the actual canonical D/Knot feel like a meaningful character, not a pasted sticker or another mascot?
- Does empty Home work just as well as populated Home?
- Evidence: actual Flutter 390×844 and narrow-screen screenshots, blind 3-second comprehension test (at least five relevant target users). Internal visual judgment cannot replace observed users.

### J2: 3–60 seconds / first meaningful payoff
- Can a new learner add a real source, see it, start reading/listening, perform **unaided** recall, and get a source-grounded honest result?
- Is each action responsive, understandable, enjoyable, and worth continuing?
- Are hints/answer reveal honest about assistance, with no false mastery or progress?
- Does the transition from source visible → source hidden → answer compared have an emotionally legible rhythm?
- Evidence: end-to-end functional tests and five target-user first-minute observation sessions. Record completion and confusion, not invented conversion percentages.

### J3: visual art direction / every panel
- Does the composition have one distinctive visual identity across Home, Reader, Listen, Recall, Result, empty/error/loading states?
- Are panel sizes, spacing, layering, radii, borders, elevation, alignment and hierarchy intentional rather than nested generic rounded cards?
- Are all colors harmonious and semantic (background/paper/ink/CTA/secondary/accent/success/error), with accessible contrast?
- Are headings, long reading text, labels and controls comfortably readable in Turkish, with resilient long content and 200% text scale?
- Is the source visually a learning object, not a dull text dump? Is Result an evidence comparison, not a generic score screen?
- Evidence: pixel captures of each surface and all six outcomes; human side-by-side visual review at device size; overflow and contrast checks.

### J4: assets / character / motion
- Are all visible assets production-quality, consistent in resolution/style, legally usable, and actually integrated in Flutter?
- Is D/Knot the verified canonical character, legible at shipped sizes, expressive in six real states and interacting meaningfully with the learning moment?
- Is motion semantic, smooth, and appropriately reduced when accessibility requests reduced motion?
- Are there no temporary placeholders, fake mockups, stock-looking mismatched art, unverified fonts or low-resolution raster scaling presented as final?
- Evidence: source provenance + app rendering + animation/device recording, not a conceptual illustration.

### J5: usability / accessibility / technical
- Real actions, keyboard focus, scrolling, safe areas, screen reader semantics, tap targets and navigation work; no hidden/overlaid critical content.
- Android and iOS actual-device or suitable emulator validation as available; loading/error/offline paths and 320/390/large layouts tested.
- Golden snapshots, widget/integration tests, formatting, static analysis and CI all green; screenshots are **inspected**, not merely uploaded.
- Evidence: test outputs, visual review and device QA; missing proof means NOT VERIFIED, not PASS.

### J6: commercial-grade desire / differentiated value
- Would the target learner choose this over a generic PDF reader, AI summary or flashcard app?
- Is the first-use benefit understandable in store-page creative and a 5–15-second demonstration?
- Is there an authentic reason to return beyond notifications or artificial streaks?
- Are the learning outcomes honest and genuinely source-grounded?
- Evidence: competitor comparison, user preference test and real retention/conversion research. Commercial upside remains an assumption until measured.

## Decision rules

- Each jury criterion: **PASS**, **FAIL**, or **NOT VERIFIED**, with linked evidence.
- Any critical FAIL or NOT VERIFIED blocks overall PASS. No averaging, no “looks good enough.”
- A passing Flutter CI means **ENGINEERING CHECKS PASS**, never **PRODUCT PASS**.
- Run the loop: inspect actual app → identify root causes → redesign the connected surfaces and assets → integrate → run tests → capture and personally inspect → score all juries → repeat.
- Do not request founder approval for a FAIL. When ALL six juries pass, send a concise **INTERNAL PASS — FOUNDER APPROVAL PENDING** package with actual app captures, test proof and candid residual risks.
- Never claim user tests, commercial validation, premium quality, iOS QA, or production-ready art without conducting those checks.

## Current assessment (2026-10-08)

**OVERALL: FAIL / NOT READY.** J1 FAIL (generic first impression); J2 NOT VERIFIED (real first-minute observation missing); J3 FAIL (flat cards and weak hierarchy); J4 FAIL (D/Knot low-resolution sticker effect); J5 NOT VERIFIED (CI changes and device QA); J6 NOT VERIFIED (no preference/retention validation). Keep all prior screenshots internal, not founder approval candidates.
