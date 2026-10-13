import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/learning_contracts.dart';
import '../domain/learning_truth.dart';
import '../domain/retention_schedule.dart';
import '../domain/study_plan.dart';
import 'app_theme.dart';
import 'daily_study_plan.dart';
import 'study_plan_screen.dart';
import 'companion_view.dart';

/// Current source-first product experience scope.
///
/// The legacy shell remains available only as an explicit fallback while this
/// unmerged branch is verified. This scope does not imply visual-lock or release approval.
class LivingDeskReviewScope extends InheritedWidget {
  const LivingDeskReviewScope({required super.child, super.key});

  static bool active(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LivingDeskReviewScope>() != null;

  @override
  bool updateShouldNotify(LivingDeskReviewScope oldWidget) => false;
}

/// The learner's REAL material is the main interface object, not a feature menu.
/// This is the active reversible branch implementation; final visual lock and release remain separate gates.
class LivingStudyDeskHome extends StatelessWidget {
  const LivingStudyDeskHome({
    required this.material,
    required this.continuation,
    this.retention,
    this.dailyStudy,
    this.studyTarget,
    this.listenResumeChunk = 0,
    this.readerResumeProgress = 0,
    this.readerResumePreferred = false,
    required this.sourceText,
    required this.otherMaterials,
    required this.onOpenWorkspace,
    this.onOpenReader,
    required this.onOpenLearning,
    required this.onOpenListen,
    required this.onOpenMaterial,
    required this.onOpenStudyPlan,
    super.key,
  });

  final MaterialRecord? material;
  final LearningContinuation? continuation;
  final RetentionMaterialStatus? retention;
  final DailyStudyPlan? dailyStudy;
  final StudyTargetProjection? studyTarget;
  final int listenResumeChunk;
  final double readerResumeProgress;
  final bool readerResumePreferred;
  final String? sourceText;
  final List<MaterialRecord> otherMaterials;
  final VoidCallback onOpenWorkspace;
  final VoidCallback? onOpenReader;
  final VoidCallback onOpenLearning;
  final VoidCallback onOpenListen;
  final ValueChanged<MaterialId> onOpenMaterial;
  final VoidCallback onOpenStudyPlan;

  static const _canvas = AppPalette.canvas;
  static const _paper = AppPalette.surface;
  static const _ink = AppPalette.ink;
  static const _sub = AppPalette.inkMuted;
  static const _accent = AppPalette.primary;
  static const _line = AppPalette.outline;

  DailyStudyItem? get _todayPrimary => dailyStudy?.primary;

  bool get _todayQuiet => material != null && dailyStudy != null && dailyStudy!.items.isEmpty;

  String get _todayNextTiming {
    final at = dailyStudy?.nextScheduledAt;
    final evaluatedAt = dailyStudy?.evaluatedAt;
    if (at == null || evaluatedAt == null) return 'daha sonra';
    final difference = at.difference(evaluatedAt);
    if (difference.inMinutes < 60) return '${difference.inMinutes.clamp(1, 59)} dk sonra';
    if (difference.inHours < 24) return '${difference.inHours} sa sonra';
    final days = difference.inDays;
    return '${days < 1 ? 1 : days} gün sonra';
  }

  String get _todayLabel {
    return switch (_todayPrimary?.kind) {
      DailyStudyActionKind.scheduledReview => 'BUGÜN · TEKRAR ZAMANI',
      DailyStudyActionKind.sourceRepair => 'BUGÜN · KAYNAK ONARIMI',
      DailyStudyActionKind.retryRecall => 'BUGÜN · YENİDEN DENE',
      DailyStudyActionKind.resumeReader => 'BUGÜN · OKUMAYA DEVAM',
      DailyStudyActionKind.resumeListen => 'BUGÜN · DİNLEMEYE DEVAM',
      DailyStudyActionKind.beginRecall => 'BUGÜN · AKTİF HATIRLAMA',
      DailyStudyActionKind.workspaceRecovery => 'BUGÜN · GÜVENLİ DEVAM',
      null => 'BUGÜN',
    };
  }

