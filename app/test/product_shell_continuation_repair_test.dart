import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/app_runtime.dart';
import 'package:sesli_ogren/src/app/product_shell_screen.dart';
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

class _RepairingRecallService extends RecallLearningService {
  _RepairingRecallService({required super.sourceStore, required super.learningStore});

  int reopenCalls = 0;
  int repairCalls = 0;

  @override
  Future<LearningContinuation?> reopen({required AuthenticatedLearner learner, required MaterialId materialId}) async {
    reopenCalls++;
    throw const RecallLearningException('simulated stale derived projection');
  }

  @override
  Future<LearningContinuation?> repairContinuation({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  }) async {
    repairCalls++;
    return null;
  }
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder, {int maxPumps = 100}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Expected repaired product shell was not reached within bounded pumps.');
}

void main() {
  sqfliteFfiInit();

  testWidgets('first material action opens the real source-entry flow', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    const learner = AppRuntime.localM5LearnerFixture;
    final runtime = AppRuntime(
      learner: learner,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
    );

    await tester.pumpWidget(MaterialApp(home: ProductShellScreen(runtime: runtime)));
    await _pumpUntilFound(tester, find.text('Materyal ekle'));
    await tester.tap(find.text('Materyal ekle'));
    await tester.pumpAndSettle();
    expect(find.byType(ProductShellScreen), findsOneWidget);
    expect(find.text('Kütüphane şu anda yüklenemedi.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('product shell repairs stale continuation without blocking the library', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    const learner = AppRuntime.localM5LearnerFixture;
    await ingest.ingestPastedText(
      learner: learner,
      materialId: const MaterialId('repair-shell-material'),
      text: 'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür.',
      sourceName: 'Biyoloji · Fotosentez',
    );

    final recall = _RepairingRecallService(sourceStore: store, learningStore: store.learningTruthStore());
    final runtime = AppRuntime(
      learner: learner,
      store: store,
      ingest: ingest,
      recall: recall,
      telemetry: store.operationalTelemetry(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: ProductShellScreen(runtime: runtime),
        ),
      ),
    );

    await _pumpUntilFound(tester, find.text('Biyoloji · Fotosentez'));
    expect(find.text('Kütüphane şu anda yüklenemedi.'), findsNothing);
    expect(recall.reopenCalls, greaterThan(0));
    expect(recall.repairCalls, greaterThan(0));
  });
}
