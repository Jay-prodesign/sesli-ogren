> **CURRENT V3 CONTINUATION (2026-10-08):** The Home+Reader V2 visual family is now extended to source-hidden Recall and literal-source Result in [LA-0040 four-screen visual review](LA-0040_LIVING_SOURCE_ATELIER_V3_FOUR_SCREEN_VISUAL_REVIEW_2026-10-08.md). V2 remains the underlying first-two-screen design, not the latest overall board. New screens and QA are browser/static prototype ONLY, and visual approval is still PENDING / REWORK. No independent mascot, theme or feature scope was introduced. Previous V2-only next-step wording is historical.

> **V2 VISUAL REVISION — 2026-10-08 (LATEST TWO-SCREEN CONCEPT):** A revised STATIC HTML visual concept and real rendered PNG are available in the current Learning App conversation as `la0040_canli_kaynak_atolyesi_v2.html`, `la0040_canli_kaynak_atolyesi_v2.png`, `la0040_v2_home_screen.png`, `la0040_v2_reader_screen.png`. Changes: eliminate duplicated material title from Home headline (now “Kaldığın yer hazır.” while the actual material title belongs to the source folio); move the unchanged original D/Knot to a smaller, source/action-attached guide placement; convert Home content to independently scrollable region keeping its navigation pinned; remove child-reader bottom tab bar, keep back navigation; convert normalized source text into a genuinely scrollable document zone separate from a compact bottom listening dock (no visual gradient overlay that hides text); retain honest demo-source labeling. **Verified by render-layout script:** both Home and Reader have scrollHeight > clientHeight, reader content bottom does NOT intersect audio dock, and canonical D/Knot base64 bytes equal the GitHub Actions source asset (SHA-256 `4b9e4744cddc2cd6dcf069a97d865f67e62148103f97b82b6830663114bafe76`). This is a *browser-rendered STATIC ART-DIRECTION PROTOTYPE* — no audio plays, no canonical learner data, no actual Flutter routes, no human 3–5s study. **VISUAL ART GATE remains PARTIAL/REWORK; NO FOUNDER LOCK**. Further QA: source overflow on 320px, 1.5× text scale, accessible navigation, independent learning paths, original 128px D/Knot production fidelity and human visual judgement. Keep earlier V1 below as history, not as the current working screenshot.

# LA-0040 — CANLI KAYNAK ATÖLYESİ / Living Source Atelier
## Two-screen art-direction composition — 2026-10-08

**Status:** VISUAL DIRECTION CANDIDATE — **NOT FOUNDER LOCKED, NOT RUNNING FLUTTER**. This is a bounded correction to the art-direction process: solve **Home and Material/Reader** as one visible design world before expanding to Recall/Result and production integration. Keep initial commercial Sesli Öğren product, canonical D/Knot identity, 9–12 initial audience priority (not restriction), existing source/recall contracts and Founder visual approval gate. Earlier generic dark-card, A/B/C, and V3/V4 concepts remain failed or unapproved.

**Visual artifacts in this conversation:**
- `la0040_canli_kaynak_atolyesi_two_screen.png` — actual rendered static visual composition (two distinct full phone screens and art-direction notes).
- `la0040_home_screen_direction.png` and `la0040_reader_screen_direction.png` — exact phone visual crops.
- `la0040_canli_kaynak_atolyesi_two_screen.html` — self-contained concept layout source. HTML is not production UI, not Flutter, not a functional reader/player, and not authorized product data.
- All source content displayed is **DEMO**, not a claim of an existing user's source. Real app must read current `MaterialRecord` and `ExtractedContentRecord.normalizedText`.
- The canonical blue/purple `app/assets/companions/D_KNOT_128.webp` is embedded **byte-identically** from its existing 128×128 original. Verified SHA-256: `4b9e4744cddc2cd6dcf069a97d865f67e62148103f97b82b6830663114bafe76`. No AI replacement mascot. The background abstract paper/ribbon generated for this conceptual board is NOT an approved production asset.

## Focused competitor VISUAL decisions, not marketing/market analysis

