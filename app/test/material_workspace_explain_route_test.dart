import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/app_runtime.dart';
import 'package:sesli_ogren/src/app/material_workspace_screen.dart';
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
