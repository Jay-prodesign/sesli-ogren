import '../domain/learning_contracts.dart';
import '../domain/learning_truth.dart';
import '../domain/retention_schedule.dart';
import 'progress_surface.dart';

enum DailyStudyActionKind {
  scheduledReview,
  sourceRepair,
  retryRecall,
  resumeReader,
  resumeListen,
  beginRecall,
  workspaceRecovery,
}

class DailyStudyItem {
  const DailyStudyItem({
    required this.materialId,
    required this.materialTitle,
    required this.sourceVersionId,
    required this.kind,
    required this.title,
    required this.actionLabel,
    required this.reasonCode,
    required this.reasonText,
    required this.activityAt,
    this.dueAt,
  });

  final MaterialId materialId;
  final String materialTitle;
  final SourceVersionId sourceVersionId;
  final DailyStudyActionKind kind;
  final String title;
  final String actionLabel;
  final String reasonCode;
  final String reasonText;
  final DateTime activityAt;
  final DateTime? dueAt;
}

class DailyStudyPlan {
  const DailyStudyPlan({
    required this.items,
    required this.evaluatedAt,
    this.nextScheduledAt,
    this.nextScheduledMaterialId,
  });

  static const policyVersion = 'daily-study-v1';

  final List<DailyStudyItem> items;
  final DateTime evaluatedAt;
  final DateTime? nextScheduledAt;
  final MaterialId? nextScheduledMaterialId;

  DailyStudyItem? get primary => items.isEmpty ? null : items.first;

  static DailyStudyPlan build({required List<ProgressItem> progress, required DateTime evaluatedAt}) {
    final at = evaluatedAt.toUtc();
    final items = <DailyStudyItem>[];
    DateTime? nextScheduledAt;
    MaterialId? nextScheduledMaterialId;

    for (final progressItem in progress) {
      final sourceVersionId = progressItem.sourceVersionId;
      if (sourceVersionId == null) {
        // No current source identity means there is no safe Daily Study action.
        continue;
      }

      final scheduled = progressItem.retention?.nextScheduled;
      if (scheduled != null && scheduled.dueAt.isAfter(at)) {
        if (nextScheduledAt == null ||
            scheduled.dueAt.isBefore(nextScheduledAt) ||
            (scheduled.dueAt == nextScheduledAt &&
                progressItem.material.id.value.compareTo(nextScheduledMaterialId?.value ?? '') < 0)) {
          nextScheduledAt = scheduled.dueAt;
          nextScheduledMaterialId = progressItem.material.id;
        }
      }

      final item = _project(progressItem, sourceVersionId, at);
      if (item != null) items.add(item);
    }

    items.sort(_compare);
    return DailyStudyPlan(
      items: List<DailyStudyItem>.unmodifiable(items),
      evaluatedAt: at,
      nextScheduledAt: nextScheduledAt,
      nextScheduledMaterialId: nextScheduledMaterialId,
    );
  }

