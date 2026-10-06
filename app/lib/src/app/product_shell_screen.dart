import 'package:flutter/material.dart';

import '../domain/learning_contracts.dart';
import '../domain/learning_truth.dart';
import 'app_runtime.dart';
import 'companion_view.dart';
import 'learning_slice_screen.dart';
import 'listen_screen.dart';
import 'material_workspace_screen.dart';

class ProductShellScreen extends StatefulWidget {
  const ProductShellScreen({required this.runtime, super.key});

  final AppRuntime runtime;

  @override
  State<ProductShellScreen> createState() => _ProductShellScreenState();
}

class _ProductShellScreenState extends State<ProductShellScreen> {
  int _index = 0;
  late Future<_HomeSnapshot> _snapshot;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _snapshot = _loadSnapshot();
  }

  Future<_HomeSnapshot> _loadSnapshot() async {
    final materials = await widget.runtime.store.activeMaterials(learner: widget.runtime.learner);
    if (materials.isEmpty) return const _HomeSnapshot();
    final material = materials.first;
    final source = await widget.runtime.store.currentSourceVersion(
      learner: widget.runtime.learner,
      materialId: material.id,
    );
    final continuation = await widget.runtime.recall.reopen(
      learner: widget.runtime.learner,
      materialId: material.id,
    );
    return _HomeSnapshot(
      material: material,
      source: source,
      continuation: continuation,
      materials: materials,
    );
  }

  Future<void> _openLearning() async {
    await Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => LearningSliceScreen(runtime: widget.runtime, materialId: AppRuntime.primaryMaterialId)));
    if (!mounted) return;
    setState(_refresh);
  }

  Future<void> _openWorkspace([MaterialId? materialId]) async {
    await Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => MaterialWorkspaceScreen(runtime: widget.runtime, materialId: materialId ?? (await _snapshot).material!.id)));
    if (!mounted) return;
    setState(_refresh);
  }

  Future<void> _openListen() async {
    final material = (await _snapshot).material;
    if (material == null || !mounted) return;
    await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => ListenScreen(runtime: widget.runtime, materialId: material.id)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<_HomeSnapshot>(
          future: _snapshot,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data!;
            return IndexedStack(
              index: _index,
              children: [
                _HomeSurface(
                  data: data,
                  onOpenLearning: _openLearning,
                  onOpenListen: _openListen,
                  onOpenWorkspace: () => _openWorkspace(),
                ),
                _LibrarySurface(data: data, onOpenLearning: _openLearning, onOpenWorkspace: _openWorkspace),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Ana Sayfa',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_books_outlined),
            selectedIcon: Icon(Icons.library_books_rounded),
            label: 'Kütüphane',
          ),
        ],
      ),
    );
  }
}

class _HomeSurface extends StatelessWidget {
  const _HomeSurface({
    required this.data,
    required this.onOpenLearning,
    required this.onOpenListen,
    required this.onOpenWorkspace,
  });

  final _HomeSnapshot data;
  final VoidCallback onOpenLearning;
  final VoidCallback onOpenListen;
  final VoidCallback onOpenWorkspace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasMaterial = data.material != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Row(
          children: [
            const CompanionView(state: CompanionVisualState.idle, size: 64),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sesli Öğren', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  Text(
                    hasMaterial ? 'Kaldığın yerden devam et.' : 'Materyalini öğrenmeye dönüştür.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        if (!hasMaterial)
          _PrimaryCard(
            title: 'İlk materyalini ekle',
            body: 'Metnini ekle; kaynağa bağlı bir öğrenme adımıyla hemen başla.',
            buttonLabel: 'Materyal ekle',
            icon: Icons.add_rounded,
            onPressed: onOpenLearning,
          )
        else ...[
          Text('Şimdi ne yapmalı?', style: theme.textTheme.labelLarge),
          const SizedBox(height: 10),
          _PrimaryCard(
            title: _nextTitle(data.continuation),
            body: _nextReason(data.continuation),
            buttonLabel: 'Devam et',
            icon: Icons.arrow_forward_rounded,
            onPressed: onOpenWorkspace,
          ),
          const SizedBox(height: 22),
          Text('Materyalin', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          _MaterialCard(data: data, onPressed: onOpenWorkspace),
          const SizedBox(height: 22),
          _ContextRow(onRecall: onOpenLearning, onListen: onOpenListen),
        ],
      ],
    );
  }

