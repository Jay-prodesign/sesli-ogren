import 'package:flutter/material.dart';

import 'app_runtime.dart';
import 'learning_slice_screen.dart';
import 'listen_screen.dart';

class MaterialOverviewScreen extends StatefulWidget {
  const MaterialOverviewScreen({required this.runtime, super.key});

  final AppRuntime runtime;

  @override
  State<MaterialOverviewScreen> createState() => _MaterialOverviewScreenState();
}

class _MaterialOverviewScreenState extends State<MaterialOverviewScreen> {
  late Future<_MaterialOverview> _overview;

  @override
  void initState() {
    super.initState();
    _overview = _load();
  }

  Future<_MaterialOverview> _load() async {
    final material = await widget.runtime.store.material(
      learner: widget.runtime.learner,
      materialId: AppRuntime.primaryMaterialId,
    );
    if (material == null || !material.isActive) {
      throw StateError('material_missing');
    }
    final source = await widget.runtime.store.currentSourceVersion(
      learner: widget.runtime.learner,
      materialId: material.id,
    );
    if (source == null) throw StateError('source_missing');
    final extracted = await widget.runtime.store.extractedContentForSource(
      learner: widget.runtime.learner,
      sourceVersionId: source.identity.sourceVersionId,
    );
    if (extracted == null || !extracted.isValid) {
      throw StateError('content_missing');
    }

    final normalized = extracted.normalizedText.trim();
    final orientation = normalized.length <= 520
        ? normalized
        : '${normalized.substring(0, 520).trimRight()}…';
    return _MaterialOverview(
      title: material.title,
      sourceName: source.sourceName,
      orientation: orientation,
    );
  }

  Future<void> _openRecall() => Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => LearningSliceScreen(runtime: widget.runtime),
        ),
      );

  Future<void> _openListen() => Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ListenScreen(runtime: widget.runtime),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Materyal')),
      body: SafeArea(
        child: FutureBuilder<_MaterialOverview>(
          future: _overview,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Materyalin güncel içeriği açılamadı.'),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
              children: [
                Text(
                  data.title,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  data.sourceName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Kaynağa hızlı bakış',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Bu bir AI özeti değil; yüklediğin kaynağın başlangıcından doğrudan bir görünüm.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: SelectableText(
                      data.orientation,
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Nasıl devam etmek istersin?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _openRecall,
                  icon: const Icon(Icons.psychology_alt_outlined),
                  label: const Text('Hatırlamayı dene'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _openListen,
                  icon: const Icon(Icons.headphones_rounded),
                  label: const Text('Dinle'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MaterialOverview {
  const _MaterialOverview({
    required this.title,
    required this.sourceName,
    required this.orientation,
  });

  final String title;
  final String sourceName;
  final String orientation;
}
