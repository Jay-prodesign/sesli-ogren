import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/app_runtime.dart';
import 'package:sesli_ogren/src/app/product_shell_screen.dart';
import 'package:sesli_ogren/src/app/living_study_desk_home.dart';
import 'package:sesli_ogren/src/app/listen_screen.dart';
import 'package:sesli_ogren/src/app/material_workspace_screen.dart';
import 'package:sesli_ogren/src/app/quick_recap_screen.dart';
import 'package:sesli_ogren/src/app/source_reader_screen.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
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

Future<AppRuntime> _runtimeWithEvidence({
  required RecallResponseDisposition disposition,
  required bool submitCorrectAnswer,
}) async {
  final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
  final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
  final recall = RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore());
  final runtime = AppRuntime(
    learner: AppRuntime.localM5LearnerFixture,
    store: store,
    ingest: ingest,
    recall: recall,
    telemetry: store.operationalTelemetry(),
  );

  await ingest.ingestPastedText(
    learner: runtime.learner,
    materialId: AppRuntime.primaryMaterialId,
    text:
        'Fotosentez sırasında klorofil ışık enerjisini kimyasal enerjiye dönüştürmeye yardımcı olur. '
        'Bitkiler karbondioksit kullanır ve oksijen açığa çıkarır. '
        'Mitokondri hücresel solunumla kullanılabilir enerji üretimine katkı sağlar.',
    sourceName: 'Biyoloji çalışma notu',
  );
  final prompt = await recall.createCurrentPrompt(learner: runtime.learner, materialId: AppRuntime.primaryMaterialId);
  final session = await recall.openAttempt(learner: runtime.learner, actionId: prompt.id);
  final action = await store.learningTruthStore().recallAction(learner: runtime.learner, actionId: prompt.id);
  await recall.submit(
    learner: runtime.learner,
    actionId: prompt.id,
    attemptId: session.attempt.attemptId,
    disposition: disposition,
    answer: submitCorrectAnswer ? action!.expectedAnswer : '',
  );
  return runtime;
}

Widget _testApp(Widget home) => MaterialApp(
  builder: (context, child) =>
      MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
  home: home,
);

void usePhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

Future<void> pumpUntilFound(WidgetTester tester, Finder finder, {int maxPumps = 100}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Expected source-first route state was not reached within bounded pumps.');
}

