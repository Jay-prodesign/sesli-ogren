import 'package:flutter/material.dart';

import '../domain/learning_contracts.dart';
import '../domain/learning_truth.dart';
import 'companion_view.dart';

/// Opt-in runtime review. Never changes the unscoped shipping Home.
class LivingDeskReviewScope extends InheritedWidget {
  const LivingDeskReviewScope({required super.child, super.key});

  static bool active(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LivingDeskReviewScope>() != null;

  @override
  bool updateShouldNotify(LivingDeskReviewScope oldWidget) => false;
}

/// The learner's REAL material is the main interface object, not a feature menu.
/// This is a falsifiable visual candidate, not an approved production design.
class LivingStudyDeskHome extends StatelessWidget {
  const LivingStudyDeskHome({
    required this.material,
    required this.continuation,
    required this.sourceText,
    required this.otherMaterials,
    required this.onOpenWorkspace,
    required this.onOpenLearning,
    required this.onOpenListen,
    required this.onOpenMaterial,
    super.key,
  });

  final MaterialRecord? material;
  final LearningContinuation? continuation;
  final String? sourceText;
  final List<MaterialRecord> otherMaterials;
  final VoidCallback onOpenWorkspace;
  final VoidCallback onOpenLearning;
  final VoidCallback onOpenListen;
  final ValueChanged<MaterialId> onOpenMaterial;

  static const _canvas = Color(0xFFF5F7F4);
  static const _paper = Color(0xFFFFFDF9);
  static const _ink = Color(0xFF15313A);
  static const _sub = Color(0xFF52696B);
  static const _accent = Color(0xFF0A716A);
  static const _line = Color(0xFFD5E3DC);

  String get _nextStep {
    final action = continuation?.nextAction.kind;
    return switch (action) {
      NextLearningActionKind.reviewSourceThenRecall => 'Kaynağa dön, sonra yeniden dene',
      NextLearningActionKind.retryRecallWithoutHint => 'İpucusuz bir kez daha dene',
      NextLearningActionKind.repeatRecallLater => 'Bugünlük tamam. Kaynağın burada.',
      null => 'İlk hatırlama denemeni yap',
    };
  }

  String get _why => continuation?.nextAction.reasonText ?? 'Kaynağından bir hatırlama denemesiyle ne bildiğini gör.';

  String get _continuationLabel {
    if (continuation == null) return 'KAYNAĞINDAN ÖĞREN';
    return continuation!.nextAction.kind == NextLearningActionKind.repeatRecallLater
        ? 'DENEMEN KAYITLI · BUGÜNLÜK TAMAM'
        : 'DENEMEN KAYITLI · SIRADAKİ ADIM';
  }

  String get _nextActionCta {
    final action = continuation?.nextAction.kind;
    return switch (action) {
      NextLearningActionKind.reviewSourceThenRecall => 'Kaynağı gözden geçir',
      NextLearningActionKind.retryRecallWithoutHint => 'İpucusuz tekrar dene',
      NextLearningActionKind.repeatRecallLater => 'Kaynağa dön',
      null => 'Hatırlamayı dene',
    };
  }

  VoidCallback get _nextActionHandler =>
      continuation?.nextAction.kind == NextLearningActionKind.repeatRecallLater ? onOpenWorkspace : onOpenLearning;

