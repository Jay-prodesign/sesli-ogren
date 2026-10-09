import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/learning_contracts.dart';
import '../speech/device_speech_output.dart';
import 'app_runtime.dart';
import 'app_theme.dart';
import 'companion_view.dart';

class ListenScreen extends StatefulWidget {
  const ListenScreen({required this.runtime, required this.materialId, this.speechOutput, this.onRecall, super.key});

  final AppRuntime runtime;
  final MaterialId materialId;
  final SpeechOutput? speechOutput;
  final VoidCallback? onRecall;

  @override
  State<ListenScreen> createState() => _ListenScreenState();
}

class _ListenScreenState extends State<ListenScreen> {
  late final SpeechOutput _speech;
  late Future<_ListenSource> _source;
  bool _speaking = false;
  bool _startedPlayback = false;
  bool _startingPlayback = false;
  bool _finishedListening = false;
  String? _error;
  int? _resumeChunkOverride;
  int _currentChunkIndex = 0;
  int _playToken = 0;

  @override
  void initState() {
    super.initState();
    _speech = widget.speechOutput ?? DeviceSpeechOutput();
    _source = _load();
  }

  Future<_ListenSource> _load() async {
    final version = await widget.runtime.store.currentSourceVersion(
      learner: widget.runtime.learner,
      materialId: widget.materialId,
    );
    if (version == null) {
      throw StateError('listen_source_missing');
    }
    final extracted = await widget.runtime.store.extractedContentForSource(
      learner: widget.runtime.learner,
      sourceVersionId: version.identity.sourceVersionId,
    );
    if (extracted == null || !extracted.isValid || extracted.normalizedText.trim().isEmpty) {
      throw StateError('listen_content_missing');
    }

    final text = extracted.normalizedText.trim();
    final chunks = _chunkText(text);
    final storedResume = await widget.runtime.store.listenResumeChunk(
      learner: widget.runtime.learner,
      materialId: widget.materialId,
      sourceVersionId: version.identity.sourceVersionId,
    );
    final resumeChunk = storedResume >= 0 && storedResume < chunks.length ? storedResume : 0;
    return _ListenSource(
      name: version.sourceName,
      text: text,
      sourceVersionId: version.identity.sourceVersionId,
      chunks: chunks,
      resumeChunk: resumeChunk,
    );
  }

  Future<void> _play(_ListenSource source, {int? fromChunk}) async {
    final start = fromChunk ?? _resumeChunkOverride ?? source.resumeChunk;
    final safeStart = start >= 0 && start < source.chunks.length ? start : 0;
    final token = ++_playToken;
    setState(() {
      _error = null;
      _currentChunkIndex = safeStart;
      _startedPlayback = false;
      _startingPlayback = true;
      _finishedListening = false;
    });
    await _playChunk(source, safeStart, token);
  }

  Future<void> _playChunk(_ListenSource source, int index, int token) async {
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
        unawaited(_completeChunk(source, index, token));
      },
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

  Future<void> _completeChunk(_ListenSource source, int index, int token) async {
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
    await _playChunk(source, next, token);
  }

  Future<void> _saveResume(_ListenSource source, int chunkIndex) {
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
    if (mounted)
      setState(() {
        _speaking = false;
        _startedPlayback = false;
        _startingPlayback = false;
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
    return Scaffold(
      appBar: AppBar(title: const Text('Dinle')),
      body: SafeArea(
        child: FutureBuilder<_ListenSource>(
          future: _source,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Dinlenecek güncel kaynak bulunamadı. Materyale dönüp kaynağı yeniden aç.'),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final source = snapshot.data!;
            final resumeChunk = _resumeChunkOverride ?? source.resumeChunk;
            final hasResume = resumeChunk > 0;
            final visibleChunk = _speaking ? _currentChunkIndex : resumeChunk;
            final progress = _finishedListening
                ? 1.0
                : _speaking || _startedPlayback || hasResume
                ? (visibleChunk + 1) / source.chunks.length
                : 0.0;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(color: AppPalette.primaryDark, borderRadius: BorderRadius.circular(24)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppPalette.signalSoft,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(5),
                                child: CompanionView(
                                  state: _speaking ? CompanionVisualState.speak : CompanionVisualState.listen,
                                  size: 64,
                                ),
                              ),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: AppPalette.signal,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
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
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 6,
                            value: progress,
                            backgroundColor: Colors.white.withValues(alpha: 0.12),
                            color: AppPalette.signal,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _finishedListening
                              ? 'Tüm bölümler dinlendi · Hatırlamayı deneyebilirsin'
                              : progress == 0
                              ? 'Dinleme henüz başlamadı · ${source.chunks.length} bölüm'
                              : 'Dinleme konumu: bölüm ${visibleChunk + 1} / ${source.chunks.length}',
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.72)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DecoratedBox(
                  decoration: BoxDecoration(color: AppPalette.attentionSoft, borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppPalette.attention, size: 19),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'Dinlemek öğrenme kanıtı oluşturmaz. Hatırlamayı denediğinde öğrenme durumun güncellenebilir.',
                            style: theme.textTheme.bodySmall?.copyWith(color: AppPalette.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppPalette.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppPalette.outline),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.article_outlined, color: AppPalette.signal, size: 18),
                            const SizedBox(width: 7),
                            Text(
                              'Kaynak metni',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: AppPalette.signal,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(source.text, style: theme.textTheme.bodyLarge?.copyWith(height: 1.58)),
                      ],
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                ],
                const SizedBox(height: 18),
                if (_speaking || _startingPlayback)
                  FilledButton.icon(
                    onPressed: _stop,
                    icon: const Icon(Icons.stop_rounded),
                    label: Text(_startingPlayback ? 'Başlatmayı iptal et' : 'Durdur'),
                  )
                else ...[
                  FilledButton.icon(
                    onPressed: () => _play(source),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(hasResume ? 'Kaldığın yerden dinle' : 'Dinlemeye başla'),
                  ),
                  if (hasResume) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(onPressed: () => _play(source, fromChunk: 0), child: const Text('Baştan dinle')),
                  ],
                ],
                if (widget.onRecall != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await _stop();
                      if (!mounted) return;
                      widget.onRecall?.call();
                    },
                    icon: const Icon(Icons.psychology_alt_outlined),
                    label: Text(_finishedListening ? 'Dinlemeyi bitirdin · Şimdi hatırla' : 'Şimdi hatırlamayı dene'),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  'Dinledikten sonra hatırlamayı denemek, öğrenme durumunu güncelleyebilen aktif adımdır.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

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
  });

  final String name;
  final String text;
  final SourceVersionId sourceVersionId;
  final List<String> chunks;
  final int resumeChunk;
}