void main() {
  testWidgets('Home review action opens the persisted repair continuation', (tester) async {
    usePhoneViewport(tester);
    final runtime = await _runtimeWithEvidence(
      disposition: RecallResponseDisposition.unknown,
      submitCorrectAnswer: false,
    );
    addTearDown(runtime.close);

    await tester.pumpWidget(_testApp(ProductShellScreen(runtime: runtime)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final action = find.text('Kaynağı gözden geçir');
    expect(action, findsOneWidget);
    await tapVisible(tester, action);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Bu bölümü yeniden kur'), findsOneWidget);
    expect(find.text('Kaynağı kapat ve yeniden dene'), findsOneWidget);
  });

  testWidgets('Library continuation opens the canonical repair step', (tester) async {
    usePhoneViewport(tester);
    final runtime = await _runtimeWithEvidence(
      disposition: RecallResponseDisposition.unknown,
      submitCorrectAnswer: false,
    );
    addTearDown(runtime.close);

    await tester.pumpWidget(_testApp(LivingDeskReviewScope(child: ProductShellScreen(runtime: runtime))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    await tapVisible(tester, find.text('Kütüphane'));
    await tester.pump(const Duration(milliseconds: 150));
    final continueAction = find.byKey(ValueKey('library-continue-${AppRuntime.primaryMaterialId.value}'));
    expect(continueAction, findsOneWidget);
    await tapVisible(tester, continueAction);
    await pumpUntilFound(tester, find.text('Bu bölümü yeniden kur'));

    expect(find.text('Bu bölümü yeniden kur'), findsOneWidget);
    expect(find.text('Kaynağı kapat ve yeniden dene'), findsOneWidget);
  });

  testWidgets('Progress exposes and opens the same canonical repair action as Home and Library', (tester) async {
    usePhoneViewport(tester);
    final runtime = await _runtimeWithEvidence(
      disposition: RecallResponseDisposition.unknown,
      submitCorrectAnswer: false,
    );
    addTearDown(runtime.close);

    await tester.pumpWidget(_testApp(LivingDeskReviewScope(child: ProductShellScreen(runtime: runtime))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    await tapVisible(tester, find.text('İlerleme'));
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('Kaynağı gözden geçir'), findsOneWidget);
    final continueAction = find.byKey(ValueKey('progress-continue-${AppRuntime.primaryMaterialId.value}'));
    expect(continueAction, findsOneWidget);
    await tapVisible(tester, continueAction);
    await pumpUntilFound(tester, find.text('Bu bölümü yeniden kur'));

    expect(find.text('Bu bölümü yeniden kur'), findsOneWidget);
    expect(find.text('Kaynağı kapat ve yeniden dene'), findsOneWidget);
  });

  testWidgets('Home other-material entry preserves that material canonical repair action', (tester) async {
    usePhoneViewport(tester);
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    final recall = RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore());
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: recall,
      telemetry: store.operationalTelemetry(),
    );
    addTearDown(runtime.close);

    const repairMaterial = MaterialId('home-other-repair');
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: repairMaterial,
      text:
          'Mitokondri hücresel solunumla enerji dönüşümüne katkı sağlar. '
          'ATP hücrenin doğrudan kullanabildiği enerji taşıyıcılarından biridir.',
      sourceName: 'Enerji onarım notu',
    );
    final repairPrompt = await recall.createCurrentPrompt(
      learner: runtime.learner,
      materialId: repairMaterial,
    );
    final repairSession = await recall.openAttempt(learner: runtime.learner, actionId: repairPrompt.id);
    await recall.submit(
      learner: runtime.learner,
      actionId: repairPrompt.id,
      attemptId: repairSession.attempt.attemptId,
      disposition: RecallResponseDisposition.unknown,
      answer: '',
    );

    await Future<void>.delayed(const Duration(milliseconds: 2));
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: AppRuntime.primaryMaterialId,
      text:
          'Fotosentez sırasında klorofil ışık enerjisinin yakalanmasına yardım eder. '
          'Bitkiler bu süreçte karbondioksit kullanır.',
      sourceName: 'Güncel çalışma notu',
    );

    await tester.pumpWidget(_testApp(LivingDeskReviewScope(child: ProductShellScreen(runtime: runtime))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('Güncel çalışma notu'), findsWidgets);
    expect(find.text('Enerji onarım notu'), findsOneWidget);
    await tapVisible(tester, find.text('Enerji onarım notu'));
    await pumpUntilFound(tester, find.text('Bu bölümü yeniden kur'));

    expect(find.text('Kaynağı kapat ve yeniden dene'), findsOneWidget);
    expect(find.byType(MaterialWorkspaceScreen), findsNothing);
  });

  testWidgets('Home completed action returns directly to the current source instead of replaying Recall', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final runtime = await _runtimeWithEvidence(
      disposition: RecallResponseDisposition.answer,
      submitCorrectAnswer: true,
    );
    addTearDown(runtime.close);

    await tester.pumpWidget(_testApp(ProductShellScreen(runtime: runtime)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final action = find.text('Kaynağa dön');
    expect(action, findsOneWidget);
    await tapVisible(tester, action);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Biyoloji çalışma notu'), findsWidgets);
    expect(find.byType(SourceReaderScreen), findsOneWidget);
    expect(find.byType(LearningSliceScreen), findsNothing);
  });
  testWidgets('source-first scope survives Home to Workspace, Recap and Listen routes', (tester) async {
    usePhoneViewport(tester);
    final runtime = await _runtimeWithEvidence(
      disposition: RecallResponseDisposition.answer,
      submitCorrectAnswer: true,
    );
    addTearDown(runtime.close);

    await tester.pumpWidget(_testApp(LivingDeskReviewScope(child: ProductShellScreen(runtime: runtime))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final workspaceEntry = find.byKey(const ValueKey('la0040-living-material-open'));
    expect(workspaceEntry, findsOneWidget);
    await tapVisible(tester, workspaceEntry);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.byType(MaterialWorkspaceScreen), findsOneWidget);
    expect(LivingDeskReviewScope.active(tester.element(find.byType(MaterialWorkspaceScreen))), isTrue);

    final quickRecapButton = find.byKey(const ValueKey('la0040-atelier-workspace-recap'));
    expect(quickRecapButton, findsOneWidget);
    await tapVisible(tester, quickRecapButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.byType(QuickRecapScreen), findsOneWidget);
    expect(LivingDeskReviewScope.active(tester.element(find.byType(QuickRecapScreen))), isTrue);

    Navigator.of(tester.element(find.byType(QuickRecapScreen))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(MaterialWorkspaceScreen), findsOneWidget);

    final listenButton = find.byKey(const ValueKey('la0040-atelier-workspace-listen'));
    expect(listenButton, findsOneWidget);
    await tester.tap(listenButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.byType(ListenScreen), findsOneWidget);
    expect(LivingDeskReviewScope.active(tester.element(find.byType(ListenScreen))), isTrue);
  });

  testWidgets('source replacement returns Home to a fresh active-learning start', (tester) async {
    usePhoneViewport(tester);
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
    const materialId = AppRuntime.primaryMaterialId;
    final first = await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: materialId,
      text: 'Klorofil ışık enerjisinin soğurulmasına yardım eder. Bitkiler enerji üretir.',
      sourceName: 'Biyoloji sürüm 1',
    );
    await store.saveReaderResumeProgress(
      learner: runtime.learner,
      materialId: materialId,
      sourceVersionId: first.sourceVersion.identity.sourceVersionId,
      progress: 0.51,
      updatedAt: DateTime.utc(2026, 10, 10, 8),
    );

    final prompt = await runtime.recall.createCurrentPrompt(learner: runtime.learner, materialId: materialId);
    final action = await store.learningTruthStore().recallAction(learner: runtime.learner, actionId: prompt.id);
    expect(action, isNotNull);
    final attempt = await runtime.recall.openAttempt(learner: runtime.learner, actionId: prompt.id);
    await runtime.recall.submit(
      learner: runtime.learner,
      actionId: prompt.id,
      attemptId: attempt.attempt.attemptId,
      disposition: RecallResponseDisposition.answer,
      answer: action!.expectedAnswer,
    );

    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: materialId,
      text: 'Mitokondri hücresel solunumla enerji üretimine katkı sağlar. Yeni ve ayrı kaynak sürümü.',
      sourceName: 'Biyoloji sürüm 2',
    );

    await tester.pumpWidget(_testApp(LivingDeskReviewScope(child: ProductShellScreen(runtime: runtime))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('İlk hatırlama denemeni yap'), findsOneWidget);
    expect(find.text('Okumaya devam et'), findsNothing);
    expect(find.text('Dinlemeye devam et'), findsNothing);
    expect(find.text('Biyoloji sürüm 2'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home resumes the exact Reader source position before passive alternatives', (tester) async {
    usePhoneViewport(tester);
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
    const materialId = AppRuntime.primaryMaterialId;
    final source = await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: materialId,
      text: List<String>.generate(
        80,
        (index) => 'Bölüm ${index + 1}: Fotosentez ışık enerjisini dönüştürür.',
      ).join(' '),
      sourceName: 'Uzun biyoloji notu',
    );
    await store.saveReaderResumeProgress(
      learner: runtime.learner,
      materialId: materialId,
      sourceVersionId: source.sourceVersion.identity.sourceVersionId,
      progress: 0.47,
      updatedAt: DateTime.utc(2026, 10, 10, 9),
    );

    await tester.pumpWidget(_testApp(LivingDeskReviewScope(child: ProductShellScreen(runtime: runtime))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('Okumaya kaldığın yerden devam et'), findsOneWidget);
    final action = find.text('Okumaya devam et');
    expect(action, findsOneWidget);
    await tapVisible(tester, action);
    await pumpUntilFound(tester, find.byType(SourceReaderScreen));

    expect(find.byType(SourceReaderScreen), findsOneWidget);
    expect(find.text('Uzun biyoloji notu'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
