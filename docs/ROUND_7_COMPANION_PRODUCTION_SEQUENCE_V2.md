# ROUND 7 Companion Production Sequence V2

**Status:** ACTIVE EXECUTION AUTHORITY FOR COMPANION PRODUCTION
**Branch:** `feat/round7-companion-production-sequence-v2`
**Date:** 2026-10-03
**Supersedes for active execution:** any workflow that multiplies state PNGs, boards, pose sheets, or secondary expressions before canonical masters, rig parity, and real runtime integration are proven.

## Goal

Ship D/Knot and E/Tilt as real Learning App companions that can visibly idle, listen, think, speak, correct/support, and celebrate in the Flutter runtime without letting visual code own learning truth.

## Founder visual authority

Current visual direction is frozen to the Founder reference set captured on 2026-10-03:

- `DE_IDENTITY_SYSTEM_FOUNDER_REF_01.jpeg`
- `DE_COMPANION_SYSTEM_FOUNDER_REF_02.jpeg`
- `DE_HOME_CONTEXT_FOUNDER_REF_03.jpeg`
- `DE_SCALE_CONTEXT_FOUNDER_REF_04.jpeg`

These references define the current D/Knot and E/Tilt identity. Earlier faceless/no-eye Round-7 experiments, generic blob/robot concepts, human-character rig sheets, and generated asset-board composites are not production authority.

## Lean production rule

One asset or one runtime capability at a time:

`NEED -> ASSET SPEC -> SOURCE/EDIT -> SOURCE QA -> APP INTEGRATION -> DEVICE QA`

Do not generate a sheet when one isolated source asset is required.
Do not create 576 state/expression/angle/theme combinations.
Do not generate secondary greetings, celebration poses, decorative effects, or broad icon sets before the minimum runtime loop works.

## Runtime truth already available

The Flutter proof already owns the semantic companion states:

- `IDLE`
- `LISTEN`
- `THINK`
- `SPEAK`
- `CORRECT` with attention/correction tone
- `SUCCESS`

The learning flow decides these states. The renderer only expresses them.

The existing `CompanionRenderer` seam, reduced-motion/fallback behavior, animation-controller lifecycle, asset-failure degradation, and semantic labels remain the implementation base.

## Correct execution order

### P0 — Authority freeze and inventory
1. Preserve Founder visual references.
2. Mark earlier conflicting masters/sheets as REFERENCE, SUPERSEDED, or REJECTED.
3. Maintain one machine-readable asset/runtime status ledger.

**Exit:** no ambiguous current identity authority.

### P1 — Canonical neutral masters
4. Produce isolated `D_MASTER_NEUTRAL`.
5. Source-jury D against Founder refs.
6. Produce isolated `E_MASTER_NEUTRAL`.
7. Source-jury E against Founder refs.

Requirements: single character only, transparent alpha, no UI/text/environment, stable safe margins, no baked feedback effects, identity parity with Founder refs.

**Exit:** both neutral masters SOURCE PASS.

### P2 — Minimal-size gate
8. Derive 512/256/128 previews from each passed master.
9. Verify readability in the real 72 logical-pixel Companion slot and compact contexts.

**Exit:** identity survives target runtime scale. Do not rig a source that fails here.

### P2.5 — Anatomy normalization gate
10. Treat existing locked D/E masters as core face/ribbon identity authority, not as complete anatomy authority.
11. Author one rig-neutral source per character with the shared anatomy explicitly accounted for: 2 arms + 2 hands; 0 legs/feet.
12. Neutral arms/hands stay close/tucked and must not turn into a greeting pose.
13. Core face, ribbon geometry family, palette/material and proportions must remain consistent with the locked master and Founder references.

**Exit:** D and E each have an isolated anatomy-normalized rig-neutral source suitable for decomposition without inventing hidden limbs.

