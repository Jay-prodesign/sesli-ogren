import 'package:flutter/material.dart';

import '../domain/learning_contracts.dart';
import '../domain/learning_truth.dart';
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

  static const _canvas = Color(0xFFF5F7F4);
  static const _paper = Color(0xFFFFFDF9);
  static const _ink = Color(0xFF15313A);
  static const _sub = Color(0xFF52696B);
  static const _accent = Color(0xFF0A716A);
  static const _line = Color(0xFFD5E3DC);

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
      NextLearningActionKind.repeatRecallLater => 'Bu deneme tamam. Kaynağın burada.',
      null => 'İlk hatırlama denemeni yap',
    };
  }

  String get _why {
    if (_hasReaderResume) {
      return 'Okuma konumun bu kaynakta kayıtlı. Okumak öğrenme kanıtı oluşturmaz; ardından hatırlamayı deneyebilirsin.';
    }
    if (_hasListenResume) {
      return 'Dinleme konumun bu kaynakta kayıtlı. Dinlemek öğrenme kanıtı oluşturmaz; ardından hatırlamayı deneyebilirsin.';
    }
    return continuation?.nextAction.reasonText ?? 'Kaynağından bir hatırlama denemesiyle ne bildiğini gör.';
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
      NextLearningActionKind.repeatRecallLater => 'Kaynağa dön',
      null => 'Hatırlamayı dene',
    };
  }

  VoidCallback get _nextActionHandler {
    if (_hasReaderResume) return onOpenReader ?? onOpenWorkspace;
    if (_hasListenResume) return onOpenListen;
    return continuation?.nextAction.kind == NextLearningActionKind.repeatRecallLater
        ? onOpenReader ?? onOpenWorkspace
        : onOpenLearning;
  }

  IconData get _nextActionIcon {
    if (_hasReaderResume) return Icons.menu_book_outlined;
    if (_hasListenResume) return Icons.headphones_rounded;
    return continuation?.nextAction.kind == NextLearningActionKind.repeatRecallLater
        ? Icons.auto_stories_outlined
        : Icons.psychology_alt_outlined;
  }

  String? get _evidenceHeadline {
    final state = continuation?.state.kind;
    return switch (state) {
      RecallStateKind.retrievedOnce => 'Bir bağımsız geri çağırma gözlemi var',
      RecallStateKind.developing => 'Bu deneme henüz bağımsız başarı değil',
      RecallStateKind.needsReview => 'Son deneme kaynak onarımı istiyor',
      RecallStateKind.notAssessed => 'Henüz bağımsız geri çağırma kanıtı yok',
      null => null,
    };
  }

  String? get _evidenceDetail {
    final state = continuation?.state.kind;
    return switch (state) {
      RecallStateKind.retrievedOnce => 'Bu tek başına ustalık kanıtı değil. Sonraki bağımsız deneme aynı bilgiyi yeniden kurup kuramadığını gösterecek.',
      RecallStateKind.developing =>
        'İpucu veya kısmi geri çağırma yardımcı oldu; sistem bunu ustalık saymadan ipucusuz tekrarı öne çıkarıyor.',
      RecallStateKind.needsReview =>
        'Yanlış eşleşme bir etiket değil. İlgili kaynak bölümüne dönüp ardından yeniden hatırlayabilirsin.',
      RecallStateKind.notAssessed => 'Bilmiyorum demek veya yanıtı görmek bağımsız geri çağırma sayılmaz; kaynak ve kanıt kaydı birbirinden ayrı tutulur.',
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
                          height: 30,
                          decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(3)),
                        ),
                        const SizedBox(width: 11),
                        const Expanded(
                          child: Text(
                            'sesli öğren',
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            style: TextStyle(
                              fontSize: 19,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kendi kaynağın.\nGerçek hatırlama.',
          key: ValueKey('la0040-atelier-home-promise'),
          style: TextStyle(color: _ink, fontSize: 31, height: 1.05, fontWeight: FontWeight.w900, letterSpacing: -1.2),
        ),
        const SizedBox(height: 9),
        const Text(
          'Kaldığın yer ve sıradaki gerçek adım tek akışta.',
          style: TextStyle(color: _sub, fontSize: 15, height: 1.45),
        ),
        const SizedBox(height: 17),
        Material(
          color: _paper,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const ValueKey('la0040-living-material-open'),
            onTap: onOpenWorkspace,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 15, 14),
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: _accent, width: 3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_stories_outlined, color: _accent, size: 21),
                  const SizedBox(width: 11),
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
                          style: const TextStyle(
                            fontSize: 19,
                            height: 1.18,
                            letterSpacing: -0.35,
                            fontWeight: FontWeight.w900,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: _sub, height: 1.4),
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
        const SizedBox(height: 16),
        Container(
          key: const ValueKey('la0040-source-to-recall-thread'),
          padding: const EdgeInsets.fromLTRB(2, 0, 0, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 62,
                child: CompanionView(
                  state: _hasListenResume
                      ? CompanionVisualState.listen
                      : hasRecallEvidence
                      ? CompanionVisualState.idle
                      : CompanionVisualState.think,
                  size: 60,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasActiveContinuation ? _continuationLabel : 'SIRADAKİ GERÇEK ADIM',
                      style: const TextStyle(
                        color: _accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.9,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Semantics(
                      header: true,
                      label: 'Sıradaki öğrenme adımı',
                      value: _nextStep,
                      child: ExcludeSemantics(
                        child: Text(
                          _nextStep,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 22,
                            height: 1.16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.35,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(_why, style: const TextStyle(color: _sub, fontSize: 13, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
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
                backgroundColor: _ink,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(54),
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
                decoration: BoxDecoration(
                  color: _paper,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: _line),
                ),
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

  Widget _empty(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        header: true,
        child: const Text(
          'Kendi kaynağınla başla.',
          style: TextStyle(color: _ink, fontSize: 32, height: 1.12, fontWeight: FontWeight.w800, letterSpacing: -1.1),
        ),
      ),
      const SizedBox(height: 11),
      const Text(
        'PDF veya metnini getir. Önce kaynağın açılır; öğrenme kanıtını sen hatırlamayı denediğinde oluşturursun.',
        style: TextStyle(fontSize: 16, color: _sub, height: 1.46),
      ),
      const SizedBox(height: 18),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          key: const ValueKey('la0040-living-add'),
          onPressed: onOpenLearning,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Kaynak ekle'),
          style: FilledButton.styleFrom(
            backgroundColor: _ink,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      const SizedBox(height: 18),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(15, 13, 15, 14),
        decoration: BoxDecoration(
          color: _paper,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: _line),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CompanionView(state: CompanionVisualState.idle, size: 58),
            SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'D/Knot kaynağı görünür tutar.',
                    style: TextStyle(color: _ink, fontSize: 14, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Kaynak → oku veya dinle → kapat → hatırla → kanıtla karşılaştır.',
                    style: TextStyle(color: _sub, fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
