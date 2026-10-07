# LA Visual Treatment Tournament R1

Status: ACTIVE DESIGN AUTHORITY FOR LA-0039
Date: 2026-10-07
Purpose: choose a product-level visual/interaction language before broad UI implementation.

## Evaluation dimensions

Each treatment is judged on:
- 3-second comprehension;
- trust / credibility;
- emotional desire to continue;
- visible source/material identity;
- active-learning action clarity;
- truthful payoff visibility;
- return/continuation desire;
- screenshot recognition;
- long-session fatigue;
- Turkish text resilience;
- accessibility;
- asset/production burden;
- ability to scale across Home, Library, Workspace, Listen, Recall/Explain, Progress and Profile.

## T1 — Quiet Academic Minimal

Look:
- white / very light neutral surfaces;
- black/graphite type;
- subtle blue accent;
- restrained icons;
- minimal illustration;
- notebook/research-tool feel.

Strengths:
- credible;
- calm;
- source-first;
- low asset burden;
- good for dense text.

Weaknesses:
- risks looking like generic productivity software;
- weak emotional momentum;
- weak payoff;
- D/Knot becomes decorative;
- can underperform in app-store screenshots and casual daily use.

Verdict:
GOOD CONTROL / NOT SELECTED.

## T2 — Premium Active Learning Studio

Look:
- warm paper-neutral base rather than sterile white;
- near-black ink typography;
- deep cobalt/indigo primary;
- fresh mint/aqua success/progress accent;
- amber/coral only for attention/caution, not generic decoration;
- strong material cover/identity surfaces;
- one unmistakable primary action per state;
- compact pill/chip states rather than repeated grey cards;
- D/Knot used as a functional guide/feedback actor, not a mascot wallpaper;
- persistent listening mini-player when relevant;
- motion focuses on state continuity and result -> next-action handoff.

Strengths:
- premium but not corporate;
- active without becoming childish;
- strong bridge between Speechify-like media continuity and Quizlet/Brilliant-like active learning;
- supports distinctive screenshots;
- can express progress without fake percentages;
- supports D/Knot without making the whole app cartoonish.

Risks:
- needs a real token/system pass; cannot be achieved by changing one seed color;
- material covers and companion states need controlled asset cohesion;
- excessive gradients/glow would quickly cheapen the product.

Verdict:
SELECTED IMPLEMENTATION LANE.

## T3 — High-Energy Gameful Learning Path

Look:
- highly saturated palette;
- visible lesson path;
- celebratory motion;
- large companion presence;
- badges/streak-like surfaces;
- stronger game-style transitions.

Strengths:
- high energy;
- memorable;
- strong short-term continuation cues;
- large payoff vocabulary.

Weaknesses:
- can imply false progress/mastery;
- risks childlike perception for adult/student audiences;
- can distract from source grounding;
- higher asset/motion burden;
- long-session fatigue;
- pushes the product toward Duolingo-like expression rather than its own identity.

Verdict:
DO NOT USE AS THE BASE TREATMENT.
Harvest only interaction principles: obvious next action, strong state change, restrained success emphasis and continuation desire.

## Selected visual-system principles

Treatment T2 is selected with these rules:

1. Material-first, not dashboard-first.
2. One primary action per state.
3. Source/evidence/next-action must share one visual hierarchy.
4. Progress is expressed as evidence/state/continuity, never invented completion.
5. Repeated generic Card/ListTile surfaces are a smell; use named product components.
6. Color has semantic roles and is never the sole state discriminator.
7. D/Knot appears when it has a learning/feedback role.
8. Listening continuity gets a persistent compact player when playback context exists.
9. Active-learning results get a staged but restrained payoff:
   response -> evidence interpretation -> source support -> next action.
10. Reduced Motion must preserve all meaning.
11. Asset richness must not reduce text/source readability.
12. Native platform conventions remain respected for navigation, touch, text scaling and destructive actions.

## Initial token intent

These are implementation starting points, not immutable brand law:
- canvas: warm near-white / paper;
- ink: very dark blue-black;
- primary: deep cobalt-indigo;
- secondary accent: mint/aqua;
- attention: warm amber;
- error/destructive: accessible red;
- surfaces: layered paper/ink contrast rather than purple-tinted Material containers.

Exact colors must be contrast-checked and visually reviewed in runtime.

## Implementation order

1. app theme / tokens / type hierarchy;
2. bottom navigation and global canvas;
3. Home/Continue hero + material identity;
4. Material Workspace;
5. active Recall result/payoff;
6. Listen mini-player continuity;
7. Library/Progress;
8. Profile/settings cleanup;
9. motion/feel pass;
10. asset manifest + runtime QA.

Do not mass-polish all screens before the representative golden slice passes.
