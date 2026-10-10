import 'package:flutter/material.dart';

import '../domain/learning_contracts.dart';
import '../domain/learning_truth.dart';
import 'companion_view.dart';
import 'source_text_matching.dart';

/// One source-led art direction across Reader, Recall and Result.
/// Source/learning models and outcome classification stay canonical.
abstract final class AtelierStyle {
  static const canvas = Color(0xFFF5F7F4);
  static const paper = Color(0xFFFFFDF9);
  static const ink = Color(0xFF15313A);
  static const teal = Color(0xFF0A716A);
  static const muted = Color(0xFF52696B);
  static const line = Color(0xFFD5E3DC);
  static const mint = Color(0xFFE8F3EC);
  static const mark = Color(0xFFE0F0AF);
}

class AtelierSourceTrustStrip extends StatelessWidget {
  const AtelierSourceTrustStrip({required this.sourceVersion, this.showSourceName = true, super.key});

  final SourceVersionRecord sourceVersion;
  final bool showSourceName;

  String get _ownershipLabel {
    final identity = sourceVersion.identity;
    if (identity.trustClass == SourceTrustClass.userProvided &&
        identity.knowledgeClass == SourceKnowledgeClass.learnerOwned) {
      return 'KENDİ KAYNAĞIN';
    }
    if (identity.trustClass == SourceTrustClass.authoritativeReference) {
      return 'GÜVENİLİR KAYNAK';
    }
    return 'KAYNAK';
  }

  String get _mediaLabel => sourceVersion.mediaType == SourceMediaType.pdf ? 'PDF' : 'METİN';

