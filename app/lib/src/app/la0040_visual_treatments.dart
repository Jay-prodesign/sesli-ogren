import 'package:flutter/material.dart';

import '../domain/learning_contracts.dart';
import '../domain/learning_truth.dart';
import 'companion_view.dart';

/// LA-0040 candidate visuals only. The live app keeps its current UI until a
/// reviewer explicitly installs a treatment scope in the widget tree.
enum LearningVisualTreatment { editorial, studio, knowledge }

/// Keeps each visual experiment coherent across chrome, navigation and routes
/// without changing the production app theme when this scope is absent.
class LearningVisualTreatmentScope extends StatelessWidget {
  const LearningVisualTreatmentScope({required this.treatment, required this.child, super.key});

  final LearningVisualTreatment treatment;
  final Widget child;

  static LearningVisualTreatment? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_TreatmentInherited>()?.treatment;

  @override
  Widget build(BuildContext context) {
    final c = _Colors.of(treatment);
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        scaffoldBackgroundColor: c.paper,
        colorScheme: base.colorScheme.copyWith(
          primary: c.ink,
          onPrimary: Colors.white,
          primaryContainer: c.paper,
          onPrimaryContainer: c.ink,
          secondary: c.accent,
          onSecondary: c.ink,
          surface: c.paper,
          onSurface: c.ink,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: c.paper,
          indicatorColor: (treatment == LearningVisualTreatment.studio ? c.ink : c.accent).withValues(alpha: 0.15),
        ),
      ),
      child: _TreatmentInherited(treatment: treatment, child: child),
    );
  }
}

class _TreatmentInherited extends InheritedWidget {
  const _TreatmentInherited({required this.treatment, required super.child});
  final LearningVisualTreatment treatment;

  @override
  bool updateShouldNotify(_TreatmentInherited oldWidget) => treatment != oldWidget.treatment;
}

String _status(LearningContinuation? c) => switch (c?.state.kind) {
  RecallStateKind.retrievedOnce => 'Bir kez bağımsız hatırlandı',
  RecallStateKind.developing => 'Gelişiyor',
  RecallStateKind.needsReview => 'Tekrar gerekli',
  _ => 'Henüz ölçülmedi',
};

String _outcome(RecallAttemptResult r) => switch (r.evidence.outcome) {
  RecallOutcome.correct when r.evidence.assistance == RecallAssistance.none => 'İpucusuz hatırladın',
  RecallOutcome.helpedCorrect => 'Destekle doğru yanıt',
  RecallOutcome.answerExposed => 'Yanıt gösterildi',
  RecallOutcome.partial => 'Kısmen hatırlandı',
  RecallOutcome.incorrect => 'Tekrar denemen gerekiyor',
  RecallOutcome.unknown => 'Henüz yanıt veremedin',
  _ => 'Yanıtın değerlendirildi',
};

class _Colors {
  const _Colors(this.paper, this.ink, this.accent, this.support);
  final Color paper;
  final Color ink;
  final Color accent;
  final Color support;
  static _Colors of(LearningVisualTreatment lane) => switch (lane) {
    LearningVisualTreatment.editorial => const _Colors(
      Color(0xFFF8F3E9),
      Color(0xFF292B26),
      Color(0xFFB95636),
      Color(0xFF676D62),
    ),
    LearningVisualTreatment.studio => const _Colors(
      Color(0xFFF4F2ED),
      Color(0xFF173139),
      Color(0xFFE2F3AB),
      Color(0xFF587077),
    ),
    LearningVisualTreatment.knowledge => const _Colors(
      Color(0xFFF0F5F1),
      Color(0xFF1B4037),
      Color(0xFF167F67),
      Color(0xFF5F786F),
    ),
  };
}

class _Action extends StatelessWidget {
  const _Action({required this.label, required this.onTap, required this.dark, this.enabled = true});
  final String label;
  final VoidCallback onTap;
  final bool dark;
  final bool enabled;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: dark ? const Color(0xFFE2F3AB) : const Color(0xFF255447),
        foregroundColor: dark ? const Color(0xFF173139) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: enabled ? onTap : null,
      icon: const Icon(Icons.arrow_forward_rounded),
      label: Text(label),
    ),
  );
}