1. **Quizlet**: official home-feed design demonstrates high-salience *jump back in* and one next action. [First-party source](https://quizlet.com/), image: `https://images.prismic.io/quizlet-web/aKYZnaTt2nPbai7V_Homefeed.png`. Learning App: current real learner material is visually first. **DO NOT** copy Quizlet colors, layout, completed-percentage badges, art or text.
2. **Speechify**: first-party public screenshot shows source text readable together with a compact playing-control relationship. [First-party reference](https://speechify.com/es/blog/gtts/) showing a reader with player. Learning App: long normalized source remains central and a compact bottom listening dock should not obscure its reading or suggest unsupported word-level synchronization. Exact running reader and listening controller needs Flutter feasibility after visual direction review.
3. **Brilliant**: public app visual references show one meaningful problem/single action, without feature marketing panels. [Public screenshot source](https://www.mobileappdaily.com/product-review/brilliant). Learning App: keep the actual source/Recall interaction as the work, not a four-tool card dashboard. Screenshots may be historical/marketing, not a verified current installed build.

**Research classification:** these are public screenshots; NOT logged-in device interaction or user preference experiments, not complete marketplace superiority evidence. Borrow interaction/visual principles only; never protected expression or code.

## Concrete Home composition

- Compact product identity and one contextual top action.
- Large real-source typography/folio as **one layered document-like working object**; incoming valid sample from user's latest authorized material and actual excerpt, not decorative textbook covers, biology-specific leaves, fake PDF page image or made-up metrics.
- D/Knot appears **once** attached to the working-source focal zone in a calm state, with a meaningful welcome/support role; its source is the unchanged canon. No mascot redesign, no repeated stickers in each card.
- One physically related `Materyale dön` action spans the source surface. Secondary `Dinle` and `Hatırla` entries are compact, with real behavior; library materials lower in hierarchy, bottom nav preserved.
- Empty state is **not shown on this board** and remains an explicit following screen spec before any implementation/lock.
- The source title appears twice on the concept Home (stage headline + mini-paper), which may be overly repetitive; refine typography/hierarchy before lock.
- The visually generated abstract paper motif is subtle and **not subject-specific**; if it becomes visual noise or makes all sources look alike, reduce/remove.

## Concrete Material / Reader composition

- Real title and clear top back navigation; quiet mode rail Oku / Dinle / Açıkla / Odaklan.
- Readable full-width normalized document body using generous line height; no artificially inferred page numbers or chapters.
- Small source-bound line highlight shown in the **DEMO** to indicate visual affordance only. In production highlight requires actual source-derived selection/provenance, not arbitrary AI-yellow markup or false TTS word-sync.
- Bottom audio dock shares the same canvas as the source and provides a clear **play entry**. No fabricated timestamp/progress, player is not claimed active until real playback. Link to Recall names the next action.
- The reader's bottom dock may cover paragraphs on a small phone: **mandatory responsive and keyboard/scroll test** before any acceptance. Toolbar and bottom nav must be adjusted if real app routes differ.
- D/Knot is intentionally absent from this reading state to preserve comprehension and long-session legibility; stateful mascot may reappear later in *honest* Recall/Result.

## Initial visual tokens (CANDIDATE)

| Surface | Hex | Note |
| --- | --- | --- |
| Cloud | `#F0F5F1` | Atmospheric reading base |
| Paper | `#FCFBF6` | Real document stage |
| Ink | `#142B36` | Text, chrome |
| Deep Ink | `#0B333F` | One main action / dock |
| Teal | `#087F78` | Active brand/action |
| Highlight | `#DEEDAE` | Literal source/span only |
| Warm | `#F3B28C` | Sparse context accent |

Inter-like clear UI typography (license/status to verify) plus comfortable editorial source typography, Turkish glyphs verified in static composition; exact font families, text weights and dynamic type are not locked. No oversized dark hero panels, multiple repeated rounded feature cards, made-up source illustrations or fictional progress.

## Explicit self-critique / acceptance gate (existing LA-0040)

| AD gate | Current assessment | Reason / next evidence |
| --- | --- | --- |
| AD-01 Source as hero | **PARTIAL** | Main folio leads Home, long real-looking source leads Reader. Need populated + empty states and long/different actual materials. |
| AD-02 Professional/premium visual identity | **PARTIAL** | Better visual hierarchy and shared canvas than V4; some paper/folio metaphor is still conventional and needs original D/Knot-level visual signature and screen-specific polished details. |
| AD-03 3–5s clear value | **UNTESTED** | No priority learner observations; first-fold appears legible to designer only. |
| AD-04 Learning visible | **PARTIAL** | Read/listen/recall connection exists; no actual runtime sequence, Recall and real source-backed payoff still pending. |
| AD-05 Canonical companion | **SOURCE-VERIFIED / PERCEPTUAL PENDING** | Original byte-identical 128px D/Knot embedded; no proof of premium high-res rendering, state animations or contextual helpfulness. Palette recolor NOT done. |
| AD-06 Data truth | **CONCEPT GATE PASS WITH DEMO MARKING** | No fake XP/scores/timing/page counts in this composition; real source/veracity must be verified at Flutter integration. |
| AD-07 Asset feasibility | **PENDING** | Rendered abstract image and source-native D/Knot not production-qualified for a large native screen; require asset spec and rights, high-res state art before shipment. |
| AD-08 Readability/responsiveness | **NOT RUN** | Need 320 logical width, >=1.3/1.5 scaling, scroll/player/keyboard/reduced motion, type contrast and touch targets. |
| AD-09 Founder approval | **PENDING** | No auto-lock; Founder can request rework or reject. |

**Decision:** This two-screen visual direction is a CANDIDATE; do not call it a design system locked, native app screens or world-class visual proof. Next work (after critical review/Founder signal) should be a **real brand/style refinement of THESE TWO surfaces** and then extend to the source-bound Recall/Result, not another broad theme or market search. After a protected visual decision, derive Flutter layout/asset tasks with tests/QA; keep PR #13 unmerged/unreleased.
