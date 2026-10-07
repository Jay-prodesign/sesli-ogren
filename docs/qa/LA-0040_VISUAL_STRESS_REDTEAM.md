# LA-0040 Visual Stress + Red-Team

Status: ROUND 0 EXECUTED AGAINST CURRENT LA-0039 CAPTURE
Decision: **FAIL — HIGH visual/product findings remain.**

## Evidence
Representative current captures:
- Home 390×844
- Material Workspace 390×844
- Recall payoff 390×844
Engineering validation remains green at the current baseline. This document evaluates presentation quality, not runtime correctness.

## Stress tests

### ST-01 — 3–5 second comprehension
Home: PASS.
Workspace: PASS for material/action, FAIL for desire.
Recall payoff: PASS.
Finding: user can understand the flow, but immediate visual attraction is only moderate.

### ST-02 — 10 second value comprehension
Result: CONDITIONAL PASS.
The own-material + active-learning proposition is inferable, but the visual system does not show enough of why the experience is richer than a clean study utility.

### ST-03 — Workspace repetition fatigue
Result: **FAIL / HIGH.**
Four repeated action cards create strong menu/list repetition and flatten the experience.

### ST-04 — Show-don't-tell
Result: **FAIL / HIGH.**
Capability explanations and learning meaning rely heavily on text. Visual state/interaction carries too little of the message.

### ST-05 — Student relevance
Result: **FAIL / HIGH for target ambition.**
Current treatment is credible but not clearly student-native; it could serve a general professional knowledge app with limited change.

### ST-06 — Companion integration
Result: CONDITIONAL / MEDIUM.
D/Knot is attractive but rendering language is disconnected from the surrounding system.

### ST-07 — Recall emotional payoff
Result: CONDITIONAL PASS / MEDIUM.
Result is truthful and clear. It lacks a strong visual transformation that makes progress feel tangible without overclaiming.

### ST-08 — Narrow phone
Result: PASS on captured 390px logical width.
No critical clipping observed in representative slice.

### ST-09 — Long-session comfort
Result: LIKELY PASS for current colors/density; human-duration test pending.
The redesign must not trade this strength for excessive energy.

### ST-10 — Long Turkish / text scale
Result: engineering coverage exists for resilience, but the new winning treatment must be rerun after redesign. NOT YET CLOSED for LA-0040.

## Red team

### RT-01 “Boring app”
Attack: “Temiz ama beni geri çağıracak kadar heyecanlı değil.”
Severity: **HIGH**
Evidence: low visual variation and large repeated surfaces.
Disposition: CONFIRMED.

### RT-02 “Template app”
Attack: “Logoyu kaldırınca birçok eğitim/productivity uygulamasından biri olabilir.”
Severity: **HIGH**
Evidence: common indigo/white card language; weak signature composition in Workspace.
Disposition: CONFIRMED.

### RT-03 “Too much reading”
Attack: “Arayüz yapacağı şeyi anlatıyor; bana göstermiyor.”
Severity: **HIGH**
Evidence: Workspace descriptions + Recall explanatory blocks.
Disposition: CONFIRMED.

### RT-04 “Unclear differentiated value”
Attack: “Neden genel AI not uygulaması yerine bunu açayım?”
Severity: MEDIUM.
Home/Recall partially answer this through active learning truth, but visual demonstration is weak.
Disposition: PARTIALLY CONFIRMED.

### RT-05 “Not made for me”
Attack from student: “Bir okul/öğrenme aracı ama benim dünyama ait hissettirmiyor.”
Severity: **HIGH**
Disposition: CONFIRMED for visual identity; product function remains relevant.

### RT-06 “Not premium enough”
Attack: “Düzgün ama App Store’da ekran görüntüsünü görünce hemen para verecek kadar özel değil.”
Severity: HIGH for stated ambition.
Disposition: CONFIRMED.

### RT-07 “Mascot mismatch”
Attack: “Karakter başka bir görsel dünyadan gelmiş gibi.”
Severity: MEDIUM-HIGH.
Disposition: CONFIRMED enough to reopen companion.

### RT-08 “No strong return pull”
Attack: “Ne yapacağımı biliyorum ama yarın geri dönme isteğim görsel olarak güçlenmiyor.”
Severity: MEDIUM-HIGH.
Disposition: CONFIRMED.

## Round-0 gate
Automatic VQG failures:
- generic identity risk;
- prototype-like Workspace;
- over-text / under-visual.

Therefore current treatment cannot receive PASS even though engineering and clarity are strong.

## Retest requirements
After treatment prototype:
1. repeat ST-01…ST-10;
2. rerun RT-01…RT-08;
3. add long-title + 1.3×/1.5× text-scale captures;
4. test tired-night-student and rushed-30-second scenarios;
5. require no BLOCKER/HIGH before Founder lock.
