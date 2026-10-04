import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/app_runtime.dart';
import 'package:sesli_ogren/src/app/learning_slice_screen.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
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

Widget testShell(AppRuntime runtime) {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: LearningSliceScreen(runtime: runtime),
    ),
  );
}

void main() {
  sqfliteFfiInit();

  testWidgets('production learning slice boots at truthful source entry', (
    tester,
  ) async {
    final store = await SqliteSourceStore.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(store.close);

    final runtime = AppRuntime(
      store: store,
      ingest: SourceIngestService(
        store: store,
        pdfTextExtractor: const _UnusedPdfExtractor(),
      ),
      recall: RecallLearningService(
        sourceStore: store,
        learningStore: store.learningTruthStore(),
      ),
    );

    await tester.pumpWidget(testShell(runtime));
    await tester.pumpAndSettle();

    expect(find.text('Sesli Öğren'), findsOneWidget);
    expect(find.text('Çalışma materyalini ekle'), findsOneWidget);
    expect(find.text('Recall oluştur'), findsOneWidget);
    expect(find.text('İpucu'), findsNothing);
  });


  testWidgets('source to Recall result persists and reopens as one continuation', (
    tester,
  ) async {
    final store = await SqliteSourceStore.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(store.close);

    final ingest = SourceIngestService(
      store: store,
      pdfTextExtractor: const _UnusedPdfExtractor(),
      now: () => DateTime.utc(2026, 10, 4, 16),
    );
    final recall = RecallLearningService(
      sourceStore: store,
      learningStore: store.learningTruthStore(),
      now: () => DateTime.utc(2026, 10, 4, 16, 1),
    );
    final runtime = AppRuntime(store: store, ingest: ingest, recall: recall);

    await ingest.ingestPastedText(
      learner: AppRuntime.learner,
      materialId: AppRuntime.primaryMaterialId,
      text:
          'Fotosentez sırasında klorofil ışık enerjisini kimyasal enerjiye '
          'dönüştürmeye yardımcı olur. Bitkiler bu süreçte karbondioksit kullanır.',
      sourceName: 'Biyoloji notu',
    );
    final prompt = await recall.createCurrentPrompt(
      learner: AppRuntime.learner,
      materialId: AppRuntime.primaryMaterialId,
    );
    final action = await store.learningTruthStore().recallAction(
      learner: AppRuntime.learner,
      actionId: prompt.id,
    );
    expect(action, isNotNull);

    await tester.pumpWidget(testShell(runtime));
    await tester.pumpAndSettle();

    expect(find.text('Hatırla'), findsOneWidget);
    await tester.enterText(find.byType(TextField), action!.expectedAnswer);
    await tester.tap(find.text('Yanıtla'));
    await tester.pumpAndSettle();

    expect(find.text('İpucusuz hatırladın'), findsOneWidget);
    expect(find.text('Sıradaki adım'), findsOneWidget);
    await tester.tap(find.text('Devam et'));
    await tester.pumpAndSettle();
    expect(find.text('Devam noktası'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: LearningSliceScreen(
            key: const ValueKey('reopened-slice'),
            runtime: runtime,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Devam noktası'), findsOneWidget);
    expect(find.textContaining('ONE_UNASSISTED_RETRIEVAL_OBSERVED'), findsOneWidget);
  });

  testWidgets('Reduced Motion keeps the learning slice usable', (tester) async {
    final store = await SqliteSourceStore.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(store.close);
    final runtime = AppRuntime(
      store: store,
      ingest: SourceIngestService(
        store: store,
        pdfTextExtractor: const _UnusedPdfExtractor(),
      ),
      recall: RecallLearningService(
        sourceStore: store,
        learningStore: store.learningTruthStore(),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: LearningSliceScreen(runtime: runtime),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Çalışma materyalini ekle'), findsOneWidget);
    expect(find.text('Recall oluştur'), findsOneWidget);
  });
}