  static String _nextTitle(LearningContinuation? continuation) {
    if (continuation == null) return 'Aktif öğrenmeye başla';
    return switch (continuation.state.kind) {
      RecallStateKind.retrievedOnce => 'Hatırlamanı güçlendir',
      RecallStateKind.developing => 'Bir kez daha dene',
      RecallStateKind.needsReview => 'Kısa bir tekrar yap',
      RecallStateKind.notAssessed => 'Ne kadar hatırladığını gör',
    };
  }

  static String _nextReason(LearningContinuation? continuation) =>
      continuation?.nextAction.reasonText ?? 'Kaynağından kısa bir Recall ile ilk gerçek öğrenme kanıtını oluştur.';
}

class _LibrarySurface extends StatelessWidget {
  const _LibrarySurface({required this.data, required this.onOpenLearning, required this.onOpenWorkspace});

  final _HomeSnapshot data;
  final VoidCallback onOpenLearning;
  final ValueChanged<MaterialId> onOpenWorkspace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        Text('Kütüphane', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          'Kaynakların ve öğrenme devamın burada.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        if (data.materials.isEmpty)
          _PrimaryCard(
            title: 'Henüz materyal yok',
            body: 'İlk kaynağını eklediğinde burada kaldığın yerden devam edebilirsin.',
            buttonLabel: 'Materyal ekle',
            icon: Icons.add_rounded,
            onPressed: onOpenLearning,
          )
        else
          for (final material in data.materials) ...[
            _LibraryMaterialCard(material: material, onPressed: () => onOpenWorkspace(material.id)),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _LibraryMaterialCard extends StatelessWidget {
  const _LibraryMaterialCard({required this.material, required this.onPressed});
  final MaterialRecord material;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      child: ListTile(
        onTap: onPressed,
        leading: Icon(material.mediaType == SourceMediaType.pdf ? Icons.picture_as_pdf_outlined : Icons.notes_rounded),
        title: Text(material.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _ContextRow extends StatelessWidget {
  const _ContextRow({required this.onRecall, required this.onListen});

  final VoidCallback onRecall;
  final VoidCallback onListen;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ContextCard(
            icon: Icons.psychology_alt_outlined,
            title: 'Hatırla',
            body: 'Aktif olarak geri çağır.',
            onPressed: onRecall,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ContextCard(
            icon: Icons.headphones_rounded,
            title: 'Dinle',
            body: 'Kaynağını Türkçe dinle.',
            onPressed: onListen,
          ),
        ),
      ],
    );
  }
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({required this.icon, required this.title, required this.body, this.onPressed});

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(height: 12),
              Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(body, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  const _MaterialCard({required this.data, required this.onPressed});

  final _HomeSnapshot data;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final material = data.material!;
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  material.mediaType == SourceMediaType.pdf ? Icons.picture_as_pdf_outlined : Icons.notes_rounded,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(material.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(
                      data.source?.sourceName ?? 'Kaynak hazır',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
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

class _PrimaryCard extends StatelessWidget {
  const _PrimaryCard({
    required this.title,
    required this.body,
    required this.buttonLabel,
    required this.icon,
    required this.onPressed,
  });

  final String title;
  final String body;
  final String buttonLabel;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(body),
            const SizedBox(height: 18),
            FilledButton.icon(onPressed: onPressed, icon: Icon(icon), label: Text(buttonLabel)),
          ],
        ),
      ),
    );
  }
}

class _HomeSnapshot {
  const _HomeSnapshot({this.material, this.source, this.continuation, this.materials = const []});

  final MaterialRecord? material;
  final SourceVersionRecord? source;
  final LearningContinuation? continuation;
  final List<MaterialRecord> materials;
}