  @override
  Widget build(BuildContext context) {
    final versionLabel = sourceVersion.isCurrent ? 'GÜNCEL SÜRÜM' : 'ÖNCEKİ SÜRÜM';
    return Semantics(
      container: true,
      label:
          '${sourceVersion.sourceName}. $_ownershipLabel. $versionLabel. Öğrenme kanıtı bu kaynak sürümüne bağlıdır.',
      child: ExcludeSemantics(
        child: Container(
          key: const ValueKey('atelier-source-trust'),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
          decoration: BoxDecoration(
            color: AtelierStyle.mint,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AtelierStyle.line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.verified_user_outlined, color: AtelierStyle.teal, size: 19),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_ownershipLabel · $_mediaLabel · $versionLabel',
                      style: const TextStyle(
                        color: AtelierStyle.teal,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (showSourceName) ...[
                      const SizedBox(height: 4),
                      Text(
                        sourceVersion.sourceName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AtelierStyle.ink, fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                    ],
                    const SizedBox(height: 3),
                    const Text(
                      'Hatırlama ve kaynak kanıtı bu sürümle ilişkilendirilir.',
                      style: TextStyle(color: AtelierStyle.muted, fontSize: 12, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AtelierWorkspace extends StatelessWidget {
  const AtelierWorkspace({
    required this.material,
    required this.sourceText,
    this.sourceVersion,
    required this.continuation,
    required this.onReadSource,
    required this.onQuickRecap,
    required this.onRecall,
    required this.onListen,
    required this.onExplain,
    required this.onFocus,
    super.key,
  });

  final MaterialRecord material;
  final String sourceText;
  final SourceVersionRecord? sourceVersion;
  final LearningContinuation? continuation;
  final VoidCallback onReadSource;
  final VoidCallback onQuickRecap;
  final VoidCallback onRecall;
  final VoidCallback onListen;
  final VoidCallback onExplain;
  final VoidCallback onFocus;

  String get _activeStepTitle {
    final action = continuation?.nextAction.kind;
    return switch (action) {
      NextLearningActionKind.reviewSourceThenRecall => 'Kaynak onarımın hazır',
      NextLearningActionKind.retryRecallWithoutHint => 'İpucusuz tekrarın hazır',
      NextLearningActionKind.repeatRecallLater => 'Bugünlük planın hazır',
      null => 'İlk aktif denemeni yap',
    };
  }

  String get _activeStepReason {
    final action = continuation?.nextAction;
    if (action != null) return action.reasonText;
    return 'Okumak ve dinlemek hazırlık adımıdır. İlk öğrenme kanıtın kaynağı kapatıp hatırlamayı denediğinde oluşur.';
  }

  String get _activeStepLabel {
    return switch (continuation?.nextAction.kind) {
      NextLearningActionKind.reviewSourceThenRecall => 'Kaynağı gözden geçir',
      NextLearningActionKind.retryRecallWithoutHint => 'İpucusuz tekrar dene',
      NextLearningActionKind.repeatRecallLater => 'Devam planını aç',
      null => 'Kaynağı kapat · Hatırla',
    };
  }

  IconData get _activeStepIcon {
    return switch (continuation?.nextAction.kind) {
      NextLearningActionKind.reviewSourceThenRecall => Icons.auto_stories_outlined,
      NextLearningActionKind.retryRecallWithoutHint => Icons.refresh_rounded,
      NextLearningActionKind.repeatRecallLater => Icons.event_available_outlined,
      null => Icons.psychology_alt_outlined,
    };
  }

  String get _sourcePreview {
    final normalized = sourceText.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length <= 640) return normalized;
    return '${normalized.substring(0, 637).trimRight()}…';
  }

  bool get _sourcePreviewIsTrimmed => sourceText.trim().replaceAll(RegExp(r'\s+'), ' ').length > 640;

  @override
  Widget build(BuildContext context) {
    final compactSurface =
        MediaQuery.sizeOf(context).width < 340 || MediaQuery.textScalerOf(context).scale(1) > 1.25;
    return ColoredBox(
      key: const ValueKey('la0040-atelier-workspace'),
    color: AtelierStyle.canvas,
    child: Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(21, 13, 21, 25),
            children: [
              Text(
                material.mediaType == SourceMediaType.pdf ? 'PDF KAYNAĞI' : 'KENDİ METNİN',
                style: const TextStyle(
                  color: AtelierStyle.teal,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                material.title,
                style: const TextStyle(
                  color: AtelierStyle.ink,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  height: 1.14,
                ),
              ),
              if (sourceVersion != null) ...[
                const SizedBox(height: 14),
                AtelierSourceTrustStrip(sourceVersion: sourceVersion!),
              ],
              const SizedBox(height: 17),
              if (sourceText.trim().isNotEmpty) ...[
                const AtelierLearningRail(phase: AtelierLearningPhase.source),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: const ValueKey('la0040-atelier-workspace-reader'),
                      onPressed: onReadSource,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AtelierStyle.teal,
                        backgroundColor: AtelierStyle.paper,
                        side: const BorderSide(color: AtelierStyle.line),
                      ),
                      icon: const Icon(Icons.menu_book_outlined),
                      label: const Text('Tam metni oku'),
                    ),
                    TextButton.icon(
                      key: const ValueKey('la0040-atelier-workspace-recap'),
                      onPressed: onQuickRecap,
                      style: TextButton.styleFrom(foregroundColor: AtelierStyle.teal),
                      icon: const Icon(Icons.auto_awesome_outlined),
                      label: const Text('Hızlı özet'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              if (compactSurface) ...[
                const SizedBox(height: 10),
                Container(
                  key: const ValueKey('la0040-atelier-compact-action-context'),
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
                  decoration: BoxDecoration(
                    color: AtelierStyle.mint,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AtelierStyle.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(_activeStepIcon, color: AtelierStyle.teal, size: 18),
                          const SizedBox(width: 7),
                          const Expanded(
                            child: Text(
                              'SIRADAKİ GERÇEK ADIM',
                              style: TextStyle(
                                color: AtelierStyle.teal,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _activeStepTitle,
                        style: const TextStyle(
                          color: AtelierStyle.ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _activeStepReason,
                        style: const TextStyle(color: AtelierStyle.muted, fontSize: 12.5, height: 1.4),
                      ),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          OutlinedButton.icon(
                            key: const ValueKey('la0040-atelier-workspace-listen'),
                            onPressed: onListen,
                            icon: const Icon(Icons.headphones_rounded),
                            label: const Text('Dinle'),
                          ),
                          TextButton.icon(
                            onPressed: onExplain,
                            icon: const Icon(Icons.record_voice_over_outlined),
                            label: const Text('Açıkla'),
                          ),
                          TextButton.icon(
                            onPressed: onFocus,
                            icon: const Icon(Icons.center_focus_strong),
                            label: const Text('Odaklan'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              const Divider(color: AtelierStyle.line),
              const SizedBox(height: 14),
              if (sourceText.trim().isEmpty)
                const Text(
                  'Bu kaynağın metni henüz okunamıyor.',
                  style: TextStyle(color: AtelierStyle.muted, fontSize: 16),
                )
              else
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 30),
                  decoration: const BoxDecoration(
                    color: AtelierStyle.paper,
                    border: Border(left: BorderSide(color: AtelierStyle.teal, width: 3)),
                    boxShadow: [BoxShadow(color: Color(0x0B15313A), blurRadius: 18, offset: Offset(0, 8))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.auto_stories_outlined, color: AtelierStyle.teal, size: 17),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'KAYNAK ÖNİZLEMESİ',
                              softWrap: true,
                              style: TextStyle(
                                color: AtelierStyle.teal,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 17),
                      SelectableText(
                        _sourcePreview,
                        style: const TextStyle(color: AtelierStyle.ink, fontSize: 18, height: 1.65),
                      ),
                      if (_sourcePreviewIsTrimmed) ...[
                        const SizedBox(height: 14),
                        const Text(
                          'Bu yalnızca önizleme. Kaynağın tamamı “Tam metni oku” ile Reader’da açılır.',
                          style: TextStyle(color: AtelierStyle.muted, fontSize: 12, height: 1.35),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(17, 12, 17, 14),
          decoration: const BoxDecoration(
            color: AtelierStyle.ink,
            borderRadius: BorderRadius.vertical(top: Radius.circular(21)),
          ),
          child: compactSurface
              ? FilledButton.icon(
                  key: const ValueKey('la0040-atelier-workspace-recall'),
                  onPressed: onRecall,
                  style: FilledButton.styleFrom(
                    backgroundColor: AtelierStyle.mark,
                    foregroundColor: AtelierStyle.ink,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  icon: Icon(_activeStepIcon),
                  label: Text(_activeStepLabel),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
              Row(
                children: [
                  Icon(_activeStepIcon, color: AtelierStyle.mark, size: 18),
                  const SizedBox(width: 7),
                  const Text(
                    'SIRADAKİ GERÇEK ADIM',
                    style: TextStyle(
                      color: AtelierStyle.mark,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _activeStepTitle,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17),
              ),
              const SizedBox(height: 3),
              Text(_activeStepReason, style: const TextStyle(color: Color(0xFFC7D5D2), fontSize: 12, height: 1.3)),
              const SizedBox(height: 10),
              FilledButton.icon(
                key: const ValueKey('la0040-atelier-workspace-recall'),
                onPressed: onRecall,
                style: FilledButton.styleFrom(
                  backgroundColor: AtelierStyle.mark,
                  foregroundColor: AtelierStyle.ink,
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: Icon(_activeStepIcon),
                label: Text(_activeStepLabel),
              ),
              const SizedBox(height: 7),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compactActions = constraints.maxWidth < 340 || MediaQuery.textScalerOf(context).scale(1) > 1.2;
                  final listen = OutlinedButton.icon(
                    key: const ValueKey('la0040-atelier-workspace-listen'),
                    onPressed: onListen,
                    icon: const Icon(Icons.headphones_rounded),
                    label: const Text('Dinle'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF8EA9A3)),
                    ),
                  );
                  final explain = TextButton.icon(
                    onPressed: onExplain,
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    icon: const Icon(Icons.record_voice_over_outlined),
                    label: const Text('Açıkla'),
                  );
                  final focus = TextButton.icon(
                    onPressed: onFocus,
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    icon: const Icon(Icons.center_focus_strong),
                    label: const Text('Odaklan'),
                  );
                  if (compactActions) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        listen,
                        const SizedBox(height: 4),
                        Wrap(alignment: WrapAlignment.center, spacing: 4, runSpacing: 2, children: [explain, focus]),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: listen),
                      const SizedBox(width: 7),
                      explain,
                      focus,
                    ],
                  );
                },
              ),
              const SizedBox(height: 4),
              const Text(
                'Okuma ve dinleme hazırlık; öğrenme durumunu aktif Hatırla denemesi günceller.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFB6C8C4), fontSize: 11, height: 1.35),
              ),
            ],
          ),
        ),
        ],
      ),
    );
  }

enum AtelierLearningPhase { source, recall, evidence }

class AtelierLearningRail extends StatelessWidget {
  const AtelierLearningRail({required this.phase, super.key});

  final AtelierLearningPhase phase;

  int get _activeIndex => switch (phase) {
    AtelierLearningPhase.source => 0,
    AtelierLearningPhase.recall => 2,
    AtelierLearningPhase.evidence => 3,
  };

  String get _semanticLabel => switch (phase) {
    AtelierLearningPhase.source => 'Kaynak açık. Sonra kaynağı kapat, hatırla ve sonucu kaynak kanıtıyla karşılaştır.',
    AtelierLearningPhase.recall =>
      'Kaynak okundu ve kapatıldı. Şimdi hatırlama adımındasın; kaynak kanıtı yanıttan sonra açılacak.',
    AtelierLearningPhase.evidence =>
      'Kaynak okundu ve kapatıldı. Hatırlama tamamlandı. Şimdi kaynak kanıtı gösteriliyor.',
  };

  @override
  Widget build(BuildContext context) {
    const steps = <(IconData, String)>[
      (Icons.auto_stories_outlined, 'KAYNAK'),
      (Icons.visibility_off_outlined, 'KAPAT'),
      (Icons.psychology_alt_outlined, 'HATIRLA'),
      (Icons.find_in_page_outlined, 'KANIT'),
    ];
    return Semantics(
      label: _semanticLabel,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: AtelierStyle.paper,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AtelierStyle.line),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 360 || MediaQuery.textScalerOf(context).scale(1) > 1.2;
              if (compact) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var index = 0; index < steps.length; index++) ...[
                      Expanded(
                        child: _AtelierLearningRailCompactStep(
                          icon: steps[index].$1,
                          label: steps[index].$2,
                          state: index < _activeIndex
                              ? _AtelierLearningRailState.done
                              : index == _activeIndex
                              ? _AtelierLearningRailState.active
                              : _AtelierLearningRailState.upcoming,
                        ),
                      ),
                      if (index != steps.length - 1)
                        _AtelierLearningRailLine(done: index < _activeIndex, width: 8, topMargin: 14),
                    ],
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var index = 0; index < steps.length; index++) ...[
                    _AtelierLearningRailStep(
                      icon: steps[index].$1,
                      label: steps[index].$2,
                      state: index < _activeIndex
                          ? _AtelierLearningRailState.done
                          : index == _activeIndex
                          ? _AtelierLearningRailState.active
                          : _AtelierLearningRailState.upcoming,
                    ),
                    if (index != steps.length - 1) _AtelierLearningRailLine(done: index < _activeIndex),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

enum _AtelierLearningRailState { done, active, upcoming }

class _AtelierLearningRailStep extends StatelessWidget {
  const _AtelierLearningRailStep({required this.icon, required this.label, required this.state});

  final IconData icon;
  final String label;
  final _AtelierLearningRailState state;

  @override
  Widget build(BuildContext context) {
    final active = state == _AtelierLearningRailState.active;
    final done = state == _AtelierLearningRailState.done;
    final foreground = active || done ? AtelierStyle.teal : AtelierStyle.muted;
    final background = active
        ? AtelierStyle.mark
        : done
        ? AtelierStyle.mint
        : AtelierStyle.canvas;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(done ? Icons.check_rounded : icon, color: foreground, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(color: foreground, fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }
}

class _AtelierLearningRailCompactStep extends StatelessWidget {
  const _AtelierLearningRailCompactStep({required this.icon, required this.label, required this.state});

  final IconData icon;
  final String label;
  final _AtelierLearningRailState state;

  @override
  Widget build(BuildContext context) {
    final active = state == _AtelierLearningRailState.active;
    final done = state == _AtelierLearningRailState.done;
    final foreground = active || done ? AtelierStyle.teal : AtelierStyle.muted;
    final background = active
        ? AtelierStyle.mark
        : done
        ? AtelierStyle.mint
        : AtelierStyle.canvas;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: background, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(done ? Icons.check_rounded : icon, color: foreground, size: 14),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          textAlign: TextAlign.center,
          style: TextStyle(color: foreground, fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: 0.2),
        ),
      ],
    );
  }
}

class _AtelierLearningRailLine extends StatelessWidget {
  const _AtelierLearningRailLine({required this.done, this.width = 12, this.topMargin = 0});

  final bool done;
  final double width;
  final double topMargin;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: 2,
    margin: EdgeInsets.fromLTRB(3, topMargin, 3, 0),
    color: done ? AtelierStyle.teal : AtelierStyle.line,
  );
}

class AtelierRecall extends StatelessWidget {
  const AtelierRecall({
    required this.prompt,
    required this.controller,
    required this.busy,
    required this.onSubmit,
    required this.onHint,
    required this.onReveal,
    required this.onUnknown,
    this.support,
    this.error,
    super.key,
  });
  final RecallPrompt prompt;
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSubmit;
  final VoidCallback onHint;
  final VoidCallback onReveal;
  final VoidCallback onUnknown;
  final String? support;
  final String? error;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('la0040-atelier-recall'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'KAYNAK EKRANI KAPALI · ŞİMDİ SEN',
        style: TextStyle(color: AtelierStyle.teal, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1),
      ),
      const SizedBox(height: 10),
      const AtelierLearningRail(phase: AtelierLearningPhase.recall),
      const SizedBox(height: 14),
      const Text(
        'Hatırlama sırası sende.',
        style: TextStyle(
          color: AtelierStyle.ink,
          fontSize: 29,
          height: 1.08,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.8,
        ),
      ),
      const SizedBox(height: 10),
      const Row(
        key: ValueKey('la0040-recall-companion-guidance'),
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CompanionView(state: CompanionVisualState.think, size: 52),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'D/Knot: Kaynağı kapattık. Hatırladığını yaz; yardım istersen seçenekler aşağıda.',
              style: TextStyle(color: AtelierStyle.muted, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(19, 19, 19, 23),
        decoration: BoxDecoration(color: AtelierStyle.ink, borderRadius: BorderRadius.circular(21)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.visibility_off_outlined, color: AtelierStyle.mark, size: 17),
                SizedBox(width: 8),
                Text(
                  'KAYNAĞA BAKMADAN',
                  style: TextStyle(
                    color: AtelierStyle.mark,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 17),
            Semantics(
              label: 'Hatırlama sorusu',
              value: prompt.promptText,
              child: ExcludeSemantics(
                child: Text(
                  prompt.promptText,
                  softWrap: true,
                  style: const TextStyle(color: Colors.white, fontSize: 23, height: 1.34, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const Row(
        children: [
          Icon(Icons.lock_outline_rounded, color: AtelierStyle.teal, size: 17),
          SizedBox(width: 7),
          Expanded(
            child: Text(
              'Kaynak, yanıtını gönderene veya “Yanıtı göster” seçeneğini kullanana kadar gizli kalır.',
              style: TextStyle(color: AtelierStyle.muted, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      const Text(
        'YANITIN',
        style: TextStyle(color: AtelierStyle.muted, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1),
      ),
      const SizedBox(height: 7),
      TextField(
        key: const ValueKey('la0040-atelier-answer'),
        controller: controller,
        enabled: !busy,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        minLines: 3,
        maxLines: 6,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: 'Yanıtın',
          hintText: 'Kaynağa bakmadan hatırladığını kendi cümlelerinle yaz…',
          filled: true,
          fillColor: AtelierStyle.paper,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
        ),
      ),
      if (support != null) ...[
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: Text(
            support!,
            style: const TextStyle(color: AtelierStyle.teal, fontWeight: FontWeight.w700),
          ),
        ),
      ],
      if (error != null) ...[
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: Text(
            error!,
            style: const TextStyle(color: Color(0xFF9A3530), fontWeight: FontWeight.w700),
          ),
        ),
      ],
      const SizedBox(height: 17),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          key: const ValueKey('la0040-atelier-submit'),
          onPressed: busy ? null : onSubmit,
          style: FilledButton.styleFrom(
            backgroundColor: AtelierStyle.teal,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
          ),
          child: const Text('Yanıtı karşılaştır'),
        ),
      ),
      const SizedBox(height: 9),
      Wrap(
        spacing: 7,
        runSpacing: 4,
        children: [
          OutlinedButton(onPressed: busy ? null : onHint, child: const Text('İpucu')),
          OutlinedButton(onPressed: busy ? null : onReveal, child: const Text('Yanıtı göster')),
          TextButton(onPressed: busy ? null : onUnknown, child: const Text('Bilmiyorum')),
        ],
      ),
    ],
  );
}

class AtelierResult extends StatelessWidget {
  const AtelierResult({
    required this.result,
    required this.answerInMemory,
    required this.onContinue,
    this.sourceVersion,
    super.key,
  });
  final RecallAttemptResult result;
  final String answerInMemory;
  final VoidCallback onContinue;
  final SourceVersionRecord? sourceVersion;

  String get _heading => switch (result.evidence.outcome) {
    RecallOutcome.correct when result.evidence.assistance == RecallAssistance.none => 'Bir kez bağımsız hatırladın',
    RecallOutcome.helpedCorrect => 'İpucuyla doğru yanıt',
    RecallOutcome.answerExposed => 'Yanıtı gördün',
    RecallOutcome.unknown => 'Bu kez bilmiyorum dedin',
    RecallOutcome.partial => 'Yanıtının bir kısmı eşleşti',
    RecallOutcome.incorrect => 'Bu kez yanıtın eşleşmedi',
    _ => 'Bu denemenin sonucu',
  };

  String get _response {
    if (result.evidence.outcome == RecallOutcome.unknown) return 'Bilmiyorum dedin.';
    if (result.evidence.assistance == RecallAssistance.answerExposed) {
      return 'Yanıt gösterildi; bağımsız hatırlama sayılmadı.';
    }
    return answerInMemory.trim().isEmpty ? 'Yanıt metni bu oturumda yok.' : answerInMemory.trim();
  }

  String get _nextActionLabel => switch (result.nextAction.kind) {
    NextLearningActionKind.reviewSourceThenRecall => 'Kaynağı gözden geçir',
    NextLearningActionKind.retryRecallWithoutHint => 'İpucusuz tekrar dene',
    NextLearningActionKind.repeatRecallLater => 'Bu denemeyi tamamla',
  };

  @override
  Widget build(BuildContext context) {
    final excerpt = result.sourceExcerpt;
    final answer = result.correctAnswer.trim();
    final match = answer.isEmpty ? null : findFirstTurkishSourceTextMatch(excerpt, answer);
    final independent =
        result.evidence.outcome == RecallOutcome.correct && result.evidence.assistance == RecallAssistance.none;
    final assisted = result.evidence.outcome == RecallOutcome.helpedCorrect;
    final responseColor = independent
        ? AtelierStyle.mint
        : assisted
        ? const Color(0xFFFFF1D9)
        : const Color(0xFFF1F0EC);
    final spans = <TextSpan>[];
    if (match == null) {
      spans.add(TextSpan(text: excerpt));
    } else {
      spans.add(TextSpan(text: excerpt.substring(0, match.start)));
      spans.add(
        TextSpan(
          text: excerpt.substring(match.start, match.end),
          style: const TextStyle(
            color: AtelierStyle.ink,
            backgroundColor: AtelierStyle.mark,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
      spans.add(TextSpan(text: excerpt.substring(match.end)));
    }
    return Column(
      key: const ValueKey('la0040-atelier-result'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'KAYNAĞINLA KARŞILAŞTIR',
          style: TextStyle(color: AtelierStyle.teal, fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        const AtelierLearningRail(phase: AtelierLearningPhase.evidence),
        const SizedBox(height: 14),
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            _heading,
            style: const TextStyle(
              color: AtelierStyle.ink,
              fontWeight: FontWeight.w900,
              fontSize: 29,
              height: 1.12,
              letterSpacing: -0.6,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          result.evidence.outcome == RecallOutcome.correct && result.evidence.assistance == RecallAssistance.none
              ? 'Tek bir bağımsız deneme, henüz ustalık değil.'
              : 'Bu sonuç denemeni ve varsa aldığın yardımı yansıtır.',
          style: const TextStyle(color: AtelierStyle.muted, fontSize: 14, height: 1.42),
        ),
        const SizedBox(height: 16),
        const Text(
          'ÖNCE SENİN YANITIN',
          style: TextStyle(color: AtelierStyle.muted, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: responseColor,
            borderRadius: BorderRadius.circular(14),
            border: Border(
              left: BorderSide(
                color: independent
                    ? AtelierStyle.teal
                    : assisted
                    ? const Color(0xFFC48B33)
                    : AtelierStyle.muted,
                width: 4,
              ),
            ),
          ),
          child: Text(
            _response,
            style: const TextStyle(color: AtelierStyle.ink, fontSize: 16, height: 1.45, fontWeight: FontWeight.w700),
          ),
        ),
        if (sourceVersion != null) ...[
          const SizedBox(height: 14),
          AtelierSourceTrustStrip(sourceVersion: sourceVersion!),
        ],
        const SizedBox(height: 13),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.arrow_downward_rounded, color: AtelierStyle.teal, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'ŞİMDİ KAYNAĞINDAKİ KANIT',
                  textAlign: TextAlign.center,
                  softWrap: true,
                  style: TextStyle(
                    color: AtelierStyle.teal,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(width: 28),
            ],
          ),
        ),
        TweenAnimationBuilder<double>(
          key: const ValueKey('la0040-source-evidence-reveal'),
          tween: Tween<double>(begin: 0, end: 1),
          duration:
              ((MediaQuery.maybeOf(context)?.disableAnimations ?? false) ||
                  (MediaQuery.maybeOf(context)?.accessibleNavigation ?? false))
              ? Duration.zero
              : const Duration(milliseconds: 240),
          builder: (context, progress, child) => Opacity(
            opacity: progress,
            child: Transform.translate(offset: Offset(0, 12 * (1 - progress)), child: child),
          ),
          child: Semantics(
            container: true,
            label: 'Kaynak kanıtı',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 21, 20, 23),
              decoration: BoxDecoration(color: AtelierStyle.ink, borderRadius: BorderRadius.circular(21)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.find_in_page_outlined, color: AtelierStyle.mark, size: 20),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'KAYNAKTAKİ DOĞRU İFADE',
                          style: TextStyle(
                            color: AtelierStyle.mark,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    result.correctAnswer,
                    style: const TextStyle(color: Colors.white, fontSize: 25, height: 1.2, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 15),
                  const Divider(color: Color(0xFF486068), height: 1),
                  const SizedBox(height: 14),
                  SelectableText.rich(
                    TextSpan(children: spans),
                    style: const TextStyle(color: Color(0xFFE4EDEC), fontSize: 16, height: 1.54),
                  ),
                  if (match == null) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Bu alıntıda doğru ifadeye birebir vurgu bulunamadı.',
                      style: TextStyle(color: Color(0xFFC7D6D4), fontSize: 12, height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          key: const ValueKey('la0040-result-companion-reflection'),
          padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
          decoration: BoxDecoration(color: AtelierStyle.mint, borderRadius: BorderRadius.circular(12)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.auto_awesome_outlined, color: AtelierStyle.teal, size: 18),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  independent
                      ? 'D/Knot: Bunu kendi başına hatırladın. Kalıcılığı sonraki bağımsız deneme gösterecek.'
                      : assisted
                      ? 'D/Knot: İpucundan yararlandın. Şimdi kaynakla bağı güçlendirip yeniden deneyebilirsin.'
                      : 'D/Knot: Kanıt, bir sonraki çalışmanda nereye dönmen gerektiğini gösteriyor.',
                  style: const TextStyle(
                    color: AtelierStyle.ink,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'SIRADAKİ GERÇEK ADIM',
          style: TextStyle(color: AtelierStyle.teal, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1),
        ),
        const SizedBox(height: 8),
        Text(
          result.nextAction.reasonText,
          style: const TextStyle(color: AtelierStyle.ink, fontSize: 16, height: 1.44, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 13),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('la0040-atelier-next'),
            onPressed: onContinue,
            style: FilledButton.styleFrom(
              backgroundColor: AtelierStyle.teal,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(_nextActionLabel),
          ),
        ),
      ],
    );
  }
}
