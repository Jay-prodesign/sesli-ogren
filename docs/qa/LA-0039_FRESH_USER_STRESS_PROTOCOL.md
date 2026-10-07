# LA-0039 Fresh-User Stress Protocol

Status: ACTIVE QA PROTOCOL
Date: 2026-10-07
Applies to: representative Golden Product Slice

## Purpose

Adapt the Game Engine fresh-player stress method to a source-grounded learning product without importing game retention mechanics.

The target is immediate comprehension, meaningful first action, truthful payoff and continuation desire.

## Test conditions

Run at minimum in these states:
1. cold user, no material;
2. returning user, prepared material, no Recall evidence;
3. returning user, one retrieved-once result;
4. returning user, review-needed state;
5. returning user with Listen resume checkpoint.

Use Turkish UI first. Repeat critical checks with narrow phone width and increased text scale.

## 3-second comprehension

Without explanation, ask:
- What kind of product is this?
- What is the object you are working on?
- What is the single most important action?

PASS:
- user identifies learning/study intent;
- material or add-material action is visible;
- primary action is not confused with navigation or passive Listen.

RETURN:
- looks like generic notes/PDF/TTS app;
- user cannot identify current material;
- multiple CTAs compete equally.

## 10-second promise

Ask:
- What does this app help you do that a normal reader/player does not?
- What would you tap next?

PASS:
- user can describe source-connected active learning in their own words;
- next action maps to the canonical continuation.

## Prepared-material 60-second stress

Starting on Home with a prepared material:
- open continuation;
- reach one active Recall or Explain-Back action;
- submit/complete the action;
- understand the result;
- identify the next action.

Record:
- time to first meaningful action;
- hesitations/backtracks;
- wrong taps;
- unclear terms;
- points where source identity is lost;
- points where passive and active learning are confused.

PASS target:
meaningful active learning is reachable inside 60 seconds without a tutorial dependency.

## Payoff comprehension

Immediately after a result, ask:
- What happened?
- Does the app claim you mastered this?
- What evidence did it use?
- What should you do next?

PASS:
- learner distinguishes one observed result from mastery;
- source support/uncertainty is understandable;
- next action is obvious.

## Continuation desire

After the result:
- ask what the user expects to happen if they return tomorrow;
- ask whether the app gives a concrete reason to reopen the same material.

PASS:
continuation desire comes from unfinished meaningful learning work, not fake streak/XP pressure.

## Friend-retell test

After one representative session:
“Tell a friend what Sesli Öğren does in one sentence.”

Strong retell should contain at least two of:
- own material/source;
- listen;
- actively recall/explain;
- learning evidence/state;
- next step.

If retell collapses to “it reads PDFs aloud” or “AI study app,” return to product hierarchy/coupling.

## Replacement test

Show/describe strong alternatives separately:
- Speechify-style reading/listening;
- Quizlet-style study;
- Brilliant-style active learning;
- Notebook-style source-grounded workspace.

Ask:
“Why would you still open Sesli Öğren for your own material?”

PASS answer must be specific to the coupled experience:
the same source persists across listening, active retrieval/explanation, truthful evidence and an explainable next action.

## Evidence packet

Record:
- device/viewport/text scale;
- starting state;
- elapsed times;
- first three taps;
- observed confusion;
- exact user retell;
- exact replacement-test answer;
- PASS / ITERATE / RETURN;
- screenshot or recording references when available.

Static reviewer analysis may catch obvious defects, but human fresh-user evidence is required before final Founder visual/UX closure.
