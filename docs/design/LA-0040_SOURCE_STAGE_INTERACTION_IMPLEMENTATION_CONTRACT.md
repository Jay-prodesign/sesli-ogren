> **2026-10-08 COMPETITOR CHALLENGE / DESIGN REQUIREMENT:** [Market+visual UX benchmark](../research/LA-0040_PUBLIC_LEARNING_AUDIO_SUMMARY_UX_BENCHMARK_2026-10-08.md) plus [BM-01…BM-07 QA gate](../qa/LA-0040_VISUAL_QUALITY_GATE.md) control acceptance of Source Stage. **NotebookLM already offers own-source audio and quiz/flashcards**, Quizlet offers short active retrieval, and Speechify/ElevenReader provide mature listen+read controls. Therefore “load PDF, listen, answer one question” is not assumed a differentiated/commercially compelling design. Source Stage must prove a faster-to-understand and more personally meaningful *honest learner evidence+source return* loop in actual uncoached user comparison, not from aesthetic self-scoring. Keep this as a FALSIFIABLE hypothesis; no visual lock, new paid/provider contract or copied UI.

# LA-0040 — SOURCE STAGE / KAYNAK SAHNESİ
## Concrete interaction-first design and implementation contract (2026-10-08)

**Status:** DESIGN HYPOTHESIS / READY FOR A BOUNDED RUNTIME EXPERIMENT **ONLY AFTER Q0 SPEC CHECK**; **NOT** an approved visual direction, completed product redesign, character lock, or production asset PASS.
**Task authority:** Existing LA-0040 second-FAIL corrective spec (S1–S7), current visual quality gate and Founder rejection of **all three** Editorial/Studio/Knowledge treatments. No new task ID. This contract supplies implementation specifics missing from the original failure diagnosis.
**Applicable surfaces:** only one continuous real-data mobile learner session: current material → reading/workspace → Recall → source-backed result → resume. Existing Home, Listen, Explain, Focus, Library and Profile remain working; do not redesign all in this iteration.

## 0. Design decision logic: what drives visual choices

Design must be traceable to:
1. **User need and real source:** Students bring a document and want to turn it into useful learning, not admire dashboards or generic success cards. Context is Turkish high-school-first, learner-owned-material broadly supported.
2. **Actual runnable app contracts:** Flutter MaterialWorkspace loads `MaterialRecord`, `SourceVersionRecord`, `ExtractedContentRecord.normalizedText` and `LearningContinuation`. Recall service supplies `RecallPrompt.promptText`, `SourceAnchor.startOffset/endOffset/pageNumber` and, AFTER submission, `RecallAttemptResult.correctAnswer`, `sourceExcerpt`, `LearnerEvidence`, `LearnerState`, `nextAction`. Do not imply a capability beyond these.
3. **Proven interaction grammar, independently implemented:** distraction-resistant document reading/annotation, active retrieval with sources hidden until commitment, and grounded post-answer feedback. Readwise Reader establishes reader-first highlight patterns; Quizlet Learn establishes explicit retrieval questions, answer commitment and review. **This project may study their interaction principle, not copy proprietary UI expression, assets, screenshots or implementation.** URLs: https://readwise.io/read/ ; https://quizlet.com/features/learn ; https://quizlet.com/features/how-quizlet-works .
4. **Accessibility and readability:** text, focus, target and reduced-motion constraints. WCAG 2.2 concepts are reference criteria adapted to Flutter semantics and Android/iOS, not a claim of web conformance: https://www.w3.org/TR/WCAG22/ ; reading long text needs real text-scale validation.
5. **Our own evidence:** the original 12 screen captures and the Founder's second explicit FAIL show that changing palette, headers and card proportions did NOT solve the product problem. Existing CI remains a correctness baseline, never desirability proof.

**The chosen single IMPLEMENTATION HYPOTHESIS is SOURCE STAGE:** one recognizable study surface turns the user's real source into a spatial journey: **source in view → source intentionally concealed during Recall → actual answer/source revealed together → source revisited with an honest next action**. The visual affordance is the movement/relationship of source and attempt, NOT animated decoration. This hypothesis must be rejected if the resulting Flutter screens still look like a generic card stack; it is not declared a winner now.

## 1. Information architecture and behavioral storyboard

### S0 — Empty / import, only if no active material
- Primary object is an unmistakable material intake slot with only two real ways in: existing PDF picker and paste text; clearly label them.
- Never display fictional demo pages or pretend current learner already has content; use an explicitly identified demo only in offline review fixtures.
- After ingest, open the actual active source version; recoverable errors do not discard the user's prior source.

### S1 — Home / believable return
- Primary visual is the latest **real** material, not a giant abstract promotional card: visible title, source type, honest continuation state and one action `Materyale dön` / `Çalışmaya devam et`.
- If Home needs a text preview, read it from the currently authorized `ExtractedContentRecord` at the current source version. Until that async fetch succeeds, show a truthful skeleton/loading or text-only title. DO NOT generate a summary or fake completion/progress percentage.
- Secondary destinations remain available but subordinate. For multiple documents, the existing library remains real; never promote the last material as the only material.
- The first 3–5 seconds should answer: **What material is this? Where am I? What can I do?** without reading a paragraph of marketing text.

