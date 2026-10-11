import 'package:flutter/material.dart';

import '../domain/learning_contracts.dart';
import '../domain/learning_truth.dart';
import 'app_theme.dart';
import 'atelier_learning_surfaces.dart';
import 'companion_view.dart';

/// Current source-first product experience scope.
///
/// The legacy shell remains available only as an explicit fallback while this
/// unmerged branch is verified. This scope does not imply visual-lock or release approval.
class LivingDeskReviewScope extends InheritedWidget {
  const LivingDeskReviewScope({required super.child, super.key});

  static bool active(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LivingDeskReviewScope>() != null;

  @override
  bool updateShouldNotify(LivingDeskReviewScope oldWidget) => false;
}

/// The learner's REAL material is the main interface object, not a feature menu.
/// This is the active reversible branch implementation; final visual lock and release remain separate gates.
class LivingStudyDeskHome extends StatelessWidget {
  const LivingStudyDeskHome({
    required this.material,
    required this.continuation,
    this.listenResumeChunk = 0,
    this.readerResumeProgress = 0,
    this.readerResumePreferred = false,
    required this.sourceText,
    required this.otherMaterials,
    required this.onOpenWorkspace,
    this.onOpenReader,
    required this.onOpenLearning,
    required this.onOpenListen,
    required this.onOpenMaterial,
    super.key,
  });

  final MaterialRecord? material;
  final LearningContinuation? continuation;
  final int listenResumeChunk;
  final double readerResumeProgress;
  final bool readerResumePreferred;
  final String? sourceText;
  final List<MaterialRecord> otherMaterials;
  final VoidCallback onOpenWorkspace;
  final VoidCallback? onOpenReader;
  final VoidCallback onOpenLearning;
  final VoidCallback onOpenListen;
  final ValueChanged<MaterialId> onOpenMaterial;

  static const _canvas = AppPalette.canvas;
  static const _paper = AppPalette.surface;
  static const _ink = AppPalette.ink;
  static const _sub = AppPalette.inkMuted;
  static const _accent = AppPalette.primary;
  static const _line = AppPalette.outline;

  bool get _hasReaderResume =>
      continuation == null && readerResumePreferred && readerResumeProgress > 0.02 && readerResumeProgress < 0.95;

  bool get _hasListenResume => continuation == null && !_hasReaderResume && listenResumeChunk > 0;

  String get _nextStep {
    if (_hasReaderResume) return 'Okumaya kaldığın yerden devam et';
    if (_hasListenResume) return 'Dinlemeye kaldığın yerden devam et';
    final action = continuation?.nextAction.kind;
    return switch (action) {
      NextLearningActionKind.reviewSourceThenRecall => 'Kaynağa dön, sonra yeniden dene',
      NextLearningActionKind.retryRecallWithoutHint => 'İpucusuz bir kez daha dene',
      NextLearningActionKind.repeatRecallLater => 'Bu tur tamam. Sonra yeniden hatırla.',
      null => 'İlk hatırlama denemeni yap',
    };
  }

  String get _why {
    if (_hasReaderResume) {
      return 'Okuma konumun kayıtlı. Devam et; hazır olduğunda kaynağı kapatıp hatırlamayı dene.';
    }
    if (_hasListenResume) {
      return 'Dinleme konumun kayıtlı. Devam et; hazır olduğunda kaynağı kapatıp hatırlamayı dene.';
    }
    return continuation?.nextAction.reasonText ?? 'Kaynağa bakmadan kısa bir hatırlama denemesi yap.';
  }

  String get _continuationLabel {
    if (_hasReaderResume) return 'OKUMA KONUMUN KAYITLI';
    if (_hasListenResume) return 'DİNLEME KONUMUN KAYITLI';
    if (continuation == null) return 'KAYNAĞINDAN ÖĞREN';
    return continuation!.nextAction.kind == NextLearningActionKind.repeatRecallLater
        ? 'DENEMEN KAYITLI · SONRA YENİDEN HATIRLA'
        : 'DENEMEN KAYITLI · SIRADAKİ ADIM';
  }