class _Secondary extends StatelessWidget {
  const _Secondary({required this.actions});
  final List<(String, IconData, VoidCallback)> actions;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 5,
    runSpacing: 2,
    children: [
      for (final action in actions)
        TextButton.icon(onPressed: action.$3, icon: Icon(action.$2), label: Text(action.$1)),
    ],
  );
}

class _ThreadRow extends StatelessWidget {
  const _ThreadRow({required this.label, required this.value, required this.ink, required this.accent});
  final String label;
  final String value;
  final Color ink;
  final Color accent;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(height: 60, width: 3, color: accent),
      const SizedBox(width: 15),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 23),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: ink.withValues(alpha: 0.62),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                value,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.3, color: ink),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

/// Real Material/Continuation/Result become distinct compositions; these are
/// not fake status fixtures or palette-only CSS variants.
class LearningTreatmentStage extends StatelessWidget {
  const LearningTreatmentStage({
    required this.lane,
    required this.stage,
    required this.label,
    required this.headline,
    required this.sourceLabel,
    required this.sourceText,
    required this.nextReason,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondary = const [],
    this.outcomeIndependent = false,
    super.key,
  });
  final LearningVisualTreatment lane;
  final String stage;
  final String label;
  final String headline;
  final String sourceLabel;
  final String sourceText;
  final String nextReason;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final List<(String, IconData, VoidCallback)> secondary;
  final bool outcomeIndependent;

  @override
  Widget build(BuildContext context) {
    final c = _Colors.of(lane);
    final source = sourceText.trim().isEmpty ? 'Kaynak hazır' : sourceText.trim();
    final isResult = stage == 'result';
    final isStudio = lane == LearningVisualTreatment.studio;
    final colorForSmall = isStudio ? const Color(0xFFE2F3AB) : c.accent;
    return ColoredBox(
      key: ValueKey('la0040-$stage-${lane.name}'),
      color: c.paper,
      child: ListView(
        shrinkWrap: isResult,
        physics: isResult ? const NeverScrollableScrollPhysics() : null,
        key: stage == 'home' ? const ValueKey('home-surface') : null,
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 42),
        children: [
          if (lane == LearningVisualTreatment.editorial) ...[
            Text(
              'SESLİ ÖĞREN  /  ${stage.toUpperCase()}',
              style: TextStyle(color: c.accent, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.55),
            ),
            const SizedBox(height: 30),
            Text(
              headline,
              style: TextStyle(
                color: c.ink,
                fontSize: 35,
                height: 1.08,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.1,
              ),
            ),
            const SizedBox(height: 16),
            Text(label, style: TextStyle(color: c.support, fontSize: 15)),
            const SizedBox(height: 24),
            Divider(color: c.support.withValues(alpha: 0.5)),
            const SizedBox(height: 18),
            Text(
              sourceLabel.toUpperCase(),
              style: TextStyle(color: c.accent, letterSpacing: 1.1, fontWeight: FontWeight.bold, fontSize: 11),
            ),
            const SizedBox(height: 11),
            Text(
              source,
              maxLines: 7,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c.ink, fontSize: 17, height: 1.45),
            ),
            const SizedBox(height: 28),
            Text(nextReason, style: TextStyle(color: c.ink, fontSize: 18, height: 1.4)),
            const SizedBox(height: 22),
            _Action(label: primaryLabel, onTap: onPrimary, dark: false),
          ] else if (isStudio) ...[
            Row(
              children: [
                Text(
                  'SESLİ ÖĞREN  /  ${stage.toUpperCase()}',
                  style: TextStyle(color: c.ink, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                ),
                const Spacer(),
                if (isResult)
                  CompanionView(
                    state: outcomeIndependent ? CompanionVisualState.success : CompanionVisualState.correct,
                    size: 48,
                  )
                else
                  const CompanionView(state: CompanionVisualState.think, size: 48),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.fromLTRB(23, 26, 23, 24),
              decoration: BoxDecoration(color: c.ink, borderRadius: BorderRadius.circular(29)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      color: colorForSmall,
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    headline,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 35,
                      height: 1.08,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 17),
                  Text(nextReason, style: const TextStyle(color: Color(0xFFD0E2DE), fontSize: 15, height: 1.42)),
                  const SizedBox(height: 27),
                  _Action(label: primaryLabel, onTap: onPrimary, dark: true),
                ],
              ),
            ),
            const SizedBox(height: 29),
            Text(
              sourceLabel.toUpperCase(),
              style: TextStyle(color: c.support, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1),
            ),
            const SizedBox(height: 12),
            Text(
              source,
              maxLines: 7,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c.ink, fontSize: 17, fontWeight: FontWeight.w600, height: 1.4),
            ),
          ] else ...[
            Text(
              'SESLİ ÖĞREN  /  KAYNAK İZİ',
              style: TextStyle(color: c.accent, fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            Text(
              headline,
              style: TextStyle(color: c.ink, fontSize: 31, fontWeight: FontWeight.w800, letterSpacing: -0.8),
            ),
            const SizedBox(height: 28),
            _ThreadRow(label: sourceLabel, value: source, ink: c.ink, accent: c.accent),
            _ThreadRow(label: 'Öğrenme / sonuç durumu', value: label, ink: c.ink, accent: c.accent),
            _ThreadRow(label: 'Bir sonraki eylemin nedeni', value: nextReason, ink: c.ink, accent: c.accent),
            const SizedBox(height: 8),
            _Action(label: primaryLabel, onTap: onPrimary, dark: false),
          ],
          if (secondary.isNotEmpty) ...[
            const SizedBox(height: 24),
            Divider(color: c.support.withValues(alpha: 0.28)),
            const SizedBox(height: 8),
            _Secondary(actions: secondary),
          ],
        ],
      ),
    );
  }
}

