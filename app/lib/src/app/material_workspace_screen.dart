import 'package:flutter/material.dart';

import '../domain/learning_contracts.dart';
import '../domain/learning_truth.dart';
import 'app_runtime.dart';
import 'app_theme.dart';
import 'explain_screen.dart';
import 'focus_screen.dart';
import 'learning_slice_screen.dart';
import 'listen_screen.dart';

class MaterialWorkspaceScreen extends StatefulWidget {
  const MaterialWorkspaceScreen({required this.runtime, required this.materialId, super.key});

  final AppRuntime runtime;
  final MaterialId materialId;

  @override
  State<MaterialWorkspaceScreen> createState() => _MaterialWorkspaceScreenState();
}

class _MaterialWorkspaceScreenState extends State<MaterialWorkspaceScreen> {
  late Future<_WorkspaceSnapshot> _snapshot;

  @override
  void initState() {
    super.initState();
    _snapshot = _load();
  }

  Future<_WorkspaceSnapshot> _load() async {
    final material = await widget.runtime.store.material(
      learner: widget.runtime.learner,
      materialId: widget.materialId,
    );
    if (material == null || !material.isActive) {
      throw StateError('workspace_material_missing');
    }
    final source = await widget.runtime.store.currentSourceVersion(
      learner: widget.runtime.learner,
      materialId: material.id,
    );
    if (source == null) {
      throw StateError('workspace_source_missing');
    }
    final extracted = await widget.runtime.store.extractedContentForSource(
      learner: widget.runtime.learner,
      sourceVersionId: source.identity.sourceVersionId,
    );
    final continuation = await widget.runtime.recall.reopen(learner: widget.runtime.learner, materialId: material.id);
    return _WorkspaceSnapshot(material: material, source: source, extracted: extracted, continuation: continuation);
  }

  Future<void> _openRecall() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => LearningSliceScreen(runtime: widget.runtime, materialId: widget.materialId),
      ),
    );
    if (!mounted) return;
    setState(() => _snapshot = _load());
  }

  Future<void> _openListen() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ListenScreen(runtime: widget.runtime, materialId: widget.materialId),
    ),
  );

  Future<void> _openFocus(_WorkspaceSnapshot data) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) =>
          FocusScreen(runtime: widget.runtime, source: data.source, sourceText: data.extracted?.normalizedText ?? ''),
    ),
  );

  Future<void> _openExplain(SourceVersionRecord source) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ExplainScreen(runtime: widget.runtime, source: source),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Materyal')),
      body: SafeArea(
        child: FutureBuilder<_WorkspaceSnapshot>(
          future: _snapshot,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Padding(padding: EdgeInsets.all(24), child: Text('Materyal açılamadı.')),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return _WorkspaceBody(
              data: snapshot.data!,
              onRecall: _openRecall,
              onListen: _openListen,
              onExplain: () => _openExplain(snapshot.data!.source),
              onFocus: () => _openFocus(snapshot.data!),
            );
          },
        ),
      ),
    );
  }
}

class _WorkspaceBody extends StatelessWidget {
  const _WorkspaceBody({
    required this.data,
    required this.onRecall,
    required this.onListen,
    required this.onExplain,
    required this.onFocus,
  });

