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

Future<void> _waitForTutorSubmitToFinish(
  WidgetTester tester, {
  required Finder questionField,
  int maxWaits = 250,
}) async {
  for (var i = 0; i < maxWaits; i++) {
    await tester.pump();
    final field = tester.widget<TextField>(questionField);
    if ((field.controller?.text ?? '').isEmpty) return;

    // SQLite futures complete on real wall time, while their widget
    // continuations advance on tester pumps. Alternate both clocks so the
    // assertion is stable whether the submit is instant or CI-load delayed.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  }
  final field = tester.widget<TextField>(questionField);
  expect(field.controller?.text ?? '', isEmpty, reason: 'Tutor submit should finish before response UI assertions.');
}

Future<void> _scrollTutorUntilFound(WidgetTester tester, Finder target, {int maxSteps = 40}) async {
  final listFinder = find.byKey(const ValueKey('grounded-tutor-scroll'));
  expect(listFinder, findsOneWidget);
  final list = tester.widget<ListView>(listFinder);
  final controller = list.controller;
  expect(controller, isNotNull);
  expect(controller!.hasClients, isTrue);
  expect(controller.position.viewportDimension, greaterThan(0));

  // Tutor auto-scrolls to the newest action after a response. On compact,
  // large-text layouts that can place the supported turn just above the
  // viewport. Traverse from the top instead of repeatedly jumping to the
  // bottom, which can skip and recycle the very card this proof is checking.
  controller.jumpTo(controller.position.minScrollExtent);
  await tester.pump();

  for (var i = 0; i < maxSteps && target.evaluate().isEmpty; i++) {
    final position = controller.position;
    final next = (position.pixels + position.viewportDimension * 0.55)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((next - position.pixels).abs() < 0.5) break;
    controller.jumpTo(next);
    await tester.pump();
  }
  expect(target, findsOneWidget);
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
    // Verify the non-evidence boundary while the header is actually in the
    // compact ListView viewport; scrolling can legitimately recycle it.
    expect(find.textContaining('öğrenme kanıtı'), findsWidgets);
    await _scrollTutorUntilFound(tester, find.byKey(const ValueKey('grounded-tutor-empty')));

    final questionField = find.byKey(const ValueKey('grounded-tutor-question'));
    await tester.enterText(questionField, 'Klorofil ne işe yarar?');
    final send = find.byKey(const ValueKey('grounded-tutor-send')).hitTestable();
    expect(send, findsOneWidget);
    await tester.tap(send);
    await _waitForTutorSubmitToFinish(tester, questionField: questionField);
    await _scrollTutorUntilFound(tester, find.textContaining('TUTOR · KAYNAĞA BAĞLI'));
    expect(find.textContaining('TUTOR · KAYNAĞA BAĞLI'), findsOneWidget);
    expect(find.textContaining('Klorofil ışığın soğurulmasına yardım eder.'), findsOneWidget);

    await _scrollTutorUntilFound(tester, find.byKey(const ValueKey('grounded-tutor-next-actions')));
    expect(find.byKey(const ValueKey('grounded-tutor-next-actions')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