  IconData get _nextActionIcon =>
      continuation?.nextAction.kind == NextLearningActionKind.repeatRecallLater
      ? Icons.auto_stories_outlined
      : Icons.psychology_alt_outlined;

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
          'Kaynağı aç. Sonra kapatıp kendi cümlelerinle geri çağır.',
          style: TextStyle(color: _sub, fontSize: 15, height: 1.45),
        ),
        const SizedBox(height: 19),
        Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 9, 0, 0),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: const Color(0xFFE2E9E3), borderRadius: BorderRadius.circular(13)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 8, 9),
              child: Material(
                color: _paper,
                elevation: 0,
                borderRadius: BorderRadius.circular(13),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: const ValueKey('la0040-living-material-open'),
                  onTap: onOpenWorkspace,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(21, 18, 20, 19),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_stories_outlined, color: _accent, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _type(current),
                                style: const TextStyle(
                                  color: _accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.05,
                                ),
                              ),
                            ),
                            const Icon(Icons.north_east_rounded, color: _sub, size: 18),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(width: 66, height: 3, color: _accent),
                        const SizedBox(height: 13),
                        Text(
                          current.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 27,
                            height: 1.1,
                            letterSpacing: -0.8,
                            fontWeight: FontWeight.w900,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Divider(color: _line, height: 1),
                        const SizedBox(height: 13),
                        Text(
                          _preview,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, color: _sub, height: 1.5),
                        ),
                        const SizedBox(height: 17),
                        const Row(
                          children: [
                            Text(
                              'KAYNAĞI AÇ',
                              style: TextStyle(
                                color: _accent,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                letterSpacing: 0.8,
                              ),
                            ),
                            SizedBox(width: 7),
                            Icon(Icons.arrow_forward_rounded, size: 18, color: _accent),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          key: const ValueKey('la0040-source-to-recall-thread'),
          padding: const EdgeInsets.fromLTRB(5, 1, 0, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 74,
                child: Column(
                  children: [
                    Container(width: 2, height: 24, color: _accent),
                    const SizedBox(height: 2),
                    const Icon(Icons.arrow_downward_rounded, color: _accent, size: 19),
                    const SizedBox(height: 1),
                    CompanionView(
                      state: hasRecallEvidence ? CompanionVisualState.idle : CompanionVisualState.think,
                      size: 76,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasRecallEvidence ? _continuationLabel : 'KAYNAĞINDAN ÖĞREN',
                        style: const TextStyle(
                          color: _accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.95,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        _nextStep,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 22,
                          height: 1.16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.35,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(_why, style: const TextStyle(color: _sub, fontSize: 13, height: 1.42)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 13),
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
        const SizedBox(height: 7),
        Align(
          alignment: Alignment.center,
          child: TextButton.icon(
            key: const ValueKey('la0040-living-listen'),
            onPressed: onOpenListen,
            icon: const Icon(Icons.headphones_rounded, size: 18),
            label: const Text('Önce dinlemek istiyorum'),
            style: TextButton.styleFrom(foregroundColor: _accent),
          ),
        ),
        if (otherMaterials.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Divider(color: _line),
          const SizedBox(height: 15),
          const Text(
            'Diğer materyallerin',
            style: TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          for (final item in otherMaterials.take(3))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                item.mediaType == SourceMediaType.pdf ? Icons.picture_as_pdf_outlined : Icons.notes_rounded,
                color: _accent,
              ),
              title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right_rounded, color: _sub),
              onTap: () => onOpenMaterial(item.id),
            ),
        ],
      ],
    );
  }

  Widget _empty(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Kendi kaynağını\ncanlandıralım.',
        style: TextStyle(color: _ink, fontSize: 35, height: 1.12, fontWeight: FontWeight.w800, letterSpacing: -1.3),
      ),
      const SizedBox(height: 13),
      const Text(
        'Bir PDF ya da metin ekle. Okumaya, dinlemeye ve hatırlamaya aynı yerden başla.',
        style: TextStyle(fontSize: 16, color: _sub, height: 1.48),
      ),
      const SizedBox(height: 18),
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const CompanionView(state: CompanionVisualState.idle, size: 148),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Merhaba, ben D/Knot.',
                  style: TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 7),
                Text(
                  'Kaynağını birlikte keşfedelim. Sonra ne kadarını hatırladığını göreceğiz.',
                  style: TextStyle(color: _sub, fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 23, 24, 29),
        decoration: BoxDecoration(
          color: _paper,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.menu_book_outlined, color: _accent, size: 22),
                SizedBox(width: 9),
                Text(
                  'SENİN ÇALIŞMA SAYFAN',
                  style: TextStyle(color: _accent, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.9),
                ),
              ],
            ),
            const SizedBox(height: 29),
            const Text(
              'İlk materyalin\nburada açılacak.',
              style: TextStyle(fontSize: 25, color: _ink, fontWeight: FontWeight.w800, height: 1.17),
            ),
            const SizedBox(height: 25),
            for (var i = 0; i < 3; i++) ...[
              Container(height: 2, width: i == 2 ? 126 : double.infinity, color: _line),
              const SizedBox(height: 15),
            ],
          ],
        ),
      ),
      const SizedBox(height: 23),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          key: const ValueKey('la0040-living-add'),
          onPressed: onOpenLearning,
          icon: const Icon(Icons.add_rounded),
          label: const Text('İlk materyalini ekle'),
          style: FilledButton.styleFrom(
            backgroundColor: _ink,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      const SizedBox(height: 13),
      const Center(
        child: Text('PDF veya kendi metnin', style: TextStyle(color: _sub, fontSize: 13)),
      ),
    ],
  );
}
