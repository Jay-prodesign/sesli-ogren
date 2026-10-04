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

    await tester.pumpWidget(
      MaterialApp(home: LearningSliceScreen(runtime: runtime)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sesli Öğren'), findsOneWidget);
    expect(find.text('Çalışma materyalini ekle'), findsOneWidget);
    expect(find.text('Recall oluştur'), findsOneWidget);
    expect(find.text('İpucu'), findsNothing);
  });
}
