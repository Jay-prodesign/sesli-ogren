import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/app_runtime.dart';
import 'package:sesli_ogren/src/app/product_shell_screen.dart';
import 'package:sesli_ogren/src/app/living_study_desk_home.dart';
import 'package:sesli_ogren/src/app/listen_screen.dart';
import 'package:sesli_ogren/src/app/material_workspace_screen.dart';
import 'package:sesli_ogren/src/app/quick_recap_screen.dart';
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
    final continueAction = find.byKey(
      ValueKey('library-continue-${AppRuntime.primaryMaterialId.value}'),
    );
    expect(continueAction, findsOneWidget);
    await tapVisible(tester, continueAction);
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.text('Bu bölümü yeniden kur'), findsOneWidget);
    expect(find.text('Kaynağı kapat ve yeniden dene'), findsOneWidget);
  });

  testWidgets('Home completed action returns to the source workspace instead of replaying Recall', (tester) async {
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
    expect(find.text('Öğrenme durumu'), findsOneWidget);
    expect(find.byType(MaterialWorkspaceScreen), findsOneWidget);
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

    await tapVisible(tester, find.text('Kaynağa dön'));
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
}