class LearningTreatmentHome extends StatelessWidget {
  const LearningTreatmentHome({
    required this.lane,
    required this.material,
    required this.continuation,
    required this.nextTitle,
    required this.nextReason,
    required this.onWorkspace,
    required this.onRecall,
    required this.onListen,
    super.key,
  });
  final LearningVisualTreatment lane;
  final MaterialRecord material;
  final LearningContinuation? continuation;
  final String nextTitle;
  final String nextReason;
  final VoidCallback onWorkspace;
  final VoidCallback onRecall;
  final VoidCallback onListen;
  @override
  Widget build(BuildContext context) => LearningTreatmentStage(
    lane: lane,
    stage: 'home',
    label: _status(continuation),
    headline: nextTitle,
    sourceLabel: 'Kaldığın materyal',
    sourceText: material.title,
    nextReason: nextReason,
    primaryLabel: 'Materyalle devam et',
    onPrimary: onWorkspace,
    secondary: [('Hatırla', Icons.psychology_alt_outlined, onRecall), ('Dinle', Icons.headphones_outlined, onListen)],
  );
}

class LearningTreatmentWorkspace extends StatelessWidget {
  const LearningTreatmentWorkspace({
    required this.lane,
    required this.material,
    required this.excerpt,
    required this.continuation,
    required this.onRecall,
    required this.onListen,
    required this.onExplain,
    required this.onFocus,
    super.key,
  });
  final LearningVisualTreatment lane;
  final MaterialRecord material;
  final String excerpt;
  final LearningContinuation? continuation;
  final VoidCallback onRecall;
  final VoidCallback onListen;
  final VoidCallback onExplain;
  final VoidCallback onFocus;
  @override
  Widget build(BuildContext context) => LearningTreatmentStage(
    lane: lane,
    stage: 'workspace',
    label: _status(continuation),
    headline: material.title,
    sourceLabel: 'Gerçek kaynak metninden',
    sourceText: excerpt,
    nextReason: continuation?.nextAction.reasonText ?? 'İlk hatırlama denemesiyle öğrenme durumunu gör.',
    primaryLabel: 'Kaynaktan hatırla',
    onPrimary: onRecall,
    secondary: [
      ('Dinle', Icons.headphones_outlined, onListen),
      ('Açıkla', Icons.menu_book_outlined, onExplain),
      ('Odaklan', Icons.center_focus_strong_outlined, onFocus),
    ],
  );
}

