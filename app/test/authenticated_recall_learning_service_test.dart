import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/continuity/cloud_continuity_gateway.dart';
import 'package:sesli_ogren/src/continuity/cloud_continuity_service.dart';
import 'package:sesli_ogren/src/continuity/retention_continuity_gateway.dart';
import 'package:sesli_ogren/src/continuity/retention_continuity_service.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/domain/authenticated_learner.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sesli_ogren/src/domain/learning_truth.dart';
import 'package:sesli_ogren/src/domain/retention_schedule.dart';
import 'package:sesli_ogren/src/domain/quiz_learning.dart';
import 'package:sesli_ogren/src/learning/authenticated_recall_learning_service.dart';
import 'package:sesli_ogren/src/learning/quiz_learning_service.dart';
import 'package:sesli_ogren/src/learning/server_recall_gateway.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _UnusedPdfExtractor implements PdfTextExtractor {
  const _UnusedPdfExtractor();

  @override
  Future<ExtractedPdf> extract(Uint8List bytes, {required String sourceName}) {
    throw UnimplementedError();
  }
}

class _InSyncGateway implements CloudContinuityGateway {
  @override
  Future<List<CloudMaterialSnapshot>> listMaterials({required AuthenticatedLearner learner}) async => const [];

  @override
  Future<CloudMaterialSnapshot?> readMaterial({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  }) async => null;

  @override
  Future<CloudMaterialSnapshot> ensureTextSource({
    required AuthenticatedLearner learner,
    required SourceIngestResult source,
    SourceVersionId? expectedPreviousSourceVersionId,
  }) async {
    return CloudMaterialSnapshot(
      serverMaterialId: 'server-${source.material.id.value}',
      materialId: source.material.id,
      title: source.material.title,
      serverSourceAssetId: 'server-source',
      sourceVersionId: source.sourceVersion.identity.sourceVersionId,
      serverSourceVersion: 1,
      sourceContentHash: source.sourceVersion.identity.contentDigest,
      mediaType: source.sourceVersion.mediaType,
      sourceName: source.sourceVersion.sourceName,
      mimeType: source.sourceVersion.mimeType,
      byteSize: source.sourceVersion.byteSize,
      storageBucket: null,
      storagePath: null,
      inlineText: source.sourceVersion.inlineText,
      serverExtractedContentId: 'server-extracted',
      normalizedText: source.extractedContent.normalizedText,
      extractionMethod: source.extractedContent.method,
      extractionMethodVersion: source.extractedContent.methodVersion,
      anchors: source.extractedContent.anchors,
      warnings: source.extractedContent.warnings,
      materialUpdatedAt: source.material.updatedAt,
      sourceCreatedAt: source.sourceVersion.createdAt,
    );
  }