  final _WorkspaceSnapshot data;
  final VoidCallback onRecall;
  final VoidCallback onListen;
  final VoidCallback onExplain;
  final VoidCallback onFocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                data.material.mediaType == SourceMediaType.pdf ? Icons.picture_as_pdf_outlined : Icons.notes_rounded,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.material.title,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _sourceLabel(data),
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Öğrenme durumu', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        _LearningStatusCard(continuation: data.continuation, onRecall: onRecall),
        const SizedBox(height: 24),
        Text('Çalış', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        _ActionCard(
          icon: Icons.auto_awesome_outlined,
          title: 'Açıkla',
          body: 'Kaynağına bağlı, kaynak metinden açıkça ayrılan öğretici açıklama.',
          onPressed: onExplain,
        ),
        const SizedBox(height: 10),
        _ActionCard(
          icon: Icons.center_focus_strong_rounded,
          title: 'Odaklan',
          body: 'Kaynağa bağlı kısa çalışma: soru sor, ipucu veya doğrudan açıklama iste.',
          onPressed: onFocus,
        ),
        const SizedBox(height: 10),
        _ActionCard(
          icon: Icons.psychology_alt_outlined,
          title: 'Hatırla',
          body: 'Kaynağa bakmadan geri çağır; öğrenme durumunu güncelleyebilen aktif adım.',
          onPressed: onRecall,
        ),
        const SizedBox(height: 10),
        _ActionCard(
          icon: Icons.headphones_rounded,
          title: 'Dinle',
          body: 'Kaynak metnini cihazın Türkçe sesiyle dinle.',
          onPressed: onListen,
        ),
        if (data.extracted != null && data.extracted!.normalizedText.trim().isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Hızlı bakış', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'AI özeti değil; yüklediğin kaynağın başlangıcından doğrudan bir görünüm.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppPalette.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppPalette.outline),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                _orientationText(data.extracted!.normalizedText),
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text('Kaynak', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(data.source.sourceName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  data.source.identity.trustClass == SourceTrustClass.userProvided
                      ? 'Senin eklediğin kaynak'
                      : 'Doğrulanmış kaynak',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                if (data.extracted != null) ...[
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () => _showSource(context, data.extracted!.normalizedText),
                    icon: const Icon(Icons.article_outlined),
                    label: const Text('Kaynak metnini gör'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _orientationText(String text) {
    final normalized = text.trim();
    if (normalized.length <= 520) return normalized;
    return '${normalized.substring(0, 520).trimRight()}…';
  }

  static String _sourceLabel(_WorkspaceSnapshot data) {
    final kind = data.material.mediaType == SourceMediaType.pdf ? 'PDF' : 'Metin';
    final chars = data.extracted?.normalizedText.length;
    return chars == null ? kind : '$kind • $chars karakter';
  }

  static Future<void> _showSource(BuildContext context, String text) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.86,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  Expanded(child: Text('Kaynak metni', style: Theme.of(context).textTheme.titleLarge)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: SelectableText(text)),
            ),
          ],
        ),
      ),
    ),
  );
}

class _LearningStatusCard extends StatelessWidget {
  const _LearningStatusCard({required this.continuation, required this.onRecall});

  final LearningContinuation? continuation;
  final VoidCallback onRecall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = continuation?.state.kind;
    final (title, body, icon) = switch (state) {
      RecallStateKind.retrievedOnce => (
        'Bir kez bağımsız hatırlandı',
        'Bu güçlü bir sinyal, ancak henüz ustalık iddiası değil.',
        Icons.check_circle_outline_rounded,
      ),
      RecallStateKind.developing => (
        'Gelişiyor',
        continuation?.nextAction.reasonText ?? 'Bir sonraki aktif deneme hazır.',
        Icons.trending_up_rounded,
      ),
      RecallStateKind.needsReview => (
        'Tekrar gerekli',
        continuation?.nextAction.reasonText ?? 'Kaynağı kısaca gözden geçirip yeniden dene.',
        Icons.refresh_rounded,
      ),
      RecallStateKind.notAssessed || null => (
        'Henüz ölçülmedi',
        'İlk Recall denemesi gerçek öğrenme durumunu görünür kılar.',
        Icons.radio_button_unchecked_rounded,
      ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(color: AppPalette.primaryDark, borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(9),
                    child: Icon(icon, color: Colors.white, size: 21),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sıradaki aktif adım',
                        style: theme.textTheme.labelMedium?.copyWith(color: const Color(0xFFAFC0FF)),
                      ),
                      const SizedBox(height: 4),
                      Text(title, style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(body, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.80))),
            const SizedBox(height: 18),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppPalette.primaryDark),
              onPressed: onRecall,
              icon: const Icon(Icons.psychology_alt_rounded),
              label: const Text('Hatırla ile devam'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.icon, required this.title, required this.body, required this.onPressed});

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppPalette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppPalette.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: title == 'Dinle' ? AppPalette.successSoft : AppPalette.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(9),
                  child: Icon(icon, size: 21, color: title == 'Dinle' ? AppPalette.success : AppPalette.primary),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(body, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceSnapshot {
  const _WorkspaceSnapshot({
    required this.material,
    required this.source,
    required this.extracted,
    required this.continuation,
  });

  final MaterialRecord material;
  final SourceVersionRecord source;
  final ExtractedContentRecord? extracted;
  final LearningContinuation? continuation;
}
