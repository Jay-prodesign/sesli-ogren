import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/app_runtime.dart';
import 'package:sesli_ogren/src/app/first_run_onboarding.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/learning/recall_learning_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _UnusedPdfExtractor implements PdfTextExtractor {
  const _UnusedPdfExtractor();

  @override
  Future<ExtractedPdf> extract(Uint8List bytes, {required String sourceName}) {
    throw UnimplementedError();
  }
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Expected widget was not reached within bounded pumps.');
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

void main() {
  sqfliteFfiInit();

  test('learner purge removes onboarding completion', () async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);

    final learner = AppRuntime.localM5LearnerFixture;
    await store.markOnboardingCompleted(learner: learner, updatedAt: DateTime.utc(2026, 10, 7, 9, 32));
    expect(await store.onboardingCompleted(learner: learner), isTrue);

    await store.purgeLearnerData(learner: learner);

    expect(await store.onboardingCompleted(learner: learner), isFalse);
  });

  testWidgets('first-run onboarding explains learning truth and persists completion', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor()),
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: FirstRunOnboardingGate(
          runtime: runtime,
          child: const Scaffold(body: Text('APP_READY')),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('Materyalinle başla'));
    expect(find.text('APP_READY'), findsNothing);

    await _tapVisible(tester, find.text('Devam et'));
    await tester.pump();
    expect(find.text('Öğrenmeyi kanıtla'), findsOneWidget);
    expect(find.textContaining('tek başına öğrendiğin anlamına gelmez'), findsOneWidget);

    await _tapVisible(tester, find.text('Devam et'));
    await tester.pump();
    expect(find.text('Kontrol sende'), findsOneWidget);

    await _tapVisible(tester, find.text('Öğrenmeye başla'));
    await _pumpUntilFound(tester, find.text('APP_READY'));
    expect(await store.onboardingCompleted(learner: runtime.learner), isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: FirstRunOnboardingGate(
          runtime: runtime,
          child: const Scaffold(body: Text('APP_READY_AGAIN')),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('APP_READY_AGAIN'));
    expect(find.text('Materyalinle başla'), findsNothing);
  });
}