  static DailyStudyItem? _project(ProgressItem progress, SourceVersionId sourceVersionId, DateTime evaluatedAt) {
    final action = progress.continuation?.nextAction.kind;
    final material = progress.material;
    final activityAt = _activityAt(progress);

    if (action == NextLearningActionKind.reviewSourceThenRecall) {
      return DailyStudyItem(
        materialId: material.id,
        materialTitle: material.title,
        sourceVersionId: sourceVersionId,
        kind: DailyStudyActionKind.sourceRepair,
        title: 'Kaynağı onar, sonra yeniden dene',
        actionLabel: 'Kaynağı gözden geçir',
        reasonCode: progress.continuation!.nextAction.reasonCode,
        reasonText: progress.continuation!.nextAction.reasonText,
        activityAt: activityAt,
      );
    }

    if (action == NextLearningActionKind.retryRecallWithoutHint) {
      return DailyStudyItem(
        materialId: material.id,
        materialTitle: material.title,
        sourceVersionId: sourceVersionId,
        kind: DailyStudyActionKind.retryRecall,
        title: 'İpucusuz bir kez daha dene',
        actionLabel: 'Tekrar dene',
        reasonCode: progress.continuation!.nextAction.reasonCode,
        reasonText: progress.continuation!.nextAction.reasonText,
        activityAt: activityAt,
      );
    }

    final due = progress.retention?.nextDue;
    if (due != null && due.isDueAt(evaluatedAt)) {
      return DailyStudyItem(
        materialId: material.id,
        materialTitle: material.title,
        sourceVersionId: sourceVersionId,
        kind: DailyStudyActionKind.scheduledReview,
        title: 'Planlanan tekrarın hazır',
        actionLabel: 'Tekrarı aç',
        reasonCode: 'RETENTION_REVIEW_DUE',
        reasonText: _retentionReason(due),
        activityAt: activityAt,
        dueAt: due.dueAt,
      );
    }

    if (progress.continuation == null && progress.prefersReaderResume) {
      return DailyStudyItem(
        materialId: material.id,
        materialTitle: material.title,
        sourceVersionId: sourceVersionId,
        kind: DailyStudyActionKind.resumeReader,
        title: 'Okumaya kaldığın yerden devam et',
        actionLabel: 'Okumaya devam et',
        reasonCode: 'READER_RESUME_AVAILABLE',
        reasonText:
            'Okuma konumun güncel kaynakta kayıtlı. Devam et; hazır olduğunda kaynağı kapatıp hatırlamayı dene.',
        activityAt: activityAt,
      );
    }

    if (progress.continuation == null && progress.hasListenResume) {
      return DailyStudyItem(
        materialId: material.id,
        materialTitle: material.title,
        sourceVersionId: sourceVersionId,
        kind: DailyStudyActionKind.resumeListen,
        title: 'Dinlemeye kaldığın yerden devam et',
        actionLabel: 'Dinlemeye devam et',
        reasonCode: 'LISTEN_RESUME_AVAILABLE',
        reasonText: 'Dinleme konumun güncel kaynakta kayıtlı. Dinlemek öğrenme kanıtı değildir; ardından aktif hatırlamayı dene.',
        activityAt: activityAt,
      );
    }

    if (progress.continuation == null) {
      return DailyStudyItem(
        materialId: material.id,
        materialTitle: material.title,
        sourceVersionId: sourceVersionId,
        kind: DailyStudyActionKind.beginRecall,
        title: 'İlk hatırlamayı dene',
        actionLabel: 'Hatırlamayı dene',
        reasonCode: 'NO_DURABLE_RECALL_EVIDENCE',
        reasonText: 'Bu kaynak için henüz bağımsız hatırlama kanıtı yok. Kaynağa bakmadan kısa bir deneme yap.',
        activityAt: activityAt,
      );
    }

    if (action == NextLearningActionKind.repeatRecallLater && progress.retention?.hasSchedule != true) {
      return DailyStudyItem(
        materialId: material.id,
        materialTitle: material.title,
        sourceVersionId: sourceVersionId,
        kind: DailyStudyActionKind.workspaceRecovery,
        title: 'Planlı dönüşü yeniden kontrol et',
        actionLabel: 'Çalışma alanını aç',
        reasonCode: 'RETENTION_SCHEDULE_MISSING',
        reasonText: 'Önceki deneme kaydedilmiş ancak planlı dönüş görünmüyor. Güncel kaynak ve sıradaki adımı çalışma alanında doğrula.',
        activityAt: activityAt,
      );
    }

    // repeatRecallLater with a future source-bound schedule is intentionally
    // absent from "do now". The return time remains visible via nextScheduledAt.
    return null;
  }

  static int _compare(DailyStudyItem left, DailyStudyItem right) {
    final priority = _priority(right.kind).compareTo(_priority(left.kind));
    if (priority != 0) return priority;

    if (left.kind == DailyStudyActionKind.scheduledReview && right.kind == DailyStudyActionKind.scheduledReview) {
      final leftDue = left.dueAt;
      final rightDue = right.dueAt;
      if (leftDue != null && rightDue != null) {
        final dueOrder = leftDue.compareTo(rightDue);
        if (dueOrder != 0) return dueOrder;
      }
    }

    final activityOrder = right.activityAt.compareTo(left.activityAt);
    if (activityOrder != 0) return activityOrder;
    return left.materialId.value.compareTo(right.materialId.value);
  }

  static int _priority(DailyStudyActionKind kind) => switch (kind) {
    DailyStudyActionKind.scheduledReview => 600,
    DailyStudyActionKind.sourceRepair => 550,
    DailyStudyActionKind.retryRecall => 540,
    DailyStudyActionKind.resumeReader => 430,
    DailyStudyActionKind.resumeListen => 420,
    DailyStudyActionKind.beginRecall => 300,
    DailyStudyActionKind.workspaceRecovery => 100,
  };

  static DateTime _activityAt(ProgressItem item) {
    var latest = item.material.updatedAt;
    final learningAt = item.continuation?.state.updatedAt;
    if (learningAt != null && learningAt.isAfter(latest)) latest = learningAt;
    final listenAt = item.listenActivityAt;
    if (listenAt != null && listenAt.isAfter(latest)) latest = listenAt;
    final readerAt = item.readerActivityAt;
    if (readerAt != null && readerAt.isAfter(latest)) latest = readerAt;
    final retentionAt = item.retention?.latestReviewedAt;
    if (retentionAt != null && retentionAt.isAfter(latest)) latest = retentionAt;
    return latest;
  }

  static String _retentionReason(RetentionScheduleRecord item) {
    return switch (item.latestOutcomeBand) {
      RetentionOutcomeBand.independentRetrieval =>
        'Planlanan tekrar zamanı geldi. Yeni aktif deneme kalıcılığı yeniden ölçer; bu bir ustalık puanı değildir.',
      RetentionOutcomeBand.supportedRetrieval =>
        'Önceki aktif çalışma destekliydi. Şimdi aynı kaynak noktasını yeniden aktif biçimde yokla.',
      RetentionOutcomeBand.repairNeeded =>
        'Önceki aktif deneme onarım gerektirdi. Kısa aralıklı tekrar şimdi yeniden hazır.',
      RetentionOutcomeBand.unassessed =>
        'Önceki çalışma olumlu kalıcılık kanıtı üretmedi. Yeni aktif deneme durumu yeniden ölçecek.',
    };
  }
}