  @override
  Future<CloudMaterialSnapshot> ensureMediaSource({
    required AuthenticatedLearner learner,
    required SourceIngestResult source,
    required Uint8List rawSourceBytes,
    SourceVersionId? expectedPreviousSourceVersionId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Uint8List> downloadMediaSource({
    required AuthenticatedLearner learner,
    required CloudMaterialSnapshot source,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> cleanupSupersededMedia({required AuthenticatedLearner learner, required MaterialId materialId}) async {}
}

class _FakeServerRecallGateway implements ServerRecallGateway {
  _FakeServerRecallGateway({required this.materialId, required this.sourceVersionId, required this.sourceText});

  final MaterialId materialId;
  final SourceVersionId sourceVersionId;
  final String sourceText;
  final actionId = const RecallActionId('11111111-1111-4111-8111-111111111111');
  RecallAssistance assistance = RecallAssistance.none;
  ServerRecallProjection? latestProjection;
  List<RetentionScheduleRecord>? retentionProjection;
  Future<void> Function()? beforeSubmit;

  @override
  Future<ServerRecallAction> createAction({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    SourceAnchor? anchor,
  }) async {
    final bounded = anchor ?? SourceAnchor(startOffset: 0, endOffset: sourceText.length);
    return ServerRecallAction(
      id: actionId,
      materialId: this.materialId,
      sourceVersionId: sourceVersionId,
      promptText: 'Fotosentez _____ enerjisini kimyasal enerjiye dönüştürür.',
      anchor: bounded,
      ruleVersion: 'recall-cloze-v1',
    );
  }

  @override
  Future<RecallAssistance> openAttempt({
    required AuthenticatedLearner learner,
    required RecallActionId actionId,
    required RecallAttemptId attemptId,
  }) async => assistance;

  @override
  Future<String> requestHint({
    required AuthenticatedLearner learner,
    required RecallActionId actionId,
    required RecallAttemptId attemptId,
  }) async {
    assistance = RecallAssistance.hint;
    return 'ı · 4';
  }

  @override
  Future<String> revealAnswer({
    required AuthenticatedLearner learner,
    required RecallActionId actionId,
    required RecallAttemptId attemptId,
  }) async {
    assistance = RecallAssistance.answerExposed;
    return 'ışık';
  }

  @override
  Future<ServerRecallSubmission> submit({
    required AuthenticatedLearner learner,
    required RecallActionId actionId,
    required RecallAttemptId attemptId,
    required RecallResponseDisposition disposition,
    required String answer,
  }) async {
    final hook = beforeSubmit;
    if (hook != null) await hook();
    final normalized = disposition == RecallResponseDisposition.unknown
        ? ''
        : RecallTruthPolicy.normalizeAnswer(answer);
    final outcome = disposition == RecallResponseDisposition.unknown
        ? RecallOutcome.unknown
        : assistance == RecallAssistance.answerExposed
        ? RecallOutcome.answerExposed
        : normalized == 'ışık'
        ? assistance == RecallAssistance.hint
              ? RecallOutcome.helpedCorrect
              : RecallOutcome.correct
        : RecallOutcome.incorrect;
    final created = DateTime.utc(2026, 10, 14, 1);
    final evidenceId = const LearnerEvidenceId('22222222-2222-4222-8222-222222222222');
    return ServerRecallSubmission(
      evidenceId: evidenceId,
      outcome: outcome,
      stateKind: RecallTruthPolicy.stateForOutcome(outcome),
      evidenceCount: 1,
      nextReasonCode: RecallTruthPolicy.nextActionFor(
        materialId: materialId,
        sourceVersionId: sourceVersionId,
        evidenceId: evidenceId,
        outcome: outcome,
        createdAt: created,
      ).reasonCode,
      assistance: assistance,
      responseDigest: sha256.convert(utf8.encode(normalized)).toString(),
      responseLength: normalized.length,
      evidenceRuleVersion: RecallTruthPolicy.evidenceRuleVersion,
      evidenceCreatedAt: created,
      normalizedResponse: normalized,
      correctAnswer: 'ışık',
      sourceExcerpt: sourceText,
      materialId: materialId,
      sourceVersionId: sourceVersionId,
      promptText: 'Fotosentez _____ enerjisini kimyasal enerjiye dönüştürür.',
      anchor: SourceAnchor(startOffset: 0, endOffset: sourceText.length),
    );
  }

  @override
  Future<ServerRecallProjection?> readLatest({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  }) async => latestProjection;

  @override
  Future<List<RetentionScheduleRecord>> readRetention({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  }) async {
    final override = retentionProjection;
    if (override != null) return override;
    final outcomeBand = switch (assistance) {
      RecallAssistance.none => RetentionOutcomeBand.independentRetrieval,
      RecallAssistance.hint => RetentionOutcomeBand.supportedRetrieval,
      RecallAssistance.answerExposed => RetentionOutcomeBand.unassessed,
    };
    final anchor = SourceAnchor(startOffset: 0, endOffset: sourceText.length);
    final interval = switch (outcomeBand) {
      RetentionOutcomeBand.independentRetrieval => const Duration(days: 1),
      RetentionOutcomeBand.supportedRetrieval => const Duration(hours: 12),
      RetentionOutcomeBand.repairNeeded => const Duration(minutes: 10),
      RetentionOutcomeBand.unassessed => Duration.zero,
    };
    final reviewedAt = DateTime.utc(2026, 10, 14, 1);
    return [
      RetentionScheduleRecord(
        id: RetentionPolicy.scheduleIdFor(sourceVersionId, anchor),
        materialId: this.materialId,
        sourceVersionId: sourceVersionId,
        sourceAnchor: anchor,
        latestEvidenceKind: RetentionEvidenceKind.recall,
        latestOutcomeBand: outcomeBand,
        latestEventId: 'server-recall:22222222-2222-4222-8222-222222222222',
        reasonCode: switch (outcomeBand) {
          RetentionOutcomeBand.independentRetrieval => 'INDEPENDENT_RETRIEVAL_OBSERVED',
          RetentionOutcomeBand.supportedRetrieval => 'SUPPORTED_OR_PARTIAL_RETRIEVAL',
          RetentionOutcomeBand.repairNeeded => 'RETRIEVAL_REPAIR_NEEDED',
          RetentionOutcomeBand.unassessed => 'NO_POSITIVE_RETENTION_EVIDENCE',
        },
        reviewCount: 1,
        successStreak: outcomeBand == RetentionOutcomeBand.independentRetrieval ? 1 : 0,
        interval: interval,
        dueAt: reviewedAt.add(interval),
        lastReviewedAt: reviewedAt,
        policyVersion: RetentionPolicy.version,
      ),
    ];
  }
}

class _TrackingRetentionGateway implements RetentionContinuityGateway {
  final List<CloudRetentionSnapshot> remote = <CloudRetentionSnapshot>[];
  int writes = 0;

  @override
  Future<List<CloudRetentionSnapshot>> readMaterial({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  }) async => remote.where((item) => item.schedule.materialId == materialId).toList(growable: false);

  @override
  Future<CloudRetentionSnapshot> writeSchedule({
    required AuthenticatedLearner learner,
    required RetentionScheduleRecord schedule,
    required int? expectedRevision,
  }) async {
    writes += 1;
    final existingIndex = remote.indexWhere((item) => item.schedule.id == schedule.id);
    final current = existingIndex < 0 ? null : remote[existingIndex];
    if ((current == null && expectedRevision != null) || (current != null && current.revision != expectedRevision)) {
      throw const RetentionContinuityException(
        'retention revision conflict',
        kind: RetentionContinuityFailureKind.conflict,
      );
    }
    final saved = CloudRetentionSnapshot(schedule: schedule, revision: (current?.revision ?? 0) + 1);
    if (existingIndex < 0) {
      remote.add(saved);
    } else {
      remote[existingIndex] = saved;
    }
    return saved;
  }
}

void main() {
  sqfliteFfiInit();

  test('authenticated Recall caches only server-verified evidence and reopens it locally', () async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    const learner = AuthenticatedLearner(id: LearnerId('server-recall-learner'));
    const materialId = MaterialId('material_server_recall_0001');
    const text = 'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür.';

    final ingest = SourceIngestService(
      store: store,
      pdfTextExtractor: const _UnusedPdfExtractor(),
      now: () => DateTime.utc(2026, 10, 14),
    );
    final source = await ingest.ingestPastedText(
      learner: learner,
      materialId: materialId,
      text: text,
      sourceName: 'Biyoloji',
    );
    final cloud = CloudContinuityService(store: store, ingest: ingest, gateway: _InSyncGateway());
    final remote = _FakeServerRecallGateway(
      materialId: materialId,
      sourceVersionId: source.sourceVersion.identity.sourceVersionId,
      sourceText: source.extractedContent.normalizedText,
    );
    final service = AuthenticatedRecallLearningService(
      store: store,
      continuity: cloud,
      gateway: remote,
      clock: () => DateTime.utc(2026, 10, 14, 0, 30),
    );

    final prompt = await service.createCurrentPrompt(learner: learner, materialId: materialId);
    final session = await service.openAttempt(learner: learner, actionId: prompt.id);
    final result = await service.submit(
      learner: learner,
      actionId: prompt.id,
      attemptId: session.attempt.attemptId,
      disposition: RecallResponseDisposition.answer,
      answer: 'ışık',
    );

    expect(result.evidence.outcome, RecallOutcome.correct);
    expect(result.evidence.assistance, RecallAssistance.none);
    expect(result.state.kind, RecallStateKind.retrievedOnce);
    expect(result.correctAnswer, 'ışık');
    expect(result.sourceExcerpt, text);

    final reopened = await service.reopen(learner: learner, materialId: materialId);
    expect(reopened, isNotNull);
    expect(reopened!.state.latestEvidenceId, result.evidence.id);
    expect(reopened.state.evidenceCount, 1);
    expect(reopened.nextAction.reasonCode, 'ONE_UNASSISTED_RETRIEVAL_OBSERVED');

    final retention = await store.retentionSchedulesForMaterial(learner: learner, materialId: materialId);
    expect(retention, hasLength(1));
    expect(retention.single.latestEventId, 'server-recall:${result.evidence.id.value}');
  });

  test('second device hydrates canonical Recall projection and server retention without raw answer history', () async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    const learner = AuthenticatedLearner(id: LearnerId('server-recall-second-device'));
    const materialId = MaterialId('material_server_recall_second_device');
    const text = 'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür.';

    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    final source = await ingest.ingestPastedText(
      learner: learner,
      materialId: materialId,
      text: text,
      sourceName: 'Biyoloji',
    );
    final sourceId = source.sourceVersion.identity.sourceVersionId;
    final cloud = CloudContinuityService(store: store, ingest: ingest, gateway: _InSyncGateway());
    final remote = _FakeServerRecallGateway(
      materialId: materialId,
      sourceVersionId: sourceId,
      sourceText: source.extractedContent.normalizedText,
    );
    final evidenceAt = DateTime.utc(2026, 10, 14, 6);
    const evidenceId = LearnerEvidenceId('33333333-3333-4333-8333-333333333333');
    remote.latestProjection = ServerRecallProjection(
      actionId: remote.actionId,
      attemptId: const RecallAttemptId('attempt-second-device-0001'),
      evidenceId: evidenceId,
      outcome: RecallOutcome.correct,
      stateKind: RecallStateKind.retrievedOnce,
      evidenceCount: 4,
      nextReasonCode: 'ONE_UNASSISTED_RETRIEVAL_OBSERVED',
      assistance: RecallAssistance.none,
      responseDigest: sha256.convert(utf8.encode('ışık')).toString(),
      responseLength: 4,
      evidenceRuleVersion: RecallTruthPolicy.evidenceRuleVersion,
      evidenceCreatedAt: evidenceAt,
      correctAnswer: 'ışık',
      sourceExcerpt: text,
      materialId: materialId,
      sourceVersionId: sourceId,
      promptText: 'Fotosentez _____ enerjisini kimyasal enerjiye dönüştürür.',
      anchor: SourceAnchor(startOffset: 0, endOffset: text.length),
    );
    final reviewedAt = DateTime.utc(2026, 10, 14, 6);
    remote.retentionProjection = [
      RetentionScheduleRecord(
        id: RetentionPolicy.scheduleIdFor(sourceId, SourceAnchor(startOffset: 0, endOffset: text.length)),
        materialId: materialId,
        sourceVersionId: sourceId,
        sourceAnchor: SourceAnchor(startOffset: 0, endOffset: text.length),
        latestEvidenceKind: RetentionEvidenceKind.recall,
        latestOutcomeBand: RetentionOutcomeBand.independentRetrieval,
        latestEventId: 'server-recall:${evidenceId.value}',
        reasonCode: 'INDEPENDENT_RETRIEVAL_OBSERVED',
        reviewCount: 4,
        successStreak: 3,
        interval: const Duration(days: 7),
        dueAt: reviewedAt.add(const Duration(days: 7)),
        lastReviewedAt: reviewedAt,
        policyVersion: RetentionPolicy.version,
      ),
    ];

    final service = AuthenticatedRecallLearningService(store: store, continuity: cloud, gateway: remote);
    expect(await service.syncLatestContinuity(learner: learner), 0);

    final reopened = await service.reopen(learner: learner, materialId: materialId);
    expect(reopened, isNotNull);
    expect(reopened!.state.latestEvidenceId, evidenceId);
    expect(reopened.state.evidenceCount, 4);
    expect(reopened.state.kind, RecallStateKind.retrievedOnce);
    expect(reopened.nextAction.reasonCode, 'ONE_UNASSISTED_RETRIEVAL_OBSERVED');

    final retention = await store.retentionSchedulesForMaterial(learner: learner, materialId: materialId);
    expect(retention, hasLength(1));
    expect(retention.single.reviewCount, 4);
    expect(retention.single.successStreak, 3);
    expect(retention.single.interval, const Duration(days: 7));
    expect(retention.single.latestEventId, 'server-recall:${evidenceId.value}');
  });

  test('server hint assistance is authoritative in the cached Recall result', () async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    const learner = AuthenticatedLearner(id: LearnerId('server-recall-hint-learner'));
    const materialId = MaterialId('material_server_recall_hint_1');
    const text = 'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür.';

    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    final source = await ingest.ingestPastedText(
      learner: learner,
      materialId: materialId,
      text: text,
      sourceName: 'Biyoloji',
    );
    final cloud = CloudContinuityService(store: store, ingest: ingest, gateway: _InSyncGateway());
    final remote = _FakeServerRecallGateway(
      materialId: materialId,
      sourceVersionId: source.sourceVersion.identity.sourceVersionId,
      sourceText: source.extractedContent.normalizedText,
    );
    final service = AuthenticatedRecallLearningService(store: store, continuity: cloud, gateway: remote);

    final prompt = await service.createCurrentPrompt(learner: learner, materialId: materialId);
    final session = await service.openAttempt(learner: learner, actionId: prompt.id);
    await service.requestHint(learner: learner, actionId: prompt.id, attemptId: session.attempt.attemptId);
    final result = await service.submit(
      learner: learner,
      actionId: prompt.id,
      attemptId: session.attempt.attemptId,
      disposition: RecallResponseDisposition.answer,
      answer: 'ışık',
    );

    expect(result.evidence.assistance, RecallAssistance.hint);
    expect(result.evidence.outcome, RecallOutcome.helpedCorrect);
    expect(result.state.kind, RecallStateKind.developing);
    expect(result.nextAction.reasonCode, 'HINTED_SUCCESS_NEEDS_UNASSISTED_RETRIEVAL');
  });

  test('authenticated Recall pushes pending Quiz retention before server evidence submit', () async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    const learner = AuthenticatedLearner(id: LearnerId('recall-retention-order'));
    const materialId = MaterialId('material_recall_retention_order');
    const text =
        'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür. '
        'Klorofil ışığın soğurulmasına yardım eder. '
        'Stomalar gaz alışverişini düzenler. '
        'Karbondioksit organik madde üretiminde kullanılır.';

    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    final source = await ingest.ingestPastedText(
      learner: learner,
      materialId: materialId,
      text: text,
      sourceName: 'Biyoloji',
    );
    final quiz = QuizLearningService(store: store, clock: () => DateTime.utc(2026, 10, 14, 8));
    final quizState = await quiz.openCurrentSet(learner: learner, materialId: materialId);
    final question = quizState.currentQuestion!;
    await quiz.recordAnswer(
      learner: learner,
      materialId: materialId,
      setId: quizState.set.id,
      questionId: question.id,
      kind: QuizAnswerKind.selected,
      selectedOptionIndex: question.correctOptionIndex,
    );

    final retentionGateway = _TrackingRetentionGateway();
    final retention = RetentionContinuityService(store: store, gateway: retentionGateway);
    final cloud = CloudContinuityService(store: store, ingest: ingest, gateway: _InSyncGateway());
    final remote = _FakeServerRecallGateway(
      materialId: materialId,
      sourceVersionId: source.sourceVersion.identity.sourceVersionId,
      sourceText: source.extractedContent.normalizedText,
    );
    remote.beforeSubmit = () async {
      if (retentionGateway.writes != 1) {
        throw StateError('server Recall submitted before pending Quiz retention was reconciled');
      }
    };
    final service = AuthenticatedRecallLearningService(
      store: store,
      continuity: cloud,
      gateway: remote,
      retentionContinuity: retention,
      clock: () => DateTime.utc(2026, 10, 14, 9),
    );

    final prompt = await service.createCurrentPrompt(learner: learner, materialId: materialId);
    final session = await service.openAttempt(learner: learner, actionId: prompt.id);
    final result = await service.submit(
      learner: learner,
      actionId: prompt.id,
      attemptId: session.attempt.attemptId,
      disposition: RecallResponseDisposition.answer,
      answer: 'ışık',
    );

    expect(retentionGateway.writes, 1);
    expect(result.evidence.outcome, RecallOutcome.correct);
  });
}
