import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/learning_contracts.dart';
import '../speech/device_speech_output.dart';
import 'app_runtime.dart';
import 'app_theme.dart';
import 'atelier_learning_surfaces.dart';
import 'companion_view.dart';
import 'living_study_desk_home.dart';

class ListenScreen extends StatefulWidget {
  const ListenScreen({
    required this.runtime,
    required this.materialId,
    this.speechOutput,
    this.onRecall,
    this.textOverride,
    this.titleOverride,
    this.persistProgress = true,
    super.key,
  });

  final AppRuntime runtime;
  final MaterialId materialId;
  final SpeechOutput? speechOutput;
  final VoidCallback? onRecall;
  final String? textOverride;
  final String? titleOverride;
  final bool persistProgress;

  @override
  State<ListenScreen> createState() => _ListenScreenState();
}

class _ListenScreenState extends State<ListenScreen> {
  late final SpeechOutput _speech;
  late Future<_ListenSource?> _source;
  bool _speaking = false;
  bool _startedPlayback = false;
  bool _startingPlayback = false;
  bool _finishedListening = false;
  String? _error;
  int? _resumeChunkOverride;
  int _currentChunkIndex = 0;
  int _playToken = 0;
  double? _playbackRate;

  @override
  void initState() {
    super.initState();
    _speech = widget.speechOutput ?? DeviceSpeechOutput();
    _source = _load();
  }

  Future<_ListenSource?> _load() async {
    final version = await widget.runtime.store.currentSourceVersion(
      learner: widget.runtime.learner,
      materialId: widget.materialId,
    );
    if (version == null) {
      return null;
    }
    final overrideText = widget.textOverride?.trim();
    String text;
    if (overrideText != null && overrideText.isNotEmpty) {
      text = overrideText;
    } else {
      final extracted = await widget.runtime.store.extractedContentForSource(
        learner: widget.runtime.learner,
        sourceVersionId: version.identity.sourceVersionId,
      );
      if (extracted == null || !extracted.isValid || extracted.normalizedText.trim().isEmpty) {
        return null;
      }
      text = extracted.normalizedText.trim();
    }

    final chunks = _chunkText(text);
    final storedResume = widget.persistProgress
        ? await widget.runtime.store.listenResumeChunk(
            learner: widget.runtime.learner,
            materialId: widget.materialId,
            sourceVersionId: version.identity.sourceVersionId,
          )
        : 0;
    final resumeChunk = storedResume >= 0 && storedResume < chunks.length ? storedResume : 0;
    final playbackRate = await widget.runtime.store.listenRate(learner: widget.runtime.learner);
    return _ListenSource(
      name: widget.titleOverride?.trim().isNotEmpty == true ? widget.titleOverride!.trim() : version.sourceName,
      text: text,
      sourceVersionId: version.identity.sourceVersionId,
      chunks: chunks,
      resumeChunk: resumeChunk,
      playbackRate: playbackRate,
    );
  }

  Future<void> _play(_ListenSource source, {int? fromChunk}) async {
    final start = fromChunk ?? _resumeChunkOverride ?? source.resumeChunk;
    final safeStart = start >= 0 && start < source.chunks.length ? start : 0;
    final rate = _playbackRate ?? source.playbackRate;
    final token = ++_playToken;
    setState(() {
      _error = null;
      _currentChunkIndex = safeStart;
      _startedPlayback = false;
      _startingPlayback = true;
      _finishedListening = false;
    });
    await _playChunk(source, safeStart, token, rate);
  }

