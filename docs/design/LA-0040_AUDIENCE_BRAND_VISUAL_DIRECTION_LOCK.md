# LA-0040 — Audience, Brand Voice & Visual Direction Lock

Status: FOUNDER DIRECTION LOCK — implementation/prototype proof still required
Date: 2026-10-07

## Primary audience lock
**Primary audience: Turkish high-school students, grades 9–12 / approximately ages 14–18.**

Initial product design should optimize for:
- everyday school study;
- exam-period pressure and limited attention;
- self-provided notes, PDFs and study material;
- quick transitions between understanding, listening and active recall;
- phone-first sessions;
- students who reject both childish education products and sterile corporate productivity tools.

This does not make the product “for children.” The visual and verbal bar should respect a teenager as an intelligent, independent learner.

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

## Companion decision

### Rejected visual
The generated round, plush, blue/purple humanoid mascot shown in the LA-0040 concept board is **explicitly REJECTED**.
Do not reproduce it, approximate it or use its childlike/3D-plush language.

### Companion role
A companion may remain, but it is not the visual protagonist.

### New companion brief
Preferred direction: **living graphic guide / signal mark**, not a cute mascot.

Requirements:
- abstract or highly simplified;
- no animal;
- no plush body;
- no baby face;
- no oversized cartoon eyes as the identity;
- no arms/legs required;
- 2D/vector-first;
- recognizable at 24–48 px;
- visually credible to a 16–18 year-old;
- can express listening / thinking / success / support through geometry, posture, pulse or transformation;
- shares Pulse Blue / Deep Focus / Signal Aqua / Volt Lime language;
- sparse use: onboarding, thinking/loading, active guidance, result and recovery only.

Working hypothesis:
**D/Knot may evolve from “character” into a living knot/signal glyph.**
Name/identity is not protected if prototype evidence supports a better solution.

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
- primary audience: high-school students;
- Visual Learning Studio × Student Momentum direction;
- material-first / show-don’t-tell principle;
- core color direction;
- brand voice;
- rejection of plush/cartoon companion style;
- companion is secondary to material/learning.

### Still open until prototype evidence
- exact typography family;
- exact companion form/name;
- exact motion curves;
- exact component compositions;
- whether Volt Lime survives final accessibility/brand tests;
- final dark-mode treatment.

## Gate
This lock does not itself mean visual PASS.
Home + Workspace + Recall prompt + Recall payoff must be rebuilt/prototyped under this direction and pass:
- LA-0040 VQG-01;
- visual stress/red-team;
- accessibility;
- Founder representative visual review.
