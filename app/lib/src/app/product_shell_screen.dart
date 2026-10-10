import 'package:flutter/material.dart';

import '../domain/learning_contracts.dart';
import '../domain/learning_truth.dart';
import '../learning/recall_learning_service.dart';
import '../generation/supabase_source_summary_gateway.dart';
import 'app_runtime.dart';
import 'app_theme.dart';
import 'atelier_learning_surfaces.dart';
import 'companion_view.dart';
import 'learning_slice_screen.dart';
import 'la0040_visual_treatments.dart';
import 'living_study_desk_home.dart';
import 'listen_screen.dart';
import 'material_workspace_screen.dart';
import 'source_reader_screen.dart';
import 'quick_recap_screen.dart';
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
  MaterialId? _deletingMaterialId;
  late Future<_HomeSnapshot> _snapshot;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _snapshot = _loadSnapshot();
  }

  Future<LearningContinuation?> _continuationFor(MaterialId materialId) async {
    try {
      return await widget.runtime.recall.reopen(learner: widget.runtime.learner, materialId: materialId);
    } on RecallLearningException {
      return widget.runtime.recall.repairContinuation(learner: widget.runtime.learner, materialId: materialId);
    }
  }

  Future<_HomeSnapshot> _loadSnapshot() async {
    // The current source-first Home uses a real source preview. The explicit
    // legacy fallback skips this extra read. This ancestor lookup is safe during
    // initState (unlike dependOnInheritedWidgetOfExactType).
    final livingReview = context.getElementForInheritedWidgetOfExactType<LivingDeskReviewScope>() != null;
    final materials = await widget.runtime.store.activeMaterials(learner: widget.runtime.learner);
    if (materials.isEmpty) return const _HomeSnapshot();
    final progress = await Future.wait(
      materials.map((item) async => ProgressItem(material: item, continuation: await _continuationFor(item.id))),
    );
    final sortedProgress = [...progress]..sort((a, b) => _activityAt(b).compareTo(_activityAt(a)));
    final active = sortedProgress.first;
    final material = active.material;
    final continuation = active.continuation;
    final source = await widget.runtime.store.currentSourceVersion(
      learner: widget.runtime.learner,
      materialId: material.id,
    );
    final extracted = source == null || !livingReview
        ? null
        : await widget.runtime.store.extractedContentForSource(
            learner: widget.runtime.learner,
            sourceVersionId: source.identity.sourceVersionId,
          );
    return _HomeSnapshot(
      material: material,
      source: source,
      extracted: extracted,
      continuation: continuation,
      materials: sortedProgress.map((item) => item.material).toList(growable: false),
      progress: sortedProgress,
    );
  }

  DateTime _activityAt(ProgressItem item) {
    final learningAt = item.continuation?.state.updatedAt;
    return learningAt != null && learningAt.isAfter(item.material.updatedAt) ? learningAt : item.material.updatedAt;
  }

  Future<void> _openLearning() async {
    final materialId = (await _snapshot).material?.id ?? widget.runtime.newMaterialId();
    if (!mounted) return;
    await _openLearningFor(materialId);
  }

  Future<void> _openNextLearningAction() async {
    final materialId = (await _snapshot).material?.id ?? widget.runtime.newMaterialId();
    if (!mounted) return;
    await _openLearningFor(materialId, autoAdvanceContinuation: true);
  }

  Future<void> _openLearningFor(MaterialId materialId, {bool autoAdvanceContinuation = false}) async {
    if (!mounted) return;
    final treatment = LearningVisualTreatmentScope.maybeOf(context);
    final sourceAdded = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) {
          final screen = LearningSliceScreen(
            runtime: widget.runtime,
            materialId: materialId,
            autoAdvanceContinuation: autoAdvanceContinuation,
          );
          if (treatment != null) return LearningVisualTreatmentScope(treatment: treatment, child: screen);
          return LivingDeskReviewScope.active(context) ? LivingDeskReviewScope(child: screen) : screen;
        },
      ),
    );
    if (!mounted) return;
    setState(_refresh);
    if (sourceAdded == true) {
      await _openWorkspace(materialId);
    }
  }

  Future<void> _openMaterialNextAction(MaterialId materialId) async {
    final snapshot = await _snapshot;
    if (!mounted) return;
    LearningContinuation? continuation;
    for (final item in snapshot.progress) {
      if (item.material.id == materialId) {
        continuation = item.continuation;
        break;
      }
    }
    if (continuation?.nextAction.kind == NextLearningActionKind.repeatRecallLater) {
      await _openWorkspace(materialId);
      return;
    }
    await _openLearningFor(materialId, autoAdvanceContinuation: continuation != null);
  }

  Future<void> _openWorkspace([MaterialId? materialId]) async {
    final selected = materialId ?? (await _snapshot).material?.id;
    if (selected == null || !mounted) return;
    final treatment = LearningVisualTreatmentScope.maybeOf(context);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) {
          final screen = MaterialWorkspaceScreen(runtime: widget.runtime, materialId: selected);
          if (treatment != null) return LearningVisualTreatmentScope(treatment: treatment, child: screen);
          return LivingDeskReviewScope.active(context) ? LivingDeskReviewScope(child: screen) : screen;
        },
      ),
    );
    if (!mounted) return;
    setState(_refresh);
  }

  Future<void> _openSourceReader([MaterialId? materialId]) async {
    try {
      final selected = materialId ?? (await _snapshot).material?.id;
      if (selected == null) return;
      final material = await widget.runtime.store.material(learner: widget.runtime.learner, materialId: selected);
      final source = await widget.runtime.store.currentSourceVersion(
        learner: widget.runtime.learner,
        materialId: selected,
      );
      if (material == null || source == null || !mounted) return;
      final extracted = await widget.runtime.store.extractedContentForSource(
        learner: widget.runtime.learner,
        sourceVersionId: source.identity.sourceVersionId,
      );
      if (!mounted) return;

      // Replace the reader route with its chosen learning activity. This avoids
      // racing a pop against a new push on the same Navigator. Capture the
      // product-experience scope before the route leaves this subtree.
      final treatment = LearningVisualTreatmentScope.maybeOf(context);
      final livingReview = LivingDeskReviewScope.active(context);
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (readerContext) {
            final screen = SourceReaderScreen(
              title: material.title,
              sourceText: extracted?.normalizedText ?? '',
              onListen: () => _replaceReaderWith(
                readerContext,
                Builder(
                  builder: (listenContext) => ListenScreen(
                    runtime: widget.runtime,
                    materialId: selected,
                    onRecall: () => _openRecallFromCurrentRoute(listenContext, selected),
                  ),
                ),
              ),
              onRecap: () =>
                  _replaceReaderWith(readerContext, QuickRecapScreen(runtime: widget.runtime, materialId: selected)),
              onRecall: () => _openRecallFromCurrentRoute(readerContext, selected),
            );
            if (treatment != null) return LearningVisualTreatmentScope(treatment: treatment, child: screen);
            return livingReview ? LivingDeskReviewScope(child: screen) : screen;
          },
        ),
      );
      if (mounted) setState(_refresh);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Kaynak açılamadı. Tekrar deneyebilirsin.')));
    }
  }

  void _replaceReaderWith(BuildContext readerContext, Widget destination) {
    final treatment = LearningVisualTreatmentScope.maybeOf(context);
    final livingReview = LivingDeskReviewScope.active(context);
    final wrapped = treatment != null
        ? LearningVisualTreatmentScope(treatment: treatment, child: destination)
        : livingReview
        ? LivingDeskReviewScope(child: destination)
        : destination;
    Navigator.of(readerContext).pushReplacement<void, void>(MaterialPageRoute(builder: (_) => wrapped));
  }

  Future<void> _openRecallFromCurrentRoute(BuildContext routeContext, MaterialId materialId) async {
    if (!mounted) return;
    final treatment = LearningVisualTreatmentScope.maybeOf(context);
    final livingReview = LivingDeskReviewScope.active(context);
    final screen = LearningSliceScreen(runtime: widget.runtime, materialId: materialId);
    await Navigator.of(routeContext).pushReplacement<bool, void>(
      MaterialPageRoute<bool>(
        builder: (_) => treatment != null
            ? LearningVisualTreatmentScope(treatment: treatment, child: screen)
            : livingReview
            ? LivingDeskReviewScope(child: screen)
            : screen,
      ),
    );
    if (mounted) setState(_refresh);
  }

  Future<void> _openListen() async {
    final material = (await _snapshot).material;
    if (material == null || !mounted) return;
    final treatment = LearningVisualTreatmentScope.maybeOf(context);
    final livingReview = LivingDeskReviewScope.active(context);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (listenContext) {
          final screen = ListenScreen(
            runtime: widget.runtime,
            materialId: material.id,
            onRecall: () => _openRecallFromCurrentRoute(listenContext, material.id),
          );
          if (treatment != null) return LearningVisualTreatmentScope(treatment: treatment, child: screen);
          return livingReview ? LivingDeskReviewScope(child: screen) : screen;
        },
      ),
    );
    if (!mounted) return;
    setState(_refresh);
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
    if (confirmed != true || !mounted || _deletingMaterialId != null) return;

    setState(() => _deletingMaterialId = material.id);
    try {
      final serverMaterialId = await widget.runtime.store.summaryServerMaterialId(
        learner: widget.runtime.learner,
        materialId: material.id,
      );
      if (serverMaterialId != null) {
        final removed = await const SupabaseSourceSummaryGateway().deleteServerMaterial(serverMaterialId);
        if (!mounted) return;
        if (!removed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sunucudaki kaynak kopyası silinemedi. Materyal güvenlik için yerelde korunuyor.'),
            ),
          );
          return;
        }
      }

      await widget.runtime.store.deleteMaterial(
        learner: widget.runtime.learner,
        materialId: material.id,
        deletedAt: DateTime.now().toUtc(),
      );
      if (!mounted) return;

      setState(_refresh);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Materyal silindi.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silme işlemi tamamlanamadı. Materyalin durumunu kontrol edip tekrar deneyebilirsin.'),
        ),
      );
      setState(_refresh);
    } finally {
      if (mounted) setState(() => _deletingMaterialId = null);
    }
  }

  Widget _readerShortcut(_HomeSnapshot data) => IconButton(
    tooltip: 'Son kaynağı oku',
    icon: const Icon(Icons.menu_book_outlined),
    onPressed: data.material == null ? null : () => _openSourceReader(data.material!.id),
  );

  Widget _buildNavigationBar() => NavigationBar(
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
  );

  @override
  Widget build(BuildContext context) {
    final living = LivingDeskReviewScope.active(context);
    return Scaffold(
      backgroundColor: living ? AtelierStyle.canvas : null,
      body: SafeArea(
        child: FutureBuilder<_HomeSnapshot>(
          future: _snapshot,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sync_problem_rounded, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        'Kütüphane şu anda yüklenemedi.',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Bu yükleme hatası kaynaklarının silindiği anlamına gelmez. Yerel öğrenme durumunu yeniden okumayı deneyebilirsin.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => setState(_refresh),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Tekrar dene'),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data!;
            return Column(
              children: [
                if (_index == 1 && data.material != null)
                  Align(alignment: Alignment.centerRight, child: _readerShortcut(data)),
                Expanded(
                  child: IndexedStack(
                    index: _index,
                    children: [
                      TickerMode(
                        enabled: _index == 0,
                        child: _HomeSurface(
                          data: data,
                          onOpenLearning: _openNextLearningAction,
                          onOpenListen: _openListen,
                          onOpenWorkspace: () => _openWorkspace(),
                          onOpenMaterial: (id) => _openWorkspace(id),
                        ),
                      ),
                      TickerMode(
                        enabled: _index == 1,
                        child: _LibrarySurface(
                          data: data,
                          onOpenLearning: _openLearning,
                          onOpenWorkspace: _openWorkspace,
                          onContinueMaterial: _openMaterialNextAction,
                          onDeleteMaterial: _deleteMaterial,
                          deletingMaterialId: _deletingMaterialId,
                        ),
                      ),
                      TickerMode(
                        enabled: _index == 2,
                        child: ProgressSurface(items: data.progress, onOpenMaterial: _openMaterialNextAction),
                      ),
                      TickerMode(
                        enabled: _index == 3,
                        child: ProfileSurface(
                          runtime: widget.runtime,
                          onAccountDeleted: widget.onAccountDeleted,
                          onSignOut: widget.onSignOut,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: living
          ? NavigationBarTheme(
              data: NavigationBarThemeData(
                backgroundColor: const Color(0xFFF5F4F0),
                indicatorColor: const Color(0xFFDCEAE1),
                labelTextStyle: const WidgetStatePropertyAll(TextStyle(color: Color(0xFF1C292B), fontSize: 12)),
                iconTheme: WidgetStateProperty.resolveWith(
                  (states) => IconThemeData(
                    color: states.contains(WidgetState.selected) ? const Color(0xFF236B63) : const Color(0xFF58696A),
                  ),
                ),
              ),
              child: _buildNavigationBar(),
            )
          : _buildNavigationBar(),
    );
  }
}

class _HomeSurface extends StatelessWidget {
  const _HomeSurface({
    required this.data,
    required this.onOpenLearning,
    required this.onOpenListen,
    required this.onOpenWorkspace,
    required this.onOpenMaterial,
  });

  final _HomeSnapshot data;
  final VoidCallback onOpenLearning;
  final VoidCallback onOpenListen;
  final VoidCallback onOpenWorkspace;
  final ValueChanged<MaterialId> onOpenMaterial;

  @override
  Widget build(BuildContext context) {
    if (LivingDeskReviewScope.active(context)) {
      return LivingStudyDeskHome(
        material: data.material,
        continuation: data.continuation,
        sourceText: data.extracted?.normalizedText,
        otherMaterials: data.materials.where((item) => item.id != data.material?.id).toList(),
        onOpenWorkspace: onOpenWorkspace,
        onOpenLearning: onOpenLearning,
        onOpenListen: onOpenListen,
        onOpenMaterial: onOpenMaterial,
      );
    }
    final theme = Theme.of(context);
    final hasMaterial = data.material != null;
    final candidate = LearningVisualTreatmentScope.maybeOf(context);
    if (hasMaterial && candidate != null) {
      return LearningTreatmentHome(
        lane: candidate,
        material: data.material!,
        continuation: data.continuation,
        nextTitle: _nextTitle(data.continuation),
        nextReason: _nextReason(data.continuation),
        onWorkspace: onOpenWorkspace,
        onRecall: onOpenLearning,
        onListen: onOpenListen,
      );
    }

    return ListView(
      key: const ValueKey('home-surface'),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 36),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: _companionSoft(data.continuation),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _companionAccent(data.continuation).withValues(alpha: 0.14)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(7),
                child: CompanionView(state: _companionState(data.continuation), size: 50),
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
                    hasMaterial ? _headerLine(data.continuation) : 'Kendi materyalini aktif öğrenmeye dönüştür.',
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
            actionLabel: _nextActionLabel(data.continuation),
            onPressed: _nextActionOpensLearning(data.continuation) ? onOpenLearning : onOpenWorkspace,
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
      continuation?.nextAction.reasonText ??
      'Kaynağından kısa bir hatırlama denemesiyle ilk gerçek öğrenme kanıtını oluştur.';

  static bool _nextActionOpensLearning(LearningContinuation? continuation) {
    final kind = continuation?.nextAction.kind;
    return kind == NextLearningActionKind.reviewSourceThenRecall ||
        kind == NextLearningActionKind.retryRecallWithoutHint;
  }

  static String _nextActionLabel(LearningContinuation? continuation) {
    if (continuation == null) return 'Çalışmaya devam et';
    return switch (continuation.nextAction.kind) {
      NextLearningActionKind.reviewSourceThenRecall => 'Kaynağı gözden geçir',
      NextLearningActionKind.retryRecallWithoutHint => 'İpucusuz tekrar dene',
      NextLearningActionKind.repeatRecallLater => 'Kaynağa dön',
    };
  }

  static String _headerLine(LearningContinuation? continuation) {
    final state = continuation?.state.kind ?? RecallStateKind.notAssessed;
    return switch (state) {
      RecallStateKind.notAssessed => 'İlk aktif adımın hazır.',
      RecallStateKind.developing => 'Kaldığın yer hazır. Bir sonraki denemeye geç.',
      RecallStateKind.retrievedOnce => 'Bir kez bağımsız hatırladın. Sıradaki adım hazır.',
      RecallStateKind.needsReview => 'Kısa bir tekrar noktası hazır.',
    };
  }

  static CompanionVisualState _companionState(LearningContinuation? continuation) {
    final state = continuation?.state.kind ?? RecallStateKind.notAssessed;
    return switch (state) {
      RecallStateKind.notAssessed => CompanionVisualState.idle,
      RecallStateKind.developing => CompanionVisualState.think,
      RecallStateKind.retrievedOnce => CompanionVisualState.success,
      RecallStateKind.needsReview => CompanionVisualState.think,
    };
  }

  static Color _companionSoft(LearningContinuation? continuation) {
    final state = continuation?.state.kind ?? RecallStateKind.notAssessed;
    return switch (state) {
      RecallStateKind.notAssessed => AppPalette.primarySoft,
      RecallStateKind.developing => AppPalette.primarySoft,
      RecallStateKind.retrievedOnce => AppPalette.successSoft,
      RecallStateKind.needsReview => AppPalette.attentionSoft,
    };
  }

  static Color _companionAccent(LearningContinuation? continuation) {
    final state = continuation?.state.kind ?? RecallStateKind.notAssessed;
    return switch (state) {
      RecallStateKind.notAssessed => AppPalette.primary,
      RecallStateKind.developing => AppPalette.primary,
      RecallStateKind.retrievedOnce => AppPalette.success,
      RecallStateKind.needsReview => AppPalette.attention,
    };
  }
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
  const _ContinueHero({
    required this.data,
    required this.title,
    required this.reason,
    required this.actionLabel,
    required this.onPressed,
  });

  final _HomeSnapshot data;
  final String title;
  final String reason;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final material = data.material!;
    final theme = Theme.of(context);
    final sourceName = data.source?.sourceName ?? 'Kaynak hazır';
    final mediaIcon = material.mediaType == SourceMediaType.pdf ? Icons.picture_as_pdf_rounded : Icons.notes_rounded;

    return Material(
      color: AppPalette.surface,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('home-continuation-hero'),
        onTap: onPressed,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: AppPalette.outline),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppPalette.primarySoft,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Icon(mediaIcon, color: AppPalette.primary, size: 21),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'KALDIĞIN MATERYAL',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppPalette.inkMuted,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.55,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                material.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_outward_rounded, color: AppPalette.inkMuted, size: 20),
                      ],
                    ),
                    if (sourceName != material.title) ...[
                      const SizedBox(height: 11),
                      Text(
                        sourceName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: AppPalette.inkMuted),
                      ),
                    ],
                    const SizedBox(height: 13),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: _stateSoft(data.continuation),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Text(
                          _stateLabel(data.continuation),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: _stateAccent(data.continuation),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              DecoratedBox(
                decoration: const BoxDecoration(color: AppPalette.primaryDark),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppPalette.momentum,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                              child: Text(
                                'ŞİMDİ',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppPalette.momentumInk,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.bolt_rounded, color: Colors.white.withValues(alpha: 0.72), size: 18),
                        ],
                      ),
                      const SizedBox(height: 11),
                      Text(title, style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white)),
                      const SizedBox(height: 7),
                      Text(
                        reason,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.80),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 17),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppPalette.primaryDark,
                        ),
                        onPressed: onPressed,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: Text(actionLabel),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _stateLabel(LearningContinuation? continuation) {
    if (continuation == null) return 'Henüz ölçülmedi';
    return switch (continuation.state.kind) {
      RecallStateKind.notAssessed => 'Henüz ölçülmedi',
      RecallStateKind.developing => 'Gelişiyor',
      RecallStateKind.retrievedOnce => 'Bir kez bağımsız hatırlandı',
      RecallStateKind.needsReview => 'Tekrar gerekiyor',
    };
  }

  static Color _stateSoft(LearningContinuation? continuation) {
    final state = continuation?.state.kind ?? RecallStateKind.notAssessed;
    return switch (state) {
      RecallStateKind.notAssessed => AppPalette.surfaceMuted,
      RecallStateKind.developing => AppPalette.primarySoft,
      RecallStateKind.retrievedOnce => AppPalette.successSoft,
      RecallStateKind.needsReview => AppPalette.attentionSoft,
    };
  }

  static Color _stateAccent(LearningContinuation? continuation) {
    final state = continuation?.state.kind ?? RecallStateKind.notAssessed;
    return switch (state) {
      RecallStateKind.notAssessed => AppPalette.inkMuted,
      RecallStateKind.developing => AppPalette.primary,
      RecallStateKind.retrievedOnce => AppPalette.success,
      RecallStateKind.needsReview => AppPalette.attention,
    };
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

class _LibrarySurface extends StatefulWidget {
  const _LibrarySurface({
    required this.data,
    required this.onOpenLearning,
    required this.onOpenWorkspace,
    required this.onContinueMaterial,
    required this.onDeleteMaterial,
    required this.deletingMaterialId,
  });

  final _HomeSnapshot data;
  final VoidCallback onOpenLearning;
  final ValueChanged<MaterialId> onOpenWorkspace;
  final ValueChanged<MaterialId> onContinueMaterial;
  final ValueChanged<MaterialRecord> onDeleteMaterial;
  final MaterialId? deletingMaterialId;

  @override
  State<_LibrarySurface> createState() => _LibrarySurfaceState();
}

class _LibrarySurfaceState extends State<_LibrarySurface> {
  final _searchController = TextEditingController();
  final _listController = ScrollController();

  @override
  void dispose() {
    _searchController.dispose();
    _listController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    if (_listController.hasClients) _listController.jumpTo(0);
    setState(_searchController.clear);
  }

  String _searchKey(String value) =>
      value.replaceAll('I', 'i').replaceAll('ı', 'i').toLowerCase().replaceAll('\u0307', '');

  List<MaterialRecord> get _visibleMaterials {
    final query = _searchKey(_searchController.text.trim());
    if (query.isEmpty) return widget.data.materials;
    return widget.data.materials
        .where((material) => _searchKey(material.title).contains(query))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final living = LivingDeskReviewScope.active(context);
    final visibleMaterials = _visibleMaterials;
    final hasQuery = _searchController.text.trim().isNotEmpty;
    final accent = living ? AtelierStyle.teal : theme.colorScheme.primary;
    final ink = living ? AtelierStyle.ink : theme.colorScheme.onSurface;
    final muted = living ? AtelierStyle.muted : theme.colorScheme.onSurfaceVariant;
    final paper = living ? AtelierStyle.paper : theme.colorScheme.surface;
    return ListView(
      key: const ValueKey('library-material-list'),
      controller: _listController,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        if (living) ...[
          Text(
            'KAYNAKLARIN',
            style: theme.textTheme.labelSmall?.copyWith(color: accent, fontWeight: FontWeight.w900, letterSpacing: 0.9),
          ),
          const SizedBox(height: 7),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                'Kütüphane',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: ink,
                  fontWeight: living ? FontWeight.w900 : null,
                ),
              ),
            ),
            if (widget.data.materials.isNotEmpty)
              Text(
                hasQuery
                    ? '${visibleMaterials.length} / ${widget.data.materials.length} materyal'
                    : '${widget.data.materials.length} materyal',
                style: theme.textTheme.labelMedium?.copyWith(color: muted),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Kaynakların ve kaldığın yer tek yerde. Son aktiviten en üstte.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        if (widget.data.materials.isNotEmpty) ...[
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('library-search'),
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Materyal ara',
              filled: living,
              fillColor: living ? paper : null,
              prefixIcon: Icon(Icons.search_rounded, color: living ? accent : null),
              suffixIcon: hasQuery
                  ? IconButton(
                      tooltip: 'Aramayı temizle',
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.close_rounded),
                    )
                  : null,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (widget.data.materials.isEmpty)
          _PrimaryCard(
            title: 'Henüz materyal yok',
            body: 'İlk kaynağını eklediğinde burada kaldığın yerden devam edebilirsin.',
            buttonLabel: 'Materyal ekle',
            icon: Icons.add_rounded,
            onPressed: widget.onOpenLearning,
          )
        else if (visibleMaterials.isEmpty)
          _PrimaryCard(
            title: 'Eşleşen materyal bulunamadı',
            body: 'Başka bir başlık ara veya aramayı temizleyip tüm materyallerini gör.',
            buttonLabel: 'Aramayı temizle',
            icon: Icons.search_off_rounded,
            onPressed: _clearSearch,
          )
        else
          for (final material in visibleMaterials) ...[
            _LibraryMaterialCard(
              material: material,
              continuation: _continuationFor(material.id),
              onPressed: () => widget.onOpenWorkspace(material.id),
              onContinue: () => widget.onContinueMaterial(material.id),
              onDelete: () => widget.onDeleteMaterial(material),
              isDeleting: widget.deletingMaterialId == material.id,
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  LearningContinuation? _continuationFor(MaterialId materialId) {
    for (final item in widget.data.progress) {
      if (item.material.id == materialId) return item.continuation;
    }
    return null;
  }
}

class _LibraryMaterialCard extends StatelessWidget {
  const _LibraryMaterialCard({
    required this.material,
    required this.continuation,
    required this.onPressed,
    required this.onContinue,
    required this.onDelete,
    required this.isDeleting,
  });

  final MaterialRecord material;
  final LearningContinuation? continuation;
  final VoidCallback onPressed;
  final VoidCallback onContinue;
  final VoidCallback onDelete;
  final bool isDeleting;

  String get _continueLabel => switch (continuation?.nextAction.kind) {
    NextLearningActionKind.reviewSourceThenRecall => 'Kaynağı gözden geçir ve yeniden dene',
    NextLearningActionKind.retryRecallWithoutHint => 'İpucusuz tekrar dene',
    NextLearningActionKind.repeatRecallLater => 'Kaynağa dön',
    null => 'İlk hatırlamayı dene',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final living = LivingDeskReviewScope.active(context);
    final mediaIcon = material.mediaType == SourceMediaType.pdf ? Icons.picture_as_pdf_rounded : Icons.notes_rounded;
    final mediaLabel = material.mediaType == SourceMediaType.pdf ? 'PDF' : 'Metin';
    final state = continuation?.state.kind ?? RecallStateKind.notAssessed;
    final (stateLabel, stateSoft, stateAccent) = switch (state) {
      RecallStateKind.notAssessed => ('Henüz ölçülmedi', AppPalette.surfaceMuted, AppPalette.inkMuted),
      RecallStateKind.developing => ('Gelişiyor', AppPalette.primarySoft, AppPalette.primary),
      RecallStateKind.retrievedOnce => ('Bir kez bağımsız hatırlandı', AppPalette.successSoft, AppPalette.success),
      RecallStateKind.needsReview => ('Tekrar gerekiyor', AppPalette.attentionSoft, AppPalette.attention),
    };
    final nextReason =
        continuation?.nextAction.reasonText ?? 'İlk aktif hatırlama denemesi öğrenme durumunu görünür kılar.';
    final resolvedStateSoft = living
        ? switch (state) {
            RecallStateKind.notAssessed => AtelierStyle.canvas,
            RecallStateKind.developing => AtelierStyle.mint,
            RecallStateKind.retrievedOnce => AtelierStyle.mint,
            RecallStateKind.needsReview => const Color(0xFFFFF1D9),
          }
        : stateSoft;
    final resolvedStateAccent = living
        ? switch (state) {
            RecallStateKind.notAssessed => AtelierStyle.muted,
            RecallStateKind.developing => AtelierStyle.teal,
            RecallStateKind.retrievedOnce => AtelierStyle.teal,
            RecallStateKind.needsReview => const Color(0xFF9A623E),
          }
        : stateAccent;

    return Card(
      elevation: 0,
      color: living ? AtelierStyle.paper : null,
      clipBehavior: Clip.antiAlias,
      shape: living
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: AtelierStyle.line),
            )
          : null,
      child: Column(
        children: [
          InkWell(
            onTap: onPressed,
            child: Column(
              children: [
                Container(height: 5, color: living ? AtelierStyle.teal : AppPalette.primary),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 15),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: living ? AtelierStyle.mint : AppPalette.primarySoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(11),
                          child: Icon(mediaIcon, color: living ? AtelierStyle.teal : AppPalette.primary, size: 22),
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mediaLabel.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: living ? AtelierStyle.muted : AppPalette.inkMuted,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.45,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              material.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 9),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: resolvedStateSoft,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                child: Text(
                                  stateLabel,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: resolvedStateAccent,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Materyali sil',
                        onPressed: isDeleting ? null : onDelete,
                        icon: isDeleting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.delete_outline_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: '${material.title} için sıradaki öğrenme adımına devam et',
            child: InkWell(
              key: ValueKey('library-continue-${material.id.value}'),
              onTap: onContinue,
              child: DecoratedBox(
                decoration: BoxDecoration(color: living ? AtelierStyle.ink : AppPalette.primaryDark),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(15, 12, 15, 13),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: living ? AtelierStyle.mark : AppPalette.momentum,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: living ? AtelierStyle.ink : AppPalette.momentumInk,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _continueLabel,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              nextReason,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.72),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
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
    final isListen = title == 'Dinle';
    final soft = isListen ? AppPalette.signalSoft : AppPalette.primarySoft;
    final accent = isListen ? AppPalette.signal : AppPalette.primary;
    return Material(
      color: soft.withValues(alpha: 0.42),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: accent.withValues(alpha: 0.14)),
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
                  color: AppPalette.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.10)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(9),
                  child: Icon(icon, size: 20, color: accent),
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
    final living = LivingDeskReviewScope.active(context);
    return Card(
      elevation: 0,
      color: living ? AtelierStyle.paper : theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
      shape: living
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: AtelierStyle.line),
            )
          : null,
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
    this.extracted,
    this.continuation,
    this.materials = const [],
    this.progress = const [],
  });

  final MaterialRecord? material;
  final SourceVersionRecord? source;
  final ExtractedContentRecord? extracted;
  final LearningContinuation? continuation;
  final List<MaterialRecord> materials;
  final List<ProgressItem> progress;
}