  Future<void> _playChunk(_ListenSource source, int index, int token, double rate) async {
    if (!mounted || token != _playToken) return;
    _currentChunkIndex = index;
    await _speech.speak(
      source.chunks[index],
      locale: 'tr-TR',
      onStart: () {
        if (!mounted || token != _playToken) return;
        setState(() {
          _speaking = true;
          _startedPlayback = true;
          _startingPlayback = false;
          _currentChunkIndex = index;
          _resumeChunkOverride = index;
        });
        unawaited(_saveResume(source, index));
      },
      onDone: () {
        if (token != _playToken) return;
        unawaited(_completeChunk(source, index, token, rate));
      },
      rateMultiplier: rate,
      onError: (_) {
        if (!mounted || token != _playToken) return;
        setState(() {
          _speaking = false;
          _startingPlayback = false;
          _error = 'Bu cihazda Türkçe ses başlatılamadı. Metin yine kullanılabilir.';
        });
      },
    );
  }

  Future<void> _completeChunk(_ListenSource source, int index, int token, double rate) async {
    if (token != _playToken) return;
    final next = index + 1;
    if (next >= source.chunks.length) {
      await _saveResume(source, 0);
      if (!mounted || token != _playToken) return;
      setState(() {
        _speaking = false;
        _startedPlayback = false;
        _startingPlayback = false;
        _finishedListening = true;
        _resumeChunkOverride = 0;
        _currentChunkIndex = 0;
      });
      return;
    }

    await _saveResume(source, next);
    if (!mounted || token != _playToken) return;
    setState(() {
      _resumeChunkOverride = next;
      _currentChunkIndex = next;
    });
    await _playChunk(source, next, token, rate);
  }