### S2 — Material Workspace / an actual reader, not a tool catalogue
- Full usable viewport is a continuous, readable **source plane** (not three nested round cards). Strong, compact material masthead; small verified `PDF'den çıkarılan metin` or `Yapıştırılan metin` descriptor; real selectable/scrollable normalized source text. It is NOT a page-faithful PDF renderer.
- One quiet, reachable action rail relates to the source: **`Hatırlamayı dene`**; existing Listen/Explain/Focus available as secondary compact actions, not four equal oversized cards. No invented chapter count, “read %”, concept graph, or pre-computed highlights.
- Reader text can occupy most of the viewport; an obvious start of real source must be visible on a 390×844 test immediately, with action reachability maintained via safe-area and scroll. No floating bar may cover source text/selection or block on-screen keyboard.
- Reader may preserve local scroll position while route is mounted, but **must not claim persistent source-position tracking without an existing durable contract**.
- Starting Recall is an intentional learner action *on this material*. The canonical Recall service selects an already defined prompt/anchor; **tapping/selecting arbitrary reader text must NOT imply that a new prompt was generated from that passage**. Selection can support Flutter's native copy affordance only unless independently admitted later.

### S3 — Recall / source deliberately folded away
- Same source identity remains legible in a slim masthead, preserving spatial continuity; do NOT display source sentence or any answer hint before unaided submission. Source plane recedes/conceals; in its place one **question-as-task** occupies the focal region (not a menu tile).
- Show `RecallPrompt.promptText`, focused answer composition using existing `TextEditingController`, one clear `Yanıtla` action and accessible `İpucu`, `Yanıtı göster`, `Bilmiyorum` paths. No false timer/streak or mastery meter. Controls remain reachable above keyboard.
- Hint and reveal use the actual assistive service and alter canonical assistance; UI must clearly disclose assistance and never equate hinted or exposed answer with unaided retrieval.
- Switching states should be legible in reduced motion. Suggested **review-only** 180–240ms restrained source-fold/answer-sheet morph is optional; with reduced motion, use immediate equivalently clear state changes. Prefer conventional accessible transitions over bespoke animation framework.
- Back/close and interruption must preserve/recover canonical attempt according to current service; never fabricate attempt durability from a transient animation.

### S4 — Result / the one distinctive earned payoff
- Keep the learner's **current attempt** and the **actual source** in spatial relation: on a mobile screen use a two-track vertical comparison (own response or assistance status, then specific source excerpt); do NOT cram two full text columns into 320px.
- First trace: “what I tried” (transient in-memory entered response, or an explicit unknown/answer-exposed label). Second trace: “what the real source said” (`sourceExcerpt` with `correctAnswer` inline-highlighted **only when the literal matching span exists**). Third trace: canonical outcome and next-action reason, with one clearly prioritized return action.
- The canonical stored `LearnerEvidence` contains normalized answer **digest and length, not the raw free-text response**. Showing the typed response is allowed only from live transient UI state **in the current attempt**, never invented or recovered from persisted learner data. After restart, do not claim to replay the exact typed words. For `answerExposed`, do not label the prefilled revealed answer “your answer”; for `unknown`, show `Bilmiyorum dedin`, not a fabricated empty answer.
- Source relationship is version-bound: sourceId and anchor must match prompt/result. If exact highlight fails, show an unhighlighted excerpt and honest label rather than a fabricated match.
- State-specific copy respects `RecallOutcome` and `RecallAssistance`: correct/none may say **one independent retrieval**, NOT mastery; hint/answerExposed/unknown/incorrect/partial never get the unaided badge. The consequence is credible feedback, not fireworks.
- A **single spatial reveal** can animate the source excerpt reopening at the correct location; no rotating cards, confetti, artificial “brain charging”, synthetic points, or success fireworks. The payoff should still work in a still image and with animation disabled.

### S5 — Resume / return to real work
- One real next action from `NextLearningAction.reasonText`; clear way to return to the source and retry/review. Updated `LearningContinuation` is durable; no fabricated long-term mastery, recommended time or schedule.
- After app close/reopen, show genuinely persisted continuation; user-written full response is not reconstructed from its digest.

## 2. One consistent visual grammar — non-binding tokens for first candidate

