# ROUND 7 COMPANION VISUAL PRODUCTION TASK 001

**Status:** EXECUTABLE VISUAL PRODUCTION TASK / R7-01  
**Authority:** `ROUND_7_CURRENT_FINALIST_REBUILD_BRIEF_001`  
**Candidates:** D/Knot and E/Tilt  
**Goal:** produce two equal-production-quality, structurally distinct Companion finalists without mascot drift.

## Why this task exists

Prior image generation failed because the request mixed character design, UI, learning scenes, personality copy and presentation polish in a single generation. The image model then solved the problem with familiar shortcuts: faces, limbs, cute creatures, human-like posing, props and cinematic scene dressing.

This task changes the production method. **Geometry first. Personality comes from geometry. Presentation comes last.**

## Production method

### 1. F0 is form design, not illustration

Generate each candidate separately. One image may contain multiple orthographic/form-study cells for the SAME candidate, but D and E are never generated together during F0.

F0 images use:
- neutral warm off-white background;
- neutral soft studio light;
- matte material;
- no scene;
- no desk, book, phone, classroom, plant or decorative object;
- no glow, neon rim light, particles or aura;
- no marketing copy;
- no face, eyes, mouth, limbs or clothing.

Required F0 cells:
1. canonical 3/4 form;
2. front/orientation form;
3. solid black silhouette;
4. monochrome form;
5. minimal-size legibility;
6. dense-learning placement;
7. adult/professional-learning placement.

The form must work before color.

### 2. Candidate D/Knot

D is one coherent living interlaced structure.

Required:
- two broad continuous ribbon-like structural bands;
- deliberate over/under knot logic;
- meaningful negative space;
- slightly asymmetric tension;
- calm directional attention;
- two or three body-integrated attention apertures/tension points may be explored, but they must NOT read as eyes;
- no circular blob, flower, petal, cloud or pretzel silhouette;
- no head/torso/limbs.

D fails immediately if it reads primarily as a logo, flower, pet, face, plush object or random decorative knot.

### 3. Candidate E/Tilt

E is one coherent upright directional structure.

Required:
- strong vertical silhouette;
- whole body carries a deliberate forward tilt;
- one integrated folded facet/notch establishes orientation;
- composed coach-like presence without humanoid posture;
- the former risky upper marker is absorbed into the body;
- no detached topper/tab/badge/antenna;
- no loop-based body;
- no orb or rounded blob;
- no head/torso/limbs.

E fails immediately if it reads as a robot, device, triangular face, UI cursor, badge, humanoid teacher or generic upright blob.

## Shared hard fails

Reject immediately if any output contains:
- recognizable animal/pet grammar;
- human or mini-human anatomy;
- robot/assistant-device grammar;
- orb assistant;
- generic blob-with-face;
- eyes-and-mouth mascot grammar;
- arms/hands/legs/feet/ears/tail/hair;
- clothing, hat, glasses or props;
- visor or face screen;
- plush/preschool/collectible-creature styling;
- fantasy/NPC/wizard/adventurer cues;
- realistic fur or cloth;
- environment-dependent identity;
- continuous glow/particles/effects;
- obvious resemblance to existing character IP.

Do not “repair” a hard-fail image with more styling. Discard it and regenerate from the canonical prompt.

## GPT/image-generation operating rules

1. **Never freestyle the production prompt.** Build it from `scripts/round7_companion_visual_spec.json` using `scripts/round7_companion_visual_prompt.py`.
2. **One candidate per F0 generation.** This prevents visual contamination and false parity.
3. **No personality adjectives without structural translation.** “Calm” must become spacing/tension/orientation, not a smiling face. “Confident” must become silhouette/orientation, not arms-akimbo posture.
4. **Do not ask for cute, friendly, adorable, mascot, Pixar-like, toy-like, creature, face or expressive eyes.**
5. **Do not use scene dressing to make a weak form look premium.**
6. **Do not advance to F1 if F0 silhouette is not distinctive.**
7. **Regeneration changes one structural variable at a time.** Examples: knot negative-space ratio, asymmetry, Tilt facet angle, body width. Do not simultaneously change material, lighting, camera and geometry.
8. **D/E parity is locked by the spec hash.** Camera, light, background, material, scale, detail budget and effects stay identical.
9. **F1 reuses the approved F0 geometry.** State generation is deformation/orientation of the same character, never redesign.
10. **Founder review happens only after both candidates are viable.** No winner is encoded in prompts or presentation.

## Tool usage

Validate the locked production spec:

```bash
python scripts/round7_companion_visual_prompt.py --lint
```

Generate the F0 prompt:

```bash
python scripts/round7_companion_visual_prompt.py --candidate D --stage F0
python scripts/round7_companion_visual_prompt.py --candidate E --stage F0
```

After canonical forms are accepted internally:

```bash
python scripts/round7_companion_visual_prompt.py --candidate D --stage F1
python scripts/round7_companion_visual_prompt.py --candidate E --stage F1
```

## Internal image review loop

For each generated F0 sheet:
1. ignore color first and inspect silhouette;
2. check hard-fail archetypes;
3. check small-size identity;
4. check whether life/attention exists without a conventional face;
5. check D/E structural separation;
6. check whether geometry is realistically translatable to the runtime renderer seam;
7. only then inspect material/polish.

If a sheet fails, state the single dominant structural failure and regenerate that candidate only.

## Completion boundary

This task completes only when:
- D/Knot has a viable F0 canonical form;
- E/Tilt has a viable F0 canonical form;
- both pass the same hard-fail and parity rules;
- then both advance to F1 six-state production.

It does not select the final Companion and does not admit M5.
