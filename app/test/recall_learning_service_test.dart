import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/data/learning_truth_store.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/domain/authenticated_learner.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sesli_ogren/src/domain/learning_truth.dart';
import 'package:sesli_ogren/src/learning/recall_learning_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _UnusedPdfExtractor implements PdfTextExtractor {
  const _UnusedPdfExtractor();

  @override
  Future<ExtractedPdf> extract(
    Uint8List bytes, {
    required String sourceName,
  }) {
    throw UnimplementedError();
  }
}

void main() {
  sqfliteFfiInit();

  const learnerA = AuthenticatedLearner(id: LearnerId('learner-a'));
  const learnerB = AuthenticatedLearner(id: LearnerId('learner-b'));
  const materialId = MaterialId('material-recall');

  late SqliteSourceStore sourceStore;
  late SourceIngestService ingest;
  late RecallLearningService recall;

  setUp(() async {
    sourceStore = await SqliteSourceStore.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    ingest = SourceIngestService(
      store: sourceStore,
      pdfTextExtractor: const _UnusedPdfExtractor(),
      now: () => DateTime.utc(2026, 10, 4, 12),
    );
    recall = RecallLearningService(
      sourceStore: sourceStore,
      learningStore: sourceStore.learningTruthStore(),
      now: () => DateTime.utc(2026, 10, 4, 12, 5),
    );
    await ingest.ingestPastedText(
      learner: learnerA,
      materialId: materialId,
      text:
          'Fotosentez sırasında klorofil ışık enerjisini kimyasal enerjiye '
          'dönüştürmeye yardımcı olur. Bitkiler bu süreçte karbondioksit kullanır.',
      sourceName: 'Biyoloji notu',
    );
  });

  tearDown(() => sourceStore.close());

  test('creating Recall action does not create learner evidence or state', () async {
    final action = await recall.createCurrentAction(
      learner: learnerA,
      materialId: materialId,
    );

    expect(action.promptText, contains('_____'));
    expect(action.expectedAnswer, isNotEmpty);
    expect(action.anchor.startOffset, greaterThanOrEqualTo(0));

    final learningStore = sourceStore.learningTruthStore();
    final source = await sourceStore.currentSourceVersion(
      learner: learnerA,
      materialId: materialId,
    );
    expect(
      await learningStore.evidenceForMaterial(
        learner: learnerA,
        materialId: materialId,
        sourceVersionId: source!.identity.sourceVersionId,
      ),
      isEmpty,
    );
    expect(
      await learningStore.learnerState(
        learner: learnerA,
        materialId: materialId,
      ),
      isNull,
    );
  });

  test('unassisted correct Recall creates evidence but never claims mastery', () async {
    final action = await recall.createCurrentAction(
      learner: learnerA,
      materialId: materialId,
    );
    final result = await recall.submit(
      learner: learnerA,
      actionId: action.id,
      attemptId: const RecallAttemptId('attempt-correct'),
      disposition: RecallResponseDisposition.answer,
      answer: action.expectedAnswer,
    );

    expect(result.evidence.outcome, RecallOutcome.correct);
    expect(result.evidence.helpUsed, isFalse);
    expect(result.state.kind, RecallStateKind.retrievedOnce);
    expect(result.state.evidenceCount, 1);
    expect(
      result.nextAction.kind,
      NextLearningActionKind.continueToNextRecall,
    );
    expect(
      result.nextAction.reasonCode,
      'UNASSISTED_RETRIEVAL_CORRECT',
    );
  });

  test('hinted correct Recall remains developing', () async {
    final action = await recall.createCurrentAction(
      learner: learnerA,
      materialId: materialId,
    );
    final result = await recall.submit(
      learner: learnerA,
      actionId: action.id,
      attemptId: const RecallAttemptId('attempt-helped'),
      disposition: RecallResponseDisposition.answer,
      answer: action.expectedAnswer,
      hintUsed: true,
    );

    expect(result.evidence.outcome, RecallOutcome.helpedCorrect);
    expect(result.state.kind, RecallStateKind.developing);
    expect(
      result.nextAction.kind,
      NextLearningActionKind.retryRecallWithoutHint,
    );
  });

  test('near answer is partial rather than silently correct', () async {
    final action = await recall.createCurrentAction(
      learner: learnerA,
      materialId: materialId,
    );
    final answer = action.expectedAnswer;
    final nearAnswer = answer.substring(0, answer.length - 1);

    final result = await recall.submit(
      learner: learnerA,
      actionId: action.id,
      attemptId: const RecallAttemptId('attempt-partial'),
      disposition: RecallResponseDisposition.answer,
      answer: nearAnswer,
    );

    expect(result.evidence.outcome, RecallOutcome.partial);
    expect(result.state.kind, RecallStateKind.developing);
  });

  test('unknown and incorrect remain distinct evidence outcomes', () async {
    final action = await recall.createCurrentAction(
      learner: learnerA,
      materialId: materialId,
    );

    final unknown = await recall.submit(
      learner: learnerA,
      actionId: action.id,
      attemptId: const RecallAttemptId('attempt-unknown'),
      disposition: RecallResponseDisposition.unknown,
    );
    expect(unknown.evidence.outcome, RecallOutcome.unknown);
    expect(unknown.state.kind, RecallStateKind.needsReview);

    final incorrect = await recall.submit(
      learner: learnerA,
      actionId: action.id,
      attemptId: const RecallAttemptId('attempt-incorrect'),
      disposition: RecallResponseDisposition.answer,
      answer: 'tamamenyanlis',
    );
    expect(incorrect.evidence.outcome, RecallOutcome.incorrect);
    expect(incorrect.state.kind, RecallStateKind.needsReview);
    expect(incorrect.state.evidenceCount, 2);
  });

  test('same attempt replay is idempotent', () async {
    final action = await recall.createCurrentAction(
      learner: learnerA,
      materialId: materialId,
    );

    final first = await recall.submit(
      learner: learnerA,
      actionId: action.id,
      attemptId: const RecallAttemptId('attempt-replay'),
      disposition: RecallResponseDisposition.answer,
      answer: action.expectedAnswer,
    );
    final replay = await recall.submit(
      learner: learnerA,
      actionId: action.id,
      attemptId: const RecallAttemptId('attempt-replay'),
      disposition: RecallResponseDisposition.answer,
      answer: action.expectedAnswer,
    );

    expect(replay.evidence.id, first.evidence.id);
    expect(replay.state.evidenceCount, 1);
  });

  test('conflicting replay of same attempt ID fails closed', () async {
    final action = await recall.createCurrentAction(
      learner: learnerA,
      materialId: materialId,
    );

    await recall.submit(
      learner: learnerA,
      actionId: action.id,
      attemptId: const RecallAttemptId('attempt-conflict'),
      disposition: RecallResponseDisposition.answer,
      answer: action.expectedAnswer,
    );

    await expectLater(
      recall.submit(
        learner: learnerA,
        actionId: action.id,
        attemptId: const RecallAttemptId('attempt-conflict'),
        disposition: RecallResponseDisposition.answer,
        answer: 'farkliyanit',
      ),
      throwsA(isA<LearningTruthConflict>()),
    );
  });

  test('another learner cannot read or submit the action', () async {
    final action = await recall.createCurrentAction(
      learner: learnerA,
      materialId: materialId,
    );
    final learningStore = sourceStore.learningTruthStore();

    expect(
      await learningStore.recallAction(
        learner: learnerB,
        actionId: action.id,
      ),
      isNull,
    );
    await expectLater(
      recall.submit(
        learner: learnerB,
        actionId: action.id,
        attemptId: const RecallAttemptId('attempt-other-user'),
        disposition: RecallResponseDisposition.answer,
        answer: action.expectedAnswer,
      ),
      throwsA(isA<RecallLearningException>()),
    );
  });

  test('source supersession makes old Recall action stale and clears state', () async {
    final action = await recall.createCurrentAction(
      learner: learnerA,
      materialId: materialId,
    );
    await recall.submit(
      learner: learnerA,
      actionId: action.id,
      attemptId: const RecallAttemptId('attempt-before-source-change'),
      disposition: RecallResponseDisposition.answer,
      answer: action.expectedAnswer,
    );

    await ingest.ingestPastedText(
      learner: learnerA,
      materialId: materialId,
      text:
          'Yeni kaynak sürümü farklı bir kavram seti içerir ve önceki '
          'öğrenme durumunu güncel kaynak için geçersiz kılar.',
      sourceName: 'Biyoloji notu',
    );

    expect(
      await sourceStore.learningTruthStore().learnerState(
        learner: learnerA,
        materialId: materialId,
      ),
      isNull,
    );
    await expectLater(
      recall.submit(
        learner: learnerA,
        actionId: action.id,
        attemptId: const RecallAttemptId('attempt-stale-action'),
        disposition: RecallResponseDisposition.answer,
        answer: action.expectedAnswer,
      ),
      throwsA(isA<RecallLearningException>()),
    );
  });

  test('material deletion removes active Recall truth', () async {
    final action = await recall.createCurrentAction(
      learner: learnerA,
      materialId: materialId,
    );
    final result = await recall.submit(
      learner: learnerA,
      actionId: action.id,
      attemptId: const RecallAttemptId('attempt-delete'),
      disposition: RecallResponseDisposition.answer,
      answer: action.expectedAnswer,
    );

    await sourceStore.deleteMaterial(
      learner: learnerA,
      materialId: materialId,
      deletedAt: DateTime.utc(2026, 10, 4, 13),
    );

    final learningStore = sourceStore.learningTruthStore();
    expect(
      await learningStore.recallAction(
        learner: learnerA,
        actionId: action.id,
      ),
      isNull,
    );
    expect(
      await learningStore.evidenceForAttempt(
        learner: learnerA,
        attemptId: result.evidence.attemptId,
      ),
      isNull,
    );
    expect(
      await learningStore.learnerState(
        learner: learnerA,
        materialId: materialId,
      ),
      isNull,
    );
  });

  test('evidence and state survive database close and reopen', () async {
    final temp = await Directory.systemTemp.createTemp('sesli-ogren-learning-');
    final databasePath = '${temp.path}/learning.db';
    SqliteSourceStore? persistentStore;

    try {
      persistentStore = await SqliteSourceStore.open(
        factory: databaseFactoryFfi,
        path: databasePath,
      );
      final persistentIngest = SourceIngestService(
        store: persistentStore,
        pdfTextExtractor: const _UnusedPdfExtractor(),
        now: () => DateTime.utc(2026, 10, 4, 14),
      );
      final persistentRecall = RecallLearningService(
        sourceStore: persistentStore,
        learningStore: persistentStore.learningTruthStore(),
        now: () => DateTime.utc(2026, 10, 4, 14, 5),
      );
      await persistentIngest.ingestPastedText(
        learner: learnerA,
        materialId: materialId,
        text:
            'Mitokondri hücresel solunum sırasında kullanılabilir enerji '
            'üretimine katkı sağlar.',
      );
      final action = await persistentRecall.createCurrentAction(
        learner: learnerA,
        materialId: materialId,
      );
      final result = await persistentRecall.submit(
        learner: learnerA,
        actionId: action.id,
        attemptId: const RecallAttemptId('attempt-persist'),
        disposition: RecallResponseDisposition.answer,
        answer: action.expectedAnswer,
      );
      await persistentStore.close();
      persistentStore = null;

      persistentStore = await SqliteSourceStore.open(
        factory: databaseFactoryFfi,
        path: databasePath,
      );
      final learningStore = persistentStore.learningTruthStore();
      final reopenedEvidence = await learningStore.evidenceForAttempt(
        learner: learnerA,
        attemptId: result.evidence.attemptId,
      );
      final reopenedState = await learningStore.learnerState(
        learner: learnerA,
        materialId: materialId,
      );

      expect(reopenedEvidence?.id, result.evidence.id);
      expect(reopenedState?.kind, RecallStateKind.retrievedOnce);
      expect(reopenedState?.evidenceCount, 1);
    } finally {
      await persistentStore?.close();
      await temp.delete(recursive: true);
    }
  });
}
