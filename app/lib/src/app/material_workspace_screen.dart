import 'package:flutter/material.dart';

import '../continuity/passive_resume_continuity_service.dart';
import '../continuity/retention_continuity_service.dart';
import '../domain/learning_contracts.dart';
import '../domain/learning_truth.dart';
import '../domain/retention_schedule.dart';
import '../learning/recall_learning_service.dart';
import 'app_runtime.dart';
import 'app_theme.dart';
import 'companion_view.dart';
import 'explain_back_screen.dart';
import 'explain_screen.dart';
import 'first_value_intent_surface.dart';
import 'focus_screen.dart';
import 'grounded_tutor_screen.dart';
import 'flashcard_screen.dart';
import 'learning_slice_screen.dart';
import 'la0040_visual_treatments.dart';
import 'living_study_desk_home.dart';
import 'atelier_learning_surfaces.dart';
import 'listen_screen.dart';
import 'quick_recap_screen.dart';
import 'quiz_screen.dart';
import 'source_reader_screen.dart';

class MaterialWorkspaceScreen extends StatefulWidget {
  const MaterialWorkspaceScreen({
    required this.runtime,
    required this.materialId,
    this.showFirstValueIntent = false,
    super.key,
  });

  final AppRuntime runtime;
  final MaterialId materialId;
  final bool showFirstValueIntent;

  @override
  State<MaterialWorkspaceScreen> createState() => _MaterialWorkspaceScreenState();
}

class _MaterialWorkspaceScreenState extends State<MaterialWorkspaceScreen> {
  late Future<_WorkspaceSnapshot?> _snapshot;
  late bool _showFirstValueIntent;

  Widget _preserveProductExperience(Widget screen) {
    final treatment = LearningVisualTreatmentScope.maybeOf(context);
    if (treatment != null) return LearningVisualTreatmentScope(treatment: treatment, child: screen);
    return LivingDeskReviewScope.active(context) ? LivingDeskReviewScope(child: screen) : screen;
  }

  @override
  void initState() {
    super.initState();
    _showFirstValueIntent = widget.showFirstValueIntent;
    _snapshot = _load();
  }

  void _consumeFirstValueIntent() {
    if (!_showFirstValueIntent || !mounted) return;
    setState(() => _showFirstValueIntent = false);
  }

  Future<_WorkspaceSnapshot?> _load({bool retryOnSourceChange = true}) async {
    final material = await widget.runtime.store.material(
      learner: widget.runtime.learner,
      materialId: widget.materialId,
    );
    if (material == null || !material.isActive) return null;
    final source = await widget.runtime.store.currentSourceVersion(
      learner: widget.runtime.learner,
      materialId: material.id,
    );
    if (source == null) return null;
    final extracted = await widget.runtime.store.extractedContentForSource(
      learner: widget.runtime.learner,
      sourceVersionId: source.identity.sourceVersionId,
    );
    LearningContinuation? continuation;
    try {
      continuation = await widget.runtime.recall.reopen(learner: widget.runtime.learner, materialId: material.id);
    } on RecallLearningException {
      continuation = await widget.runtime.recall.repairContinuation(
        learner: widget.runtime.learner,
        materialId: material.id,
      );
    }
    final retentionSchedules = await widget.runtime.store.retentionSchedulesForMaterial(
      learner: widget.runtime.learner,
      materialId: material.id,
    );
    final retention = retentionSchedules.isEmpty
        ? null
        : RetentionMaterialStatus(schedules: retentionSchedules, evaluatedAt: DateTime.now().toUtc());

    // Source replacement may land while extraction/continuation is loading.
    // Do not compose one Workspace from an old source snapshot and newer truth.
    final currentSource = await widget.runtime.store.currentSourceVersion(
      learner: widget.runtime.learner,
      materialId: material.id,
    );
    if (currentSource?.identity.sourceVersionId != source.identity.sourceVersionId) {
      return retryOnSourceChange ? _load(retryOnSourceChange: false) : null;
    }
    return _WorkspaceSnapshot(
      material: material,
      source: source,
      extracted: extracted,
      continuation: continuation,
      retention: retention,
    );
  }

