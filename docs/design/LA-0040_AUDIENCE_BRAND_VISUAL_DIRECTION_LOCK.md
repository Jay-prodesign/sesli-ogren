# LA-0040 — Audience, Brand Voice & Visual Direction Lock

Status: FOUNDER DIRECTION LOCK — implementation/prototype proof still required
Date: 2026-10-07

## Priority audience weighting
**Sesli Öğren is not restricted to high-school students.** The product remains a broader learner-owned-material study product.

For the initial commercial visual/UX optimization, **Turkish high-school students (grades 9–12 / approx. ages 14–18) are the priority-weighted audience segment**, not the exclusive target audience.

The design should optimize strongly for:
- everyday school study and exam-period pressure;
- self-provided notes, PDFs and study material;
- quick transitions between understanding, listening and active recall;
- phone-first sessions;
- users who reject both childish education products and sterile corporate productivity tools.

The same system must remain credible and usable for adjacent learner groups rather than baking “high-school-only” assumptions into product truth, data model or brand identity.

## Product emotional target
Sesli Öğren should feel:
**Focused + Alive + Smart + Contemporary + Encouraging + Ownable.**

It must not feel:
- childish;
- teacherly/patronizing;
- corporate/SaaS-like;
- generic “AI purple”;
- over-gamified;
- luxury-formal;
- visually noisy.

## Theme lock
### **Visual Learning Studio × Student Momentum**

The learner’s own material is the visual protagonist. The experience should feel like opening a modern personal study studio rather than a menu of AI tools.

Core visual promise:
**“Materyalin burada yaşamaya başlar: gör, anla, hatırla, devam et.”**

The direction is conceptually locked by Founder. Exact implementation must still pass VQG-01, accessibility and stress/red-team.

## Visual-language principles
1. **Material-first:** source/material identity should be visible before generic product chrome.
2. **Show, don’t tell:** state, action and payoff should be carried by composition, visual relationships and interaction; explanatory copy is secondary.
3. **One dominant action:** each state has one obvious primary move.
4. **Visible transformation:** active learning should visibly change the screen/state without inventing fake progress.
5. **High-school energy, not child gamification:** expressive color and motion are bounded to meaningful moments.
6. **Calm reading base:** long study sessions stay visually comfortable.
7. **Asymmetric rhythm:** avoid endless identical cards; use hierarchy, clusters, strips, stages and focus zones.
8. **Real-source visuals:** prefer actual source previews, extracted headings, real diagrams/images where permitted, and source-derived concept structures over decorative AI artwork.
9. **Motion has a job:** acknowledge action, clarify transition, reveal result, pull attention to next action.
10. **No decorative mascot dependency:** the product remains visually strong even when companion is absent.

## Color system — V1 locked direction

### Core neutrals
- **Canvas / Cloud:** `#F7F8FC` — primary long-session background
- **Surface / Pure:** `#FFFFFF`
- **Ink / Midnight:** `#111827` — primary text
- **Muted Ink:** `#667085`
- **Divider / Mist:** `#E4E7EC`

### Signature colors
- **Pulse Blue:** `#3657FF` — primary action / active learning
- **Deep Focus:** `#14224A` — immersive hero/focus surfaces
- **Signal Aqua:** `#20BFA9` — listening, supportive/secondary positive state
- **Volt Lime:** `#C9F45D` — very limited signature highlight / momentum cue

### Semantic colors
- **Success:** `#138A72`
- **Attention:** `#E99024`
- **Error:** `#D64550`

## Color rules
- No default purple/blue gradient as a brand crutch.
- Pulse Blue is the primary brand/action anchor.
- Volt Lime is a signature spark, never a large reading background.
- Deep Focus may create immersive moments but must not dominate every screen.
- Aqua is not a second primary CTA color; it communicates listening/supportive states.
- Semantic meaning never relies on color alone.
- Gradient use is rare, stateful and bounded; flat color is default.

## Typography direction
Target: contemporary, highly legible, slightly expressive geometric/humanist sans.

- Headings: strong 650–750 visual weight, compact line-height.
- Body: comfortable 400–500, generous line-height.
- Labels: short, direct, never tiny metadata walls.
- Avoid academic serif as the dominant product voice.
- Avoid overly rounded/cartoon type.

Implementation font candidate must pass provenance/licensing/performance checks before lock; visual direction is more important than a specific font family.

## Shape / surface language
- Medium-to-large radii, but not “bubble UI.”
- Action areas may use 16–22px radii.
- Stronger geometry for study tools and source objects.
- Fewer bordered white cards.
- Prefer grouped regions / bands / object-like study surfaces.
- Use elevation sparingly; hierarchy should come from composition and color first.

