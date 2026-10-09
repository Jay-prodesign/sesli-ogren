import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/app_runtime.dart';
import 'package:sesli_ogren/src/app/learning_slice_screen.dart';
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
  fail('Expected material-title widget was not reached within bounded pumps.');
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

Future<AppRuntime> _runtime(SqliteSourceStore store) async {
  final ingest = SourceIngestService(
    store: store,
    pdfTextExtractor: const _UnusedPdfExtractor(),
  );
  return AppRuntime(
    learner: AppRuntime.localM5LearnerFixture,
    store: store,
    ingest: ingest,
    recall: RecallLearningService(
      sourceStore: store,
      learningStore: store.learningTruthStore(),
    ),
    telemetry: store.operationalTelemetry(),
  );
}

Widget _host(AppRuntime runtime, MaterialId materialId) => MaterialApp(
  home: MediaQuery(
    data: const MediaQueryData(disableAnimations: true),
    child: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => MediaQuery(
                  data: const MediaQueryData(disableAnimations: true),
                  child: LearningSliceScreen(runtime: runtime, materialId: materialId),
                ),
              ),
            ),
            child: const Text('Yeni materyal'),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  sqfliteFfiInit();

  testWidgets('pasted material keeps the learner supplied library title', (tester) async {
    final store = await SqliteSourceStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    addTearDown(store.close);
    final runtime = await _runtime(store);
    const materialId = MaterialId('named-pasted-material');

    await tester.pumpWidget(_host(runtime, materialId));
    await tester.tap(find.text('Yeni materyal'));
    await _pumpUntilFound(tester, find.text('Çalışma materyalini ekle'));

    await tester.enterText(
      find.byKey(const ValueKey('pasted-material-title')),
      'Biyoloji · Fotosentez',
    );
    await tester.enterText(
      find.byKey(const ValueKey('pasted-material-text')),
      'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürmeye yardımcı olur.',
    );
    await _tapVisible(tester, find.text('Hatırlama başlat'));
    await _pumpUntilFound(tester, find.text('Yeni materyal'));

    final material = await store.material(
      learner: runtime.learner,
      materialId: materialId,
    );
    expect(material?.title, 'Biyoloji · Fotosentez');
  });

  testWidgets('blank pasted material title derives a useful bounded library name', (tester) async {
    final store = await SqliteSourceStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    addTearDown(store.close);
    final runtime = await _runtime(store);
    const materialId = MaterialId('derived-pasted-material');

    await tester.pumpWidget(_host(runtime, materialId));
    await tester.tap(find.text('Yeni materyal'));
    await _pumpUntilFound(tester, find.text('Çalışma materyalini ekle'));

    await tester.enterText(
      find.byKey(const ValueKey('pasted-material-text')),
      'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür ve bitkinin enerji depolamasına yardım eder.',
    );
    await _tapVisible(tester, find.text('Hatırlama başlat'));
    await _pumpUntilFound(tester, find.text('Yeni materyal'));

    final material = await store.material(
      learner: runtime.learner,
      materialId: materialId,
    );
    expect(material, isNotNull);
    expect(material!.title, startsWith('Fotosentez ışık enerjisini'));
    expect(material.title, isNot('Çalışma materyalim'));
    expect(material.title.length, lessThanOrEqualTo(72));
  });
}