  Future<void> _setPlaybackRate(double rate) async {
    if (_speaking || _startingPlayback || _playbackRate == rate) return;
    final previous = _playbackRate;
    setState(() {
      _playbackRate = rate;
      _error = null;
    });
    try {
      await widget.runtime.store.saveListenRate(
        learner: widget.runtime.learner,
        rate: rate,
        updatedAt: DateTime.now().toUtc(),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _playbackRate = previous;
        _error = 'Dinleme hızı kaydedilemedi. Önceki hız korunuyor.';
      });
    }
  }

  Future<void> _saveResume(_ListenSource source, int chunkIndex) {
    if (!widget.persistProgress) return Future<void>.value();
    return widget.runtime.store.saveListenResumeChunk(
      learner: widget.runtime.learner,
      materialId: widget.materialId,
      sourceVersionId: source.sourceVersionId,
      chunkIndex: chunkIndex,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  Future<void> _stop() async {
    _playToken++;
    await _speech.stop();
    if (mounted) {
      setState(() {
        _speaking = false;
        _startedPlayback = false;
        _startingPlayback = false;
      });
    }
  }

  void _retryLoad() {
    setState(() {
      _error = null;
      _resumeChunkOverride = null;
      _finishedListening = false;
      _source = _load();
    });
  }

  @override
  void dispose() {
    _playToken++;
    unawaited(_speech.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final living = LivingDeskReviewScope.active(context);
    final hero = living ? AtelierStyle.ink : AppPalette.primaryDark;
    final accent = living ? AtelierStyle.teal : AppPalette.signal;
    final accentSoft = living ? AtelierStyle.mint : AppPalette.signalSoft;
    final surface = living ? AtelierStyle.paper : AppPalette.surface;
    final line = living ? AtelierStyle.line : AppPalette.outline;
    final ink = living ? AtelierStyle.ink : AppPalette.ink;
    final muted = living ? AtelierStyle.muted : theme.colorScheme.onSurfaceVariant;
    final truthSoft = living ? AtelierStyle.mint : AppPalette.attentionSoft;
    final truthAccent = living ? AtelierStyle.teal : AppPalette.attention;
    final progressAccent = living ? AtelierStyle.mark : AppPalette.signal;
    final primaryButtonStyle = living
        ? FilledButton.styleFrom(backgroundColor: AtelierStyle.ink, foregroundColor: Colors.white)
        : null;
    final outlineButtonStyle = living
        ? OutlinedButton.styleFrom(
            foregroundColor: AtelierStyle.teal,
            side: const BorderSide(color: AtelierStyle.line),
          )
        : null;
    return Scaffold(
      backgroundColor: living ? AtelierStyle.canvas : null,
      appBar: AppBar(
        title: const Text('Dinle'),
        backgroundColor: living ? AtelierStyle.canvas : null,
        foregroundColor: living ? AtelierStyle.ink : null,
      ),
      body: SafeArea(
        child: FutureBuilder<_ListenSource?>(
          future: _source,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || snapshot.data == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sync_problem_rounded, size: 38),
                      const SizedBox(height: 12),
                      const Text('Dinlenecek güncel kaynak bulunamadı.', textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Text(
                        'Bu hata tek başına kaynağın silindiği anlamına gelmez. Materyal verisini yeniden okumayı deneyebilir veya materyale dönebilirsin.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _retryLoad,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Tekrar dene'),
                      ),
                      if (Navigator.of(context).canPop()) ...[
                        const SizedBox(height: 6),
                        TextButton.icon(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Materyale dön'),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }
            final source = snapshot.data!;
            final resumeChunk = _resumeChunkOverride ?? source.resumeChunk;
            final hasResume = resumeChunk > 0;
            final playbackRate = _playbackRate ?? source.playbackRate;
            final visibleChunk = _speaking || _startingPlayback ? _currentChunkIndex : resumeChunk;
            final completedChunks = _finishedListening
                ? source.chunks.length
                : _speaking || _startingPlayback
                ? _currentChunkIndex
                : hasResume
                ? resumeChunk
                : 0;
            final progress = source.chunks.isEmpty ? 0.0 : (completedChunks / source.chunks.length).clamp(0.0, 1.0);

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(color: hero, borderRadius: BorderRadius.circular(living ? 20 : 24)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(color: accentSoft, borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(5),
                                child: CompanionView(
                                  state: _speaking ? CompanionVisualState.speak : CompanionVisualState.listen,
                                  size: 52,
                                ),
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DecoratedBox(
                                    decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(999)),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                      child: Text(
                                        _speaking ? 'ŞİMDİ DİNLİYORSUN' : 'DİNLEME',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 9),
                                  Text(
                                    source.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 6,
                            value: progress,
                            backgroundColor: Colors.white.withValues(alpha: 0.12),
                            color: progressAccent,
                            semanticsLabel: 'Dinleme ilerlemesi',
                            semanticsValue: '%${(progress * 100).round()}',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _finishedListening
                                ? 'Tüm bölümler dinlendi · Hatırlamayı deneyebilirsin'
                                : _speaking || _startingPlayback
                                ? 'Dinleniyor: bölüm ${visibleChunk + 1} / ${source.chunks.length} · $completedChunks bölüm tamamlandı'
                                : hasResume
                                ? 'Kaldığın yer: bölüm ${resumeChunk + 1} / ${source.chunks.length} · $completedChunks bölüm tamamlandı'
                                : 'Dinleme henüz başlamadı · ${source.chunks.length} bölüm',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.72)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DecoratedBox(
                  key: const ValueKey('listen-source-transcript'),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: line),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.article_outlined, color: accent, size: 18),
                            const SizedBox(width: 7),
                            Text(
                              widget.textOverride?.trim().isNotEmpty == true ? 'Quick Recap özeti' : 'Kaynak metni',
                              style: theme.textTheme.labelMedium?.copyWith(color: accent, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(source.text, style: theme.textTheme.bodyLarge?.copyWith(height: 1.58, color: ink)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DecoratedBox(
                  decoration: BoxDecoration(color: truthSoft, borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, color: truthAccent, size: 19),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'Dinlemek öğrenme kanıtı oluşturmaz. Hatırlamayı denediğinde öğrenme durumun güncellenebilir.',
                            style: theme.textTheme.bodySmall?.copyWith(color: ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Dinleme hızı',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: ink),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final rate in const <double>[0.75, 1.0, 1.25, 1.5])
                      ChoiceChip(
                        label: Text(_rateLabel(rate)),
                        selected: playbackRate == rate,
                        selectedColor: living ? AtelierStyle.mark : null,
                        checkmarkColor: living ? AtelierStyle.ink : null,
                        side: living ? const BorderSide(color: AtelierStyle.line) : null,
                        labelStyle: living
                            ? const TextStyle(color: AtelierStyle.ink, fontWeight: FontWeight.w700)
                            : null,
                        onSelected: _speaking || _startingPlayback ? null : (_) => _setPlaybackRate(rate),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Hız tercihin bu cihazda hatırlanır.', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                  ),
                ],
                const SizedBox(height: 18),
                if (_speaking || _startingPlayback)
                  FilledButton.icon(
                    onPressed: _stop,
                    style: primaryButtonStyle,
                    icon: const Icon(Icons.stop_rounded),
                    label: Text(_startingPlayback ? 'Başlatmayı iptal et' : 'Durdur'),
                  )
                else ...[
                  FilledButton.icon(
                    onPressed: () => _play(source),
                    style: primaryButtonStyle,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(hasResume ? 'Kaldığın yerden dinle' : 'Dinlemeye başla'),
                  ),
                  if (hasResume) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => _play(source, fromChunk: 0),
                      style: outlineButtonStyle,
                      child: const Text('Baştan dinle'),
                    ),
                  ],
                ],
                if (widget.onRecall != null) ...[
                  const SizedBox(height: 12),
                  if (living && _finishedListening)
                    FilledButton.icon(
                      onPressed: () {
                        unawaited(_stop().catchError((Object _) {}));
                        if (!mounted) return;
                        widget.onRecall?.call();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AtelierStyle.mark,
                        foregroundColor: AtelierStyle.ink,
                      ),
                      icon: const Icon(Icons.psychology_alt_outlined),
                      label: const Text('Dinlemeyi bitirdin · Şimdi hatırla'),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () {
                        // Stop playback without blocking the navigation gesture on a
                        // platform TTS response. Disposal also stops any active speech.
                        unawaited(_stop().catchError((Object _) {}));
                        if (!mounted) return;
                        widget.onRecall?.call();
                      },
                      style: outlineButtonStyle,
                      icon: const Icon(Icons.psychology_alt_outlined),
                      label: Text(_finishedListening ? 'Dinlemeyi bitirdin · Şimdi hatırla' : 'Şimdi hatırlamayı dene'),
                    ),
                ],
                const SizedBox(height: 10),
                Text(
                  'Dinledikten sonra hatırlamayı denemek, öğrenme durumunu güncelleyebilen aktif adımdır.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _rateLabel(double rate) => switch (rate) {
    0.75 => '0.75×',
    1.0 => '1×',
    1.25 => '1.25×',
    1.5 => '1.5×',
    _ => '$rate×',
  };

  static List<String> _chunkText(String text, {int maxCharacters = 650}) {
    final words = text.trim().split(RegExp(r'\s+'));
    final chunks = <String>[];
    var current = StringBuffer();

    for (final word in words) {
      if (word.isEmpty) continue;
      final projectedLength = current.isEmpty ? word.length : current.length + 1 + word.length;
      if (current.isNotEmpty && projectedLength > maxCharacters) {
        chunks.add(current.toString());
        current = StringBuffer();
      }
      if (current.isNotEmpty) current.write(' ');
      current.write(word);
    }
    if (current.isNotEmpty) chunks.add(current.toString());
    return chunks.isEmpty ? [text.trim()] : chunks;
  }
}

class _ListenSource {
  const _ListenSource({
    required this.name,
    required this.text,
    required this.sourceVersionId,
    required this.chunks,
    required this.resumeChunk,
    required this.playbackRate,
  });

  final String name;
  final String text;
  final SourceVersionId sourceVersionId;
  final List<String> chunks;
  final int resumeChunk;
  final double playbackRate;
}