  String get _nextActionCta {
    if (_hasReaderResume) return 'Okumaya devam et';
    if (_hasListenResume) return 'Dinlemeye devam et';
    final action = continuation?.nextAction.kind;
    return switch (action) {
      NextLearningActionKind.reviewSourceThenRecall => 'Kaynağı gözden geçir',
      NextLearningActionKind.retryRecallWithoutHint => 'İpucusuz tekrar dene',
      NextLearningActionKind.repeatRecallLater => 'Çalışma alanına dön',
      null => 'Hatırlamayı dene',
    };
  }

  VoidCallback get _nextActionHandler {
    if (_hasReaderResume) return onOpenReader ?? onOpenWorkspace;
    if (_hasListenResume) return onOpenListen;
    return switch (continuation?.nextAction.kind) {
      NextLearningActionKind.reviewSourceThenRecall => onOpenReader ?? onOpenWorkspace,
      NextLearningActionKind.retryRecallWithoutHint => onOpenLearning,
      NextLearningActionKind.repeatRecallLater => onOpenWorkspace,
      null => onOpenLearning,
    };
  }

  IconData get _nextActionIcon {
    if (_hasReaderResume) return Icons.menu_book_outlined;
    if (_hasListenResume) return Icons.headphones_rounded;
    return continuation?.nextAction.kind == NextLearningActionKind.repeatRecallLater
        ? Icons.space_dashboard_outlined
        : Icons.psychology_alt_outlined;
  }

  String? get _evidenceHeadline {
    final state = continuation?.state.kind;
    return switch (state) {
      RecallStateKind.retrievedOnce => 'Kendi başına hatırladın',
      RecallStateKind.developing => 'İpucuyla ilerledin',
      RecallStateKind.needsReview => 'Bu bölüm bir tur daha istiyor',
      RecallStateKind.notAssessed => 'Henüz bağımsız deneme yok',
      null => null,
    };
  }

  String? get _evidenceDetail {
    final state = continuation?.state.kind;
    return switch (state) {
      RecallStateKind.retrievedOnce => 'İlk bağımsız hatırlaman kaydedildi. Kalıcılığı sonraki deneme gösterecek.',
      RecallStateKind.developing =>
        'Bu denemede yardım kullandın. Sıradaki hedef, aynı bilgiyi ipucusuz geri çağırmak.',
      RecallStateKind.needsReview => 'Bu bölüm henüz oturmadı. Kaynağa dönüp kısa bir onarım yap, sonra yeniden dene.',
      RecallStateKind.notAssessed => 'Henüz bağımsız bir hatırlama denemen yok.',
      null => null,
    };
  }

  IconData? get _evidenceIcon {
    final state = continuation?.state.kind;
    return switch (state) {
      RecallStateKind.retrievedOnce => Icons.check_circle_outline_rounded,
      RecallStateKind.developing => Icons.trending_up_rounded,
      RecallStateKind.needsReview => Icons.auto_stories_outlined,
      RecallStateKind.notAssessed => Icons.radio_button_unchecked_rounded,
      null => null,
    };
  }

  String get _preview {
    final source = sourceText?.trim() ?? '';
    if (source.isEmpty) return 'Bu materyalin metin önizlemesi henüz hazır değil.';
    return source.replaceAll(RegExp(r'\s+'), ' ');
  }

  String _type(MaterialRecord m) => m.mediaType == SourceMediaType.pdf ? 'PDF KAYNAĞI' : 'METİN NOTU';

