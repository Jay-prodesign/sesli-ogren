import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/continuity/retention_continuity_gateway.dart';
import 'package:sesli_ogren/src/continuity/retention_continuity_service.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/domain/authenticated_learner.dart';
import 'package:sesli_ogren/src/domain/flashcard_learning.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sesli_ogren/src/domain/retention_schedule.dart';
import 'package:sesli_ogren/src/learning/flashcard_learning_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _UnusedPdfExtractor implements PdfTextExtractor {
  const _UnusedPdfExtractor();

  @override
  Future<ExtractedPdf> extract(Uint8List bytes, {required String sourceName}) {
    throw UnimplementedError();
  }
}

class _FakeRetentionGateway implements RetentionContinuityGateway {
  final Map<RetentionScheduleId, CloudRetentionSnapshot> remote = {};
  int reads = 0;
  int writes = 0;

  @override
  Future<List<CloudRetentionSnapshot>> readMaterial({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  }) async {
    reads += 1;
    return remote.values
        .where((item) => item.schedule.materialId == materialId)
        .toList(growable: false);
  }

  @override
  Future<CloudRetentionSnapshot> writeSchedule({
    required AuthenticatedLearner learner,
    required RetentionScheduleRecord schedule,
    required int? expectedRevision,
  }) async {
    writes += 1;
    if (schedule.latestEvidenceKind == RetentionEvidenceKind.recall) {
      throw const RetentionContinuityException(
        'client_recall_forbidden',
        kind: RetentionContinuityFailureKind.conflict,
      );
    }

    final current = remote[schedule.id];
    if (current != null && current.schedule.latestEventId == schedule.latestEventId) {
      return current;
    }
    if (current == null) {
      if (expectedRevision != null) {
        throw const RetentionContinuityException(
          'retention_revision_conflict',
          kind: RetentionContinuityFailureKind.conflict,
        );
      }
    } else if (current.revision != expectedRevision) {
      throw const RetentionContinuityException(
        'retention_revision_conflict',
        kind: RetentionContinuityFailureKind.conflict,
      );
    }

    final next = CloudRetentionSnapshot(
      schedule: schedule,
      revision: (current?.revision ?? 0) + 1,
    );
    remote[schedule.id] = next;
    return next;
  }
}

Future<(SqliteSourceStore, SourceIngestResult)> _source({
  required AuthenticatedLearner learner,
  required MaterialId materialId,
}) async {
  final store = await SqliteSourceStore.open(
    factory: databaseFactoryFfiNoIsolate,
    path: inMemoryDatabasePath,
  );
  final ingest = SourceIngestService(
    store: store,
    pdfTextExtractor: const _UnusedPdfExtractor(),
    now: () => DateTime.utc(2026, 10, 14),
  );
  final source = await ingest.ingestPastedText(
    learner: learner,
    materialId: materialId,
    sourceName: 'Biyoloji',
    text:
        'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür. '
        'Klorofil ışığın soğurulmasına yardım eder. '
        'Karbondioksit süreçte önemli bir girdidir.',
  );
  return (store, source);
}