  IconData _dailyIcon(DailyStudyActionKind kind) => switch (kind) {
    DailyStudyActionKind.scheduledReview => Icons.event_repeat_rounded,
    DailyStudyActionKind.sourceRepair => Icons.auto_stories_outlined,
    DailyStudyActionKind.retryRecall => Icons.refresh_rounded,
    DailyStudyActionKind.resumeReader => Icons.menu_book_outlined,
    DailyStudyActionKind.resumeListen => Icons.headphones_rounded,
    DailyStudyActionKind.beginRecall => Icons.psychology_alt_outlined,
    DailyStudyActionKind.workspaceRecovery => Icons.space_dashboard_outlined,
  };

  bool get _hasReaderResume =>
      continuation == null && readerResumePreferred && readerResumeProgress > 0.02 && readerResumeProgress < 0.95;

  bool get _hasListenResume => continuation == null && !_hasReaderResume && listenResumeChunk > 0;

  bool get _retentionIsPrimary {
    if (retention?.hasDue != true || _hasReaderResume || _hasListenResume) return false;
    return switch (continuation?.nextAction.kind) {
      NextLearningActionKind.reviewSourceThenRecall || NextLearningActionKind.retryRecallWithoutHint => false,
      NextLearningActionKind.repeatRecallLater || null => true,
    };
  }

  String get _retentionTiming {
    final status = retention;
    final dueAt = status?.nextScheduled?.dueAt;
    if (status == null || dueAt == null || status.hasDue) return 'şimdi';
    final difference = dueAt.difference(status.evaluatedAt);
    if (difference.inMinutes < 60) return '${difference.inMinutes.clamp(1, 59)} dk sonra';
    if (difference.inHours < 24) return '${difference.inHours} sa sonra';
    final days = difference.inDays;
    return '${days < 1 ? 1 : days} gün sonra';
  }

  String get _retentionReason {
    final item = retention?.nextDue ?? retention?.nextScheduled;
    if (item == null) return 'Aktif çalışmandan sonra planlanan tekrar burada görünecek.';
    return switch (item.latestOutcomeBand) {
      RetentionOutcomeBand.independentRetrieval => 'Bağımsız bir geri çağırma kaydedildi. Yeni tekrar kalıcılığı yeniden ölçer; bu sonuç ustalık iddiası değildir.',
      RetentionOutcomeBand.supportedRetrieval =>
        'Önceki deneme destekli ya da kısmiydi. Planlanan tekrar bağımsız geri çağırmayı yeniden denetler.',
      RetentionOutcomeBand.repairNeeded =>
        'Önceki aktif deneme onarım gerektiriyordu. Kısa aralıkla yeniden çalışmak için tekrar hazır.',
      RetentionOutcomeBand.unassessed =>
        'Önceki aktif çalışma ölçülebilir olumlu kanıt üretmedi. Tekrar hazır; henüz kalıcılık sonucu yok.',
    };
  }

  String get _nextStep {
    final today = _todayPrimary;
    if (today != null) return today.title;
    if (_todayQuiet) return 'Şu an planlı bir tekrar yok';
    if (_hasReaderResume) return 'Okumaya kaldığın yerden devam et';
    if (_hasListenResume) return 'Dinlemeye kaldığın yerden devam et';
    final action = continuation?.nextAction.kind;
    if (action == NextLearningActionKind.reviewSourceThenRecall) return 'Kaynağa dön, sonra yeniden dene';
    if (action == NextLearningActionKind.retryRecallWithoutHint) return 'İpucusuz bir kez daha dene';
    if (_retentionIsPrimary) return 'Tekrar zamanı geldi';
    if (action == NextLearningActionKind.repeatRecallLater && retention?.hasSchedule == true) {
      return 'Sonraki tekrar $_retentionTiming';
    }
    return action == NextLearningActionKind.repeatRecallLater
        ? 'Bu tur tamam. Sonra yeniden hatırla.'
        : 'İlk hatırlama denemeni yap';
  }

