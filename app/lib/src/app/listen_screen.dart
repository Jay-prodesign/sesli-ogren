import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/learning_contracts.dart';
import '../speech/device_speech_output.dart';
import 'app_runtime.dart';
import 'companion_view.dart';

class ListenScreen extends StatefulWidget {
  const ListenScreen({
    required this.runtime,
    required this.materialId,
    this.speechOutput,
    super.key,
  });

  final AppRuntime runtime;
  final MaterialId materialId;
  final SpeechOutput? speechOutput;

  @override
  State<ListenScreen> createState() => _ListenScreenState();
}

class _ListenScreenState extends State<ListenScreen> {
  late final SpeechOutput _speech;
  late Future<_ListenSource> _source;
  bool _speaking = false;
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
    if (mounted) setState(() => _speaking = false);
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

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
              children: [
                Center(
                  child: CompanionView(
                    state: _speaking ? CompanionVisualState.speak : CompanionVisualState.idle,
                    size: 108,
                  ),
                ),
                const SizedBox(height: 16),
                Text(source.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  'Dinlemek maruziyettir; tek başına öğrenme başarısı olarak sayılmaz.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                Text(
                  'Dinleme konumu: bölüm ${visibleChunk + 1} / ${source.chunks.length}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(source.text, style: theme.textTheme.bodyLarge?.copyWith(height: 1.55)),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                ],
                const SizedBox(height: 18),
                if (_speaking)
                  FilledButton.icon(onPressed: _stop, icon: const Icon(Icons.stop_rounded), label: const Text('Durdur'))
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
