import 'package:flutter/material.dart';

import '../domain/grounded_tutor.dart';
import '../domain/learning_contracts.dart';
import '../learning/grounded_tutor_service.dart';
import 'app_runtime.dart';
import 'atelier_learning_surfaces.dart';
import 'companion_view.dart';
import 'explain_back_screen.dart';
import 'learning_slice_screen.dart';
import 'living_study_desk_home.dart';

enum GroundedTutorExit { reviewSource }

class GroundedTutorScreen extends StatefulWidget {
  const GroundedTutorScreen({required this.runtime, required this.source, this.initialContextAnchor, super.key});

  final AppRuntime runtime;
  final SourceVersionRecord source;
  final SourceAnchor? initialContextAnchor;

  @override
  State<GroundedTutorScreen> createState() => _GroundedTutorScreenState();
}

class _GroundedTutorScreenState extends State<GroundedTutorScreen> {
  final TextEditingController _question = TextEditingController();
  final ScrollController _scroll = ScrollController();
  late Future<GroundedTutorThreadState> _future;
  GroundedTutorThreadState? _state;
  bool _busy = false;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _question.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<GroundedTutorThreadState> _load() => widget.runtime.tutor.openThread(
    learner: widget.runtime.learner,
    materialId: widget.source.identity.materialId,
    expectedSourceVersionId: widget.source.identity.sourceVersionId,
    contextAnchor: widget.initialContextAnchor,
  );

  void _reload() {
    setState(() {
      _state = null;
      _inlineError = null;
      _future = _load();
    });
  }