/// Real, version-bound answer/provenance reveal. No generated relation.
class _GroundedExcerpt extends StatelessWidget {
  const _GroundedExcerpt({required this.answer, required this.excerpt, required this.ink, required this.accent});

  final String answer;
  final String excerpt;
  final Color ink;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final needle = answer.trim();
    final at = needle.isEmpty ? -1 : excerpt.toLowerCase().indexOf(needle.toLowerCase());
    final spans = <TextSpan>[];
    if (at < 0) {
      spans.add(TextSpan(text: excerpt));
    } else {
      spans.add(TextSpan(text: excerpt.substring(0, at)));
      spans.add(
        TextSpan(
          text: excerpt.substring(at, at + needle.length),
          style: TextStyle(color: ink, fontWeight: FontWeight.w900, backgroundColor: accent.withValues(alpha: 0.45)),
        ),
      );
      spans.add(TextSpan(text: excerpt.substring(at + needle.length)));
    }
    return Text.rich(
      TextSpan(children: spans),
      maxLines: 8,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: ink, fontSize: 16, height: 1.5),
    );
  }
}

class LearningTreatmentResult extends StatelessWidget {
  const LearningTreatmentResult({required this.lane, required this.result, required this.onContinue, super.key});

  final LearningVisualTreatment lane;
  final RecallAttemptResult result;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final c = _Colors.of(lane);
    final outcome = _outcome(result);
    final independent =
        result.evidence.outcome == RecallOutcome.correct && result.evidence.assistance == RecallAssistance.none;
    final studio = lane == LearningVisualTreatment.studio;
    final knowledge = lane == LearningVisualTreatment.knowledge;
    return ColoredBox(
      key: ValueKey('la0040-result-${lane.name}'),
      color: c.paper,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (studio)
              Container(
                padding: const EdgeInsets.fromLTRB(23, 21, 23, 25),
                decoration: BoxDecoration(color: c.ink, borderRadius: BorderRadius.circular(25)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'HATIRLAMA / SONUÇ',
                            style: TextStyle(
                              color: Color(0xFFE2F3AB),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        CompanionView(
                          state: independent ? CompanionVisualState.success : CompanionVisualState.correct,
                          size: 56,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      outcome,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        height: 1.08,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      independent
                          ? 'Bu kavramı bir kez bağımsız hatırladın. Ustalık henüz ölçülmedi.'
                          : 'Denemenin sonucu kaydedildi. Kaynağınla karşılaştır.',
                      style: const TextStyle(color: Color(0xFFD0E2DE), fontSize: 14, height: 1.42),
                    ),
                  ],
                ),
              )
            else ...[
              Text(
                knowledge ? 'KAYNAKTAN KANITA' : 'YANITIN / KAYITLI SONUÇ',
                style: TextStyle(color: c.accent, letterSpacing: 1.3, fontWeight: FontWeight.w800, fontSize: 11),
              ),
              const SizedBox(height: 18),
              Text(
                outcome,
                style: TextStyle(color: c.ink, fontSize: 34, height: 1.1, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(
                independent ? 'Bir kez bağımsız hatırlama; henüz ustalık değil.' : 'Bu denemenin kayda geçen sonucu.',
                style: TextStyle(color: c.support, fontSize: 14, height: 1.4),
              ),
            ],
            const SizedBox(height: 29),
            if (knowledge)
              _ThreadRow(
                label: 'Kaynağa dayalı geri bildirim',
                value: result.correctAnswer,
                ink: c.ink,
                accent: c.accent,
              )
            else ...[
              Text(
                'DOĞRU İFADE',
                style: TextStyle(color: c.support, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
              ),
              const SizedBox(height: 10),
              Text(
                result.correctAnswer,
                style: TextStyle(color: c.ink, fontSize: 27, height: 1.12, fontWeight: FontWeight.w800),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'KAYNAKTAKİ YERİ',
              style: TextStyle(color: c.support, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
            ),
            const SizedBox(height: 12),
            _GroundedExcerpt(answer: result.correctAnswer, excerpt: result.sourceExcerpt, ink: c.ink, accent: c.accent),
            const SizedBox(height: 28),
            Divider(color: c.support.withValues(alpha: 0.35)),
            const SizedBox(height: 15),
            Text(
              'ŞİMDİ NE YAPMALI?',
              style: TextStyle(color: studio ? c.ink : c.accent, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
            ),
            const SizedBox(height: 10),
            Text(
              result.nextAction.reasonText,
              style: TextStyle(color: c.ink, fontSize: 17, height: 1.35, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            _Action(label: 'Sıradaki adıma geç', onTap: onContinue, dark: false),
          ],
        ),
      ),
    );
  }
}

/// The actual RecallPrompt from the active SourceVersion drives this stage;
/// no answer, source hint, or expected outcome is created by the visual lane.
class LearningTreatmentRecallPrompt extends StatelessWidget {
  const LearningTreatmentRecallPrompt({
    required this.lane,
    required this.prompt,
    required this.controller,
    required this.busy,
    required this.onSubmit,
    required this.onHint,
    required this.onReveal,
    required this.onUnknown,
    this.supportText,
    this.errorText,
    super.key,
  });
  final LearningVisualTreatment lane;
  final RecallPrompt prompt;
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSubmit;
  final VoidCallback onHint;
  final VoidCallback onReveal;
  final VoidCallback onUnknown;
  final String? supportText;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final c = _Colors.of(lane);
    final studio = lane == LearningVisualTreatment.studio;
    return ColoredBox(
      key: ValueKey('la0040-prompt-${lane.name}'),
      color: c.paper,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (studio)
              Container(
                padding: const EdgeInsets.all(21),
                decoration: BoxDecoration(color: c.ink, borderRadius: BorderRadius.circular(24)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Expanded(
                          child: Text(
                            'KAYNAĞA BAKMADAN',
                            style: TextStyle(color: Color(0xFFE2F3AB), fontSize: 11, letterSpacing: 1.1),
                          ),
                        ),
                        CompanionView(state: CompanionVisualState.think, size: 48),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      prompt.promptText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              )
            else if (lane == LearningVisualTreatment.editorial)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HATIRLA / AÇIK KİTAP YOK',
                    style: TextStyle(color: c.accent, fontSize: 11, letterSpacing: 1.1, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    prompt.promptText,
                    style: TextStyle(color: c.ink, fontSize: 26, height: 1.22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 20),
                  Divider(color: c.support.withValues(alpha: 0.45)),
                ],
              )
            else
              _ThreadRow(label: 'Kaynaktan geri çağır', value: prompt.promptText, ink: c.ink, accent: c.accent),
            const SizedBox(height: 22),
            TextField(
              controller: controller,
              enabled: !busy,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onSubmit(),
              maxLines: 3,
              minLines: 2,
              decoration: const InputDecoration(labelText: 'Kendi yanıtın', border: OutlineInputBorder()),
            ),
            if (supportText != null) ...[
              const SizedBox(height: 9),
              Text(supportText!, style: TextStyle(color: c.support)),
            ],
            if (errorText != null) ...[
              const SizedBox(height: 9),
              Text(errorText!, style: const TextStyle(color: Color(0xFFAA463D))),
            ],
            const SizedBox(height: 18),
            _Action(label: 'Yanıtla', onTap: onSubmit, dark: false, enabled: !busy),
            const SizedBox(height: 13),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                OutlinedButton(onPressed: busy ? null : onHint, child: const Text('İpucu')),
                OutlinedButton(onPressed: busy ? null : onReveal, child: const Text('Yanıtı göster')),
                TextButton(onPressed: busy ? null : onUnknown, child: const Text('Bilmiyorum')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
