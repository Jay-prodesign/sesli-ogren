import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/app_runtime.dart';
import 'package:sesli_ogren/src/app/learning_slice_screen.dart';
import 'package:sesli_ogren/src/app/living_study_desk_home.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/domain/authenticated_learner.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sesli_ogren/src/domain/learning_truth.dart';
import 'package:sesli_ogren/src/learning/recall_learning_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _NoPdf implements PdfTextExtractor {
  const _NoPdf();
  @override
  Future<ExtractedPdf> extract(Uint8List bytes, {required String sourceName}) => throw UnimplementedError();
}

class _FailOnceRecall extends RecallLearningService {
  _FailOnceRecall(SqliteSourceStore store) : super(sourceStore: store, learningStore: store.learningTruthStore());
  int calls = 0;

  @override
  Future<RecallAttemptResult> submit({
    required AuthenticatedLearner learner,
    required RecallActionId actionId,
    required RecallAttemptId attemptId,
    required RecallResponseDisposition disposition,
    String answer = '',
  }) {
    calls += 1;
    if (calls == 1) {
      throw const RecallLearningException('temporary verification failure');
    }
    return super.submit(
      learner: learner,
      actionId: actionId,
      attemptId: attemptId,
      disposition: disposition,
      answer: answer,
    );
  }
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 160; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Expected recovery state was not reached.');
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 180, scrollable: find.byType(Scrollable).last);
  await tester.pump();
  expect(finder.hitTestable(), findsOneWidget);
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  sqfliteFfiInit();

  testWidgets('failed Recall verification preserves answer and creates no evidence before retry', (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _NoPdf());
    final recall = _FailOnceRecall(store);
    const learner = AppRuntime.localM5LearnerFixture;
    const materialId = MaterialId('recall_recovery_material');
    await ingest.ingestPastedText(
      learner: learner,
      materialId: materialId,
      sourceName: 'Biyoloji',
      text: 'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür. Klorofil ışığın soğurulmasına yardım eder.',
    );
    final runtime = AppRuntime(
      learner: learner,
      store: store,
      ingest: ingest,
      recall: recall,
      telemetry: store.operationalTelemetry(),
    );

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true, textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: LivingDeskReviewScope(
          child: LearningSliceScreen(runtime: runtime, materialId: materialId),
        ),
      ),
    );
    final answer = find.byKey(const ValueKey('la0040-atelier-answer'));
    final submit = find.byKey(const ValueKey('la0040-atelier-submit'));
    await _pumpUntil(tester, answer);
    await tester.enterText(answer, 'Fotosentez');
    await _tapVisible(tester, submit);
    await _pumpUntil(tester, find.textContaining('Ekrandaki yanıtın korunuyor'));

    final editable = tester.widget<EditableText>(find.descendant(of: answer, matching: find.byType(EditableText)));
    expect(editable.controller.text, 'Fotosentez');
    final source = await store.currentSourceVersion(learner: learner, materialId: materialId);
    var evidence = await store.learningTruthStore().evidenceForMaterial(
      learner: learner,
      materialId: materialId,
      sourceVersionId: source!.identity.sourceVersionId,
    );
    expect(evidence, isEmpty);

    await _tapVisible(tester, submit);
    await _pumpUntil(tester, find.byKey(const ValueKey('la0040-atelier-result')));
    evidence = await store.learningTruthStore().evidenceForMaterial(
      learner: learner,
      materialId: materialId,
      sourceVersionId: source.identity.sourceVersionId,
    );
    expect(recall.calls, 2);
    expect(evidence, hasLength(1));
    expect(evidence.single.outcome, RecallOutcome.correct);
    expect(tester.takeException(), isNull);
  });
}