  Future<void> _openSourceReader(_WorkspaceSnapshot data) async {
    final sourceVersionId = data.source.identity.sourceVersionId;
    final initialProgress = await widget.runtime.store.readerResumeProgress(
      learner: widget.runtime.learner,
      materialId: data.material.id,
      sourceVersionId: sourceVersionId,
    );
    final annotations = await widget.runtime.store.readerAnnotationsForSource(
      learner: widget.runtime.learner,
      materialId: data.material.id,
      sourceVersionId: sourceVersionId,
    );
    final staleAnnotationCount = await widget.runtime.store.staleReaderAnnotationCount(
      learner: widget.runtime.learner,
      materialId: data.material.id,
      currentSourceVersionId: sourceVersionId,
    );
    if (!mounted) return;
    // Revalidate the source identity after the asynchronous resume read. An
    // updated document must not reopen a stale Reader snapshot.
    final currentSource = await widget.runtime.store.currentSourceVersion(
      learner: widget.runtime.learner,
      materialId: data.material.id,
    );
    if (!mounted) return;
    if (currentSource?.identity.sourceVersionId != sourceVersionId) {
      setState(() {
        _snapshot = _load();
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Kaynak güncellendi. Güncel sürümü açmak için tekrar dokun.')));
      return;
    }
    final extracted = data.extracted;
    if (extracted == null || !extracted.isValid || extracted.normalizedText.trim().isEmpty) {
      setState(() {
        _snapshot = _load();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu kaynak için okunabilir güncel metin bulunamadı. Kaynağı kontrol edip tekrar dene.'),
        ),
      );
      return;
    }
    final treatment = LearningVisualTreatmentScope.maybeOf(context);
    final livingReview = LivingDeskReviewScope.active(context);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (readerContext) {
          final screen = SourceReaderScreen(
            title: data.material.title,
            sourceText: extracted.normalizedText,
            sourceVersion: data.source,
            sourceWarnings: extracted.warnings,
            initialProgress: initialProgress,
            sourceAnchors: extracted.anchors,
            initialAnnotations: annotations,
            staleAnnotationCount: staleAnnotationCount,
            onSaveAnnotation: (anchor, selectedText, kind, noteText) => widget.runtime.store.upsertReaderAnnotation(
              learner: widget.runtime.learner,
              materialId: data.material.id,
              sourceVersionId: sourceVersionId,
              sourceAnchor: anchor,
              selectedText: selectedText,
              kind: kind,
              noteText: noteText,
              updatedAt: DateTime.now().toUtc(),
            ),
            onDeleteAnnotation: (annotationId) => widget.runtime.store.deleteReaderAnnotation(
              learner: widget.runtime.learner,
              annotationId: annotationId,
            ),
            onTutorSelection: (anchor) {
              Navigator.of(readerContext).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => _preserveProductExperience(
                    GroundedTutorScreen(runtime: widget.runtime, source: data.source, initialContextAnchor: anchor),
                  ),
                ),
              );
            },
            onRecallSelection: (anchor) => _replaceReaderWith(
              readerContext,
              LearningSliceScreen(
                runtime: widget.runtime,
                materialId: widget.materialId,
                requestedRecallSourceVersionId: sourceVersionId,
                requestedRecallSourceAnchor: anchor,
              ),
            ),
            onProgressChanged: (progress) => widget.runtime.store.saveReaderResumeProgress(
              learner: widget.runtime.learner,
              materialId: data.material.id,
              sourceVersionId: sourceVersionId,
              progress: progress,
              updatedAt: DateTime.now().toUtc(),
            ),
            onListen: () => _replaceReaderWith(
              readerContext,
              Builder(
                builder: (listenContext) => ListenScreen(
                  runtime: widget.runtime,
                  materialId: widget.materialId,
                  onRecall: () => _replaceReaderWith(
                    listenContext,
                    LearningSliceScreen(
                      runtime: widget.runtime,
                      materialId: widget.materialId,
                      reviewedSourceVersionId: sourceVersionId,
                    ),
                  ),
                  onReadSource: () {
                    Navigator.of(listenContext).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _readCurrentSource();
                    });
                  },
                ),
              ),
            ),
            onRecap: () => _replaceReaderWith(
              readerContext,
              QuickRecapScreen(runtime: widget.runtime, materialId: widget.materialId),
            ),
            onRecall: () => _replaceReaderWith(
              readerContext,
              LearningSliceScreen(
                runtime: widget.runtime,
                materialId: widget.materialId,
                reviewedSourceVersionId: sourceVersionId,
              ),
            ),
          );
          if (treatment != null) return LearningVisualTreatmentScope(treatment: treatment, child: screen);
          return livingReview ? LivingDeskReviewScope(child: screen) : screen;
        },
      ),
    );
    if (mounted) {
      await _syncPassiveResumeAfterActivity(data.material.id);
      if (!mounted) return;
      setState(() {
        _snapshot = _load();
      });
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
    Navigator.of(readerContext).pushReplacement<void, void>(MaterialPageRoute<void>(builder: (_) => wrapped));
  }

  Future<void> _readCurrentSource() async {
    final data = await _load();
    if (!mounted) return;
    if (data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kaynak açılamadı. Materyali yeniden yükleyip tekrar deneyebilirsin.')),
      );
      return;
    }
    await _openSourceReader(data);
  }

  Future<void> _syncPassiveResumeAfterActivity(MaterialId materialId) async {
    if (!widget.runtime.learner.isAuthenticated) return;
    try {
      final results = await widget.runtime.syncPassiveResumeForMaterial(materialId);
      if (!mounted) return;
      final conflicts = results.where((item) => item.disposition == PassiveResumeSyncDisposition.conflict).length;
      if (conflicts > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Okuma/dinleme konumu başka bir cihazda da değişmiş. Otomatik üzerine yazmadık; bu cihazdaki konum korundu.',
            ),
          ),
        );
      }
    } catch (_) {
      // Local Reader/Listen progress is already durable. Cloud retry happens
      // from Home/startup; passive continuity must never block local study.
    }
  }

  Future<void> _syncRetentionAfterActivity(MaterialId materialId) async {
    if (!widget.runtime.learner.isAuthenticated) return;
    try {
      final results = await widget.runtime.syncRetentionForMaterial(materialId);
      if (!mounted) return;
      final conflicts = results
          .where((item) => item.disposition == RetentionContinuityDisposition.conflict)
          .length;
      if (conflicts > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tekrar zamanlaması başka bir cihazda da değişmiş. Otomatik üzerine yazmadık; bu cihazdaki öğrenme kaydı korundu.',
            ),
          ),
        );
      }
    } catch (_) {
      // Local active-learning timing is already durable. Home/startup retries
      // cloud reconciliation; network failure must not erase local study.
    }
  }

  Future<void> _openSourceEditor() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => _preserveProductExperience(
          LearningSliceScreen(runtime: widget.runtime, materialId: widget.materialId, startInSourceEditor: true),
        ),
      ),
    );
    if (!mounted || updated != true) return;
    setState(() {
      _snapshot = _load();
    });
  }

  Future<void> _openQuickRecap() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            _preserveProductExperience(QuickRecapScreen(runtime: widget.runtime, materialId: widget.materialId)),
      ),
    );
    if (!mounted) return;
    setState(() {
      _snapshot = _load();
    });
  }

  Future<void> _openRecall({
    bool autoAdvanceContinuation = false,
    SourceVersionId? scheduledReviewSourceVersionId,
    SourceAnchor? scheduledReviewSourceAnchor,
  }) async {
    final treatment = LearningVisualTreatmentScope.maybeOf(context);
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) {
          final screen = LearningSliceScreen(
            runtime: widget.runtime,
            materialId: widget.materialId,
            autoAdvanceContinuation: autoAdvanceContinuation,
            scheduledReviewSourceVersionId: scheduledReviewSourceVersionId,
            scheduledReviewSourceAnchor: scheduledReviewSourceAnchor,
          );
          if (treatment != null) return LearningVisualTreatmentScope(treatment: treatment, child: screen);
          return LivingDeskReviewScope.active(context) ? LivingDeskReviewScope(child: screen) : screen;
        },
      ),
    );
    if (!mounted) return;
    setState(() {
      _snapshot = _load();
    });
  }

  Future<void> _openListen() async {
    final navigator = Navigator.of(context);
    await navigator.push<void>(
      MaterialPageRoute(
        builder: (listenContext) => _preserveProductExperience(
          ListenScreen(
            runtime: widget.runtime,
            materialId: widget.materialId,
            onRecall: () {
              Navigator.of(listenContext).pop();
              _openRecall();
            },
            onReadSource: () {
              Navigator.of(listenContext).pop();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _readCurrentSource();
              });
            },
          ),
        ),
      ),
    );
    if (!mounted) return;
    await _syncPassiveResumeAfterActivity(widget.materialId);
    if (!mounted) return;
    setState(() {
      _snapshot = _load();
    });
  }

  Future<void> _openFlashcards({
    SourceVersionId? scheduledReviewSourceVersionId,
    SourceAnchor? scheduledReviewSourceAnchor,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _preserveProductExperience(
          FlashcardScreen(
            runtime: widget.runtime,
            materialId: widget.materialId,
            scheduledReviewSourceVersionId: scheduledReviewSourceVersionId,
            scheduledReviewSourceAnchor: scheduledReviewSourceAnchor,
          ),
        ),
      ),
    );
    if (!mounted) return;
    await _syncRetentionAfterActivity(widget.materialId);
    if (!mounted) return;
    setState(() {
      _snapshot = _load();
    });
  }

  Future<void> _openQuiz({
    SourceVersionId? scheduledReviewSourceVersionId,
    SourceAnchor? scheduledReviewSourceAnchor,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _preserveProductExperience(
          QuizScreen(
            runtime: widget.runtime,
            materialId: widget.materialId,
            scheduledReviewSourceVersionId: scheduledReviewSourceVersionId,
            scheduledReviewSourceAnchor: scheduledReviewSourceAnchor,
          ),
        ),
      ),
    );
    if (!mounted) return;
    await _syncRetentionAfterActivity(widget.materialId);
    if (!mounted) return;
    setState(() {
      _snapshot = _load();
    });
  }

  // Activation revalidates the scheduled source lineage before opening a fresh review action.
  Future<void> _openRetentionReview(_WorkspaceSnapshot data) async {
    final candidate = data.retention?.nextDue;
    if (candidate == null) return;

    final currentSource = await widget.runtime.store.currentSourceVersion(
      learner: widget.runtime.learner,
      materialId: data.material.id,
    );
    if (!mounted) return;
    if (currentSource?.identity.sourceVersionId != candidate.sourceVersionId) {
      setState(() => _snapshot = _load());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kaynak güncellendi. Tekrar planı güncel kaynaktan yeniden hazırlanıyor.')),
      );
      return;
    }

    final currentSchedules = await widget.runtime.store.retentionSchedulesForMaterial(
      learner: widget.runtime.learner,
      materialId: data.material.id,
    );
    if (!mounted) return;
    final now = DateTime.now().toUtc();
    RetentionScheduleRecord? due;
    for (final schedule in currentSchedules) {
      if (schedule.id == candidate.id && schedule.isDueAt(now)) {
        due = schedule;
        break;
      }
    }
    if (due == null) {
      setState(() => _snapshot = _load());
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Bu tekrar artık güncel değil. Sıradaki plan yenilendi.')));
      return;
    }

    switch (due.latestEvidenceKind) {
      case RetentionEvidenceKind.recall:
        await _openRecall(
          scheduledReviewSourceVersionId: due.sourceVersionId,
          scheduledReviewSourceAnchor: due.sourceAnchor,
        );
      case RetentionEvidenceKind.flashcard:
        await _openFlashcards(
          scheduledReviewSourceVersionId: due.sourceVersionId,
          scheduledReviewSourceAnchor: due.sourceAnchor,
        );
      case RetentionEvidenceKind.quiz:
        await _openQuiz(
          scheduledReviewSourceVersionId: due.sourceVersionId,
          scheduledReviewSourceAnchor: due.sourceAnchor,
        );
    }
  }

  Future<void> _openFocus(_WorkspaceSnapshot data) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (focusContext) => _preserveProductExperience(
          FocusScreen(
            runtime: widget.runtime,
            source: data.source,
            sourceText: data.extracted?.normalizedText ?? '',
            onReadSource: () {
              Navigator.of(focusContext).pop();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _readCurrentSource();
              });
            },
          ),
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _snapshot = _load();
    });
  }

  Future<void> _openGroundedTutor(_WorkspaceSnapshot data, {SourceAnchor? contextAnchor}) async {
    final exit = await Navigator.of(context).push<GroundedTutorExit>(
      MaterialPageRoute<GroundedTutorExit>(
        builder: (_) => _preserveProductExperience(
          GroundedTutorScreen(runtime: widget.runtime, source: data.source, initialContextAnchor: contextAnchor),
        ),
      ),
    );
    if (!mounted) return;
    if (exit == GroundedTutorExit.reviewSource) {
      await _openSourceReader(data);
    }
    if (!mounted) return;
    setState(() {
      _snapshot = _load();
    });
  }

  Future<void> _openGroundedExplain(SourceVersionRecord source) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _preserveProductExperience(ExplainScreen(runtime: widget.runtime, source: source)),
      ),
    );
    if (!mounted) return;
    setState(() {
      _snapshot = _load();
    });
  }

  Future<void> _openExplainBack(SourceVersionRecord source) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _preserveProductExperience(ExplainBackScreen(runtime: widget.runtime, source: source)),
      ),
    );
    if (!mounted) return;
    setState(() {
      _snapshot = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Çalışma alanı'),
        backgroundColor: LivingDeskReviewScope.active(context) ? AtelierStyle.canvas : null,
      ),
      body: SafeArea(
        child: FutureBuilder<_WorkspaceSnapshot?>(
          future: _snapshot,
          builder: (context, snapshot) {
            if (snapshot.hasError || (snapshot.connectionState == ConnectionState.done && snapshot.data == null)) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CompanionView(state: CompanionVisualState.think, size: 72),
                      const SizedBox(height: 12),
                      const Text('Materyal açılamadı.', textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      const Text(
                        'Bu hata tek başına kaynağın silindiği anlamına gelmez. Bağlantıyı veya yerel veriyi yeniden okumayı deneyebilirsin.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => setState(() {
                          _snapshot = _load();
                        }),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Tekrar dene'),
                      ),
                      if (Navigator.of(context).canPop()) ...[
                        const SizedBox(height: 6),
                        TextButton.icon(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Geri dön'),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const SingleChildScrollView(
                padding: EdgeInsets.all(28),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CompanionView(state: CompanionVisualState.think, size: 72),
                      SizedBox(height: 14),
                      Text(
                        'Çalışma alanın hazırlanıyor…',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AtelierStyle.ink, fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Güncel kaynağın ve gerçek sıradaki adımın birlikte açılıyor.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AtelierStyle.muted, height: 1.4),
                      ),
                    ],
                  ),
                ),
              );
            }
            final data = snapshot.data!;
            final shouldContinueCurrent =
                data.continuation?.nextAction.kind == NextLearningActionKind.reviewSourceThenRecall ||
                data.continuation?.nextAction.kind == NextLearningActionKind.retryRecallWithoutHint;
            return _WorkspaceBody(
              data: data,
              showFirstValueIntent: _showFirstValueIntent,
              onRecall: () {
                _consumeFirstValueIntent();
                _openRecall(autoAdvanceContinuation: shouldContinueCurrent);
              },
              onQuickRecap: () {
                _consumeFirstValueIntent();
                _openQuickRecap();
              },
              onUpdateSource: _openSourceEditor,
              onReadSource: () {
                _consumeFirstValueIntent();
                _readCurrentSource();
              },
              onListen: () {
                _consumeFirstValueIntent();
                _openListen();
              },
              onGroundedExplain: () => _openGroundedExplain(snapshot.data!.source),
              onGroundedTutor: () {
                _consumeFirstValueIntent();
                _openGroundedTutor(snapshot.data!);
              },
              onExplain: () => _openExplainBack(snapshot.data!.source),
              onFlashcards: () {
                _consumeFirstValueIntent();
                _openFlashcards();
              },
              onQuiz: () {
                _consumeFirstValueIntent();
                _openQuiz();
              },
              onRetentionReview: () {
                _consumeFirstValueIntent();
                _openRetentionReview(snapshot.data!);
              },
              onFocus: () {
                _consumeFirstValueIntent();
                _openFocus(snapshot.data!);
              },
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
    required this.showFirstValueIntent,
    required this.onRecall,
    required this.onQuickRecap,
    required this.onUpdateSource,
    required this.onReadSource,
    required this.onListen,
    required this.onGroundedExplain,
    required this.onGroundedTutor,
    required this.onExplain,
    required this.onFlashcards,
    required this.onQuiz,
    required this.onRetentionReview,
    required this.onFocus,
  });

  final _WorkspaceSnapshot data;
  final bool showFirstValueIntent;
  final VoidCallback onRecall;
  final VoidCallback onQuickRecap;
  final VoidCallback onUpdateSource;
  final VoidCallback onReadSource;
  final VoidCallback onListen;
  final VoidCallback onGroundedExplain;
  final VoidCallback onGroundedTutor;
  final VoidCallback onExplain;
  final VoidCallback onFlashcards;
  final VoidCallback onQuiz;
  final VoidCallback onRetentionReview;
  final VoidCallback onFocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final candidate = LearningVisualTreatmentScope.maybeOf(context);
    if (LivingDeskReviewScope.active(context)) {
      if (showFirstValueIntent &&
          data.continuation == null &&
          data.extracted?.normalizedText.trim().isNotEmpty == true) {
        return FirstValueIntentSurface(
          material: data.material,
          sourceText: data.extracted!.normalizedText,
          sourceVersion: data.source,
          onReadSource: onReadSource,
          onQuickRecap: onQuickRecap,
          onRecall: onRecall,
          onListen: onListen,
          onFocus: onFocus,
        );
      }
      return AtelierWorkspace(
        material: data.material,
        sourceText: data.extracted?.normalizedText ?? '',
        sourceVersion: data.source,
        continuation: data.continuation,
        retention: data.retention,
        onReadSource: onReadSource,
        onQuickRecap: onQuickRecap,
        onUpdateSource: onUpdateSource,
        onRecall: onRecall,
        onListen: onListen,
        onGroundedExplain: onGroundedExplain,
        onGroundedTutor: onGroundedTutor,
        onExplain: onExplain,
        onFlashcards: onFlashcards,
        onQuiz: onQuiz,
        onRetentionReview: onRetentionReview,
        onFocus: onFocus,
      );
    }
    if (candidate != null) {
      return LearningTreatmentWorkspace(
        lane: candidate,
        material: data.material,
        excerpt: data.extracted?.normalizedText ?? '',
        continuation: data.continuation,
        onRecall: onRecall,
        onListen: onListen,
        onExplain: onExplain,
        onFocus: onFocus,
      );
    }
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
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onReadSource,
          icon: const Icon(Icons.menu_book_outlined),
          label: const Text('Kaynağın tamamını oku'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onQuickRecap,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Quick Recap — AI özet'),
        ),
        const SizedBox(height: 24),
        Text('Öğrenme durumu', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        _LearningStatusCard(continuation: data.continuation, onRecall: onRecall, onReadSource: onReadSource),
        const SizedBox(height: 24),
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
        LayoutBuilder(
          builder: (context, constraints) {
            final tileWidth = (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: tileWidth,
                  child: _StudyToolTile(
                    icon: Icons.psychology_alt_outlined,
                    title: 'Hatırla',
                    body: 'Kaynağa bakmadan geri çağır.',
                    tone: _StudyToolTone.primary,
                    onPressed: onRecall,
                  ),
                ),
                SizedBox(
                  width: tileWidth,
                  child: _StudyToolTile(
                    icon: Icons.headphones_rounded,
                    title: 'Dinle',
                    body: 'Metni sesli olarak takip et.',
                    tone: _StudyToolTone.signal,
                    onPressed: onListen,
                  ),
                ),
                SizedBox(
                  width: tileWidth,
                  child: _StudyToolTile(
                    icon: Icons.record_voice_over_outlined,
                    title: 'Açıkla',
                    body: 'Kendi cümlelerinle anlat ve geri bildirim al.',
                    tone: _StudyToolTone.warm,
                    onPressed: onExplain,
                  ),
                ),
                SizedBox(
                  width: tileWidth,
                  child: _StudyToolTile(
                    icon: Icons.center_focus_strong_rounded,
                    title: 'Odaklan',
                    body: 'Takıldığın noktayı netleştir.',
                    tone: _StudyToolTone.momentum,
                    onPressed: onFocus,
                  ),
                ),
              ],
            );
          },
        ),
        if (data.extracted != null && data.extracted!.normalizedText.trim().isNotEmpty) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: Text('Kaynağa hızlı bakış', style: theme.textTheme.titleMedium)),
              DecoratedBox(
                decoration: BoxDecoration(color: AppPalette.signalSoft, borderRadius: BorderRadius.circular(999)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Text(
                    'Kaynak metni',
                    style: theme.textTheme.labelSmall?.copyWith(color: AppPalette.signal, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppPalette.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppPalette.outline),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(17, 15, 17, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yüklediğin içeriğin başlangıcı',
                    style: theme.textTheme.labelMedium?.copyWith(color: AppPalette.inkMuted),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _orientationText(data.extracted!.normalizedText),
                    maxLines: 7,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.48),
                  ),
                ],
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
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const ValueKey('workspace-update-source'),
                  onPressed: onUpdateSource,
                  icon: const Icon(Icons.sync_rounded),
                  label: const Text('Kaynağı güncelle'),
                ),
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
    final text = data.extracted?.normalizedText.trim();
    if (text == null || text.isEmpty) return kind;
    final words = text.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).length;
    return '$kind • $words kelime';
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
  const _LearningStatusCard({required this.continuation, required this.onRecall, required this.onReadSource});

  final LearningContinuation? continuation;
  final VoidCallback onRecall;
  final VoidCallback onReadSource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = continuation?.state.kind;
    final nextKind = continuation?.nextAction.kind;
    final reviewFirst = nextKind == NextLearningActionKind.reviewSourceThenRecall;
    final waitUntilLater = nextKind == NextLearningActionKind.repeatRecallLater;
    final (title, body) = switch (state) {
      RecallStateKind.retrievedOnce => (
        'Bir kez bağımsız hatırlandı',
        'Bu güçlü bir sinyal, ancak henüz ustalık iddiası değil.',
      ),
      RecallStateKind.developing => (
        'Gelişiyor',
        continuation?.nextAction.reasonText ?? 'Bir sonraki aktif deneme hazır.',
      ),
      RecallStateKind.needsReview => (
        'Tekrar gerekli',
        continuation?.nextAction.reasonText ?? 'Kaynağı kısaca gözden geçirip yeniden dene.',
      ),
      RecallStateKind.notAssessed ||
      null => ('Henüz ölçülmedi', 'İlk hatırlama denemesi öğrenme durumunu görünür kılar.'),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                'SIRADAKİ ADIM',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppPalette.momentumInk,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(title, style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                CompanionView(state: _companionState(state), size: 58),
              ],
            ),
            const SizedBox(height: 12),
            Text(body, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.80))),
            const SizedBox(height: 18),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppPalette.primaryDark),
              onPressed: reviewFirst || waitUntilLater ? onReadSource : onRecall,
              icon: Icon(reviewFirst || waitUntilLater ? Icons.menu_book_outlined : Icons.psychology_alt_rounded),
              label: Text(
                reviewFirst
                    ? 'Önce kaynağı gözden geçir'
                    : waitUntilLater
                    ? 'Kaynağa dön'
                    : 'Hatırla ile devam',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _StudyToolTone { primary, signal, warm, momentum }

class _StudyToolTile extends StatelessWidget {
  const _StudyToolTile({
    required this.icon,
    required this.title,
    required this.body,
    required this.tone,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String body;
  final _StudyToolTone tone;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (soft, accent) = switch (tone) {
      _StudyToolTone.primary => (AppPalette.primarySoft, AppPalette.primary),
      _StudyToolTone.signal => (AppPalette.signalSoft, AppPalette.signal),
      _StudyToolTone.warm => (AppPalette.attentionSoft, AppPalette.attention),
      _StudyToolTone.momentum => (const Color(0xFFF0F9D7), AppPalette.momentumInk),
    };

    return Material(
      color: AppPalette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppPalette.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 138),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(icon, size: 20, color: accent),
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_outward_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
                  ],
                ),
                const SizedBox(height: 15),
                Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

CompanionVisualState _companionState(RecallStateKind? state) => switch (state) {
  RecallStateKind.retrievedOnce => CompanionVisualState.success,
  RecallStateKind.developing => CompanionVisualState.idle,
  RecallStateKind.needsReview => CompanionVisualState.think,
  RecallStateKind.notAssessed || null => CompanionVisualState.listen,
};

class _WorkspaceSnapshot {
  const _WorkspaceSnapshot({
    required this.material,
    required this.source,
    required this.extracted,
    required this.continuation,
    required this.retention,
  });

  final MaterialRecord material;
  final SourceVersionRecord source;
  final ExtractedContentRecord? extracted;
  final LearningContinuation? continuation;
  final RetentionMaterialStatus? retention;
}