  Future<void> _ask() async {
    final state = _state;
    final question = _question.text.trim();
    if (state == null || question.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _inlineError = null;
    });
    try {
      final next = await widget.runtime.tutor.ask(
        learner: widget.runtime.learner,
        threadId: state.thread.id,
        question: question,
      );
      if (!mounted) return;
      _question.clear();
      setState(() {
        _state = next;
        _busy = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients) return;
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      });
    } on GroundedTutorException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _inlineError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _inlineError = 'Tutor yanıtı hazırlanamadı. Sorun korunuyor; tekrar deneyebilirsin.';
      });
    }
  }

  GroundedTutorTurnRecord? get _latestTutorTurn {
    final turns = _state?.turns;
    if (turns == null) return null;
    for (final turn in turns.reversed) {
      if (turn.role == GroundedTutorTurnRole.tutor) return turn;
    }
    return null;
  }

  Future<void> _openRecall() async {
    final latest = _latestTutorTurn;
    final anchor = latest?.sourceAnchor ?? widget.initialContextAnchor;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) {
          final screen = LearningSliceScreen(
            runtime: widget.runtime,
            materialId: widget.source.identity.materialId,
            requestedRecallSourceVersionId: anchor == null ? null : widget.source.identity.sourceVersionId,
            requestedRecallSourceAnchor: anchor,
          );
          return LivingDeskReviewScope.active(context) ? LivingDeskReviewScope(child: screen) : screen;
        },
      ),
    );
  }

  Future<void> _openExplainBack() async {
    final screen = ExplainBackScreen(runtime: widget.runtime, source: widget.source);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LivingDeskReviewScope.active(context) ? LivingDeskReviewScope(child: screen) : screen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final living = LivingDeskReviewScope.active(context);
    final media = MediaQuery.of(context);
    final compact = media.size.width < 340 || media.textScaler.scale(1) > 1.25;
    final content = FutureBuilder<GroundedTutorThreadState>(
      future: _future,
      builder: (context, snapshot) {
        if (_state == null && snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
          _state = snapshot.data;
        }
        if (_state == null && snapshot.connectionState == ConnectionState.done && snapshot.hasError) {
          return _errorState();
        }
        final state = _state;
        if (state == null) return _loadingState();
        return _conversation(context, state);
      },
    );

    return Scaffold(
      key: const ValueKey('grounded-tutor-screen'),
      backgroundColor: living ? AtelierStyle.canvas : null,
      appBar: AppBar(
        title: const Text('Kaynağa sor'),
        backgroundColor: living ? AtelierStyle.canvas : null,
        foregroundColor: living ? AtelierStyle.ink : null,
      ),
      // A large-text composer can consume the entire Scaffold body when it is
      // measured as bottomNavigationBar. Keep the conventional pinned bar on
      // regular layouts, but make compact accessibility layouts an explicit
      // flex contract so the conversation always retains a real viewport.
      bottomNavigationBar: compact ? null : _composer(context),
      body: SafeArea(
        child: compact
            ? Column(
                children: [
                  Expanded(child: content),
                  _composer(context),
                ],
              )
            : content,
      ),
    );
  }

  Widget _loadingState() => const Center(
    child: Padding(
      padding: EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CompanionView(state: CompanionVisualState.think, size: 82),
          SizedBox(height: 14),
          Text(
            'Kaynak bağlamı hazırlanıyor…',
            textAlign: TextAlign.center,
            style: TextStyle(color: AtelierStyle.ink, fontSize: 18, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 6),
          Text(
            'Tutor yalnız güncel kaynak sürümünü kullanacak.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AtelierStyle.muted, height: 1.4),
          ),
        ],
      ),
    ),
  );

  Widget _errorState() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CompanionView(state: CompanionVisualState.think, size: 82),
          const SizedBox(height: 14),
          const Text(
            'Tutor bu kaynakla açılamadı.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AtelierStyle.ink, fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Kaynak değişmiş veya okunabilir metin artık güncel olmayabilir. Eski konuşma yeni kaynağa taşınmaz.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AtelierStyle.muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tekrar dene'),
          ),
          const SizedBox(height: 6),
          TextButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Materyale dön')),
        ],
      ),
    ),
  );

  Widget _conversation(BuildContext context, GroundedTutorThreadState state) {
    final compact = MediaQuery.sizeOf(context).width < 340 || MediaQuery.textScalerOf(context).scale(1) > 1.25;
    return ListView(
      key: const ValueKey('grounded-tutor-scroll'),
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(16, compact ? 12 : 16, 16, 28),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CompanionView(
              state: _busy ? CompanionVisualState.think : CompanionVisualState.idle,
              size: compact ? 56 : 68,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'KAYNAĞA BAĞLI TUTOR',
                    style: TextStyle(
                      color: AtelierStyle.pulse,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Sorunu kaynaktan birlikte netleştir.',
                    style: TextStyle(color: AtelierStyle.ink, fontSize: 20, height: 1.15, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Tutor cevabı yalnız güncel kaynağa dayanır. Sohbet etmek öğrenme kanıtı, ustalık veya hazır olma sonucu değildir.',
                    style: TextStyle(color: AtelierStyle.muted, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        AtelierSourceTrustStrip(sourceVersion: widget.source),
        if (widget.initialContextAnchor != null) ...[
          const SizedBox(height: 10),
          Container(
            key: const ValueKey('grounded-tutor-context'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AtelierStyle.aquaSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AtelierStyle.line),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.format_quote_rounded, color: AtelierStyle.aqua, size: 19),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Reader’dan seçtiğin bölüm bu konuşmanın kaynak bağlamı. Tutor bunu yeni kaynağa otomatik taşımaz.',
                    style: TextStyle(color: AtelierStyle.ink, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (state.turns.isEmpty) _emptyConversation(),
        for (final turn in state.turns) ...[_turnCard(turn), const SizedBox(height: 10)],
        if (_inlineError != null) ...[
          Container(
            key: const ValueKey('grounded-tutor-inline-error'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AtelierStyle.attentionSoft, borderRadius: BorderRadius.circular(12)),
            child: Text(_inlineError!, style: const TextStyle(color: AtelierStyle.ink, height: 1.35)),
          ),
          const SizedBox(height: 10),
        ],
        if (_latestTutorTurn != null) _nextActions(context),
      ],
    );
  }

  Widget _emptyConversation() => Container(
    key: const ValueKey('grounded-tutor-empty'),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AtelierStyle.paper,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AtelierStyle.line),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bu kaynak hakkında neyi netleştirmek istiyorsun?', style: TextStyle(fontWeight: FontWeight.w900)),
        SizedBox(height: 5),
        Text(
          'Kaynakta açık dayanak yoksa Tutor cevap uydurmak yerine bunu söyleyecek.',
          style: TextStyle(color: AtelierStyle.muted, height: 1.35),
        ),
      ],
    ),
  );

  Widget _turnCard(GroundedTutorTurnRecord turn) {
    final learner = turn.role == GroundedTutorTurnRole.learner;
    final unsupported = turn.supportState == GroundedTutorSupportState.sourceUnsupported;
    return Align(
      alignment: learner ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          key: ValueKey('grounded-tutor-turn-${turn.id.value}'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: learner
                ? AtelierStyle.pulseSoft
                : unsupported
                ? AtelierStyle.attentionSoft
                : AtelierStyle.paper,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AtelierStyle.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                learner
                    ? 'SEN'
                    : unsupported
                    ? 'TUTOR · KAYNAKTA DAYANAK YOK'
                    : 'TUTOR · KAYNAĞA BAĞLI',
                style: TextStyle(
                  color: learner
                      ? AtelierStyle.pulse
                      : unsupported
                      ? AtelierStyle.attention
                      : AtelierStyle.aqua,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 5),
              Text(turn.text, style: const TextStyle(color: AtelierStyle.ink, height: 1.45)),
              if (turn.hasSourceSupport && turn.sourceExcerpt != null) ...[
                const SizedBox(height: 10),
                Container(
                  key: ValueKey('grounded-tutor-source-${turn.id.value}'),
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(color: AtelierStyle.aquaSoft, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        turn.sourceAnchor?.pageNumber == null
                            ? 'KAYNAK DAYANAĞI'
                            : 'KAYNAK DAYANAĞI · SAYFA ${turn.sourceAnchor!.pageNumber}',
                        style: const TextStyle(
                          color: AtelierStyle.aqua,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('“${turn.sourceExcerpt}”', style: const TextStyle(color: AtelierStyle.ink, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _nextActions(BuildContext context) => Container(
    key: const ValueKey('grounded-tutor-next-actions'),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AtelierStyle.paper,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AtelierStyle.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Buradan öğrenme döngüsüne dön',
          style: TextStyle(color: AtelierStyle.ink, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        const Text(
          'Tutor hazırlıktır. Öğrenmeyi gerçekten ölçmek için aktif bir eylem seç.',
          style: TextStyle(color: AtelierStyle.muted, height: 1.35),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          key: const ValueKey('grounded-tutor-recall'),
          onPressed: _openRecall,
          icon: const Icon(Icons.psychology_alt_outlined),
          label: const Text('Kaynağı kapat · Hatırla'),
        ),
        const SizedBox(height: 7),
        OutlinedButton.icon(
          key: const ValueKey('grounded-tutor-explain-back'),
          onPressed: _openExplainBack,
          icon: const Icon(Icons.record_voice_over_outlined),
          label: const Text('Kendi cümlelerimle anlat'),
        ),
        TextButton.icon(
          key: const ValueKey('grounded-tutor-source-review'),
          onPressed: () => Navigator.of(context).pop(GroundedTutorExit.reviewSource),
          icon: const Icon(Icons.menu_book_outlined),
          label: const Text('Kaynağı gözden geçir'),
        ),
      ],
    ),
  );

  Widget _composer(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 340 || MediaQuery.textScalerOf(context).scale(1) > 1.25;
    final field = TextField(
      key: const ValueKey('grounded-tutor-question'),
      controller: _question,
      enabled: !_busy && _state != null,
      minLines: 1,
      maxLines: 2,
      maxLength: 2000,
      textInputAction: TextInputAction.newline,
      decoration: InputDecoration(
        hintText: 'Bu kaynak hakkında sor…',
        helperText: compact ? null : 'Soru ve Tutor yanıtı öğrenme kanıtı değildir.',
        counterText: compact ? '' : null,
      ),
    );
    final send = FilledButton.icon(
      key: const ValueKey('grounded-tutor-send'),
      onPressed: _busy || _state == null ? null : _ask,
      icon: _busy
          ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.arrow_upward_rounded),
      label: Text(_busy ? 'Kaynak kontrol ediliyor' : 'Sor'),
    );
    return SafeArea(
      top: false,
      child: Container(
        padding: compact ? const EdgeInsets.fromLTRB(12, 8, 12, 8) : const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: const BoxDecoration(
          color: AtelierStyle.paper,
          border: Border(top: BorderSide(color: AtelierStyle.line)),
        ),
        child: compact
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [field, const SizedBox(height: 8), send])
            : Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: field),
                  const SizedBox(width: 10),
                  send,
                ],
              ),
      ),
    );
  }
}
