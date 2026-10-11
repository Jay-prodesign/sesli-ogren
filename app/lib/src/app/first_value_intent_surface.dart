import 'package:flutter/material.dart';

import '../domain/learning_contracts.dart';
import 'atelier_learning_surfaces.dart';
import 'companion_view.dart';

class FirstValueIntentSurface extends StatelessWidget {
  const FirstValueIntentSurface({
    required this.material,
    required this.sourceText,
    required this.sourceVersion,
    required this.onReadSource,
    required this.onQuickRecap,
    required this.onRecall,
    required this.onListen,
    required this.onFocus,
    super.key,
  });

  final MaterialRecord material;
  final String sourceText;
  final SourceVersionRecord sourceVersion;
  final VoidCallback onReadSource;
  final VoidCallback onQuickRecap;
  final VoidCallback onRecall;
  final VoidCallback onListen;
  final VoidCallback onFocus;

  bool get _recommendListenFirst => sourceText.trim().replaceAll(RegExp(r'\s+'), ' ').length > 1800;

  String get _recommendationTitle =>
      _recommendListenFirst ? 'Önce genel resmi dinleyerek al.' : 'Önce kaynağın tamamını bir kez gör.';

  String get _recommendationReason => _recommendListenFirst
      ? 'Kaynağın uzun. İlk geçişte yapıyı duymak daha hafif bir başlangıç; sonra kaynağı kapatıp ne kaldığını sınarsın.'
      : 'Kaynağın kısa. Önce bütünü gör; sonra kaynağı kapatıp gerçekten ne kaldığını sınarsın.';

  VoidCallback get _recommendedAction => _recommendListenFirst ? onListen : onReadSource;

  String get _recommendedActionLabel => _recommendListenFirst ? 'Dinlemeye başla' : 'Kaynağı aç';

  void _showOtherPaths(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('Başka bir çalışma yolu'),
                subtitle: Text('Aynı kaynaktasın. Seçimin kalıcı bir mod değil.'),
              ),
              if (_recommendListenFirst)
                ListTile(
                  key: const ValueKey('first-intent-read'),
                  leading: const Icon(Icons.menu_book_outlined),
                  title: const Text('Kaynağı oku'),
                  subtitle: const Text('Tam metni gör ve sonra aktif hatırlamaya geç.'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onReadSource();
                  },
                )
              else
                ListTile(
                  key: const ValueKey('first-intent-listen'),
                  leading: const Icon(Icons.headphones_rounded),
                  title: const Text('Dinle'),
                  subtitle: const Text('Kaynağın genel akışını sesli olarak takip et.'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onListen();
                  },
                ),
              ListTile(
                key: const ValueKey('first-intent-recall'),
                leading: const Icon(Icons.psychology_alt_outlined),
                title: const Text('Bildiğimi kontrol et'),
                subtitle: const Text('Kaynak kapanır; kendi hatırladığınla kısa bir aktif deneme yaparsın.'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onRecall();
                },
              ),
              ListTile(
                key: const ValueKey('first-intent-focus'),
                leading: const Icon(Icons.center_focus_strong_rounded),
                title: const Text('Birlikte odaklanalım'),
                subtitle: const Text('Kaynağın küçük bir bölümünü adım adım çalış.'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onFocus();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < 350 || MediaQuery.textScalerOf(context).scale(1) > 1.25;

    final guideCopy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'İLK 60 SANİYE',
          style: TextStyle(
            color: AtelierStyle.mark,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _recommendationTitle,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 18 : 22,
            height: 1.18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.35,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          _recommendationReason,
          style: const TextStyle(color: Color(0xFFD6DDF0), fontSize: 12.5, height: 1.45),
        ),
      ],
    );

    return ColoredBox(
      key: const ValueKey('first-value-intent'),
      color: AtelierStyle.canvas,
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(21, 14, 21, 34),
          children: [
            Text(
              material.mediaType == SourceMediaType.pdf ? 'PDF KAYNAĞIN HAZIR' : 'KAYNAĞIN HAZIR',
              style: const TextStyle(
                color: AtelierStyle.teal,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              material.title,
              style: TextStyle(
                color: AtelierStyle.ink,
                fontSize: compact ? 22 : 28,
                height: 1.12,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.45,
              ),
            ),
            SizedBox(height: compact ? 9 : 13),
            AtelierSourceTrustStrip(sourceVersion: sourceVersion, showSourceName: !compact),
            SizedBox(height: compact ? 10 : 14),
            const AtelierLearningRail(phase: AtelierLearningPhase.source),
            SizedBox(height: compact ? 12 : 16),
            Container(
              key: const ValueKey('first-value-recommendation-card'),
              padding: EdgeInsets.fromLTRB(18, compact ? 17 : 19, 18, 18),
              decoration: BoxDecoration(
                color: AtelierStyle.focus,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(color: Color(0x1A14224A), blurRadius: 24, offset: Offset(0, 12)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (compact) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: CompanionView(state: CompanionVisualState.think, size: 48),
                    ),
                    const SizedBox(height: 7),
                    guideCopy,
                  ] else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CompanionView(state: CompanionVisualState.think, size: 68),
                        const SizedBox(width: 13),
                        Expanded(child: guideCopy),
                      ],
                    ),
                  SizedBox(height: compact ? 12 : 17),
                  FilledButton.icon(
                    key: const ValueKey('first-intent-recommend'),
                    onPressed: _recommendedAction,
                    style: FilledButton.styleFrom(
                      backgroundColor: AtelierStyle.mark,
                      foregroundColor: AtelierStyle.focus,
                      minimumSize: const Size.fromHeight(54),
                    ),
                    icon: Icon(_recommendListenFirst ? Icons.headphones_rounded : Icons.menu_book_outlined),
                    label: Text(_recommendedActionLabel),
                  ),
                  SizedBox(height: compact ? 7 : 10),
                  const Text(
                    'Bu adım hazırlık. Öğrenme durumun yalnız kaynağı kapatıp kendi Hatırla denemeni yaptığında değişir.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFFB9C5E4), fontSize: 11.5, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
              decoration: BoxDecoration(
                color: AtelierStyle.paper,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: AtelierStyle.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Daha hızlı bir genel bakış mı istiyorsun?',
                    style: TextStyle(color: AtelierStyle.ink, fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 9),
                  OutlinedButton.icon(
                    key: const ValueKey('first-intent-recap'),
                    onPressed: onQuickRecap,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AtelierStyle.teal,
                      minimumSize: const Size.fromHeight(48),
                      side: const BorderSide(color: AtelierStyle.line),
                    ),
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text('Hızlı özetle genel resmi gör'),
                  ),
                  const SizedBox(height: 5),
                  TextButton.icon(
                    key: const ValueKey('first-intent-other-paths'),
                    onPressed: () => _showOtherPaths(context),
                    icon: const Icon(Icons.alt_route_rounded),
                    label: const Text('Diğer çalışma yolları'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Aynı kaynakta kalırsın: Kaynak → Kapat → Hatırla → Kanıt. Yolunu daha sonra değiştirebilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AtelierStyle.muted, fontSize: 11.5, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