  String get _why {
    final today = _todayPrimary;
    if (today != null) return today.reasonText;
    if (_todayQuiet) {
      return dailyStudy?.nextScheduledAt == null
          ? 'Güncel kaynakların şu an zorunlu bir öğrenme adımı üretmiyor. İstersen materyaline göz atabilirsin.'
          : 'Yeni aktif kanıt gelene kadar sıradaki planlı dönüş $_todayNextTiming. Şu an ek bir ustalık iddiası üretmiyoruz.';
    }
    if (_hasReaderResume) {
      return 'Okuma konumun kayıtlı. Devam et; hazır olduğunda kaynağı kapatıp hatırlamayı dene.';
    }
    if (_hasListenResume) {
      return 'Dinleme konumun kayıtlı. Devam et; hazır olduğunda kaynağı kapatıp hatırlamayı dene.';
    }
    if (_retentionIsPrimary || continuation?.nextAction.kind == NextLearningActionKind.repeatRecallLater) {
      if (retention?.hasSchedule == true) return _retentionReason;
    }
    return continuation?.nextAction.reasonText ?? 'Kaynağa bakmadan kısa bir hatırlama denemesi yap.';
  }

  String get _continuationLabel {
    if (dailyStudy != null) return _todayLabel;
    if (_hasReaderResume) return 'OKUMA KONUMUN KAYITLI';
    if (_hasListenResume) return 'DİNLEME KONUMUN KAYITLI';
    if (_retentionIsPrimary) return 'TEKRAR ZAMANI';
    if (continuation == null) return 'KAYNAĞINDAN ÖĞREN';
    return continuation!.nextAction.kind == NextLearningActionKind.repeatRecallLater
        ? 'DENEMEN KAYITLI · SONRA YENİDEN HATIRLA'
        : 'DENEMEN KAYITLI · SIRADAKİ ADIM';
  }

  String get _nextActionCta {
    final today = _todayPrimary;
    if (today != null) return today.actionLabel;
    if (_todayQuiet) return 'Materyali aç';
    if (_hasReaderResume) return 'Okumaya devam et';
    if (_hasListenResume) return 'Dinlemeye devam et';
    final action = continuation?.nextAction.kind;
    if (_retentionIsPrimary) return 'Tekrarı aç';
    return switch (action) {
      NextLearningActionKind.reviewSourceThenRecall => 'Kaynağı gözden geçir',
      NextLearningActionKind.retryRecallWithoutHint => 'İpucusuz tekrar dene',
      NextLearningActionKind.repeatRecallLater => 'Çalışma alanına dön',
      null => 'Hatırlamayı dene',
    };
  }

  VoidCallback get _nextActionHandler {
    final today = _todayPrimary;
    if (today != null) return () => onOpenMaterial(today.materialId);
    if (_todayQuiet) return onOpenWorkspace;
    if (_hasReaderResume) return onOpenReader ?? onOpenWorkspace;
    if (_hasListenResume) return onOpenListen;
    if (_retentionIsPrimary) return onOpenWorkspace;
    return switch (continuation?.nextAction.kind) {
      NextLearningActionKind.reviewSourceThenRecall => onOpenReader ?? onOpenWorkspace,
      NextLearningActionKind.retryRecallWithoutHint => onOpenLearning,
      NextLearningActionKind.repeatRecallLater => onOpenWorkspace,
      null => onOpenLearning,
    };
  }

  IconData get _nextActionIcon {
    final today = _todayPrimary;
    if (today != null) return _dailyIcon(today.kind);
    if (_todayQuiet) return Icons.space_dashboard_outlined;
    if (_hasReaderResume) return Icons.menu_book_outlined;
    if (_hasListenResume) return Icons.headphones_rounded;
    if (_retentionIsPrimary) return Icons.event_repeat_rounded;
    return continuation?.nextAction.kind == NextLearningActionKind.repeatRecallLater
        ? Icons.space_dashboard_outlined
        : Icons.psychology_alt_outlined;
  }

