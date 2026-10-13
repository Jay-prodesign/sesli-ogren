import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/domain/authenticated_learner.dart';
import 'package:sesli_ogren/src/domain/flashcard_learning.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sesli_ogren/src/domain/learning_truth.dart';
import 'package:sesli_ogren/src/domain/quiz_learning.dart';
import 'package:sesli_ogren/src/domain/retention_schedule.dart';
import 'package:sesli_ogren/src/learning/flashcard_learning_service.dart';
import 'package:sesli_ogren/src/learning/quiz_learning_service.dart';
import 'package:sesli_ogren/src/learning/recall_learning_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _UnusedPdfExtractor implements PdfTextExtractor {
  const _UnusedPdfExtractor();

  @override
  Future<ExtractedPdf> extract(Uint8List bytes, {required String sourceName}) {
    throw UnimplementedError();
  }
}

void main() {
  sqfliteFfiInit();

  test('revealed flashcard self-report schedules support without claiming independent retrieval', () async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    var now = DateTime.utc(2026, 10, 13, 8);
    final flashcards = FlashcardLearningService(store: store, now: () => now);
    const learner = LearnerIdentity.local();
    const materialId = MaterialId('retention-flashcards');

    await ingest.ingestPastedText(
      learner: learner,
      materialId: materialId,
      sourceName: 'Fotosentez',
      text:
          'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür. '
          'Klorofil ışığın soğurulmasına yardım eder. '
          'Karbondioksit süreçte önemli bir girdidir.',
    );
    final state = await flashcards.openCurrentSet(learner: learner, materialId: materialId);
    final firstCard = state.currentCard!;
    await flashcards.recordResponse(
      learner: learner,
      materialId: materialId,
      setId: state.set.id,
      cardId: firstCard.id,
      response: FlashcardResponse.remembered,
      answerWasRevealed: true,
    );

    var schedules = await store.retentionSchedulesForMaterial(learner: learner, materialId: materialId);
    expect(schedules, hasLength(1));
    expect(schedules.single.sourceVersionId, state.set.sourceVersionId);
    expect(schedules.single.sourceAnchor.startOffset, firstCard.sourceAnchor.startOffset);
    expect(schedules.single.latestEvidenceKind, RetentionEvidenceKind.flashcard);
    expect(schedules.single.latestOutcomeBand, RetentionOutcomeBand.supportedRetrieval);
    expect(schedules.single.successStreak, 0);
    expect(schedules.single.reviewCount, 1);
    expect(schedules.single.interval, const Duration(hours: 12));
    expect(schedules.single.dueAt, now.add(const Duration(hours: 12)));
    expect(schedules.single.reasonCode, 'SUPPORTED_OR_PARTIAL_RETRIEVAL');
    expect(await store.dueRetentionSchedules(learner: learner, at: now), isEmpty);

    await flashcards.restartSession(learner: learner, materialId: materialId);
    now = DateTime.utc(2026, 10, 14, 8);
    final reopened = await flashcards.openCurrentSet(learner: learner, materialId: materialId);
    await flashcards.recordResponse(
      learner: learner,
      materialId: materialId,
      setId: reopened.set.id,
      cardId: reopened.currentCard!.id,
      response: FlashcardResponse.remembered,
      answerWasRevealed: true,
    );

    schedules = await store.retentionSchedulesForMaterial(learner: learner, materialId: materialId);
    expect(schedules.single.latestOutcomeBand, RetentionOutcomeBand.supportedRetrieval);
    expect(schedules.single.successStreak, 0);
    expect(schedules.single.reviewCount, 2);
    expect(schedules.single.interval, const Duration(hours: 12));
    expect(schedules.single.dueAt, now.add(const Duration(hours: 12)));
  });

  test('independent retrieval alone grows the deterministic retention interval', () {
    const id = RetentionScheduleId('policy-retention');
    const materialId = MaterialId('policy-material');
    const sourceVersionId = SourceVersionId('policy-source');
    const anchor = SourceAnchor(startOffset: 0, endOffset: 42);
    final firstAt = DateTime.utc(2026, 10, 13, 8);
    final first = RetentionPolicy.advance(
      existing: null,
      id: id,
      materialId: materialId,
      sourceVersionId: sourceVersionId,
      sourceAnchor: anchor,
      evidenceKind: RetentionEvidenceKind.recall,
      outcomeBand: RetentionOutcomeBand.independentRetrieval,
      eventId: 'recall:first',
      occurredAt: firstAt,
    );
    expect(first.successStreak, 1);
    expect(first.interval, const Duration(days: 1));

    final secondAt = firstAt.add(const Duration(days: 1));
    final second = RetentionPolicy.advance(
      existing: first,
      id: id,
      materialId: materialId,
      sourceVersionId: sourceVersionId,
      sourceAnchor: anchor,
      evidenceKind: RetentionEvidenceKind.quiz,
      outcomeBand: RetentionOutcomeBand.independentRetrieval,
      eventId: 'quiz:second',
      occurredAt: secondAt,
    );
    expect(second.successStreak, 2);
    expect(second.interval, const Duration(days: 3));
    expect(second.dueAt, secondAt.add(const Duration(days: 3)));
  });

  test('Recall creates a durable retention schedule that survives database reopen', () async {
    final directory = await Directory.systemTemp.createTemp('sesli-ogren-retention-');
    final path = '${directory.path}/retention.db';
    SqliteSourceStore? activeStore;
    addTearDown(() async {
      if (activeStore != null) await activeStore.close();
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    final at = DateTime.utc(2026, 10, 13, 8, 30);
    activeStore = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: path);
    final ingest = SourceIngestService(store: activeStore, pdfTextExtractor: const _UnusedPdfExtractor());
    final recall = RecallLearningService(
      sourceStore: activeStore,
      learningStore: activeStore.learningTruthStore(),
      now: () => at,
    );
    const learner = LearnerIdentity.local();
    const materialId = MaterialId('retention-recall');

    await ingest.ingestPastedText(
      learner: learner,
      materialId: materialId,
      sourceName: 'Fizik',
      text:
          'Momentum bir cismin kütlesi ile hızının çarpımıdır. '
          'Kapalı bir sistemde toplam momentum korunur.',
    );
    final prompt = await recall.createCurrentPrompt(learner: learner, materialId: materialId);
    final action = await activeStore.learningTruthStore().recallAction(learner: learner, actionId: prompt.id);
    expect(action, isNotNull);

    final result = await recall.submit(
      learner: learner,
      actionId: prompt.id,
      attemptId: const RecallAttemptId('retention-recall-attempt'),
      disposition: RecallResponseDisposition.answer,
      answer: action!.expectedAnswer,
    );
    expect(result.evidence.outcome, RecallOutcome.correct);

    var schedules = await activeStore.retentionSchedulesForMaterial(learner: learner, materialId: materialId);
    expect(schedules, hasLength(1));
    expect(schedules.single.latestEvidenceKind, RetentionEvidenceKind.recall);
    expect(schedules.single.latestOutcomeBand, RetentionOutcomeBand.independentRetrieval);
    expect(schedules.single.sourceAnchor.startOffset, action.anchor.startOffset);
    expect(schedules.single.dueAt, at.add(const Duration(days: 1)));

    await activeStore.close();
    activeStore = null;
    activeStore = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: path);

    schedules = await activeStore.retentionSchedulesForMaterial(learner: learner, materialId: materialId);
    expect(schedules, hasLength(1));
    expect(schedules.single.latestEventId, 'recall:${result.evidence.id.value}');
    expect(schedules.single.policyVersion, RetentionPolicy.version);
    expect(await activeStore.dueRetentionSchedules(learner: learner, at: at), isEmpty);
    expect(
      await activeStore.dueRetentionSchedules(learner: learner, at: at.add(const Duration(days: 1))),
      hasLength(1),
    );
  });

  test('correct Quiz answer becomes independent source-bound retention evidence', () async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    final at = DateTime.utc(2026, 10, 13, 8, 45);
    final quiz = QuizLearningService(store: store, now: () => at);
    const learner = LearnerIdentity.local();
    const materialId = MaterialId('retention-quiz-correct');

    await ingest.ingestPastedText(
      learner: learner,
      materialId: materialId,
      sourceName: 'Biyoloji quiz',
      text:
          'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür. '
          'Klorofil ışığın soğurulmasına yardım eder. '
          'Karbondioksit süreçte önemli bir girdidir. '
          'Mitokondri hücresel enerji dönüşümünde görev alır.',
    );
    final state = await quiz.openCurrentSet(learner: learner, materialId: materialId);
    final question = state.currentQuestion!;
    await quiz.recordAnswer(
      learner: learner,
      materialId: materialId,
      setId: state.set.id,
      questionId: question.id,
      kind: QuizAnswerKind.selected,
      selectedOptionIndex: question.correctOptionIndex,
    );

    final schedules = await store.retentionSchedulesForMaterial(learner: learner, materialId: materialId);
    final schedule = schedules.firstWhere(
      (item) =>
          item.sourceAnchor.startOffset == question.sourceAnchor.startOffset &&
          item.sourceAnchor.endOffset == question.sourceAnchor.endOffset,
    );
    expect(schedule.sourceVersionId, state.set.sourceVersionId);
    expect(schedule.latestEvidenceKind, RetentionEvidenceKind.quiz);
    expect(schedule.latestOutcomeBand, RetentionOutcomeBand.independentRetrieval);
    expect(schedule.successStreak, 1);
    expect(schedule.interval, const Duration(days: 1));
    expect(schedule.dueAt, at.add(const Duration(days: 1)));
    expect(schedule.reasonCode, 'INDEPENDENT_RETRIEVAL_OBSERVED');
  });

  test('again and unknown never become positive retention evidence', () async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    final at = DateTime.utc(2026, 10, 13, 9);
    final flashcards = FlashcardLearningService(store: store, now: () => at);
    final quiz = QuizLearningService(store: store, now: () => at);
    const learner = LearnerIdentity.local();
    const materialId = MaterialId('retention-negative');

    await ingest.ingestPastedText(
      learner: learner,
      materialId: materialId,
      sourceName: 'Biyoloji',
      text:
          'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür. '
          'Klorofil ışığın soğurulmasına yardım eder. '
          'Karbondioksit süreçte önemli bir girdidir.',
    );

    final cardState = await flashcards.openCurrentSet(learner: learner, materialId: materialId);
    await flashcards.recordResponse(
      learner: learner,
      materialId: materialId,
      setId: cardState.set.id,
      cardId: cardState.currentCard!.id,
      response: FlashcardResponse.again,
      answerWasRevealed: true,
    );
    var schedules = await store.retentionSchedulesForMaterial(learner: learner, materialId: materialId);
    expect(schedules.single.latestOutcomeBand, RetentionOutcomeBand.repairNeeded);
    expect(schedules.single.successStreak, 0);
    expect(schedules.single.interval, const Duration(minutes: 10));

    final quizState = await quiz.openCurrentSet(learner: learner, materialId: materialId);
    await quiz.recordAnswer(
      learner: learner,
      materialId: materialId,
      setId: quizState.set.id,
      questionId: quizState.currentQuestion!.id,
      kind: QuizAnswerKind.unknown,
    );
    schedules = await store.retentionSchedulesForMaterial(learner: learner, materialId: materialId);
    final firstAnchor = schedules.firstWhere(
      (item) => item.sourceAnchor.startOffset == quizState.currentQuestion!.sourceAnchor.startOffset,
    );
    expect(firstAnchor.latestOutcomeBand, RetentionOutcomeBand.unassessed);
    expect(firstAnchor.successStreak, 0);
    expect(firstAnchor.interval, Duration.zero);
    expect(firstAnchor.isDueAt(at), isTrue);
    expect(firstAnchor.reasonCode, 'NO_POSITIVE_RETENTION_EVIDENCE');
  });

  test('retention is learner-namespaced and stale source schedules fail closed', () async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    final service = FlashcardLearningService(store: store, now: () => DateTime.utc(2026, 10, 13, 10));
    const local = LearnerIdentity.local();
    const account = LearnerIdentity.authenticated(id: LearnerId('retention-account'));
    const materialId = MaterialId('retention-source');
    const text =
        'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür. '
        'Klorofil ışığın soğurulmasına yardım eder. '
        'Karbondioksit süreçte önemli bir girdidir.';

    await ingest.ingestPastedText(learner: local, materialId: materialId, sourceName: 'Yerel', text: text);
    final localState = await service.openCurrentSet(learner: local, materialId: materialId);
    await service.recordResponse(
      learner: local,
      materialId: materialId,
      setId: localState.set.id,
      cardId: localState.currentCard!.id,
      response: FlashcardResponse.remembered,
      answerWasRevealed: true,
    );
    expect(await store.retentionSchedulesForMaterial(learner: local, materialId: materialId), hasLength(1));
    expect(await store.retentionSchedulesForMaterial(learner: account, materialId: materialId), isEmpty);

    await ingest.ingestPastedText(
      learner: local,
      materialId: materialId,
      sourceName: 'Yeni sürüm',
      text:
          'Hücresel solunum kimyasal enerjiyi kullanılabilir enerjiye dönüştürür. '
          'Mitokondri enerji dönüşümünde görev alır. '
          'Oksijen önemli bir girdidir.',
    );
    expect(await store.retentionSchedulesForMaterial(learner: local, materialId: materialId), isEmpty);
    expect(await store.dueRetentionSchedules(learner: local, at: DateTime.utc(2030)), isEmpty);
  });
}
