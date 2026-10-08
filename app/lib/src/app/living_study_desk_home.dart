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
    if (continuation == null) return 'İlk hatırlama denemeni yap';
    return switch (continuation!.state.kind) {
      RecallStateKind.notAssessed => 'Henüz denemedin',
      RecallStateKind.needsReview => 'Kaynağa dön ve yeniden dene',
      RecallStateKind.developing => 'Bir kez daha hatırlamayı dene',
      RecallStateKind.retrievedOnce => 'Hatırlamanı sağlamlaştır',
    };
  }

  String get _why => continuation?.nextAction.reasonText ?? 'Kaynağından bir hatırlama denemesiyle ne bildiğini gör.';

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
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.9, color: _ink),
                      ),
                    ),
                    const Text(
                      'ÇALIŞMA MASAN',
                      style: TextStyle(color: _sub, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (hasMaterial) ...[
                  const _LivingCompanionHero(),
                  const SizedBox(height: 21),
                ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ŞU AN ÇALIŞTIĞIN KAYNAK',
          key: ValueKey('la0040-atelier-home-promise'),
          style: TextStyle(color: _accent, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1),
        ),
        const SizedBox(height: 13),
        Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(9, 10, 0, 0),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: const Color(0xFFE5EAE4), borderRadius: BorderRadius.circular(17)),
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
                    padding: const EdgeInsets.fromLTRB(22, 18, 20, 18),
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
                        const SizedBox(height: 15),
                        Container(
                          width: 76,
                          height: 4,
                          decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(3)),
                        ),
                        const SizedBox(height: 14),
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
                          maxLines: 3,
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
        const SizedBox(height: 12),
        _LearningJourney(continuation: continuation),
        const SizedBox(height: 12),
        Material(
          color: _paper,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const ValueKey('la0040-living-next-step-open'),
            onTap: onOpenLearning,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 11, 16, 13),
              child: Row(
                children: [
                  const CompanionView(state: CompanionVisualState.think, size: 128),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SIRADAKİ GERÇEK ADIM',
                          style: TextStyle(color: _accent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _nextStep,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 3),
                        Text(_why, style: const TextStyle(color: _sub, fontSize: 13, height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        const Divider(color: _line),
        const SizedBox(height: 12),
        const Text(
          'NASIL DEVAM ETMEK İSTERSİN?',
          style: TextStyle(color: _sub, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('la0040-living-listen'),
                onPressed: onOpenListen,
                icon: const Icon(Icons.headphones_rounded, size: 20),
                label: const Text('Dinle'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accent,
                  minimumSize: const Size.fromHeight(50),
                  side: const BorderSide(color: _accent),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey('la0040-living-recall'),
                onPressed: onOpenLearning,
                icon: const Icon(Icons.psychology_alt_outlined, size: 20),
                label: const Text('Hatırla'),
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
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

/// A truthful learning-path visualization: only recorded recall evidence can
/// mark the last stage as reached. Listening is an action, not a claimed result.
class _LearningJourney extends StatelessWidget {
  const _LearningJourney({required this.continuation});

  final LearningContinuation? continuation;

  @override
  Widget build(BuildContext context) {
    final hasRecallEvidence = continuation != null && continuation!.state.kind != RecallStateKind.notAssessed;
    const deep = Color(0xFF203D48);
    const mint = Color(0xFFBDEBD5);
    return Semantics(
      label: hasRecallEvidence
          ? 'Öğrenme yolculuğu: kaynak hazır, hatırlama denemesi kaydedildi.'
          : 'Öğrenme yolculuğu: kaynak hazır, hatırlama denemesi bekleniyor.',
      child: Container(
        key: const ValueKey('la0040-learning-journey'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 17, 18, 15),
        decoration: BoxDecoration(color: deep, borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ÖĞRENME YOLCULUĞUN',
              style: TextStyle(color: mint, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _step(Icons.menu_book_rounded, 'Kaynak', true),
                _connector(),
                _step(Icons.headphones_rounded, 'Dinle', false),
                _connector(),
                _step(Icons.psychology_alt_rounded, 'Hatırla', hasRecallEvidence),
              ],
            ),
            const SizedBox(height: 13),
            Text(
              hasRecallEvidence
                  ? 'Hatırlama denemen kaydedildi. Sonraki adımını aşağıda gör.'
                  : 'Kaynağın hazır. Dinleyebilir veya hatırlamayı deneyebilirsin.',
              style: const TextStyle(color: Color(0xFFD9E9E4), fontSize: 12, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _connector() => const Expanded(
    child: Padding(
      padding: EdgeInsets.fromLTRB(7, 0, 7, 18),
      child: Divider(color: Color(0xFF78918F), height: 1),
    ),
  );

  Widget _step(IconData icon, String label, bool completed) => Column(
    children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: completed ? const Color(0xFFBDEBD5) : const Color(0xFF365660),
          border: Border.all(color: const Color(0xFF78918F)),
        ),
        child: Icon(icon, size: 20, color: completed ? const Color(0xFF203D48) : const Color(0xFFD9E9E4)),
      ),
      const SizedBox(height: 7),
      Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class _LivingCompanionHero extends StatelessWidget {
  const _LivingCompanionHero();

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('la0040-living-companion-hero'),
    padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
    decoration: BoxDecoration(
      color: const Color(0xFFE7F2EA),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      children: [
        const CompanionView(state: CompanionVisualState.idle, size: 108),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'D/KNOT İLE DEVAM ET',
                style: TextStyle(
                  color: Color(0xFF0A716A),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              SizedBox(height: 7),
              Text(
                'Bugün neyi gerçekten hatırlayacaksın?',
                style: TextStyle(
                  color: Color(0xFF15313A),
                  fontSize: 20,
                  height: 1.2,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 7),
              Text(
                'Kaynağın hazır. Birlikte ilerleyelim.',
                style: TextStyle(color: Color(0xFF52696B), fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
