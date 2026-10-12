import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/flashcard_learning.dart';
import '../domain/learning_contracts.dart';
import '../learning/flashcard_learning_service.dart';
import 'app_runtime.dart';
import 'atelier_learning_surfaces.dart';
import 'companion_view.dart';

class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({required this.runtime, required this.materialId, super.key});

  final AppRuntime runtime;
  final MaterialId materialId;

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  late Future<_FlashcardViewData> _future;
  _FlashcardViewData? _data;
  bool _revealed = false;
  bool _busy = false;
  String? _inlineError;
  String? _recoveryNotice;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_FlashcardViewData> _load() async {
    final material = await widget.runtime.store.material(
      learner: widget.runtime.learner,
      materialId: widget.materialId,
    );
    if (material == null || !material.isActive) {
      throw const FlashcardLearningException('Materyal artık kullanılamıyor.');
    }
    final study = await widget.runtime.flashcards.openCurrentSet(
      learner: widget.runtime.learner,
      materialId: widget.materialId,
    );
    final source = await widget.runtime.store.currentSourceVersion(
      learner: widget.runtime.learner,
      materialId: widget.materialId,
    );
    if (source == null || source.identity.sourceVersionId != study.set.sourceVersionId) {
      throw const FlashcardLearningException('Kartlar güncel kaynak sürümüyle eşleşmiyor.');
    }
    return _FlashcardViewData(material: material, source: source, study: study);
  }

  void _reload() {
    setState(() {
      _revealed = false;
      _busy = false;
      _inlineError = null;
      _recoveryNotice = null;
      _data = null;
      _future = _load();
    });
  }

  void _feedback({required bool strong}) {
    final media = MediaQuery.maybeOf(context);
    if ((media?.disableAnimations ?? false) || (media?.accessibleNavigation ?? false)) return;
    try {
      if (strong) {
        unawaited(HapticFeedback.mediumImpact().catchError((_) {}));
      } else {
        unawaited(HapticFeedback.selectionClick().catchError((_) {}));
      }
    } catch (_) {
      // Feedback acknowledges an interaction; it must never block study.
    }
  }

  void _reveal() {
    if (_busy || _revealed) return;
    _feedback(strong: false);
    setState(() {
      _revealed = true;
      _inlineError = null;
    });
  }

  Future<void> _respond(FlashcardResponse response) async {
    final data = _data;
    final card = data?.study.currentCard;
    if (data == null || card == null || !_revealed || _busy) return;
    setState(() {
      _busy = true;
      _inlineError = null;
      _recoveryNotice = null;
    });
    try {
      final next = await widget.runtime.flashcards.recordResponse(
        learner: widget.runtime.learner,
        materialId: widget.materialId,
        setId: data.study.set.id,
        cardId: card.id,
        response: response,
        answerWasRevealed: true,
      );
      if (!mounted) return;
      _feedback(strong: response == FlashcardResponse.remembered);
      setState(() {
        _data = _FlashcardViewData(material: data.material, source: data.source, study: next);
        _revealed = false;
        _busy = false;
        _recoveryNotice = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _revealed = false;
        _inlineError = null;
        _data = null;
        _recoveryNotice = 'Önceki kart yanıtı kaydedilmedi. Güncel kaynaktan devam ediyorsun.';
        _future = _load();
      });
    }
  }

  Future<void> _restart() async {
    final data = _data;
    if (data == null || _busy) return;
    setState(() {
      _busy = true;
      _inlineError = null;
    });
    try {
      final next = await widget.runtime.flashcards.restartSession(
        learner: widget.runtime.learner,
        materialId: widget.materialId,
      );
      if (!mounted) return;
      _feedback(strong: false);
      setState(() {
        _data = _FlashcardViewData(material: data.material, source: data.source, study: next);
        _revealed = false;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _inlineError = 'Kart turu yeniden başlatılamadı. Tekrar deneyebilirsin.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_FlashcardViewData>(
      future: _future,
      builder: (context, snapshot) {
        // FutureBuilder retains the previous future's data while a replacement
        // future is waiting. Accept data/error only after the current load has
        // completed so source-change recovery can never re-bind stale cards.
        if (_data == null && snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
          _data = snapshot.data;
        }
        if (_data == null && snapshot.connectionState == ConnectionState.done && snapshot.hasError) {
          return _FlashcardError(onRetry: _reload);
        }
        final data = _data;
        if (data == null) return const _FlashcardLoading();
        return _FlashcardStudyView(
          data: data,
          revealed: _revealed,
          busy: _busy,
          inlineError: _inlineError,
          recoveryNotice: _recoveryNotice,
          onReveal: _reveal,
          onAgain: () => _respond(FlashcardResponse.again),
          onRemembered: () => _respond(FlashcardResponse.remembered),
          onReload: _reload,
          onRestart: _restart,
        );
      },
    );
  }
}

class _FlashcardViewData {
  const _FlashcardViewData({required this.material, required this.source, required this.study});

  final MaterialRecord material;
  final SourceVersionRecord source;
  final FlashcardStudyState study;
}

class _FlashcardLoading extends StatelessWidget {
  const _FlashcardLoading();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AtelierStyle.canvas,
    appBar: AppBar(
      title: const Text('Kartlar'),
      backgroundColor: AtelierStyle.canvas,
      surfaceTintColor: Colors.transparent,
    ),
    body: const SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CompanionView(state: CompanionVisualState.think, size: 88),
              SizedBox(height: 16),
              Text(
                'Kartların hazırlanıyor…',
                textAlign: TextAlign.center,
                style: TextStyle(color: AtelierStyle.ink, fontSize: 20, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 7),
              Text(
                'Kartlar yalnız güncel kaynak sürümünden oluşturuluyor.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AtelierStyle.muted, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _FlashcardError extends StatelessWidget {
  const _FlashcardError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AtelierStyle.canvas,
    appBar: AppBar(
      title: const Text('Kartlar'),
      backgroundColor: AtelierStyle.canvas,
      surfaceTintColor: Colors.transparent,
    ),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CompanionView(state: CompanionVisualState.think, size: 88),
              const SizedBox(height: 14),
              const Text(
                'Kartlar açılamadı.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AtelierStyle.ink, fontSize: 21, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'Kaynak değişmiş veya kart üretmeye yetecek okunabilir içerik bulunamamış olabilir.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AtelierStyle.muted, height: 1.45),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                key: const ValueKey('flashcards-retry'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _FlashcardStudyView extends StatelessWidget {
  const _FlashcardStudyView({
    required this.data,
    required this.revealed,
    required this.busy,
    required this.inlineError,
    required this.recoveryNotice,
    required this.onReveal,
    required this.onAgain,
    required this.onRemembered,
    required this.onReload,
    required this.onRestart,
  });

  final _FlashcardViewData data;
  final bool revealed;
  final bool busy;
  final String? inlineError;
  final String? recoveryNotice;
  final VoidCallback onReveal;
  final VoidCallback onAgain;
  final VoidCallback onRemembered;
  final VoidCallback onReload;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final compact = media.size.width < 360 || media.textScaler.scale(1) > 1.2;
    final reducedMotion = media.disableAnimations || media.accessibleNavigation;
    final study = data.study;
    final card = study.currentCard;
    final completed = study.session.isCompleted || card == null;
    final total = study.set.cards.length;
    final completedCount = study.session.cursorIndex.clamp(0, total);

    return Scaffold(
      key: const ValueKey('flashcards-screen'),
      backgroundColor: AtelierStyle.canvas,
      appBar: AppBar(
        title: const Text('Kartlar'),
        backgroundColor: AtelierStyle.canvas,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBar: completed
          ? null
          : SafeArea(
              top: false,
              child: Container(
                key: const ValueKey('flashcards-action-bar'),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                decoration: const BoxDecoration(
                  color: AtelierStyle.paper,
                  border: Border(top: BorderSide(color: AtelierStyle.line)),
                  boxShadow: [BoxShadow(color: Color(0x1214224A), blurRadius: 18, offset: Offset(0, -6))],
                ),
                child: revealed
                    ? compact
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                FilledButton.icon(
                                  key: const ValueKey('flashcards-remembered'),
                                  onPressed: busy ? null : onRemembered,
                                  icon: const Icon(Icons.check_rounded),
                                  label: const Text('Hatırladım'),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  key: const ValueKey('flashcards-again'),
                                  onPressed: busy ? null : onAgain,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Tekrar gerekli'),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    key: const ValueKey('flashcards-again'),
                                    onPressed: busy ? null : onAgain,
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text('Tekrar gerekli'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FilledButton.icon(
                                    key: const ValueKey('flashcards-remembered'),
                                    onPressed: busy ? null : onRemembered,
                                    icon: const Icon(Icons.check_rounded),
                                    label: const Text('Hatırladım'),
                                  ),
                                ),
                              ],
                            )
                    : FilledButton.icon(
                        key: const ValueKey('flashcards-reveal'),
                        onPressed: busy ? null : onReveal,
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('Cevabı göster'),
                      ),
              ),
            ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(compact ? 16 : 22, 12, compact ? 16 : 22, completed ? 28 : 20),
          children: [
            Text(
              data.material.title,
              style: TextStyle(
                color: AtelierStyle.ink,
                fontSize: compact ? 22 : 27,
                height: 1.12,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.45,
              ),
            ),
            const SizedBox(height: 11),
            AtelierSourceTrustStrip(sourceVersion: data.source, showSourceName: !compact),
            if (recoveryNotice != null) ...[
              const SizedBox(height: 10),
              Container(
                key: const ValueKey('flashcards-recovery-notice'),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(color: AtelierStyle.attentionSoft, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.sync_rounded, color: AtelierStyle.pulse, size: 19),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        recoveryNotice!,
                        style: const TextStyle(color: AtelierStyle.ink, fontSize: 12.5, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (completed)
              _FlashcardCompletion(study: study, busy: busy, onRestart: onRestart, compact: compact)
            else ...[
              Row(
                children: [
                  CompanionView(
                    key: const ValueKey('flashcards-companion'),
                    state: revealed ? CompanionVisualState.idle : CompanionVisualState.think,
                    size: compact ? 68 : 82,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'KART ${completedCount + 1} / $total',
                          style: const TextStyle(
                            color: AtelierStyle.pulse,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.9,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          revealed ? 'Kaynakla karşılaştır.' : 'Önce kendin hatırla.',
                          style: TextStyle(
                            color: AtelierStyle.ink,
                            fontSize: compact ? 17 : 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                key: const ValueKey('flashcards-progress'),
                value: total == 0 ? 0.0 : completedCount / total,
                minHeight: 4,
                color: AtelierStyle.pulse,
                backgroundColor: AtelierStyle.line,
                semanticsLabel: 'Kart ilerlemesi · Kart ${completedCount + 1} / $total',
              ),
              const SizedBox(height: 18),
              Container(
                key: const ValueKey('flashcards-card'),
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(compact ? 18 : 24, compact ? 20 : 28, compact ? 18 : 24, 24),
                decoration: BoxDecoration(
                  color: AtelierStyle.paper,
                  borderRadius: BorderRadius.circular(22),
                  border: const Border(left: BorderSide(color: AtelierStyle.pulse, width: 4)),
                  boxShadow: const [BoxShadow(color: Color(0x1014224A), blurRadius: 22, offset: Offset(0, 9))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'SORU',
                      style: TextStyle(
                        color: AtelierStyle.pulse,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.9,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Semantics(
                      label: 'Kart sorusu: ${card.front.replaceAll('_____', 'boşluk')}',
                      child: ExcludeSemantics(
                        child: Text(
                          card.front,
                          style: TextStyle(
                            color: AtelierStyle.ink,
                            fontSize: compact ? 20 : 23,
                            height: 1.38,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedSwitcher(
                      duration: reducedMotion || busy ? Duration.zero : const Duration(milliseconds: 200),
                      child: revealed
                          ? Semantics(
                              liveRegion: true,
                              label:
                                  'Cevap: ${card.back}. Kaynakta: ${card.sourceExcerpt}'
                                  '${card.sourceAnchor.pageNumber == null ? '' : '. Sayfa ${card.sourceAnchor.pageNumber}'}',
                              child: ExcludeSemantics(
                                child: Column(
                                  key: ValueKey('flashcards-answer-${card.id.value}'),
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const Divider(color: AtelierStyle.line),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'CEVAP',
                                      style: TextStyle(
                                        color: AtelierStyle.aqua,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.9,
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    Text(
                                      card.back,
                                      key: const ValueKey('flashcards-answer'),
                                      style: TextStyle(
                                        color: AtelierStyle.ink,
                                        fontSize: compact ? 22 : 25,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Container(
                                      key: const ValueKey('flashcards-source-evidence'),
                                      padding: const EdgeInsets.all(13),
                                      decoration: BoxDecoration(
                                        color: AtelierStyle.pulseSoft,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'KAYNAKTA',
                                            style: TextStyle(
                                              color: AtelierStyle.pulse,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            card.sourceExcerpt,
                                            style: const TextStyle(color: AtelierStyle.ink, fontSize: 13, height: 1.4),
                                          ),
                                          if (card.sourceAnchor.pageNumber != null) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              'Sayfa ${card.sourceAnchor.pageNumber}',
                                              style: const TextStyle(color: AtelierStyle.muted, fontSize: 11.5),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : const Text(
                              'Cevabı görmeden önce boşluğu zihninden tamamla.',
                              key: ValueKey('flashcards-hidden-answer-note'),
                              style: TextStyle(color: AtelierStyle.muted, fontSize: 13, height: 1.4),
                            ),
                    ),
                  ],
                ),
              ),
              if (inlineError != null) ...[
                const SizedBox(height: 12),
                Container(
                  key: const ValueKey('flashcards-inline-error'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AtelierStyle.attentionSoft, borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(inlineError!, style: const TextStyle(color: AtelierStyle.ink, fontSize: 12.5, height: 1.4)),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          key: const ValueKey('flashcards-inline-reload'),
                          onPressed: busy ? null : onReload,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Kartları yeniden yükle'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              const Text(
                'Kart yanıtın yalnız kart çalışma geçmişine yazılır. Materyalin öğrenme durumunu Hatırla denemesi ölçer.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AtelierStyle.muted, fontSize: 11.5, height: 1.4),
              ),
            ],
            if (busy) ...[const SizedBox(height: 12), const LinearProgressIndicator()],
          ],
        ),
      ),
    );
  }
}

class _FlashcardCompletion extends StatelessWidget {
  const _FlashcardCompletion({required this.study, required this.busy, required this.onRestart, required this.compact});

  final FlashcardStudyState study;
  final bool busy;
  final VoidCallback onRestart;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('flashcards-complete'),
    padding: EdgeInsets.fromLTRB(compact ? 18 : 24, 22, compact ? 18 : 24, 24),
    decoration: BoxDecoration(
      color: AtelierStyle.paper,
      borderRadius: BorderRadius.circular(22),
      border: const Border(left: BorderSide(color: AtelierStyle.aqua, width: 4)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: CompanionView(state: CompanionVisualState.success, size: 94),
        ),
        const SizedBox(height: 10),
        const Text(
          'Kart turu tamamlandı.',
          style: TextStyle(color: AtelierStyle.ink, fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          '${study.session.rememberedCount} hatırlandı · ${study.session.againCount} tekrar',
          style: const TextStyle(color: AtelierStyle.pulse, fontSize: 14, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 9),
        const Text(
          'Bu tur kart çalışma geçmişidir; ustalık veya kalıcı öğrenme iddiası değildir. Öğrenme durumunu Hatırla ölçer.',
          style: TextStyle(color: AtelierStyle.muted, fontSize: 13, height: 1.45),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          key: const ValueKey('flashcards-restart'),
          onPressed: busy ? null : onRestart,
          icon: const Icon(Icons.replay_rounded),
          label: const Text('Kartları yeniden çalış'),
        ),
        if (Navigator.of(context).canPop()) ...[
          const SizedBox(height: 6),
          TextButton.icon(
            key: const ValueKey('flashcards-return-workspace'),
            onPressed: busy ? null : () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Çalışma alanına dön'),
          ),
        ],
      ],
    ),
  );
}