- **Composition first**: source typography and interaction are primary. Use one persistent visual metaphor, a readable document plane with a minimal peripheral tool rail and an answer layer that folds over/away from it. Home visually points back to this same source plane.
- **No card-grid default**: remove the repeated 4-up mode chooser from the tested core flow and the giant dark Studio hero. Where a container exists, it signifies a real interactive layer (source/answer/proof), not decoration.
- **Text hierarchy:** draft implementation targets, not locks: source reading body ~17–19sp, line height ~1.45–1.6; question ~24–30sp; material title ~22–28sp; metadata ~12–14sp; body paragraphs with sane line lengths, never artificially truncated during reading. Scaled text must reflow.
- **Space/hierarchy:** at 390 logical px, content gutter ~16–20px; compact safe-area aware top rail; one 48px+ dominant action; touch surfaces aim >=44–48 logical px even though WCAG web target minimum is lower. Don't set fixed-height parent containers around long text.
- **Color/texture:** one quiet light reading ground and dark text, a **single accent used for meaningful focus / grounded answer**; error/help/unknown need labels and pattern, not color alone. Exact palette not locked until actual runtime readability and Founder review. No gradient soup, random colorful chips or unrelated illustrations.
- **Character rule:** canonical D/Knot is NOT required on every surface. Show it only when one real behavior helps orientation/feedback and if its approved asset quality fits runtime; otherwise omit. No new character and no copying assets across projects.
- **Asset spec/sequence:** first inspect repo-owned approved art, fonts and existing rendering; classify reference vs production. For any missing signature visual element, state its exact learning role, source/provenance, intended screen region, required states and preprocessing needs BEFORE acquiring/generating. A test mockup is not integrated production art.
- **Platform:** implementation is bounded and reversible via the existing scoped visual review mechanism. Keep all source, learner, persistence, TTS and existing baseline behaviors unchanged. No generic theme-engine package, data migrations or new providers.

## 3. Exact Flutter integration map, not an imaginary architecture

1. `product_shell_screen.dart`: extend current `_HomeSnapshot` as needed to show authorized source preview; keep current tab/nav semantics and empty/multi-material states.
2. `material_workspace_screen.dart`: use its real `_WorkspaceSnapshot(material, source, extracted, continuation)`, replace ONLY the opt-in review candidate workspace with a real long-source reader and compact actionable rail. Do not replace current production view yet.
3. `learning_slice_screen.dart`: reuse `_openRecall`, `_requestHint`, `_revealAnswer`, `_submit`, `_continuation` and callback semantics. Add review-only source-fold/attempt/result widgets without changing canonical truth service. Pass only already available fields; when passing transient typed answer, ensure unknown and answer-exposed paths are labelled correctly and no analytics/persistence of raw text.
4. `recall_learning_service.dart`: read-only contract authority for `RecallPrompt.anchor`, `RecallAttemptResult.sourceExcerpt` and canonical outcome; any requested generator change is OUT OF SCOPE until explicitly admitted on evidence.
5. `la0040_visual_treatments.dart`: old three treatments remain opt-in rejected regression controls. New review-only implementation may be a concrete separate widget/file; do not invent a generalized treatment framework. Production look untouched absent opt-in scope.
6. Flutter tests: derive a real, longer legally usable fixture from project-owned test content, not invented biographies or copied textbook pages; add tests for source identity, source concealing during Recall, truthful result, real action callback, transient answer privacy, and exact anchor fallback.

**Feasibility note:** This app currently stores normalized extracted PDF text, not a visually faithful original PDF page. Don't promise paper-page thumbnail layout, exact PDF typography or selection-based question generation without new bounded product/technical admission.

## 4. Visual hypothesis failure criteria BEFORE implementation expansion

Stop, reject/rework if any of these occur:
- **F1:** removing name and palette makes new screen indistinguishable in structure from the rejected large-header/card/button skins;
- **F2:** source does not command the working area; users cannot actually read/scroll source before Recall, or answer is visible during supposedly unaided retrieval;
- **F3:** result cannot visibly connect the specific prompt/attempt with its exact source-backed answer and honest next-action reason;
- **F4:** companion remains decoration, or learning value depends on gradient/motion rather than actual visible work;
- **F5:** source and answer are misrepresented, stale source version leaks, or synthetic achievement/progress appears;
- **F6:** keyboard/scroll/safe-area/narrow viewport/text scale breaks the primary action or focus;
- **F7:** testing stops at static screenshot/formatter PASS without actual interactions and Founder perception.

**Evidence threshold:** One representative real Flutter Home→reader→Recall→result→continue screen+short motion packet showing the *same real material* and negative outcomes, before broad system rollout. Founder and uncoached learner observations are necessary for product-level acceptance; engineering gate is necessary but not sufficient.

## 5. Implementation sequence and handoff boundaries

- **I0 — existing asset/runtime inventory (bounded, same task):** verify required assets, source reader availability, transient response and route constraints. Mark holes. No broad restart audit.
- **I1 — core workspace first:** implement source-first reader/rail on existing opt-in review scope with real longer source, reliable scroll, a visible action that opens canonical Recall.
- **I2 — conceal/reveal loop:** wire focused Recall layer and source-grounded result; the user should understand source↔answer relationship from actual transitions.
- **I3 — home/return:** make Home lead to this real workspace and preserve truthful continuation.
- **I4 — focused negative/accessibility/perceptual QA:** apply current VQG and its implementation matrix; only expand beyond core slice once a *real captured design* earns Founder attention.

**Do not** mark implementation PASS at spec creation. No merge, release, deployment, generated fake curriculum, provider spend, cross-project reuse or final character redesign is authorized by this contract.