  String? get _evidenceHeadline {
    final state = continuation?.state.kind;
    return switch (state) {
      RecallStateKind.retrievedOnce => 'Kendi başına hatırladın',
      RecallStateKind.developing => 'İpucuyla ilerledin',
      RecallStateKind.needsReview => 'Bu bölüm bir tur daha istiyor',
      RecallStateKind.notAssessed => 'Henüz bağımsız deneme yok',
      null => null,
    };
  }

  String? get _evidenceDetail {
    final state = continuation?.state.kind;
    return switch (state) {
      RecallStateKind.retrievedOnce => 'İlk bağımsız hatırlaman kaydedildi. Kalıcılığı sonraki deneme gösterecek.',
      RecallStateKind.developing =>
        'Bu denemede yardım kullandın. Sıradaki hedef, aynı bilgiyi ipucusuz geri çağırmak.',
      RecallStateKind.needsReview => 'Bu bölüm henüz oturmadı. Kaynağa dönüp kısa bir onarım yap, sonra yeniden dene.',
      RecallStateKind.notAssessed => 'Henüz bağımsız bir hatırlama denemen yok.',
      null => null,
    };
  }

  IconData? get _evidenceIcon {
    final state = continuation?.state.kind;
    return switch (state) {
      RecallStateKind.retrievedOnce => Icons.check_circle_outline_rounded,
      RecallStateKind.developing => Icons.trending_up_rounded,
      RecallStateKind.needsReview => Icons.auto_stories_outlined,
      RecallStateKind.notAssessed => Icons.radio_button_unchecked_rounded,
      null => null,
    };
  }

  String get _preview {
    final source = sourceText?.trim() ?? '';
    if (source.isEmpty) return 'Bu materyalin metin önizlemesi henüz hazır değil.';
    return source.replaceAll(RegExp(r'\s+'), ' ');
  }

  String _type(MaterialRecord m) => m.mediaType == SourceMediaType.pdf ? 'PDF KAYNAĞI' : 'METİN NOTU';

