import 'package:flutter/material.dart';

import '../domain/learning_contracts.dart';
import '../domain/learning_truth.dart';

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

  static const _canvas = Color(0xFFF5F4F0);
  static const _paper = Color(0xFFFFFEFA);
  static const _ink = Color(0xFF1C292B);
  static const _sub = Color(0xFF58696A);
  static const _accent = Color(0xFF236B63);
  static const _line = Color(0xFFDDE2DD);

  String get _nextStep {
    if (continuation == null) return 'İlk hatırlama denemeni yap';
    return switch (continuation!.state.kind) {
      RecallStateKind.notAssessed => 'Henüz denemedin',
      RecallStateKind.needsReview => 'Kaynağa dön ve yeniden dene',
      RecallStateKind.developing => 'Bir kez daha hatırlamayı dene',
      RecallStateKind.retrievedOnce => 'Hatırlamanı sağlamlaştır',
    };
  }

  String get _why =>
      continuation?.nextAction.reasonText ??
      'Kaynağından bir hatırlama denemesiyle ne bildiğini gör.';

  String get _preview {
    final source = sourceText?.trim() ?? '';
    if (source.isEmpty) return 'Bu materyalin metin önizlemesi henüz hazır değil.';
    return source.replaceAll(RegExp(r'\\s+'), ' ');
  }

  String _type(MaterialRecord m) =>
      m.mediaType == SourceMediaType.pdf ? 'PDF KAYNAĞI' : 'METİN NOTU';

  @override
  Widget build(BuildContext context) {
    final hasMaterial = material != null;
    return ColoredBox(
      color: _canvas,
      child: ListView(
        key: ValueKey(hasMaterial ? 'la0040-living-home-populated' : 'la0040-living-home-empty'),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 34),
        children: [
          Row(
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
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.9,
                    color: _ink,
                  ),
                ),
              ),
              const Text(
                'ÇALIŞMA MASAN',
                style: TextStyle(color: _sub, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (hasMaterial) _populated(context) else _empty(context),
        ],
      ),
    );
  }

  Widget _populated(BuildContext context) {
    final current = material!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kaldığın yer',
          style: TextStyle(
            color: _ink,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            height: 1.08,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 9),
        const Text(
          'Kendi notlarınla, kaldığın noktadan.',
          style: TextStyle(color: _sub, fontSize: 15, height: 1.35),
        ),
        const SizedBox(height: 24),
        Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(9, 10, 0, 0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5EAE4),
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 9, 10),
              child: Material(
                color: _paper,
                elevation: 0,
                borderRadius: BorderRadius.circular(17),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: const ValueKey('la0040-living-material-open'),
                  onTap: onOpenWorkspace,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(23, 22, 22, 27),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.menu_book_rounded, color: _accent, size: 19),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _type(current),
                                style: const TextStyle(
                                  color: _accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ),
                            const Icon(Icons.north_east_rounded, color: _sub, size: 19),
                          ],
                        ),
                        const SizedBox(height: 21),
                        Text(
                          current.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 27,
                            height: 1.12,
                            letterSpacing: -0.8,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 17),
                        const Divider(color: _line, height: 1),
                        const SizedBox(height: 15),
                        Text(
                          _preview,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, color: _sub, height: 1.52),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            const Text(
                              'MATERYALİ AÇ',
                              style: TextStyle(
                                color: _accent,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                letterSpacing: 0.7,
                              ),
                            ),
                            const SizedBox(width: 7),
                            const Icon(Icons.arrow_forward_rounded, size: 19, color: _accent),
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
        const SizedBox(height: 24),
        const Text(
          'SIRADAKİ GERÇEK ADIM',
          style: TextStyle(fontSize: 11, letterSpacing: 1.25, fontWeight: FontWeight.w800, color: _accent),
        ),
        const SizedBox(height: 10),
        Text(
          _nextStep,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: _ink, height: 1.2),
        ),
        const SizedBox(height: 7),
        Text(
          _why,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _sub, fontSize: 14, height: 1.38),
        ),
        const SizedBox(height: 17),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('la0040-living-continue'),
            onPressed: onOpenWorkspace,
            icon: const Icon(Icons.arrow_forward_rounded, size: 20),
            label: const Text('Çalışmaya devam et'),
            style: FilledButton.styleFrom(
              backgroundColor: _ink,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(53),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 22),
        const Divider(color: _line),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Bu materyalle',
                style: TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
            TextButton.icon(
              key: const ValueKey('la0040-living-recall'),
              onPressed: onOpenLearning,
              icon: const Icon(Icons.psychology_alt_outlined, size: 19),
              label: const Text('Hatırla'),
              style: TextButton.styleFrom(foregroundColor: _accent),
            ),
            const SizedBox(width: 6),
            TextButton.icon(
              key: const ValueKey('la0040-living-listen'),
              onPressed: onOpenListen,
              icon: const Icon(Icons.headphones_rounded, size: 19),
              label: const Text('Dinle'),
              style: TextButton.styleFrom(foregroundColor: _accent),
            ),
          ],
        ),
        if (otherMaterials.isNotEmpty) ...[
          const SizedBox(height: 31),
          const Text(
            'Diğer materyallerin',
            style: TextStyle(color: _ink, fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 11),
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
        'Her şey kendi\nnotlarınla başlar.',
        style: TextStyle(
          color: _ink,
          fontSize: 35,
          height: 1.12,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.3,
        ),
      ),
      const SizedBox(height: 13),
      const Text(
        'Bir PDF ya da metin ekle. Okumaya, dinlemeye ve hatırlamaya aynı yerden başla.',
        style: TextStyle(fontSize: 16, color: _sub, height: 1.48),
      ),
      const SizedBox(height: 30),
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
                  style: TextStyle(
                    color: _accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                  ),
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
