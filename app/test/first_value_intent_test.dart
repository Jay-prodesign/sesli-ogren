import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/app_runtime.dart';
import 'package:sesli_ogren/src/app/focus_screen.dart';
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
  fail('Expected first-value route was not reached within bounded pumps.');
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 220, scrollable: find.byType(Scrollable).last);
  await tester.pump();
  await tester.tap(finder);
}

void main() {
  sqfliteFfiInit();

  testWidgets('new source asks one intent question before evidence and keeps paths reversible', (tester) async {
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
    const materialId = MaterialId('first-value-intent-material');
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: materialId,
      text: 'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür. Bu kısa kaynak ilk değer yolunu seçmek için yeterlidir.',
      sourceName: 'İlk değer notu',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LivingDeskReviewScope(
          child: MaterialWorkspaceScreen(
            runtime: runtime,
            materialId: materialId,
            showFirstValueIntent: true,
          ),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const ValueKey('first-value-intent')));

    expect(find.text('Şimdi bununla ne yapmak istiyorsun?'), findsOneWidget);
    expect(find.text('Dinlemek istiyorum'), findsOneWidget);
    expect(find.text('Hızlıca anlamak istiyorum'), findsOneWidget);
    expect(find.text('Bildiğimi kontrol etmek istiyorum'), findsOneWidget);
    expect(find.text('Birlikte çalışalım'), findsOneWidget);
    expect(find.text('Sen öner · Önce kaynağı oku'), findsOneWidget);
    expect(find.textContaining('Henüz öğrenme kanıtın yok'), findsOneWidget);

    await _tapVisible(tester, find.text('Sen öner · Önce kaynağı oku'));
    await _pumpUntilFound(tester, find.byType(SourceReaderScreen));
    expect(find.text('İlk değer notu'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await _pumpUntilFound(tester, find.text('Birlikte çalışalım'));
    await _tapVisible(tester, find.text('Birlikte çalışalım'));
    await _pumpUntilFound(tester, find.text('KISA ODAK · 3 ADIM'));
    expect(find.byType(FocusScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
