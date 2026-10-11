import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/app_runtime.dart';
import 'package:sesli_ogren/src/app/learning_slice_screen.dart';
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
  Future<ExtractedPdf> extract(Uint8List bytes, {required String sourceName}) {
    throw UnimplementedError();
  }
}

Future<AppRuntime> _openRuntime({required String path, required AuthenticatedLearner learner}) async {
  final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: path);
  final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
  return AppRuntime(
    learner: learner,
    store: store,
    ingest: ingest,
    recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
    telemetry: store.operationalTelemetry(),
  );
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder, {int maxPumps = 30}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 40));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Expected widget was not reached within bounded pumps.');
}

void main() {
  sqfliteFfiInit();

  testWidgets('review-source continuation cannot bypass source review before hidden recall', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
    );
    const materialId = MaterialId('continuation-review-source-first');
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: materialId,
      text:
          'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür. '
          'Klorofil ışığın soğurulmasına yardım eder.',
      sourceName: 'Continuation kaynak notu',
    );
    final prompt = await runtime.recall.createCurrentPrompt(learner: runtime.learner, materialId: materialId);
    final attempt = await runtime.recall.openAttempt(learner: runtime.learner, actionId: prompt.id);
    final result = await runtime.recall.submit(
      learner: runtime.learner,
      actionId: prompt.id,
      attemptId: attempt.attempt.attemptId,
      disposition: RecallResponseDisposition.unknown,
      answer: '',
    );
    expect(result.nextAction.kind, NextLearningActionKind.reviewSourceThenRecall);

    await tester.pumpWidget(
      MaterialApp(
        home: LearningSliceScreen(runtime: runtime, materialId: materialId),
      ),
    );
    await _pumpUntilFound(tester, find.text('Önce kaynağı gözden geçir'));

    expect(find.text('Yeniden hatırlamayı dene'), findsNothing);
    await tester.tap(find.text('Kaynağı gözden geçir'));
    await _pumpUntilFound(tester, find.text('Bu bölümü yeniden kur'));

    expect(find.text('Kaynağı kapat ve yeniden dene'), findsOneWidget);
    expect(find.byKey(const ValueKey('atelier-source-trust')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('durable learner continuity survives a real SQLite close and reopen', () async {
    final directory = await Directory.systemTemp.createTemp('sesli-ogren-durable-reopen-');
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final dbPath = '${directory.path}/learning.sqlite';

    const learner = AuthenticatedLearner(id: LearnerId('durable-reopen-learner'));
    const otherLearner = AuthenticatedLearner(id: LearnerId('durable-reopen-other'));
    const materialId = MaterialId('durable-reopen-material');

    final firstRuntime = await _openRuntime(path: dbPath, learner: learner);
    final ingestResult = await firstRuntime.ingest.ingestPastedText(
      learner: learner,
      materialId: materialId,
      text:
          'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür. '
          'Klorofil ışığın soğurulmasına yardım eder. '
          'Bitkiler süreçte karbondioksit ve su kullanır.',
      sourceName: 'Kalıcı biyoloji notu',
    );
    final sourceId = ingestResult.sourceVersion.identity.sourceVersionId;

    await firstRuntime.store.saveReaderResumeProgress(
      learner: learner,
      materialId: materialId,
      sourceVersionId: sourceId,
      progress: 0.42,
      updatedAt: DateTime.utc(2026, 10, 11, 7),
    );
    await firstRuntime.store.saveListenResumeChunk(
      learner: learner,
      materialId: materialId,
      sourceVersionId: sourceId,
      chunkIndex: 1,
      updatedAt: DateTime.utc(2026, 10, 11, 7, 1),
    );

    final prompt = await firstRuntime.recall.createCurrentPrompt(learner: learner, materialId: materialId);
    final attempt = await firstRuntime.recall.openAttempt(learner: learner, actionId: prompt.id);
    final submitted = await firstRuntime.recall.submit(
      learner: learner,
      actionId: prompt.id,
      attemptId: attempt.attempt.attemptId,
      disposition: RecallResponseDisposition.unknown,
      answer: '',
    );
    expect(submitted.nextAction.kind, NextLearningActionKind.reviewSourceThenRecall);

    await firstRuntime.close();

    final reopened = await _openRuntime(path: dbPath, learner: learner);
    var reopenedClosed = false;
    addTearDown(() async {
      if (!reopenedClosed) await reopened.close();
    });

    final materials = await reopened.store.activeMaterials(learner: learner);
    expect(materials.map((item) => item.id), contains(materialId));

    final continuation = await reopened.recall.reopen(learner: learner, materialId: materialId);
    expect(continuation, isNotNull);
    expect(continuation!.nextAction.kind, NextLearningActionKind.reviewSourceThenRecall);
    expect(continuation.state.latestEvidenceId, submitted.evidence.id);

    expect(
      await reopened.store.readerResumeProgress(learner: learner, materialId: materialId, sourceVersionId: sourceId),
      closeTo(0.42, 0.0001),
    );
    expect(
      await reopened.store.listenResumeChunk(learner: learner, materialId: materialId, sourceVersionId: sourceId),
      1,
    );

    expect(await reopened.store.activeMaterials(learner: otherLearner), isEmpty);

    await reopened.close();
    reopenedClosed = true;
  });

  test('active Recall attempt and assistance survive close and reopen without duplicate evidence', () async {
    final directory = await Directory.systemTemp.createTemp('sesli-ogren-active-recall-reopen-');
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final dbPath = '${directory.path}/learning.sqlite';

    const learner = AuthenticatedLearner(id: LearnerId('active-recall-reopen-learner'));
    const materialId = MaterialId('active-recall-reopen-material');

    final firstRuntime = await _openRuntime(path: dbPath, learner: learner);
    await firstRuntime.ingest.ingestPastedText(
      learner: learner,
      materialId: materialId,
      text:
          'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür. '
          'Klorofil ışığın soğurulmasına yardım eder. '
          'Karbondioksit ve su bu süreçte kullanılır.',
      sourceName: 'Yarım deneme biyoloji notu',
    );

    final firstPrompt = await firstRuntime.recall.createCurrentPrompt(learner: learner, materialId: materialId);
    final firstSession = await firstRuntime.recall.openAttempt(learner: learner, actionId: firstPrompt.id);
    final hint = await firstRuntime.recall.requestHint(
      learner: learner,
      actionId: firstPrompt.id,
      attemptId: firstSession.attempt.attemptId,
    );
    await firstRuntime.close();

    final reopened = await _openRuntime(path: dbPath, learner: learner);
    final resumedPrompt = await reopened.recall.createCurrentPrompt(learner: learner, materialId: materialId);
    expect(resumedPrompt.id, firstPrompt.id);

    final resumedSession = await reopened.recall.openAttempt(learner: learner, actionId: resumedPrompt.id);
    expect(resumedSession.attempt.attemptId, firstSession.attempt.attemptId);
    expect(resumedSession.assistance, hint.assistance);

    final action = await reopened.store.learningTruthStore().recallAction(learner: learner, actionId: resumedPrompt.id);
    expect(action, isNotNull);

    final submitted = await reopened.recall.submit(
      learner: learner,
      actionId: resumedPrompt.id,
      attemptId: resumedSession.attempt.attemptId,
      disposition: RecallResponseDisposition.answer,
      answer: action!.expectedAnswer,
    );
    expect(submitted.evidence.assistance, hint.assistance);
    expect(submitted.nextAction.kind, NextLearningActionKind.retryRecallWithoutHint);

    final replayed = await reopened.recall.submit(
      learner: learner,
      actionId: resumedPrompt.id,
      attemptId: resumedSession.attempt.attemptId,
      disposition: RecallResponseDisposition.answer,
      answer: action.expectedAnswer,
    );
    expect(replayed.evidence.id, submitted.evidence.id);

    final source = await reopened.store.currentSourceVersion(learner: learner, materialId: materialId);
    expect(source, isNotNull);
    final evidence = await reopened.store.learningTruthStore().evidenceForMaterial(
      learner: learner,
      materialId: materialId,
      sourceVersionId: source!.identity.sourceVersionId,
    );
    expect(evidence, hasLength(1));
    await reopened.close();

    final reopenedAgain = await _openRuntime(path: dbPath, learner: learner);
    addTearDown(reopenedAgain.close);
    final continuation = await reopenedAgain.recall.reopen(learner: learner, materialId: materialId);
    expect(continuation, isNotNull);
    expect(continuation!.state.latestEvidenceId, submitted.evidence.id);
    expect(continuation.nextAction.kind, NextLearningActionKind.retryRecallWithoutHint);
  });
}
