# LA World-Class Product Experience Audit — 2026-10-07

Status: CANONICAL RESEARCH / ACTIVE INPUT TO LA-0039
Project: Learning App / Sesli Öğren
Cross-project source: Jay-prodesign/corebreak-game, READ-ONLY methodology reference only
Founder trigger: current colors, visual treatment and UX/UI are not competitive enough; prior Product/Visual PASS must not block correction.

## Executive diagnosis

The current app is functionally much more mature than its presentation.

The runtime now has:
- account entry/session restore;
- material ingest and continuity;
- Listen;
- Recall;
- grounded Explain;
- active Explain-Back;
- Focus;
- truthful progress/next action;
- multi-material library;
- deletion, sign-out and support surfaces.

But the visible product still relies heavily on:
- default Material 3 behavior;
- ColorScheme.fromSeed with one generic purple seed;
- repeated flat Card/ListTile/form composition;
- weak visual hierarchy between source, current learning state and next action;
- limited material identity;
- limited sense of momentum/payoff;
- no coherent presentation system connecting Home -> Workspace -> Listen -> Recall/Explain -> Result -> Return.

This produces prototype/demo perception even when the underlying learning contracts are stronger.

## Competitive benchmark patterns

Observed transferable patterns from current strong products:
- Speechify: immediate ingest affordances, strong brand color, persistent audio/player continuity, strong media identity.
- Quizlet: prominent Jump back in / Continue behavior, short action-oriented study blocks, clear learner re-entry.
- Headway: distinctive editorial card system, visible daily learning activity and content identity.
- Brilliant: action -> response -> reward rhythm, strong progress framing, purposeful visuals tied to the learning task.
- Gemini Notebook / NotebookLM lineage: clear source-grounded information architecture and strong separation between source, conversation/action and generated study outputs.
- Duolingo: extremely clear current action and feedback/momentum, but its cartoon/gamification intensity is NOT a direct visual target for Sesli Öğren.

Benchmark success logic only. Do not copy protected expression, branding, illustrations, exact layouts or assets.

## Read-only Game Engine methods worth transferring

### 1. Whole-product coupling
Adapt from Whole-Game Breakout Standard.

Learning App chain:
SOURCE / MATERIAL
-> WHAT I AM DOING NOW
-> ACTIVE LEARNING ACTION
-> TRUTHFUL FEEDBACK / EVIDENCE
-> EXPLAINABLE NEXT ACTION
-> VISIBLE CONTINUITY
-> REASON TO RETURN

A surface that looks polished in isolation but weakens this chain fails.

### 2. Desire / payoff ladder
Adapt the game payoff ladder without fake gamification.

NOW — next 5 seconds:
- know exactly what to do;
- understand the current material/state;
- feel one primary action is worth tapping.

SESSION:
- receive a clear, truthful learning payoff: recalled, repaired, explained, or clarified;
- see what changed and what did NOT become proven.

NEXT SESSION:
- a concrete unfinished next action is visible and easy to resume.

MULTI-SESSION:
- the learner can see how a material is evolving through evidence and actions without invented mastery percentages.

No XP/streak/confetti may imply learning mastery unless the learning contract supports it.

### 3. Fresh-player / cold-user stress
Adapt the Game Engine cold-player protocol to:
- 3-second comprehension;
- 10-second product promise;
- first 60 seconds;
- first completed active-learning loop;
- returning-user resume;
- friend-retell;
- why-care / replacement test.

### 4. Visual-treatment tournament
Before freezing art direction, compare:
1. premium calm academic;
2. premium active-learning studio;
3. deliberately gameful/high-energy learning path.

Judge desire, clarity, trust, memorability, learning-state readability, asset burden and long-session fatigue.

### 5. Production asset manifest
No random visual generation.

Every non-commodity asset must have:
- experience role;
- exact surface/state;
- dimensions/format;
- accessibility constraints;
- behavior/state contract where applicable;
- reuse relationship;
- production method;
- placeholder/replacement rule;
- runtime QA requirement.

### 6. VFX / interaction-feel pass
Adapt game-feel as product feedback:
INPUT
-> ACKNOWLEDGEMENT
-> STATE TRANSITION
-> LEARNING RESULT
-> NEXT-ACTION EMPHASIS

Motion, haptic and visual emphasis consume learning truth; they never create mastery/evidence.

### 7. Golden Product Slice
Build one bounded representative end-to-end experience at near-release visual quality before broad polish.

Representative returning-user slice:
Home/Continue
-> Material Workspace
-> one active Recall or Explain-Back
-> truthful result
-> next action
-> back to Home with visible continuity.

Also verify the first-material empty state because acquisition/activation quality depends on it.

### 8. Million-Dollar Quality Audit
Use the phrase as an ambition bar, not a revenue forecast.

Ask:
- Does this look like a product people would choose beside world-class apps?
- Is the product identity recognizable without the app name?
- Is the first useful action obvious?
- Is the learning payoff satisfying without lying?
- Is there an obvious return path?
- Does the visual system scale across Library, Listen, Recall, Explain, Progress and Profile?
- Does quality survive Turkish text, accessibility, narrow phones and long sessions?
- Is the experience strong enough that successful learning/content metrics could compound rather than hit a presentation ceiling?

## Methods intentionally NOT copied directly

Do not import as Learning App authority:
- game mechanics or game-specific retention loops;
- score/XP/streak systems;
- game monetization pressure design;
- live-ops event structure;
- combat/game VFX vocabulary;
- Game Engine implementation architecture;
- its task IDs, lifecycle states or product decisions.

Only the methodology is adapted.

## Founder correction to prior visual authority

D/Knot companion selection remains valid.

The prior Product/Visual PASS wording is no longer sufficient authority for the app shell/UI. Founder evidence on 2026-10-07 explicitly reopens:
- colors;
- typography;
- surface hierarchy;
- Home;
- Library presentation;
- Material Workspace;
- Listen presentation;
- active-learning interaction surfaces;
- Progress presentation;
- navigation treatment;
- microinteraction/motion;
- asset integration.

Do not reopen learning truth, source grounding, evidence semantics, account/data safety or D/Knot identity merely because visual treatment is reopened.

## Recommended direction

Proceed with Treatment T2 from LA_VISUAL_TREATMENT_TOURNAMENT_R1:
PREMIUM ACTIVE LEARNING STUDIO.

Reason:
it combines the credibility/clarity of source-grounded tools with the momentum/payoff discipline of strong learning products, while avoiding both generic enterprise UI and childlike gamification.

## Execution consequence

LA-0038 can close after validated head 5ee9f4fa.

LA-0039 becomes the active Tier-A tranche:
World-Class Experience / Golden Product Slice.

Do not broaden feature scope while this tranche is active.
