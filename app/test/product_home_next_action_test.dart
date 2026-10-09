import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/app_runtime.dart';
import 'package:sesli_ogren/src/app/product_shell_screen.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
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

Future<AppRuntime> _runtimeWithEvidence({
  required RecallResponseDisposition disposition,
  required bool submitCorrectAnswer,
}) async {
  final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
  final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
  final recall = RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore());
  final runtime = AppRuntime(
    learner: AppRuntime.localM5LearnerFixture,
    store: store,
    ingest: ingest,
    recall: recall,
    telemetry: store.operationalTelemetry(),
  );

  await ingest.ingestPastedText(
    learner: runtime.learner,
    materialId: AppRuntime.primaryMaterialId,
    text:
        'Fotosentez sırasında klorofil ışık enerjisini kimyasal enerjiye dönüştürmeye yardımcı olur. '
        'Bitkiler karbondioksit kullanır ve oksijen açığa çıkarır. '
        'Mitokondri hücresel solunumla kullanılabilir enerji üretimine katkı sağlar.',
    sourceName: 'Biyoloji çalışma notu',
  );
  final prompt = await recall.createCurrentPrompt(learner: runtime.learner, materialId: AppRuntime.primaryMaterialId);
  final session = await recall.openAttempt(learner: runtime.learner, actionId: prompt.id);
  final action = await store.learningTruthStore().recallAction(learner: runtime.learner, actionId: prompt.id);
  await recall.submit(
    learner: runtime.learner,
    actionId: prompt.id,
    attemptId: session.attempt.attemptId,
    disposition: disposition,
    answer: submitCorrectAnswer ? action!.expectedAnswer : '',
  );
  return runtime;
}

void main() {
  testWidgets('Home review action opens the persisted repair continuation', (tester) async {
    final runtime = await _runtimeWithEvidence(
      disposition: RecallResponseDisposition.unknown,
      submitCorrectAnswer: false,
    );
    addTearDown(runtime.close);

    await tester.pumpWidget(MaterialApp(home: ProductShellScreen(runtime: runtime)));
    await tester.pumpAndSettle();

    final action = find.text('Kaynağı gözden geçir');
    expect(action, findsOneWidget);
    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(find.text('Bu bölümü yeniden kur'), findsOneWidget);
    expect(find.text('Kaynağı kapat ve yeniden dene'), findsOneWidget);
    expect(find.text('Önce kaynağı gözden geçir'), findsNothing);
  });

  testWidgets('Home completed action returns to the source workspace instead of replaying Recall', (tester) async {
    final runtime = await _runtimeWithEvidence(
      disposition: RecallResponseDisposition.answer,
      submitCorrectAnswer: true,
    );
    addTearDown(runtime.close);

    await tester.pumpWidget(MaterialApp(home: ProductShellScreen(runtime: runtime)));
    await tester.pumpAndSettle();

    final action = find.text('Kaynağa dön');
    expect(action, findsOneWidget);
    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(find.text('Biyoloji çalışma notu'), findsWidgets);
    expect(find.text('Öğrenme durumu'), findsOneWidget);
    expect(find.text('Kaynağa dön'), findsNothing);
  });
}
