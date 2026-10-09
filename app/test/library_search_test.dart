import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/app_runtime.dart';
import 'package:sesli_ogren/src/app/product_shell_screen.dart';
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

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder, {int maxPumps = 100}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Expected Library widget was not reached within bounded pumps.');
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

void main() {
  sqfliteFfiInit();

  testWidgets('Library filters materials by their learner-facing title and can clear the query', (tester) async {
    final store = await SqliteSourceStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    addTearDown(store.close);
    final ingest = SourceIngestService(
      store: store,
      pdfTextExtractor: const _UnusedPdfExtractor(),
    );
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(
        sourceStore: store,
        learningStore: store.learningTruthStore(),
      ),
      telemetry: store.operationalTelemetry(),
    );

    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: const MaterialId('library-biology'),
      text: 'Fotosentez bitkilerde enerji dönüşümünü açıklar.',
      sourceName: 'Biyoloji · Fotosentez',
    );
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: const MaterialId('library-physics'),
      text: 'Newton yasaları hareket ve kuvvet ilişkisini açıklar.',
      sourceName: 'Fizik · Newton Yasaları',
    );
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: const MaterialId('library-history'),
      text: 'Sanayi Devrimi üretim biçimlerini dönüştürdü.',
      sourceName: 'Tarih · Sanayi Devrimi',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: ProductShellScreen(runtime: runtime),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('Kütüphane'));
    await _tapVisible(tester, find.text('Kütüphane').last);
    await _pumpUntilFound(tester, find.byKey(const ValueKey('library-search')));

    await tester.enterText(find.byKey(const ValueKey('library-search')), 'fizik');
    await tester.pump();

    expect(find.text('Fizik · Newton Yasaları'), findsOneWidget);
    expect(find.text('Biyoloji · Fotosentez'), findsNothing);
    expect(find.text('Tarih · Sanayi Devrimi'), findsNothing);
    expect(find.text('1 / 3 materyal'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('library-search')), 'astronomi');
    await tester.pump();
    expect(find.text('Eşleşen materyal bulunamadı'), findsOneWidget);

    await _tapVisible(tester, find.byTooltip('Aramayı temizle'));
    await tester.pump();

    expect(find.text('Biyoloji · Fotosentez'), findsOneWidget);
    expect(find.text('Fizik · Newton Yasaları'), findsOneWidget);
    expect(find.text('Tarih · Sanayi Devrimi'), findsOneWidget);
    expect(find.text('3 materyal'), findsOneWidget);
  });
}
