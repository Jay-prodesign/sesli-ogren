import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/learning_contracts.dart';
import '../speech/device_speech_output.dart';
import 'app_runtime.dart';
import 'companion_view.dart';

class ListenScreen extends StatefulWidget {
  const ListenScreen({required this.runtime, required this.materialId, super.key});

  final AppRuntime runtime;
  final MaterialId materialId;

  @override
  State<ListenScreen> createState() => _ListenScreenState();
}

class _ListenScreenState extends State<ListenScreen> {
  final DeviceSpeechOutput _speech = DeviceSpeechOutput();
  late Future<_ListenSource> _source;
  bool _speaking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
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
    return _ListenSource(name: version.sourceName, text: extracted.normalizedText.trim());
  }

  Future<void> _play(String text) async {
    setState(() => _error = null);
    await _speech.speak(
      text,
      locale: 'tr-TR',
      onStart: () {
        if (mounted) setState(() => _speaking = true);
      },
      onDone: () {
        if (mounted) setState(() => _speaking = false);
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _speaking = false;
          _error = 'Bu cihazda Türkçe ses başlatılamadı. Metin yine kullanılabilir.';
        });
      },
    );
  }

  Future<void> _stop() async {
    await _speech.stop();
    if (mounted) setState(() => _speaking = false);
  }

  @override
  void dispose() {
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
                else
                  FilledButton.icon(
                    onPressed: () => _play(source.text),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Dinlemeye başla'),
                  ),
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
}

class _ListenSource {
  const _ListenSource({required this.name, required this.text});

  final String name;
  final String text;
}
