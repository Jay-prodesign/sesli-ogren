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

  String get _recommendationTitle => 'Önce kaynağı bir kez gör.';

  String get _recommendationReason => 'Önce bütünü gör. Sonra kaynağı kapatıp ne kaldığını sınarsın.';

  VoidCallback get _recommendedAction => onReadSource;

  String get _recommendedActionLabel => 'Kaynağı aç';

  IconData get _recommendedActionIcon => Icons.menu_book_outlined;

  void _showOtherPaths(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.82),
          child: ListView(
            key: const ValueKey('first-intent-other-paths-scroll'),
            primary: false,
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
            children: [
              const ListTile(
                title: Text('Başka bir yol seç'),
                subtitle: Text('Aynı kaynakta kalırsın. Seçimin kalıcı değil.'),
              ),
              ListTile(
                key: const ValueKey('first-intent-listen'),
                leading: const Icon(Icons.headphones_rounded),
                title: const Text('Dinle'),
                subtitle: const Text('Kaynağı sesli takip et.'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onListen();
                },
              ),
              ListTile(
                key: const ValueKey('first-intent-recap'),
                leading: const Icon(Icons.auto_awesome_outlined),
                title: const Text('Hızlı özet'),
                subtitle: const Text('Kısa genel bakış al; bu kanıt değildir.'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onQuickRecap();
                },
              ),
              ListTile(
                key: const ValueKey('first-intent-recall'),
                leading: const Icon(Icons.psychology_alt_outlined),
                title: const Text('Bildiğimi kontrol et'),
                subtitle: const Text('Kaynak kapanır; kendi hatırladığınla denersin.'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onRecall();
                },
              ),
              ListTile(
                key: const ValueKey('first-intent-focus'),
                leading: const Icon(Icons.center_focus_strong_rounded),
                title: const Text('Birlikte odaklanalım'),
                subtitle: const Text('Küçük bir bölümü adım adım çalış.'),
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
    final width = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final compact = width < 350 || textScale > 1.25;
    final tightCompact = width < 350 && textScale > 1.2;
    const compactReason = 'Önce bütünü gör; sonra kaynağı kapatıp ne kaldığını sınarsın.';

    final guideCopy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!tightCompact) ...[
          const Text(
            'İLK 60 SANİYE',
            style: TextStyle(color: AtelierStyle.mark, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
          const SizedBox(height: 6),
        ],
        Text(
          _recommendationTitle,
          style: TextStyle(
            color: Colors.white,
            fontSize: tightCompact
                ? 16
                : compact
                ? 18
                : 22,
            height: 1.16,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.35,
          ),
        ),
        SizedBox(height: tightCompact ? 4 : 7),
        Text(
          tightCompact ? compactReason : _recommendationReason,
          style: TextStyle(
            color: const Color(0xFFD6DDF0),
            fontSize: tightCompact ? 11 : 12.5,
            height: tightCompact ? 1.35 : 1.45,
          ),
        ),
      ],
    );

    return ColoredBox(
      key: const ValueKey('first-value-intent'),
      color: AtelierStyle.canvas,
      child: SafeArea(
        top: false,
        child: ListView(
          padding: tightCompact ? const EdgeInsets.fromLTRB(16, 8, 16, 26) : const EdgeInsets.fromLTRB(21, 14, 21, 34),
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
                fontSize: tightCompact
                    ? 19
                    : compact
                    ? 22
                    : 28,
                height: 1.12,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.45,
              ),
            ),
            SizedBox(
              height: tightCompact
                  ? 6
                  : compact
                  ? 9
                  : 13,
            ),
            AtelierSourceTrustStrip(sourceVersion: sourceVersion, showSourceName: !compact),
            SizedBox(
              height: tightCompact
                  ? 8
                  : compact
                  ? 11
                  : 15,
            ),
            Container(
              key: const ValueKey('first-value-recommendation-card'),
              padding: tightCompact
                  ? const EdgeInsets.fromLTRB(14, 11, 14, 12)
                  : EdgeInsets.fromLTRB(18, compact ? 17 : 19, 18, 18),
              decoration: BoxDecoration(
                color: AtelierStyle.focus,
                borderRadius: BorderRadius.circular(tightCompact ? 18 : 22),
                boxShadow: const [BoxShadow(color: Color(0x1A14224A), blurRadius: 24, offset: Offset(0, 12))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (tightCompact) ...[
                    const Row(
                      children: [
                        CompanionView(
                          key: ValueKey('first-intent-companion'),
                          state: CompanionVisualState.think,
                          size: 52,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'İLK 60 SANİYE',
                            style: TextStyle(
                              color: AtelierStyle.mark,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.9,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    guideCopy,
                  ] else if (compact) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: CompanionView(
                        key: ValueKey('first-intent-companion'),
                        state: CompanionVisualState.think,
                        size: 68,
                      ),
                    ),
                    const SizedBox(height: 7),
                    guideCopy,
                  ] else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CompanionView(
                          key: ValueKey('first-intent-companion'),
                          state: CompanionVisualState.think,
                          size: 88,
                        ),
                        const SizedBox(width: 13),
                        Expanded(child: guideCopy),
                      ],
                    ),
                  SizedBox(
                    height: tightCompact
                        ? 8
                        : compact
                        ? 12
                        : 17,
                  ),
                  FilledButton.icon(
                    key: const ValueKey('first-intent-recommend'),
                    onPressed: _recommendedAction,
                    style: FilledButton.styleFrom(
                      backgroundColor: AtelierStyle.pulse,
                      foregroundColor: Colors.white,
                      minimumSize: Size.fromHeight(tightCompact ? 46 : 54),
                    ),
                    icon: Icon(_recommendedActionIcon),
                    label: Text(_recommendedActionLabel),
                  ),
                  SizedBox(
                    height: tightCompact
                        ? 5
                        : compact
                        ? 7
                        : 10,
                  ),
                  Text(
                    'Hatırla denemesi öğrenme kanıtını oluşturur.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: const Color(0xFFB9C5E4), fontSize: tightCompact ? 10.5 : 11.5, height: 1.4),
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
                    'Dinleyerek hazırlan',
                    style: TextStyle(color: AtelierStyle.ink, fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 9),
                  OutlinedButton.icon(
                    key: const ValueKey('first-intent-listen-direct'),
                    onPressed: onListen,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AtelierStyle.teal,
                      minimumSize: const Size.fromHeight(48),
                      side: const BorderSide(color: AtelierStyle.line),
                    ),
                    icon: const Icon(Icons.headphones_rounded),
                    label: const Text('Kaynağı dinle'),
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

          ],
        ),
      ),
    );
  }
}
