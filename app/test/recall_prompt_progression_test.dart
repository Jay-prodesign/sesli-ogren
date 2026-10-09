import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
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
  Future<ExtractedPdf> extract(Uint8List bytes, {required String sourceName}) => throw UnimplementedError();
}

void main() {
  sqfliteFfiInit();
  const learner = AuthenticatedLearner(id: LearnerId('recall-progression-learner'));
  const materialId = MaterialId('recall-progression-material');
  late SqliteSourceStore store;
  late SourceIngestService ingest;
  late RecallLearningService recall;

  setUp(() async {
    store = await SqliteSourceStore.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    ingest = SourceIngestService(
      store: store,
      pdfTextExtractor: const _UnusedPdfExtractor(),
      now: () => DateTime.utc(2026, 10, 9, 10),
    );
    recall = RecallLearningService(
      sourceStore: store,
      learningStore: store.learningTruthStore(),
      now: () => DateTime.utc(2026, 10, 9, 10, 1),
    );
  });

  tearDown(() => store.close());

  Future<RecallAction> actionFor(RecallPrompt prompt) async {
    final action = await store.learningTruthStore().recallAction(learner: learner, actionId: prompt.id);
    expect(action, isNotNull);
    return action!;
  }

  Future<void> answerCorrectly(RecallPrompt prompt, String attemptId) async {
    final action = await actionFor(prompt);
    final result = await recall.submit(
      learner: learner,
      actionId: prompt.id,
      attemptId: RecallAttemptId(attemptId),
      disposition: RecallResponseDisposition.answer,
      answer: action.expectedAnswer,
    );
    expect(result.evidence.outcome, RecallOutcome.correct);
  }

  test('Recall retries unmastered content and advances after independent retrieval', () async {
    await ingest.ingestPastedText(
      learner: learner,
      materialId: materialId,
      text:
          'Fotosentez bitkilerde ışık enerjisini kimyasal enerjiye dönüştürür. '
          'Mitokondri hücresel solunum sırasında kullanılabilir enerji üretimine katkı sağlar. '
          'Ribozomlar protein sentezinde aminoasit zincirlerinin kurulmasına yardım eder.',
      sourceName: 'Biyoloji',
    );

    final first = await recall.createCurrentPrompt(learner: learner, materialId: materialId);
    await recall.submit(
      learner: learner,
      actionId: first.id,
      attemptId: const RecallAttemptId('attempt-progression-unknown'),
      disposition: RecallResponseDisposition.unknown,
    );

    final retry = await recall.createCurrentPrompt(learner: learner, materialId: materialId);
    expect(retry.id, first.id);

    await answerCorrectly(retry, 'attempt-progression-correct');
    final next = await recall.createCurrentPrompt(learner: learner, materialId: materialId);

    expect(next.id, isNot(first.id));
    expect(next.anchor.startOffset, greaterThan(first.anchor.startOffset));
    expect(next.ruleVersion, RecallLearningService.promptRuleVersion);
  });

  test('Recall progression reaches useful content beyond the old 2400-character window', () async {
    final filler = List<String>.filled(420, 'a a a a.').join(' ');
    await ingest.ingestPastedText(
      learner: learner,
      materialId: materialId,
      text:
          'Fotosentez bitkilerde ışık enerjisini kimyasal enerjiye dönüştürür. '
          'Mitokondri hücresel solunum sırasında kullanılabilir enerji üretimine katkı sağlar. '
          '$filler '
          'Ribozomlar protein sentezinde aminoasit zincirlerinin kurulmasına yardım eder.',
      sourceName: 'Uzun biyoloji notu',
    );

    final first = await recall.createCurrentPrompt(learner: learner, materialId: materialId);
    await answerCorrectly(first, 'attempt-long-source-01');
    final second = await recall.createCurrentPrompt(learner: learner, materialId: materialId);
    await answerCorrectly(second, 'attempt-long-source-02');
    final third = await recall.createCurrentPrompt(learner: learner, materialId: materialId);

    expect(third.anchor.startOffset, greaterThan(2400));
    expect(third.promptText, contains('_____'));
  });
}
