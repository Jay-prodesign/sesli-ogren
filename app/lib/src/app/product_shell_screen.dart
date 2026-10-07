import 'package:flutter/material.dart';

import '../domain/learning_contracts.dart';
import '../domain/learning_truth.dart';
import 'app_runtime.dart';
import 'app_theme.dart';
import 'companion_view.dart';
import 'learning_slice_screen.dart';
import 'listen_screen.dart';
import 'material_workspace_screen.dart';
import 'profile_surface.dart';
import 'progress_surface.dart';

class ProductShellScreen extends StatefulWidget {
  const ProductShellScreen({required this.runtime, this.onAccountDeleted, this.onSignOut, super.key});

  final AppRuntime runtime;
  final VoidCallback? onAccountDeleted;
  final Future<void> Function()? onSignOut;

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
    final material = materials.reduce(
      (current, candidate) => candidate.updatedAt.isAfter(current.updatedAt) ? candidate : current,
    );
    final source = await widget.runtime.store.currentSourceVersion(
      learner: widget.runtime.learner,
      materialId: material.id,
    );
    final continuation = await widget.runtime.recall.reopen(learner: widget.runtime.learner, materialId: material.id);
    final progress = <ProgressItem>[];
    for (final item in materials) {
      progress.add(
        ProgressItem(
          material: item,
          continuation: await widget.runtime.recall.reopen(learner: widget.runtime.learner, materialId: item.id),
        ),
      );
    }
    return _HomeSnapshot(
      material: material,
      source: source,
      continuation: continuation,
      materials: materials,
      progress: progress,
    );
  }

  Future<void> _openLearning() async {
    final materialId = (await _snapshot).material?.id ?? widget.runtime.newMaterialId();
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => LearningSliceScreen(runtime: widget.runtime, materialId: materialId),
      ),
    );
    if (!mounted) return;
    setState(_refresh);
  }

  Future<void> _openWorkspace([MaterialId? materialId]) async {
    final selected = materialId ?? (await _snapshot).material?.id;
    if (selected == null || !mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MaterialWorkspaceScreen(runtime: widget.runtime, materialId: selected),
      ),
    );
    if (!mounted) return;
    setState(_refresh);
  }

  Future<void> _openListen() async {
    final material = (await _snapshot).material;
    if (material == null || !mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ListenScreen(runtime: widget.runtime, materialId: material.id),
      ),
    );
  }

  Future<void> _deleteMaterial(MaterialRecord material) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Materyali sil?'),
        content: Text(
          '“${material.title}” Kütüphane’den kaldırılacak ve erişilebilir kaynak içeriği silinecek. '
          'Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Sil')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await widget.runtime.store.deleteMaterial(
      learner: widget.runtime.learner,
      materialId: material.id,
      deletedAt: DateTime.now().toUtc(),
    );
    if (!mounted) return;

    setState(_refresh);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Materyal silindi.')));
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
                _LibrarySurface(
                  data: data,
                  onOpenLearning: _openLearning,
                  onOpenWorkspace: _openWorkspace,
                  onDeleteMaterial: _deleteMaterial,
                ),
                ProgressSurface(items: data.progress, onOpenMaterial: _openWorkspace),
                ProfileSurface(
                  runtime: widget.runtime,
                  onAccountDeleted: widget.onAccountDeleted,
                  onSignOut: widget.onSignOut,
                ),
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
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'İlerleme',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profil',
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
      key: const ValueKey('home-surface'),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 36),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppPalette.primarySoft,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppPalette.primary.withValues(alpha: 0.12)),
              ),
              child: const Padding(
                padding: EdgeInsets.all(7),
                child: CompanionView(state: CompanionVisualState.idle, size: 50),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sesli Öğren', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 2),
                  Text(
                    hasMaterial
                        ? 'Materyalin hazır. Sıradaki anlamlı adıma geç.'
                        : 'Kendi materyalini aktif öğrenmeye dönüştür.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        if (!hasMaterial)
          _FirstMaterialHero(onPressed: onOpenLearning)
        else ...[
          _ContinueHero(
            data: data,
            title: _nextTitle(data.continuation),
            reason: _nextReason(data.continuation),
            onPressed: onOpenWorkspace,
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: Text('Çalışma yolları', style: theme.textTheme.titleMedium)),
              Text(
                'Aynı kaynakla',
                style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 10),
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

class _FirstMaterialHero extends StatelessWidget {
  const _FirstMaterialHero({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: 'İlk materyalini ekle ve aktif öğrenmeye başla',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppPalette.primaryDark,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppPalette.primaryDark.withValues(alpha: 0.16),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeroLabel(
                icon: Icons.auto_stories_rounded,
                text: 'KENDİ MATERYALİN · TEK ÖĞRENME AKIŞI',
                foreground: Colors.white.withValues(alpha: 0.78),
              ),
              const SizedBox(height: 20),
              Text('İlk materyalini ekle', style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white)),
              const SizedBox(height: 9),
              Text(
                'PDF veya metnini ekle. Dinleme, hatırlama ve açıklama aynı kaynağa bağlı kalsın.',
                style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.82), height: 1.45),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppPalette.primaryDark),
                onPressed: onPressed,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Materyal ekle'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContinueHero extends StatelessWidget {
  const _ContinueHero({required this.data, required this.title, required this.reason, required this.onPressed});

  final _HomeSnapshot data;
  final String title;
  final String reason;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final material = data.material!;
    final theme = Theme.of(context);
    final sourceName = data.source?.sourceName ?? 'Kaynak hazır';
    final mediaIcon = material.mediaType == SourceMediaType.pdf ? Icons.picture_as_pdf_rounded : Icons.notes_rounded;

    return Material(
      color: AppPalette.primaryDark,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('home-continuation-hero'),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(9),
                      child: Icon(mediaIcon, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Materyalin',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.68),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          material.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_outward_rounded, color: Colors.white70, size: 20),
                ],
              ),
              if (sourceName != material.title) ...[
                const SizedBox(height: 7),
                Text(
                  sourceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.62)),
                ),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Divider(color: Colors.white.withValues(alpha: 0.16)),
              ),
              _HeroLabel(icon: Icons.bolt_rounded, text: 'Şimdi ne yapmalı?', foreground: const Color(0xFFAFC0FF)),
              const SizedBox(height: 10),
              Text(title, style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white)),
              const SizedBox(height: 8),
              Text(
                reason,
                style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.82), height: 1.42),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppPalette.primaryDark),
                onPressed: onPressed,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Devam et'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroLabel extends StatelessWidget {
  const _HeroLabel({required this.icon, required this.text, required this.foreground});

  final IconData icon;
  final String text;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: foreground, size: 16),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: foreground, fontWeight: FontWeight.w800, letterSpacing: 0.65),
          ),
        ),
      ],
    );
  }
}

