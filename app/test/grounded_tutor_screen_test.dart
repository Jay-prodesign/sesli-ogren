import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/app_runtime.dart';
import 'package:sesli_ogren/src/app/grounded_tutor_screen.dart';
import 'package:sesli_ogren/src/app/living_study_desk_home.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/domain/authenticated_learner.dart';
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

void main() {
  sqfliteFfiInit();

  testWidgets('Grounded Tutor is usable at 320px large text and exposes exact source support', (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    const learner = LearnerIdentity.local();
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    const materialId = MaterialId('tutor-screen-material');
    final result = await ingest.ingestPastedText(
      learner: learner,
      materialId: materialId,
      sourceName: 'Tutor ekranı',
      text:
          'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür. '
          'Klorofil ışığın soğurulmasına yardım eder. '
          'Karbondioksit süreçte önemli bir girdidir.',
    );
    final recall = RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore());
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
          data: const MediaQueryData(size: Size(320, 844), textScaler: TextScaler.linear(1.5), disableAnimations: true),
          child: LivingDeskReviewScope(
            child: GroundedTutorScreen(runtime: runtime, source: result.sourceVersion),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('grounded-tutor-screen')), findsOneWidget);
    expect(find.byKey(const ValueKey('grounded-tutor-empty')), findsOneWidget);
    expect(find.textContaining('öğrenme kanıtı'), findsWidgets);

    await tester.enterText(find.byKey(const ValueKey('grounded-tutor-question')), 'Klorofil ne işe yarar?');
    await tester.tap(find.byKey(const ValueKey('grounded-tutor-send')));
    await tester.pumpAndSettle();

    expect(find.textContaining('KAYNAĞA BAĞLI'), findsWidgets);
    expect(find.textContaining('Klorofil'), findsWidgets);
    expect(find.byKey(const ValueKey('grounded-tutor-next-actions')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