## Iconography
- Clean, slightly rounded line/solid hybrid.
- Icons represent action roles, not decoration.
- Recall, Listen, Explain and Focus must be visually distinct at a glance.
- No emoji-based product UI as default.

## Motion language
- Fast and purposeful: roughly 180–320ms for normal transitions.
- State changes may use subtle scale, slide, highlight expansion or line/path continuation.
- No looping decorative motion.
- No confetti by default.
- Success may use one bounded motion accent tied to actual evidence.
- Reduced Motion preserves all meaning.

## Companion authority correction

### Canonical baseline
**D/Knot remains the selected Learning App companion baseline under the prior Founder-reviewed Round-7 / D-070 work.** That work already established Founder reference authority, canonical source assets, minimum-size readability, six semantic states, bounded motion, Reduced Motion/fallback behavior and real Flutter integration.

The newly generated round/plush blue-purple humanoid shown in the LA-0040 concept board is **REJECTED because it is not faithful to canonical D/Knot**. Its rejection must not be misread as rejection of D/Knot itself.

### Correct LA-0040 question
Do **not** restart companion discovery from zero.

Evaluate how the selected D/Knot should integrate with the stronger product visual system:
- placement/frequency;
- scale;
- surrounding color treatment;
- background/surface pairing;
- state emphasis;
- whether minor production-safe styling adjustments are needed without identity drift.

D/Knot appears only when it has a learning/feedback role. It should support material/action/payoff rather than become wallpaper.

### Reopen rule
A material identity redesign or companion removal is permitted only if representative product evidence shows canonical D/Knot itself creates a HIGH/BLOCKER user-visible failure that cannot be solved by integration, placement or bounded styling. New concept art alone is not sufficient evidence.

## Brand voice — how Sesli Öğren speaks

### Role
**Smart study partner, not teacher, parent, cheerleader or chatbot.**

### Voice pillars
1. **Direct:** short, action-led sentences.
2. **Respectful:** speaks to the learner as capable.
3. **Evidence-aware:** praise describes what actually happened.
4. **Calm under failure:** no shame, drama or scolding.
5. **Energetic in action:** momentum without hype.
6. **Natural Turkish:** no AI jargon or translated-product stiffness.

### Address
Use singular informal **“sen”** consistently.

### Good
- “Şimdi bunu hatırlamayı dene.”
- “İpucusuz hatırladın.”
- “Kaynakla karşılaştır.”
- “Burada iki nokta eksik kaldı.”
- “Bir kez daha dene.”
- “Kaldığın yer hazır.”
- “Önce şu bölümü netleştirelim.”

### Avoid
- “Muhteşemsin!!!”
- “Süper öğrenci!”
- “Mastery %87”
- “AI senin için analiz etti.”
- “Başarısız oldun.”
- “Hadi şampiyon!”
- infantilizing praise, forced slang, excessive emoji or fake certainty.

## Copy density rule
If a state can be understood visually, copy should confirm it rather than explain it.
Default priority:
**visual state -> short heading -> one useful sentence -> action.**

## High-school-specific UX implications
- Sessions should feel resumable within seconds.
- “What now?” must always be obvious.
- School subject/material identity must stay visible.
- Users should be able to switch between passive support and active study without losing context.
- Long explanations use progressive disclosure.
- Results should feel satisfying without turning study into a game economy.
- Interface must remain credible for both a 9th-grade student and a 12th-grade exam-focused student.

## Locked / open
### Locked now
- broad learner-owned-material product with high-school students as the **priority-weighted initial audience**, not exclusive audience;
- material-first / show-don’t-tell principle;
- brand voice direction;
- canonical D/Knot remains the companion baseline;
- the generated non-canonical plush mascot is rejected;
- companion is secondary to material/learning truth.

### Still open until prototype evidence / roadmap reconciliation
- whether Visual Learning Studio × Student Momentum is the final treatment or a leading prototype lane;
- exact palette values and whether Volt Lime survives real-product accessibility/brand tests;
- exact typography family;
- D/Knot integration/placement and bounded styling only; identity remains baseline authority unless real evidence reopens it;
- exact motion curves;
- exact component compositions;
- final dark-mode treatment.

## Gate
This lock does not itself mean visual PASS.
Home + Workspace + Recall prompt + Recall payoff must be rebuilt/prototyped under this direction and pass:
- LA-0040 VQG-01;
- visual stress/red-team;
- accessibility;
- Founder representative visual review.