void main() {
  sqfliteFfiInit();

  test('two devices converge Flashcard retention through a shared revision checkpoint', () async {
    const learner = AuthenticatedLearner(id: LearnerId('retention-sync-learner'));
    const materialId = MaterialId('material_retention_sync_0001');
    final (storeA, sourceA) = await _source(learner: learner, materialId: materialId);
    final (storeB, sourceB) = await _source(learner: learner, materialId: materialId);
    addTearDown(storeA.close);
    addTearDown(storeB.close);
    expect(sourceA.sourceVersion.identity.sourceVersionId, sourceB.sourceVersion.identity.sourceVersionId);

    final gateway = _FakeRetentionGateway();
    final syncA = RetentionContinuityService(store: storeA, gateway: gateway);
    final syncB = RetentionContinuityService(store: storeB, gateway: gateway);
    var nowA = DateTime.utc(2026, 10, 14, 8);
    var nowB = DateTime.utc(2026, 10, 15, 8);
    final flashA = FlashcardLearningService(store: storeA, now: () => nowA);
    final flashB = FlashcardLearningService(store: storeB, now: () => nowB);

    final firstA = await flashA.openCurrentSet(learner: learner, materialId: materialId);
    await flashA.recordResponse(
      learner: learner,
      materialId: materialId,
      setId: firstA.set.id,
      cardId: firstA.currentCard!.id,
      response: FlashcardResponse.remembered,
      answerWasRevealed: true,
    );

    var resultA = await syncA.syncMaterial(learner: learner, materialId: materialId);
    expect(resultA.single.disposition, RetentionContinuityDisposition.pushedLocal);
    expect(gateway.remote.values.single.revision, 1);

    var resultB = await syncB.syncMaterial(learner: learner, materialId: materialId);
    expect(resultB.single.disposition, RetentionContinuityDisposition.pulledRemote);
    var stateB = await storeB.retentionSyncStatesForMaterial(
      learner: learner,
      materialId: materialId,
      sourceVersionId: sourceB.sourceVersion.identity.sourceVersionId,
    );
    expect(stateB.single.schedule.reviewCount, 1);
    expect(stateB.single.serverRevision, 1);
    expect(stateB.single.hasLocalChangeSinceSync, isFalse);

    final firstB = await flashB.openCurrentSet(learner: learner, materialId: materialId);
    await flashB.recordResponse(
      learner: learner,
      materialId: materialId,
      setId: firstB.set.id,
      cardId: firstB.currentCard!.id,
      response: FlashcardResponse.remembered,
      answerWasRevealed: true,
    );
    stateB = await storeB.retentionSyncStatesForMaterial(
      learner: learner,
      materialId: materialId,
      sourceVersionId: sourceB.sourceVersion.identity.sourceVersionId,
    );
    expect(stateB.single.schedule.reviewCount, 2);
    expect(stateB.single.schedule.latestEventId, isNot(gateway.remote.values.single.schedule.latestEventId));
    expect(stateB.single.hasLocalChangeSinceSync, isTrue);

    resultB = await syncB.syncMaterial(learner: learner, materialId: materialId);
    expect(resultB.single.disposition, RetentionContinuityDisposition.pushedLocal);
    expect(gateway.remote.values.single.revision, 2);

    resultA = await syncA.syncMaterial(learner: learner, materialId: materialId);
    expect(resultA.single.disposition, RetentionContinuityDisposition.pulledRemote);
    final stateA = await storeA.retentionSyncStatesForMaterial(
      learner: learner,
      materialId: materialId,
      sourceVersionId: sourceA.sourceVersion.identity.sourceVersionId,
    );
    expect(stateA.single.schedule.reviewCount, 2);
    expect(stateA.single.serverRevision, 2);
    expect(stateA.single.hasLocalChangeSinceSync, isFalse);

    // Keep clocks live so an accidental same-device event-id regression is
    // caught by the distinct durable event assertion above.
    nowA = nowA.add(const Duration(hours: 1));
    nowB = nowB.add(const Duration(hours: 1));
  });

  test('concurrent retention edits fail closed instead of overwriting another device', () async {
    const learner = AuthenticatedLearner(id: LearnerId('retention-conflict-learner'));
    const materialId = MaterialId('material_retention_conflict_01');
    final (storeA, sourceA) = await _source(learner: learner, materialId: materialId);
    final (storeB, sourceB) = await _source(learner: learner, materialId: materialId);
    addTearDown(storeA.close);
    addTearDown(storeB.close);

    final gateway = _FakeRetentionGateway();
    final syncA = RetentionContinuityService(store: storeA, gateway: gateway);
    final syncB = RetentionContinuityService(store: storeB, gateway: gateway);
    var nowA = DateTime.utc(2026, 10, 14, 8);
    var nowB = DateTime.utc(2026, 10, 14, 8);
    final flashA = FlashcardLearningService(store: storeA, now: () => nowA);
    final flashB = FlashcardLearningService(store: storeB, now: () => nowB);

    final initialA = await flashA.openCurrentSet(learner: learner, materialId: materialId);
    await flashA.recordResponse(
      learner: learner,
      materialId: materialId,
      setId: initialA.set.id,
      cardId: initialA.currentCard!.id,
      response: FlashcardResponse.remembered,
      answerWasRevealed: true,
    );
    await syncA.syncMaterial(learner: learner, materialId: materialId);
    await syncB.syncMaterial(learner: learner, materialId: materialId);

    nowA = DateTime.utc(2026, 10, 14, 9);
    final restartedA = await flashA.restartSession(learner: learner, materialId: materialId);
    await flashA.recordResponse(
      learner: learner,
      materialId: materialId,
      setId: restartedA.set.id,
      cardId: restartedA.currentCard!.id,
      response: FlashcardResponse.again,
      answerWasRevealed: true,
    );
    await syncA.syncMaterial(learner: learner, materialId: materialId);
    expect(gateway.remote.values.single.revision, 2);

    nowB = DateTime.utc(2026, 10, 14, 9, 30);
    final initialB = await flashB.openCurrentSet(learner: learner, materialId: materialId);
    await flashB.recordResponse(
      learner: learner,
      materialId: materialId,
      setId: initialB.set.id,
      cardId: initialB.currentCard!.id,
      response: FlashcardResponse.remembered,
      answerWasRevealed: true,
    );
    final before = await storeB.retentionSyncStatesForMaterial(
      learner: learner,
      materialId: materialId,
      sourceVersionId: sourceB.sourceVersion.identity.sourceVersionId,
    );
    expect(before.single.serverRevision, 1);
    expect(before.single.hasLocalChangeSinceSync, isTrue);

    final conflict = await syncB.syncMaterial(learner: learner, materialId: materialId);
    expect(conflict.single.disposition, RetentionContinuityDisposition.conflict);

    final after = await storeB.retentionSyncStatesForMaterial(
      learner: learner,
      materialId: materialId,
      sourceVersionId: sourceB.sourceVersion.identity.sourceVersionId,
    );
    expect(after.single.schedule.latestEventId, before.single.schedule.latestEventId);
    expect(after.single.serverRevision, 1);
    expect(after.single.hasLocalChangeSinceSync, isTrue);
    expect(gateway.remote.values.single.revision, 2);
    expect(
      gateway.remote.values.single.schedule.latestEventId,
      isNot(after.single.schedule.latestEventId),
    );
    expect(sourceA.sourceVersion.identity.sourceVersionId, sourceB.sourceVersion.identity.sourceVersionId);
  });

  test('guest retention sync never calls the cloud gateway', () async {
    final store = await SqliteSourceStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    addTearDown(store.close);
    final gateway = _FakeRetentionGateway();
    final service = RetentionContinuityService(store: store, gateway: gateway);

    final summary = await service.syncAll(learner: const AuthenticatedLearner.local());

    expect(summary.results, isEmpty);
    expect(gateway.reads, 0);
    expect(gateway.writes, 0);
  });
}