### P3 — Rig/deformation source
10. Decompose D and E only as far as actual motion requires.
11. Apply the shared anatomy contract: both D and E have 2 arms + 2 hands; V1 has 0 legs/feet. Limbs may be occluded, never invented per state.
12. Use `docs/agent/ROUND7_COMPANION_STATE_POSE_SPEC.json` as the state pose/visibility authority.
13. Minimum controls:
   - body/ribbon structural deformation
   - face base where required
   - eyelid/blink
   - iris/pupil/gaze
   - neutral/closed mouth
   - small speaking mouth set
14. Arm/hand layers are required for both characters because Founder references use gestures. Keep left/right identity stable across every state. Do not add feet/legs in V1.

**Exit:** every required animated component has an isolated source and no identity-changing redraw.

### P4 — Neutral recomposition parity
13. Recompose each character from the rig layers at neutral.
14. Compare against its canonical neutral master.

**Exit:** neutral rig reconstruction is visually equivalent at app size. If it drifts, repair the rig/source; do not compensate with runtime effects.

### P5 — Six semantic motion clips
15. Implement motion from the same rig:
   - IDLE: restrained breathe/float
   - LISTEN: attention orientation/lean
   - THINK: slower tilt/compress/focus
   - SPEAK: bounded body response while audio is active
   - CORRECT: calm supportive attention/correction
   - SUCCESS: short positive expand/bounce then settle
16. Reduced Motion uses static/minimal transforms, not an alternate character identity.

**Exit:** state changes are readable without separate full-character redraws.

### P6 — Speech controls
17. Add blink/gaze micro-motion.
18. Add minimum mouth shapes for speech. V0 does not require phoneme-perfect facial animation.
19. Mouth state must be driven by actual audio playback state, never by a visual timer alone.

**Exit:** character visibly speaks only while actual audio is active.

### P7 — Real Flutter integration
20. Replace the proxy body through the existing `CompanionRenderer` seam.
21. Preserve canonical semantic state ownership and fallback semantics.
22. Keep rollback to the proven proxy during bounded proof.

**Exit:** D/E renders in the actual proof/app shell with no learning-flow regression.

### P8 — Real TTS/audio linkage
23. Connect the product-local speech implementation.
24. Start SPEAK visuals on playback start; stop/settle on playback completion/interruption.
25. Transcript remains available; audio failure must not break the learning loop.

**Exit:** real speech + visual speaking state work together.

### P9 — Real-phone QA
26. Test on real phone at target orientations/safe areas.
27. Check readability, clipping, frame smoothness, state clarity, reduced motion, audio interruption, compact scale, accessibility, and fallback.
28. Asset DONE requires this device validation.

**Exit:** PRODUCTION ASSET PASS for the minimum companion loop.

### P10 — Secondary assets only after P9
29. Greeting/wave, extra celebrations, optional reactions, extra sizes, promotional renders, and decorative overlays are LATER until the minimum companion loop passes.
30. Non-identity effects should prefer deterministic Flutter/vector/runtime overlays.

## Integration map

| Product truth / event | Visual output |
|---|---|
| Context / available | IDLE |
| Challenge / repair check | LISTEN |
| Evaluating response | THINK |
| Real voice playback active | SPEAK |
| Partial evidence | CORRECT + attention tone |
| Misconception / repair | CORRECT + correction tone |
| Strong / complete | SUCCESS |
| Reduced Motion | same state, minimal/static motion |
| Asset failure | semantic label / proven fallback; learning continues |

## Current executable cursor

Verified current state:
- **P0 Authority freeze/inventory: PASS**
- **P1 Core identity masters: PASS** — existing D/E locked masters remain face/ribbon identity authority.
- **P2 Minimal/static size gate: PASS** — 512/256/128 static fallbacks already pass alpha/bounds QA.
- **P2.5 Anatomy normalization: IN PROGRESS** — explicit shared 2-arm/2-hand, 0-leg/0-foot rig-neutral sources are still required.
- **P3 Rig/deformation source: BLOCKED by P2.5**

Current cursor: **P2.5 — create and source-jury D rig-neutral anatomy source, then E.**

Do not regenerate the character identity. Do not multiply state PNGs. The next accepted output must be a real independent layer/control source that participates in neutral recomposition parity.
