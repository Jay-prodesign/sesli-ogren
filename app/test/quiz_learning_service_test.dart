import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/domain/authenticated_learner.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sesli_ogren/src/domain/quiz_learning.dart';
import 'package:sesli_ogren/src/learning/quiz_learning_service.dart';
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

  test('quiz stays source-grounded, deterministic and resumes durable session state', () async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    final service = QuizLearningService(store: store, now: () => DateTime.utc(2026, 10, 12, 17));
    const learner = LearnerIdentity.local();
    const materialId = MaterialId('quiz-material');

    await ingest.ingestPastedText(
      learner: learner,
      materialId: materialId,
      sourceName: 'Fotosentez quiz notu',
      text:
          'Fotosentez sırasında bitkiler ışık enerjisini kimyasal enerjiye dönüştürür. '
          'Klorofil ışığın soğurulmasında önemli görev alır. '
          'Karbondioksit ve su kullanılarak glikoz üretimine katkı sağlanır. '
          'Oksijen süreç sonunda çevreye bırakılabilir.',
    );

    final first = await service.openCurrentSet(learner: learner, materialId: materialId);
    expect(first.set.questions.length, 4);
    expect(first.session.cursorIndex, 0);
    expect(first.currentQuestion, isNotNull);
    expect(first.currentQuestion!.sourceExcerpt, contains('Fotosentez'));
    expect(first.currentQuestion!.prompt, contains('_____'));
    expect(first.currentQuestion!.options, contains('Fotosentez'));
    expect(first.currentQuestion!.options.length, greaterThanOrEqualTo(3));

    final reopened = await service.openCurrentSet(learner: learner, materialId: materialId);
    expect(reopened.set.id, first.set.id);
    expect(reopened.set.questions.map((question) => question.id), first.set.questions.map((question) => question.id));

    final firstQuestion = first.currentQuestion!;
    final correct = await service.recordAnswer(
      learner: learner,
      materialId: materialId,
      setId: first.set.id,
      questionId: firstQuestion.id,
      kind: QuizAnswerKind.selected,
      selectedOptionIndex: firstQuestion.correctOptionIndex,
    );
    expect(correct.session.cursorIndex, 1);
    expect(correct.session.correctCount, 1);
    expect(correct.reviews[firstQuestion.id]?.lastIsCorrect, isTrue);

    final secondQuestion = correct.currentQuestion!;
    final unknown = await service.recordAnswer(
      learner: learner,
      materialId: materialId,
      setId: correct.set.id,
      questionId: secondQuestion.id,
      kind: QuizAnswerKind.unknown,
    );
    expect(unknown.session.cursorIndex, 2);
    expect(unknown.session.unknownCount, 1);
    expect(unknown.reviews[secondQuestion.id]?.lastAnswerKind, QuizAnswerKind.unknown);
    expect(unknown.reviews[secondQuestion.id]?.lastIsCorrect, isNull);

    final durable = await service.openCurrentSet(learner: learner, materialId: materialId);
    expect(durable.session.cursorIndex, 2);
    expect(durable.session.correctCount, 1);
    expect(durable.session.unknownCount, 1);

    final answerHistory = await store.quizAnswerHistory(learner: learner, setId: first.set.id);
    expect(answerHistory, hasLength(2));
    expect(answerHistory.first.questionId, firstQuestion.id);
    expect(answerHistory.first.kind, QuizAnswerKind.selected);
    expect(answerHistory.first.isCorrect, isTrue);
    expect(answerHistory.last.questionId, secondQuestion.id);
    expect(answerHistory.last.kind, QuizAnswerKind.unknown);
    expect(answerHistory.last.isCorrect, isNull);

    final restarted = await service.restartSession(learner: learner, materialId: materialId);
    expect(restarted.session.cursorIndex, 0);
    expect(restarted.session.correctCount, 0);
    expect(restarted.reviews[firstQuestion.id]?.correctCount, 1);
  });

  test('scheduled quiz review targets the exact current-source anchor and rejects stale lineage', () async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    final service = QuizLearningService(store: store, now: () => DateTime.utc(2026, 10, 13, 9, 15));
    const learner = LearnerIdentity.local();
    const materialId = MaterialId('quiz-scheduled-review');

    await ingest.ingestPastedText(
      learner: learner,
      materialId: materialId,
      sourceName: 'Planlı quiz kaynağı',
      text:
          'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür. '
          'Klorofil ışığın soğurulmasına yardım eder. '
          'Karbondioksit süreçte önemli bir girdidir. '
          'Oksijen süreç sonunda çevreye bırakılabilir.',
    );
    final state = await service.openCurrentSet(learner: learner, materialId: materialId);
    final target = state.set.questions[2];

    final scheduled = await service.startScheduledReview(
      learner: learner,
      materialId: materialId,
      sourceVersionId: state.set.sourceVersionId,
      sourceAnchor: target.sourceAnchor,
    );
    expect(scheduled.session.cursorIndex, target.ordinal);
    expect(scheduled.currentQuestion?.id, target.id);
    expect(scheduled.session.isCompleted, isFalse);

    await ingest.ingestPastedText(
      learner: learner,
      materialId: materialId,
      sourceName: 'Yeni quiz kaynağı',
      text:
          'Hücresel solunum glikoz enerjisini kullanılabilir enerjiye dönüştürür. '
          'Mitokondri enerji dönüşümünde görev alır. '
          'Oksijenli solunum oksijen kullanır.',
    );
    await expectLater(
      service.startScheduledReview(
        learner: learner,
        materialId: materialId,
        sourceVersionId: state.set.sourceVersionId,
        sourceAnchor: target.sourceAnchor,
      ),
      throwsA(isA<QuizLearningException>()),
    );
  });

  test('learner namespaces never share quiz state', () async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    final service = QuizLearningService(store: store);
    const local = LearnerIdentity.local();
    const account = LearnerIdentity.authenticated(id: LearnerId('quiz-account-user'));
    const materialId = MaterialId('quiz-identity-boundary');
    const text =
        'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür. '
        'Klorofil ışığın soğurulmasına yardım eder. '
        'Karbondioksit süreçte önemli bir girdidir.';

    await ingest.ingestPastedText(learner: local, materialId: materialId, sourceName: 'Yerel quiz', text: text);
    final localState = await service.openCurrentSet(learner: local, materialId: materialId);
    await service.recordAnswer(
      learner: local,
      materialId: materialId,
      setId: localState.set.id,
      questionId: localState.currentQuestion!.id,
      kind: QuizAnswerKind.unknown,
    );

    await expectLater(
      service.openCurrentSet(learner: account, materialId: materialId),
      throwsA(isA<QuizLearningException>()),
    );

    await ingest.ingestPastedText(learner: account, materialId: materialId, sourceName: 'Hesap quiz', text: text);
    final accountState = await service.openCurrentSet(learner: account, materialId: materialId);
    expect(accountState.session.cursorIndex, 0);
    expect(accountState.reviews, isEmpty);

    final localReopened = await service.openCurrentSet(learner: local, materialId: materialId);
    expect(localReopened.session.cursorIndex, 1);
    expect(localReopened.reviews, isNotEmpty);
    expect(await store.quizAnswerHistory(learner: local, setId: localState.set.id), hasLength(1));
    expect(await store.quizAnswerHistory(learner: account, setId: accountState.set.id), isEmpty);
  });

  test('source update creates a new quiz and stale answer fails closed', () async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    final service = QuizLearningService(store: store);
    const learner = LearnerIdentity.local();
    const materialId = MaterialId('quiz-source-update');

    await ingest.ingestPastedText(
      learner: learner,
      materialId: materialId,
      sourceName: 'İlk sürüm',
      text:
          'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür. '
          'Klorofil ışığın soğurulmasına yardım eder. '
          'Karbondioksit süreçte önemli bir girdidir.',
    );
    final first = await service.openCurrentSet(learner: learner, materialId: materialId);
    final firstQuestion = first.currentQuestion!;
    final afterFirst = await service.recordAnswer(
      learner: learner,
      materialId: materialId,
      setId: first.set.id,
      questionId: firstQuestion.id,
      kind: QuizAnswerKind.selected,
      selectedOptionIndex: firstQuestion.correctOptionIndex,
    );
    final staleQuestion = afterFirst.currentQuestion!;

    await ingest.ingestPastedText(
      learner: learner,
      materialId: materialId,
      sourceName: 'İkinci sürüm',
      text:
          'Hücresel solunum glikozdaki kimyasal enerjiyi kullanılabilir enerjiye dönüştürür. '
          'Mitokondri ökaryot hücrelerde enerji dönüşümünde görev alır. '
          'Oksijenli solunumda oksijen önemli bir girdidir.',
    );

    await expectLater(
      store.recordQuizAnswer(
        learner: learner,
        set: first.set,
        question: staleQuestion,
        kind: QuizAnswerKind.selected,
        selectedOptionIndex: staleQuestion.correctOptionIndex,
        answeredAt: DateTime.utc(2026, 10, 12, 18),
      ),
      throwsA(isA<SourceStoreConflict>()),
    );

    final second = await service.openCurrentSet(learner: learner, materialId: materialId);
    expect(second.set.id, isNot(first.set.id));
    expect(second.set.sourceVersionId, isNot(first.set.sourceVersionId));
    expect(second.session.cursorIndex, 0);
    expect(second.reviews, isEmpty);

    final historicalSet = await store.quizSet(
      learner: learner,
      materialId: materialId,
      sourceVersionId: first.set.sourceVersionId,
      generationVersion: QuizLearningService.generationVersion,
    );
    expect(historicalSet?.id, first.set.id);
    final historicalAnswers = await store.quizAnswerHistory(learner: learner, setId: first.set.id);
    expect(historicalAnswers, hasLength(1));
    expect(historicalAnswers.single.questionId, firstQuestion.id);
    expect(historicalAnswers.single.isCorrect, isTrue);
  });
}