  @override
  Widget build(BuildContext context) {
    final hasMaterial = material != null;
    return ColoredBox(
      color: _canvas,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              key: ValueKey(hasMaterial ? 'la0040-living-home-populated' : 'la0040-living-home-empty'),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 80),
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compactHeader =
                        constraints.maxWidth < 340 || MediaQuery.textScalerOf(context).scale(1) > 1.25;
                    return Row(
                      children: [
                        Container(
                          width: 9,
                          height: compactHeader ? 36 : 30,
                          decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(3)),
                        ),
                        const SizedBox(width: 11),
                        const Expanded(
                          child: Text(
                            'sesli öğren',
                            softWrap: false,
                            style: TextStyle(
                              fontSize: 19,
                              height: 1.2,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.9,
                              color: _ink,
                            ),
                          ),
                        ),
                        if (!compactHeader)
                          const Text(
                            'ÇALIŞMA MASAN',
                            style: TextStyle(color: _sub, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                if (hasMaterial) _populated(context) else _empty(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _populated(BuildContext context) {
    final current = material!;
    final hasRecallEvidence = continuation != null && continuation!.state.kind != RecallStateKind.notAssessed;
    final hasActiveContinuation = continuation != null || _hasReaderResume || _hasListenResume;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final compactFirstViewport = MediaQuery.sizeOf(context).width < 350 && textScale > 1.2;
    final companionState = _hasListenResume
        ? CompanionVisualState.listen
        : hasRecallEvidence
        ? CompanionVisualState.idle
        : CompanionVisualState.think;

    Widget nextStepCopy({required double titleSize, required double reasonSize}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          label: 'Sıradaki öğrenme adımı',
          value: _nextStep,
          child: ExcludeSemantics(
            child: Text(
              _nextStep,
              style: TextStyle(
                color: _ink,
                fontSize: titleSize,
                height: 1.16,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.35,
              ),
            ),
          ),
        ),
        SizedBox(height: compactFirstViewport ? 3 : 5),
        Text(
          _why,
          key: const ValueKey('la0040-home-next-reason'),
          style: TextStyle(color: _sub, fontSize: reasonSize, height: 1.4),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kaldığın yer hazır.',
          key: const ValueKey('la0040-atelier-home-promise'),
          style: TextStyle(
            color: _ink,
            fontSize: compactFirstViewport ? 24 : 31,
            height: 1.05,
            fontWeight: FontWeight.w900,
            letterSpacing: compactFirstViewport ? -0.7 : -1.2,
          ),
        ),
        SizedBox(height: compactFirstViewport ? 5 : 9),
        Text(
          compactFirstViewport
              ? 'Kaynağın ve sıradaki adımın hazır.'
              : 'Kaynağın, son denemen ve sıradaki adım tek yerde.',
          style: TextStyle(color: _sub, fontSize: compactFirstViewport ? 13 : 15, height: 1.4),
        ),
        SizedBox(height: compactFirstViewport ? 10 : 17),
        Material(
          color: _paper,
          elevation: 1,
          shadowColor: const Color(0x140F1F47),
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const ValueKey('la0040-living-material-open'),
            onTap: onOpenWorkspace,
            child: Container(
              width: double.infinity,
              padding: compactFirstViewport
                  ? const EdgeInsets.fromLTRB(13, 10, 12, 10)
                  : const EdgeInsets.fromLTRB(16, 14, 15, 14),
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: _accent, width: 3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.auto_stories_outlined, color: _accent, size: compactFirstViewport ? 19 : 21),
                  SizedBox(width: compactFirstViewport ? 8 : 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _type(current),
                          style: const TextStyle(
                            color: _accent,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.9,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          current.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compactFirstViewport ? 16 : 19,
                            height: 1.18,
                            letterSpacing: -0.35,
                            fontWeight: FontWeight.w900,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _preview,
                          maxLines: compactFirstViewport ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: compactFirstViewport ? 11.5 : 13, color: _sub, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, color: _accent, size: 19),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: compactFirstViewport ? 10 : 16),
        Container(
          key: const ValueKey('la0040-source-to-recall-thread'),
          padding: const EdgeInsets.fromLTRB(2, 0, 0, 0),
          child: compactFirstViewport
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CompanionView(state: companionState, size: 42),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            hasActiveContinuation ? _continuationLabel : 'ŞİMDİ',
                            style: const TextStyle(
                              color: _accent,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    nextStepCopy(titleSize: 17.5, reasonSize: 11.5),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 62, child: CompanionView(state: companionState, size: 60)),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasActiveContinuation ? _continuationLabel : 'ŞİMDİ',
                            style: const TextStyle(
                              color: _accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.9,
                            ),
                          ),
                          const SizedBox(height: 6),
                          nextStepCopy(titleSize: 22, reasonSize: 13),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
        SizedBox(height: compactFirstViewport ? 8 : 12),
        KeyedSubtree(
          key: const ValueKey('la0040-living-next-step-open'),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('la0040-living-continue'),
              onPressed: _nextActionHandler,
              icon: Icon(_nextActionIcon, size: 20),
              label: Text(_nextActionCta),
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                minimumSize: Size.fromHeight(compactFirstViewport ? 48 : 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.center,
          child: TextButton.icon(
            key: const ValueKey('la0040-living-listen'),
            onPressed: (_hasReaderResume || _hasListenResume) ? onOpenLearning : onOpenListen,
            icon: Icon(
              (_hasReaderResume || _hasListenResume) ? Icons.psychology_alt_outlined : Icons.headphones_rounded,
              size: 18,
            ),
            label: Text((_hasReaderResume || _hasListenResume) ? 'Şimdi hatırlamayı dene' : 'Önce dinlemek istiyorum'),
            style: TextButton.styleFrom(foregroundColor: _accent),
          ),
        ),
        if (_evidenceHeadline != null) ...[
          const SizedBox(height: 12),
          Semantics(
            container: true,
            label: 'Öğrenme kanıtı. $_evidenceHeadline. $_evidenceDetail',
            child: ExcludeSemantics(
              child: Container(
                key: const ValueKey('la0040-home-evidence-payoff'),
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
                decoration: BoxDecoration(color: AppPalette.primarySoft, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_evidenceIcon, color: _accent, size: 19),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SON DENEMENDEN',
                            style: TextStyle(
                              color: _accent,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.9,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _evidenceHeadline!,
                            style: const TextStyle(color: _ink, fontSize: 14.5, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 3),
                          Text(_evidenceDetail!, style: const TextStyle(color: _sub, fontSize: 12.5, height: 1.35)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        if (otherMaterials.isNotEmpty) ...[
          const SizedBox(height: 22),
          const Divider(color: _line),
          const SizedBox(height: 13),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Diğer materyallerin',
                  style: TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                'KALDIĞIN YERDEN',
                style: TextStyle(
                  color: _accent.withValues(alpha: 0.82),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          for (final item in otherMaterials.take(3))
            Semantics(
              button: true,
              label: '${item.title} materyalinde kaldığın öğrenme adımına devam et',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  item.mediaType == SourceMediaType.pdf ? Icons.picture_as_pdf_outlined : Icons.notes_rounded,
                  color: _accent,
                ),
                title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: const Text('Sıradaki öğrenme adımını aç'),
                trailing: const Icon(Icons.chevron_right_rounded, color: _sub),
                onTap: () => onOpenMaterial(item.id),
              ),
            ),
        ],
      ],
    );
  }

  Widget _empty(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 340 || MediaQuery.textScalerOf(context).scale(1) > 1.25;
      final companion = Container(
        width: compact ? 58 : 84,
        height: compact ? 58 : 84,
        decoration: BoxDecoration(
          color: AppPalette.primarySoft,
          borderRadius: BorderRadius.circular(compact ? 16 : 20),
        ),
        child: Center(
          child: CompanionView(state: CompanionVisualState.idle, size: compact ? 52 : 74),
        ),
      );
      final promise = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'İLK OTURUM',
            style: TextStyle(color: _accent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Text(
            'Bir sayfa getir.\nBirlikte çalışalım.',
            style: TextStyle(
              color: _ink,
              fontSize: compact ? 25 : 32,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.1,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'PDF ya da metin. Sonra kaynağı kapatıp neyi gerçekten hatırladığını gör.',
            style: TextStyle(color: _sub, fontSize: 14, height: 1.45),
          ),
        ],
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, compact ? 18 : 20, 20, 20),
            decoration: BoxDecoration(
              color: _paper,
              borderRadius: BorderRadius.circular(24),
              border: const Border(left: BorderSide(color: _accent, width: 4)),
              boxShadow: const [BoxShadow(color: Color(0x1014224A), blurRadius: 24, offset: Offset(0, 10))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (compact) ...[
                  Align(alignment: Alignment.centerLeft, child: companion),
                  const SizedBox(height: 12),
                  promise,
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: promise),
                      const SizedBox(width: 14),
                      companion,
                    ],
                  ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  key: const ValueKey('la0040-living-add'),
                  onPressed: onOpenLearning,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('İlk kaynağımı ekle'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'NASIL ÇALIŞIR',
            style: TextStyle(color: _accent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.9),
          ),
          const SizedBox(height: 10),
          const AtelierLearningRail(phase: AtelierLearningPhase.source),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
            decoration: BoxDecoration(color: AppPalette.primarySoft, borderRadius: BorderRadius.circular(16)),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_outlined, color: _accent, size: 19),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Öğrenme durumun yalnız Hatırla denemesinde değişir. Okumak ve dinlemek hazırlıktır.',
                    style: TextStyle(color: _sub, fontSize: 12.5, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}
