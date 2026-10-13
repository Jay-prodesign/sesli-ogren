import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/daily_study_plan.dart';
import 'package:sesli_ogren/src/app/progress_surface.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sesli_ogren/src/domain/learning_truth.dart';
import 'package:sesli_ogren/src/domain/retention_schedule.dart';

void main() {
  final now = DateTime.utc(2026, 10, 13, 8);

  MaterialRecord material(String id, {DateTime? updatedAt}) => MaterialRecord(
    id: MaterialId(id),
    title: 'Material $id',
    mediaType: SourceMediaType.pastedText,
    lifecycleStatus: MaterialLifecycleStatus.active,
    processingState: MaterialProcessingState.ready,
    createdAt: now.subtract(const Duration(days: 2)),
    updatedAt: updatedAt ?? now.subtract(const Duration(hours: 2)),
  );

  LearningContinuation continuation(
    String id,
    NextLearningActionKind kind, {
    RecallStateKind stateKind = RecallStateKind.needsReview,
  }) {
    final materialId = MaterialId(id);
    final sourceVersionId = SourceVersionId('source-$id');
    final evidenceId = LearnerEvidenceId('evidence-$id');
    return LearningContinuation(
      state: LearnerState(
        materialId: materialId,
        sourceVersionId: sourceVersionId,
        kind: stateKind,
        evidenceCount: 1,
        latestEvidenceId: evidenceId,
        ruleVersion: RecallTruthPolicy.stateRuleVersion,
        updatedAt: now,
      ),
      nextAction: NextLearningAction(
        materialId: materialId,
        sourceVersionId: sourceVersionId,
        latestEvidenceId: evidenceId,
        kind: kind,
        reasonCode: 'reason-$id',
        reasonText: 'Reason for $id',
        policyVersion: RecallTruthPolicy.nextActionPolicyVersion,
        createdAt: now,
      ),
    );
  }

  RetentionMaterialStatus retention(String id, DateTime dueAt) => RetentionMaterialStatus(
    evaluatedAt: now,
    schedules: [
      RetentionScheduleRecord(
        id: RetentionScheduleId('retention-$id'),
        materialId: MaterialId(id),
        sourceVersionId: SourceVersionId('source-$id'),
        sourceAnchor: const SourceAnchor(startOffset: 0, endOffset: 40),
        latestEvidenceKind: RetentionEvidenceKind.quiz,
        latestOutcomeBand: RetentionOutcomeBand.independentRetrieval,
        latestEventId: 'quiz-$id',
        reasonCode: 'INDEPENDENT_RETRIEVAL_OBSERVED',
        reviewCount: 1,
        successStreak: 1,
        interval: const Duration(days: 1),
        dueAt: dueAt,
        lastReviewedAt: dueAt.subtract(const Duration(days: 1)),
        policyVersion: RetentionPolicy.version,
      ),
    ],
  );

  test('Daily Study orders urgent repair/retry before due review and excludes future repeat-later work', () {
    final due = ProgressItem(
      material: material('due'),
      sourceVersionId: const SourceVersionId('source-due'),
      continuation: continuation(
        'due',
        NextLearningActionKind.repeatRecallLater,
        stateKind: RecallStateKind.retrievedOnce,
      ),
      retention: retention('due', now.subtract(const Duration(minutes: 20))),
    );
    final repair = ProgressItem(
      material: material('repair'),
      sourceVersionId: const SourceVersionId('source-repair'),
      continuation: continuation('repair', NextLearningActionKind.reviewSourceThenRecall),
    );
    final retry = ProgressItem(
      material: material('retry'),
      sourceVersionId: const SourceVersionId('source-retry'),
      continuation: continuation('retry', NextLearningActionKind.retryRecallWithoutHint),
    );
    final reader = ProgressItem(
      material: material('reader'),
      sourceVersionId: const SourceVersionId('source-reader'),
      continuation: null,
      readerResumeProgress: 0.42,
      readerActivityAt: now.subtract(const Duration(minutes: 5)),
    );
    final fresh = ProgressItem(
      material: material('fresh'),
      sourceVersionId: const SourceVersionId('source-fresh'),
      continuation: null,
    );
    final future = ProgressItem(
      material: material('future'),
      sourceVersionId: const SourceVersionId('source-future'),
      continuation: continuation(
        'future',
        NextLearningActionKind.repeatRecallLater,
        stateKind: RecallStateKind.retrievedOnce,
      ),
      retention: retention('future', now.add(const Duration(days: 2))),
    );

    final plan = DailyStudyPlan.build(progress: [reader, future, fresh, retry, repair, due], evaluatedAt: now);

    expect(plan.items.map((item) => item.materialId.value), ['repair', 'retry', 'due', 'reader', 'fresh']);
    expect(plan.primary?.kind, DailyStudyActionKind.sourceRepair);
    expect(plan.items[1].kind, DailyStudyActionKind.retryRecall);
    expect(plan.items[2].kind, DailyStudyActionKind.scheduledReview);
    expect(plan.items[3].kind, DailyStudyActionKind.resumeReader);
    expect(plan.items[4].kind, DailyStudyActionKind.beginRecall);
    expect(plan.nextScheduledAt, now.add(const Duration(days: 2)));
    expect(plan.nextScheduledMaterialId, const MaterialId('future'));
  });

  test('Daily Study gives repair prerequisite authority over a simultaneously due schedule', () {
    final item = ProgressItem(
      material: material('blocked-due'),
      sourceVersionId: const SourceVersionId('source-blocked-due'),
      continuation: continuation('blocked-due', NextLearningActionKind.reviewSourceThenRecall),
      retention: retention('blocked-due', now.subtract(const Duration(minutes: 5))),
    );

    final plan = DailyStudyPlan.build(progress: [item], evaluatedAt: now);

    expect(plan.items, hasLength(1));
    expect(plan.primary?.kind, DailyStudyActionKind.sourceRepair);
    expect(plan.primary?.reasonCode, 'reason-blocked-due');
  });

  test('Daily Study turns a non-ready source into recovery instead of an active-learning claim', () {
    final pendingMaterial = MaterialRecord(
      id: const MaterialId('pending'),
      title: 'Pending source',
      mediaType: SourceMediaType.pastedText,
      lifecycleStatus: MaterialLifecycleStatus.active,
      processingState: MaterialProcessingState.none,
      currentSourceVersionId: const SourceVersionId('source-pending'),
      createdAt: now.subtract(const Duration(days: 1)),
      updatedAt: now,
    );
    final item = ProgressItem(
      material: pendingMaterial,
      sourceVersionId: const SourceVersionId('source-pending'),
      continuation: null,
    );

    final plan = DailyStudyPlan.build(progress: [item], evaluatedAt: now);

    expect(plan.items, hasLength(1));
    expect(plan.primary?.kind, DailyStudyActionKind.workspaceRecovery);
    expect(plan.primary?.reasonCode, 'SOURCE_PROCESSING_NOT_READY');
    expect(plan.primary?.reasonText, contains('çalışma görevi üretmiyoruz'));
  });

  test('Daily Study fails closed when continuation truth belongs to a stale source version', () {
    final item = ProgressItem(
      material: material('stale'),
      sourceVersionId: const SourceVersionId('source-current'),
      continuation: continuation('stale', NextLearningActionKind.retryRecallWithoutHint),
    );

    final plan = DailyStudyPlan.build(progress: [item], evaluatedAt: now);

    expect(plan.items, hasLength(1));
    expect(plan.primary?.kind, DailyStudyActionKind.workspaceRecovery);
    expect(plan.primary?.reasonCode, 'STALE_CONTINUATION_SOURCE');
    expect(plan.primary?.sourceVersionId, const SourceVersionId('source-current'));
  });

  test('Daily Study fails closed when a current source identity is unavailable', () {
    final item = ProgressItem(material: material('no-source'), continuation: null);
    final plan = DailyStudyPlan.build(progress: [item], evaluatedAt: now);
    expect(plan.items, isEmpty);
    expect(plan.nextScheduledAt, isNull);
  });
}