  Widget _todayQueueItem(BuildContext context, DailyStudyItem item) {
    return Semantics(
      button: true,
      label: '${item.materialTitle}. ${item.title}. ${item.reasonText}',
      child: Material(
        color: _paper,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          key: ValueKey('today-item-${item.materialId.value}'),
          borderRadius: BorderRadius.circular(15),
          onTap: () => _runLearningAction(context, () => onOpenMaterial(item.materialId)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 11, 11, 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppPalette.primarySoft, borderRadius: BorderRadius.circular(11)),
                  child: Icon(_dailyIcon(item.kind), color: _accent, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.materialTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _ink, fontSize: 13.5, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.title,
                        style: const TextStyle(color: _accent, fontSize: 11.5, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(item.reasonText, style: const TextStyle(color: _sub, fontSize: 11.5, height: 1.35)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Padding(
                  padding: EdgeInsets.only(top: 9),
                  child: Icon(Icons.chevron_right_rounded, color: _sub, size: 19),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _runLearningAction(BuildContext context, VoidCallback action) {
    final media = MediaQuery.maybeOf(context);
    final quietFeedback = (media?.disableAnimations ?? false) || (media?.accessibleNavigation ?? false);
    if (!quietFeedback) {
      try {
        unawaited(HapticFeedback.selectionClick().catchError((_) {}));
      } catch (_) {
        // Feedback is acknowledgement only and must never block navigation.
      }
    }
    action();
  }

  @override
  Widget build(BuildContext context) {
    final hasMaterial = material != null;
    return ColoredBox(
      color: _canvas,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              key: ValueKey(hasMaterial ? 'la0040-living-home-populated' : 'la0040-living-home-empty'),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 80),
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compactHeader =
                        constraints.maxWidth < 340 || MediaQuery.textScalerOf(context).scale(1) > 1.25;
                    return Row(
                      children: [
                        Container(
                          width: 9,
                          height: compactHeader ? 36 : 30,
                          decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(3)),
                        ),
                        const SizedBox(width: 11),
                        const Expanded(
                          child: Text(
                            'sesli öğren',
                            softWrap: false,
                            style: TextStyle(
                              fontSize: 19,
                              height: 1.2,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.9,
                              color: _ink,
                            ),
                          ),
                        ),
                        if (!compactHeader)
                          const Text(
                            'ÇALIŞMA MASAN',
                            style: TextStyle(color: _sub, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                if (hasMaterial) _populated(context) else _empty(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _populated(BuildContext context) {
    final current = material!;
    final hasRecallEvidence = continuation != null && continuation!.state.kind != RecallStateKind.notAssessed;
    final hasActiveContinuation =
        continuation != null || retention?.hasSchedule == true || _hasReaderResume || _hasListenResume;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final compactFirstViewport = MediaQuery.sizeOf(context).width < 350 && textScale > 1.2;
    final todayIds = dailyStudy?.items.map((item) => item.materialId).toSet() ?? <MaterialId>{};
    final secondaryMaterials = otherMaterials.where((item) => !todayIds.contains(item.id)).toList(growable: false);
    final companionState = _hasListenResume
        ? CompanionVisualState.listen
        : _retentionIsPrimary
        ? CompanionVisualState.think
        : hasRecallEvidence
        ? CompanionVisualState.idle
        : CompanionVisualState.think;

    Widget nextReasonCopy({required double reasonSize}) => Text(
      _why,
      key: const ValueKey('la0040-home-next-reason'),
      style: TextStyle(color: _sub, fontSize: reasonSize, height: 1.4),
    );

    Widget nextStepCopy({required double titleSize, required double reasonSize, bool includeReason = true}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          label: 'Sıradaki öğrenme adımı',
          value: _nextStep,
          child: ExcludeSemantics(
            child: Text(
              _nextStep,
              style: TextStyle(
                color: _ink,
                fontSize: titleSize,
                height: 1.16,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.35,
              ),
            ),
          ),
        ),
        if (includeReason) ...[SizedBox(height: compactFirstViewport ? 3 : 5), nextReasonCopy(reasonSize: reasonSize)],
      ],
    );

    final materialCard = Material(
      color: _paper,
      elevation: 1,
      shadowColor: const Color(0x140F1F47),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('la0040-living-material-open'),
        onTap: () => _runLearningAction(context, onOpenWorkspace),
        child: Container(
          width: double.infinity,
          padding: compactFirstViewport
              ? const EdgeInsets.fromLTRB(13, 10, 12, 10)
              : const EdgeInsets.fromLTRB(16, 14, 15, 14),
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: _accent, width: 3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_stories_outlined, color: _accent, size: compactFirstViewport ? 19 : 21),
              SizedBox(width: compactFirstViewport ? 8 : 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _type(current),
                      style: const TextStyle(
                        color: _accent,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.9,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      current.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compactFirstViewport ? 16 : 19,
                        height: 1.18,
                        letterSpacing: -0.35,
                        fontWeight: FontWeight.w900,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: compactFirstViewport ? 11.5 : 13, color: _sub, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, color: _accent, size: 19),
            ],
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _todayPrimary != null
              ? 'Bugün ne çalışman gerektiği belli.'
              : _todayQuiet
              ? 'Bugün için bekleyen bir tekrar yok.'
              : 'Kaldığın yer hazır.',
          key: const ValueKey('la0040-atelier-home-promise'),
          style: TextStyle(
            color: _ink,
            fontSize: compactFirstViewport ? 24 : 31,
            height: 1.05,
            fontWeight: FontWeight.w900,
            letterSpacing: compactFirstViewport ? -0.7 : -1.2,
          ),
        ),
        SizedBox(height: compactFirstViewport ? 5 : 9),
        Text(
          _todayPrimary != null
              ? (compactFirstViewport
                    ? 'En yararlı adım hazır.'
                    : 'Güncel öğrenme kanıtına göre en yararlı adım hazır.')
              : _todayQuiet
              ? 'Bir sonraki planlı dönüşü zamanı gelince öne çıkaracağız.'
              : compactFirstViewport
              ? 'Kaynağın ve sıradaki adımın hazır.'
              : 'Kaynağın hazır. Sıradaki adımın belli.',
          style: TextStyle(color: _sub, fontSize: compactFirstViewport ? 13 : 15, height: 1.4),
        ),
        SizedBox(height: compactFirstViewport ? 10 : 17),
        if (!compactFirstViewport) ...[materialCard, const SizedBox(height: 16)],
        Container(
          key: const ValueKey('la0040-source-to-recall-thread'),
          padding: const EdgeInsets.fromLTRB(2, 0, 0, 0),
          child: compactFirstViewport
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CompanionView(key: const ValueKey('home-next-companion'), state: companionState, size: 68),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            hasActiveContinuation ? _continuationLabel : 'ŞİMDİ',
                            style: const TextStyle(
                              color: _accent,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    nextStepCopy(titleSize: 17.5, reasonSize: 11.5, includeReason: false),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 98,
                      child: CompanionView(key: const ValueKey('home-next-companion'), state: companionState, size: 90),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasActiveContinuation ? _continuationLabel : 'ŞİMDİ',
                            style: const TextStyle(
                              color: _accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.9,
                            ),
                          ),
                          const SizedBox(height: 6),
                          nextStepCopy(titleSize: 22, reasonSize: 13),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
        SizedBox(height: compactFirstViewport ? 8 : 12),
        KeyedSubtree(
          key: const ValueKey('la0040-living-next-step-open'),
          child: SizedBox(
            width: double.infinity,
            child: _todayQuiet
                ? OutlinedButton.icon(
                    key: const ValueKey('la0040-living-continue'),
                    onPressed: () => _runLearningAction(context, _nextActionHandler),
                    icon: Icon(_nextActionIcon, size: 20),
                    label: Text(_nextActionCta),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _accent,
                      minimumSize: Size.fromHeight(compactFirstViewport ? 48 : 54),
                      side: const BorderSide(color: _accent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  )
                : FilledButton.icon(
                    key: const ValueKey('la0040-living-continue'),
                    onPressed: () => _runLearningAction(context, _nextActionHandler),
                    icon: Icon(_nextActionIcon, size: 20),
                    label: Text(_nextActionCta),
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      minimumSize: Size.fromHeight(compactFirstViewport ? 48 : 54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
          ),
        ),
        if (compactFirstViewport) ...[
          const SizedBox(height: 6),
          nextReasonCopy(reasonSize: 11.5),
          const SizedBox(height: 8),
          materialCard,
        ],
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.center,
          child: TextButton.icon(
            key: const ValueKey('la0040-living-listen'),
            onPressed: () =>
                _runLearningAction(context, (_hasReaderResume || _hasListenResume) ? onOpenLearning : onOpenListen),
            icon: Icon(
              (_hasReaderResume || _hasListenResume) ? Icons.psychology_alt_outlined : Icons.headphones_rounded,
              size: 18,
            ),
            label: Text((_hasReaderResume || _hasListenResume) ? 'Şimdi hatırlamayı dene' : 'Önce dinlemek istiyorum'),
            style: TextButton.styleFrom(foregroundColor: _accent),
          ),
        ),
        const SizedBox(height: 10),
        StudyPlanHomeCard(projection: studyTarget, hasMaterials: material != null, onOpen: onOpenStudyPlan),
        if (_evidenceHeadline != null) ...[
          const SizedBox(height: 12),
          Semantics(
            container: true,
            label: 'Öğrenme kanıtı. $_evidenceHeadline. $_evidenceDetail',
            child: ExcludeSemantics(
              child: Container(
                key: const ValueKey('la0040-home-evidence-payoff'),
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
                decoration: BoxDecoration(color: AppPalette.primarySoft, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_evidenceIcon, color: _accent, size: 19),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SON DENEMENDEN',
                            style: TextStyle(
                              color: _accent,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.9,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _evidenceHeadline!,
                            style: const TextStyle(color: _ink, fontSize: 14.5, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 3),
                          Text(_evidenceDetail!, style: const TextStyle(color: _sub, fontSize: 12.5, height: 1.35)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        if ((dailyStudy?.items.length ?? 0) > 1) ...[
          const SizedBox(height: 20),
          const Divider(color: _line),
          const SizedBox(height: 12),
          const Text(
            'Bugün sırada',
            style: TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          const Text(
            'Yalnız güncel kaynak ve kayıtlı öğrenme durumundan çıkan adımlar.',
            style: TextStyle(color: _sub, fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: 9),
          for (final item in dailyStudy!.items.skip(1).take(3)) ...[
            _todayQueueItem(context, item),
            const SizedBox(height: 8),
          ],
        ],
        if (secondaryMaterials.isNotEmpty) ...[
          const SizedBox(height: 22),
          const Divider(color: _line),
          const SizedBox(height: 13),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Diğer materyallerin',
                  style: TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                'KALDIĞIN YERDEN',
                style: TextStyle(
                  color: _accent.withValues(alpha: 0.82),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          for (final item in secondaryMaterials.take(3))
            Semantics(
              button: true,
              label: '${item.title} materyalinde kaldığın öğrenme adımına devam et',
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    item.mediaType == SourceMediaType.pdf ? Icons.picture_as_pdf_outlined : Icons.notes_rounded,
                    color: _accent,
                  ),
                  title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: const Text('Sıradaki öğrenme adımını aç'),
                  trailing: const Icon(Icons.chevron_right_rounded, color: _sub),
                  onTap: () => _runLearningAction(context, () => onOpenMaterial(item.id)),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _empty(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 340 || MediaQuery.textScalerOf(context).scale(1) > 1.25;
      final companion = Container(
        width: compact ? 96 : 112,
        height: compact ? 96 : 112,
        decoration: BoxDecoration(
          color: AppPalette.primarySoft,
          borderRadius: BorderRadius.circular(compact ? 16 : 20),
        ),
        child: Center(
          child: CompanionView(
            key: const ValueKey('home-empty-companion'),
            state: CompanionVisualState.idle,
            size: compact ? 88 : 104,
          ),
        ),
      );
      final promise = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'İLK OTURUM',
            style: TextStyle(color: _accent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Text(
            'Birlikte\nöğrenelim.',
            style: TextStyle(
              color: _ink,
              fontSize: compact ? 25 : 32,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.1,
            ),
          ),
          const SizedBox(height: 10),
          const Text('Kaynağını ekle. Oku, dinle, hatırla.', style: TextStyle(color: _sub, fontSize: 14, height: 1.45)),
        ],
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, compact ? 18 : 20, 20, 20),
            decoration: BoxDecoration(
              color: _paper,
              borderRadius: BorderRadius.circular(24),
              border: const Border(left: BorderSide(color: _accent, width: 4)),
              boxShadow: const [BoxShadow(color: Color(0x1014224A), blurRadius: 24, offset: Offset(0, 10))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (compact) ...[
                  Align(alignment: Alignment.centerLeft, child: companion),
                  const SizedBox(height: 12),
                  promise,
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: promise),
                      const SizedBox(width: 10),
                      companion,
                    ],
                  ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  key: const ValueKey('la0040-living-add'),
                  onPressed: () => _runLearningAction(context, onOpenLearning),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('İlk kaynağımı ekle'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                  ),
                ),
              ],
            ),
          ),
          if (studyTarget != null) ...[
            const SizedBox(height: 12),
            StudyPlanHomeCard(projection: studyTarget, hasMaterials: false, onOpen: onOpenStudyPlan),
          ],
        ],
      );
    },
  );
}