class _LibrarySurface extends StatelessWidget {
  const _LibrarySurface({
    required this.data,
    required this.onOpenLearning,
    required this.onOpenWorkspace,
    required this.onDeleteMaterial,
  });

  final _HomeSnapshot data;
  final VoidCallback onOpenLearning;
  final ValueChanged<MaterialId> onOpenWorkspace;
  final ValueChanged<MaterialRecord> onDeleteMaterial;

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
            _LibraryMaterialCard(
              material: material,
              onPressed: () => onOpenWorkspace(material.id),
              onDelete: () => onDeleteMaterial(material),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _LibraryMaterialCard extends StatelessWidget {
  const _LibraryMaterialCard({required this.material, required this.onPressed, required this.onDelete});

  final MaterialRecord material;
  final VoidCallback onPressed;
  final VoidCallback onDelete;

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
        trailing: IconButton(
          tooltip: 'Materyali sil',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline_rounded),
        ),
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
    return Material(
      color: AppPalette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppPalette.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 14, 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: title == 'Dinle' ? AppPalette.successSoft : AppPalette.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(9),
                  child: Icon(icon, size: 20, color: title == 'Dinle' ? AppPalette.success : AppPalette.primary),
                ),
              ),
              const SizedBox(height: 14),
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                body,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.35),
              ),
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
  const _HomeSnapshot({
    this.material,
    this.source,
    this.continuation,
    this.materials = const [],
    this.progress = const [],
  });

  final MaterialRecord? material;
  final SourceVersionRecord? source;
  final LearningContinuation? continuation;
  final List<MaterialRecord> materials;
  final List<ProgressItem> progress;
}
