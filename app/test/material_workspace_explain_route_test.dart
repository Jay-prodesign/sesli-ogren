import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/app_runtime.dart';
import 'package:sesli_ogren/src/app/living_study_desk_home.dart';
import 'package:sesli_ogren/src/app/material_workspace_screen.dart';
import 'package:sesli_ogren/src/app/source_reader_screen.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sesli_ogren/src/learning/recall_learning_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _UnusedPdfExtractor implements PdfTextExtractor {
  const _UnusedPdfExtractor();

  @override
  Future<ExtractedPdf> extract(Uint8List bytes, {required String sourceName}) {
    throw UnimplementedError();
  }
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder, {int maxPumps = 80}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Expected workspace widget was not reached within bounded pumps.');
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

void main() {
  sqfliteFfiInit();

  testWidgets('Missing material shows a recoverable workspace error', (tester) async {
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

    await tester.pumpWidget(
      MaterialApp(
        home: MaterialWorkspaceScreen(runtime: runtime, materialId: const MaterialId('missing-workspace-material')),
      ),
    );
    await _pumpUntilFound(tester, find.text('Materyal açılamadı.'));
    expect(find.text('Tekrar dene'), findsOneWidget);

    await tester.tap(find.text('Tekrar dene'));
    await _pumpUntilFound(tester, find.text('Materyal açılamadı.'));
    expect(find.text('Tekrar dene'), findsOneWidget);
  });

  testWidgets('Missing material can return to the previous product surface', (tester) async {
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

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => MaterialWorkspaceScreen(
                      runtime: runtime,
                      materialId: const MaterialId('missing-workspace-material'),
                    ),
                  ),
                ),
                child: const Text('Çalışma alanını aç'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Çalışma alanını aç'));
    await _pumpUntilFound(tester, find.text('Materyal açılamadı.'));
    expect(find.text('Geri dön'), findsOneWidget);

    await tester.tap(find.text('Geri dön'));
    await tester.pumpAndSettle();
    expect(find.text('Çalışma alanını aç'), findsOneWidget);
  });

  testWidgets('Workspace alternate study paths remain usable at narrow large text', (tester) async {
    tester.view.physicalSize = const Size(320, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    const materialId = MaterialId('workspace-large-text-paths');
    await ingest.ingestPastedText(
      learner: AppRuntime.localM5LearnerFixture,
      materialId: materialId,
      text: 'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür. Çalışma yolları büyük yazıda da erişilebilir kalmalıdır.',
      sourceName: 'Büyük yazı çalışma notu',
    );
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: LivingDeskReviewScope(
            child: MaterialWorkspaceScreen(runtime: runtime, materialId: materialId),
          ),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('Diğer yollar'));
    await _tapVisible(tester, find.text('Diğer yollar'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('workspace-other-study-paths-scroll')), findsOneWidget);
    expect(find.text('Hızlı özet'), findsOneWidget);
    expect(find.text('Kaynağı bana açıkla'), findsOneWidget);
    expect(find.text('Kendi cümlelerimle anlat'), findsOneWidget);
    expect(find.text('Odaklan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('review-source continuation opens the source before another hidden recall', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);

    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    const materialId = MaterialId('workspace-review-source-first');
    await ingest.ingestPastedText(
      learner: AppRuntime.localM5LearnerFixture,
      materialId: materialId,
      text:
          'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür. '
          'Klorofil ışığın soğurulmasına yardım eder.',
      sourceName: 'Kaynak onarım notu',
    );
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
    );

    final prompt = await runtime.recall.createCurrentPrompt(
      learner: runtime.learner,
      materialId: materialId,
    );
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
        home: LivingDeskReviewScope(
          child: MaterialWorkspaceScreen(runtime: runtime, materialId: materialId),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('Kaynağı gözden geçir'));

    await _tapVisible(tester, find.text('Kaynağı gözden geçir'));
    await _pumpUntilFound(tester, find.byType(SourceReaderScreen));

    expect(find.byType(SourceReaderScreen), findsOneWidget);
    expect(find.text('Kaynak onarım notu'), findsWidgets);

    await tester.tap(find.text('Kaynağı kapat ve hatırla'));
    await _pumpUntilFound(tester, find.byKey(const ValueKey('la0040-atelier-recall')));
    expect(find.text('Önce kaynağı gözden geçir'), findsNothing);
    expect(find.byKey(const ValueKey('la0040-atelier-recall')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Material Workspace Açıkla opens active Explain-back, not generated teaching', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);

    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    const materialId = MaterialId('workspace-explain-material');
    await ingest.ingestPastedText(
      learner: AppRuntime.localM5LearnerFixture,
      materialId: materialId,
      text: 'Fotosentez ışık enerjisinin kimyasal enerjiye dönüşmesini sağlar.',
      sourceName: 'Biyoloji notu',
    );

    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MaterialWorkspaceScreen(runtime: runtime, materialId: materialId),
      ),
    );
    await _pumpUntilFound(tester, find.text('Kendi cümlelerinle anlat ve geri bildirim al.'));

    expect(find.text('Kendi cümlelerinle anlat ve geri bildirim al.'), findsOneWidget);
    await _tapVisible(tester, find.text('Açıkla'));
    await _pumpUntilFound(tester, find.text('Anlatımımı değerlendir'));

    expect(find.text('Kendi cümlelerinle anlat'), findsOneWidget);
    expect(find.text('Anlatımımı değerlendir'), findsOneWidget);
    expect(find.text('Kaynağına dayalı açıklama'), findsNothing);
  });
}
