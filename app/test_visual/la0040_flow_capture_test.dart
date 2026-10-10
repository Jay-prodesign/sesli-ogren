import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/account_entry_screen.dart';
import 'package:sesli_ogren/src/app/app_runtime.dart';
import 'package:sesli_ogren/src/app/app_theme.dart';
import 'package:sesli_ogren/src/app/atelier_learning_surfaces.dart';
import 'package:sesli_ogren/src/app/listen_screen.dart';
import 'package:sesli_ogren/src/app/living_study_desk_home.dart';
import 'package:sesli_ogren/src/app/source_reader_screen.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/domain/authenticated_learner.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sesli_ogren/src/domain/learning_truth.dart';
import 'package:sesli_ogren/src/learning/recall_learning_service.dart';
import 'package:sesli_ogren/src/speech/device_speech_output.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _UnusedPdfExtractor implements PdfTextExtractor {
  const _UnusedPdfExtractor();

  @override
  Future<ExtractedPdf> extract(Uint8List bytes, {required String sourceName}) {
    throw UnimplementedError();
  }
}

class _NoopSpeechOutput implements SpeechOutput {
  const _NoopSpeechOutput();

  @override
  Future<void> speak(
    String text, {
    required String locale,
    required VoidCallback onStart,
    required VoidCallback onDone,
    required ValueChanged<Object> onError,
    double rateMultiplier = 1.0,
  }) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUpAll(() async {
    Future<void> loadFont(String family, String path) async {
      final bytes = await File(path).readAsBytes();
      final loader = FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }

    await loadFont('Roboto', '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf');
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot == null || flutterRoot.isEmpty) {
      throw StateError('FLUTTER_ROOT is required for material icon capture.');
    }
    await loadFont('MaterialIcons', '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  });

  final now = DateTime.utc(2026, 10, 8);
  const materialId = MaterialId('visual-fixture');
  const versionId = SourceVersionId('visual-version');
  const evidenceId = LearnerEvidenceId('visual-evidence');
  const source =
      'Fotosentez sırasında bitkiler ışık enerjisini kimyasal enerjiye dönüştürür. Klorofil ışığın soğurulmasında görev alır. Bu süreçte karbondioksit ve su kullanılır.';
  final material = MaterialRecord(
    id: materialId,
    title: 'Fotosentez: ışık ve enerji',
    mediaType: SourceMediaType.pastedText,
    lifecycleStatus: MaterialLifecycleStatus.active,
    processingState: MaterialProcessingState.ready,
    createdAt: now,
    updatedAt: now,
  );
  final evidence = LearnerEvidence(
    id: evidenceId,
    attemptId: const RecallAttemptId('visual-attempt'),
    actionId: const RecallActionId('visual-action'),
    materialId: materialId,
    sourceVersionId: versionId,
    extractedContentId: const ExtractedContentId('visual-extract'),
    outcome: RecallOutcome.correct,
    assistance: RecallAssistance.none,
    responseDigest: 'visual-only',
    responseLength: 8,
    ruleVersion: RecallTruthPolicy.evidenceRuleVersion,
    createdAt: now,
  );
  final state = LearnerState(
    materialId: materialId,
    sourceVersionId: versionId,
    kind: RecallStateKind.retrievedOnce,
    evidenceCount: 1,
    latestEvidenceId: evidenceId,
    ruleVersion: RecallTruthPolicy.stateRuleVersion,
    updatedAt: now,
  );
  final next = RecallTruthPolicy.nextActionFor(
    materialId: materialId,
    sourceVersionId: versionId,
    evidenceId: evidenceId,
    outcome: RecallOutcome.correct,
    createdAt: now,
  );
  final continuation = LearningContinuation(state: state, nextAction: next);
  final result = RecallAttemptResult(
    evidence: evidence,
    state: state,
    nextAction: next,
    correctAnswer: 'Klorofil',
    sourceExcerpt: 'Klorofil ışığın soğurulmasında görev alır.',
  );

  Future<void> capture(
    WidgetTester tester,
    String name,
    Widget child, {
    Size size = const Size(390, 844),
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          data: MediaQueryData(textScaler: textScaler, disableAnimations: true),
          child: Scaffold(body: child),
        ),
      ),
    );
    // Resolve asynchronously decoded character assets before capturing the first frame.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    });
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/$name.png'));
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  testWidgets('LA-0040 populated Home', (tester) async {
    await capture(
      tester,
      'la0040_home_populated_390x844',
      LivingStudyDeskHome(
        material: material,
        continuation: continuation,
        sourceText: source,
        otherMaterials: const [],
        onOpenWorkspace: () {},
        onOpenLearning: () {},
        onOpenListen: () {},
        onOpenMaterial: (_) {},
      ),
    );
  });

  testWidgets('LA-0040 populated Home survives 320px + large type', (tester) async {
    await capture(
      tester,
      'la0040_home_populated_320_text150',
      SingleChildScrollView(
        child: SizedBox(
          height: 920,
          child: LivingStudyDeskHome(
            material: material,
            continuation: continuation,
            sourceText: source,
            otherMaterials: const [],
            onOpenWorkspace: () {},
            onOpenLearning: () {},
            onOpenListen: () {},
            onOpenMaterial: (_) {},
          ),
        ),
      ),
      size: const Size(320, 700),
      textScaler: const TextScaler.linear(1.5),
    );
  });

  testWidgets('LA-0040 source Reader', (tester) async {
    await capture(
      tester,
      'la0040_reader_390x844',
      AtelierWorkspace(
        material: material,
        sourceText: source,
        onRecall: () {},
        onListen: () {},
        onExplain: () {},
        onFocus: () {},
      ),
    );
  });

  testWidgets('LA-0040 account entry', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: SesliOgrenTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: AccountEntryScreen(
            requestOtp: (_) async {},
            verifyOtp: ({required email, required token}) async =>
                const AuthenticatedLearner(id: LearnerId('visual-account-user')),
            onAuthenticated: (_) async {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/la0040_account_entry_390x844.png'));
  });

  testWidgets('LA-0040 source-first Listen', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
    const listenMaterialId = MaterialId('visual-listen-material');
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: listenMaterialId,
      text: source,
      sourceName: 'Fotosentez: ışık ve enerji',
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: LivingDeskReviewScope(
          child: ListenScreen(
            runtime: runtime,
            materialId: listenMaterialId,
            speechOutput: const _NoopSpeechOutput(),
            onRecall: () {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/la0040_listen_390x844.png'));
  });

  testWidgets('LA-0040 real source Reader', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: LivingDeskReviewScope(
          child: SourceReaderScreen(
            title: material.title,
            sourceText: source,
            onListen: () {},
            onRecap: () {},
            onRecall: () {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/la0040_source_reader_390x844.png'));
  });

  testWidgets('LA-0040 source-hidden Recall', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await capture(
      tester,
      'la0040_recall_390x844',
      SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: AtelierRecall(
          prompt: const RecallPrompt(
            id: RecallActionId('visual-action'),
            materialId: materialId,
            sourceVersionId: versionId,
            promptText: 'Işığın soğurulmasında hangi pigment görev alır?',
            anchor: SourceAnchor(startOffset: 75, endOffset: 84),
            ruleVersion: 'visual-fixture',
          ),
          controller: controller,
          busy: false,
          onSubmit: () {},
          onHint: () {},
          onReveal: () {},
          onUnknown: () {},
        ),
      ),
    );
  });

  testWidgets('LA-0040 source-evidence Result', (tester) async {
    await capture(
      tester,
      'la0040_result_390x844',
      SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: AtelierResult(result: result, answerInMemory: 'Klorofil', onContinue: () {}),
      ),
    );
  });

  testWidgets('LA-0040 Recall and Result survive 320px + large type', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await capture(
      tester,
      'la0040_recall_320_text150',
      SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AtelierRecall(
          prompt: const RecallPrompt(
            id: RecallActionId('visual-action'),
            materialId: materialId,
            sourceVersionId: versionId,
            promptText: 'Işığın soğurulmasında hangi pigment görev alır?',
            anchor: SourceAnchor(startOffset: 75, endOffset: 84),
            ruleVersion: 'visual-fixture',
          ),
          controller: controller,
          busy: false,
          onSubmit: () {},
          onHint: () {},
          onReveal: () {},
          onUnknown: () {},
        ),
      ),
      size: const Size(320, 700),
      textScaler: const TextScaler.linear(1.5),
    );

    await capture(
      tester,
      'la0040_result_320_text150',
      SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AtelierResult(result: result, answerInMemory: 'Klorofil', onContinue: () {}),
      ),
      size: const Size(320, 700),
      textScaler: const TextScaler.linear(1.5),
    );
  });
}
