import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/account/account_overview_gateway.dart';
import 'package:sesli_ogren/src/app/account_entry_screen.dart';
import 'package:sesli_ogren/src/app/app_runtime.dart';
import 'package:sesli_ogren/src/app/app_theme.dart';
import 'package:sesli_ogren/src/app/daily_study_plan.dart';
import 'package:sesli_ogren/src/app/atelier_learning_surfaces.dart';
import 'package:sesli_ogren/src/app/explain_back_screen.dart';
import 'package:sesli_ogren/src/app/first_value_intent_surface.dart';
import 'package:sesli_ogren/src/app/flashcard_screen.dart';
import 'package:sesli_ogren/src/app/focus_screen.dart';
import 'package:sesli_ogren/src/app/listen_screen.dart';
import 'package:sesli_ogren/src/app/learning_slice_screen.dart';
import 'package:sesli_ogren/src/app/product_shell_screen.dart';
import 'package:sesli_ogren/src/app/quick_recap_screen.dart';
import 'package:sesli_ogren/src/app/quiz_screen.dart';
import 'package:sesli_ogren/src/app/living_study_desk_home.dart';
import 'package:sesli_ogren/src/app/source_reader_screen.dart';
import 'package:sesli_ogren/src/app/study_plan_screen.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/domain/authenticated_learner.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sesli_ogren/src/domain/learning_truth.dart';
import 'package:sesli_ogren/src/domain/study_plan.dart';
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

class _VisualAccountOverviewGateway implements AccountOverviewGateway {
  const _VisualAccountOverviewGateway();

  @override
  Future<AccountOverview?> load({required AuthenticatedLearner learner}) async => AccountOverview(
    locale: 'tr-TR',
    accountStatus: 'active',
    plan: 'free',
    entitlementStatus: 'active',
    usage: [
      AccountUsageEntry(periodStart: DateTime.utc(2026, 10, 11), capability: 'explain', consumed: 3),
      AccountUsageEntry(periodStart: DateTime.utc(2026, 10, 11), capability: 'summary', consumed: 2),
    ],
    dailyLimits: const {'summary_daily': 20, 'explain_daily': 20, 'focus_daily': 20, 'explain_back_daily': 20},
  );
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
  final sourceVersion = SourceVersionRecord(
    identity: const SourceVersionIdentity(
      materialId: materialId,
      sourceVersionId: versionId,
      contentDigest: 'visual-source-digest',
      trustClass: SourceTrustClass.userProvided,
      knowledgeClass: SourceKnowledgeClass.learnerOwned,
    ),
    mediaType: SourceMediaType.pastedText,
    sourceName: 'Fotosentez: ışık ve enerji',
    mimeType: 'text/plain',
    byteSize: source.length,
    inlineText: source,
    createdAt: now,
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
    responseLength: 9,
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
  const todaySecondaryMaterialId = MaterialId('visual-today-secondary');
  const todaySecondaryVersionId = SourceVersionId('visual-today-secondary-version');
  final todaySecondaryMaterial = MaterialRecord(
    id: todaySecondaryMaterialId,
    title: 'Momentum: soru çözüm notu',
    mediaType: SourceMediaType.pastedText,
    lifecycleStatus: MaterialLifecycleStatus.active,
    processingState: MaterialProcessingState.ready,
    createdAt: now,
    updatedAt: now,
  );
  final todayPlan = DailyStudyPlan(
    evaluatedAt: DateTime.utc(2026, 10, 13, 8),
    items: [
      DailyStudyItem(
        materialId: materialId,
        materialTitle: material.title,
        sourceVersionId: versionId,
        kind: DailyStudyActionKind.scheduledReview,
        title: 'Planlanan tekrarın hazır',
        actionLabel: 'Tekrarı aç',
        reasonCode: 'RETENTION_REVIEW_DUE',
        reasonText: 'Planlanan tekrar zamanı geldi. Yeni aktif deneme kalıcılığı yeniden ölçer.',
        activityAt: now,
        dueAt: DateTime.utc(2026, 10, 13, 7),
      ),
      DailyStudyItem(
        materialId: todaySecondaryMaterialId,
        materialTitle: todaySecondaryMaterial.title,
        sourceVersionId: todaySecondaryVersionId,
        kind: DailyStudyActionKind.sourceRepair,
        title: 'Kaynağı onar, sonra yeniden dene',
        actionLabel: 'Kaynağı gözden geçir',
        reasonCode: 'REVIEW_SOURCE',
        reasonText: 'Eksik kısmı güncel kaynaktan yeniden gör; sonra kaynağı kapatıp yeniden dene.',
        activityAt: now.subtract(const Duration(minutes: 20)),
      ),
    ],
  );
  final result = RecallAttemptResult(
    evidence: evidence,
    state: state,
    nextAction: next,
    correctAnswer: 'Fotosentez',
    sourceExcerpt: 'Fotosentez sırasında bitkiler ışık enerjisini kimyasal enerjiye dönüştürür.',
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
        theme: SesliOgrenTheme.light(),
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
        dailyStudy: todayPlan,
        sourceText: source,
        otherMaterials: [todaySecondaryMaterial],
        onOpenWorkspace: () {},
        onOpenLearning: () {},
        onOpenListen: () {},
        onOpenMaterial: (_) {},
      ),
    );
    expect(find.byKey(const ValueKey('home-next-companion')), findsOneWidget);
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
            dailyStudy: todayPlan,
            sourceText: source,
            otherMaterials: [todaySecondaryMaterial],
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

  testWidgets('LA-0040 Today queue at 390x844', (tester) async {
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
          child: Scaffold(
            body: LivingStudyDeskHome(
              material: material,
              continuation: continuation,
              dailyStudy: todayPlan,
              sourceText: source,
              otherMaterials: [todaySecondaryMaterial],
              onOpenWorkspace: () {},
              onOpenLearning: () {},
              onOpenListen: () {},
              onOpenMaterial: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    });
    await tester.pump(const Duration(milliseconds: 300));
    final queue = find.text('Bugün sırada');
    await tester.scrollUntilVisible(queue, 200, scrollable: find.byType(Scrollable).first);
    await tester.pump();
    expect(queue, findsOneWidget);
    expect(find.text('Momentum: soru çözüm notu'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/la0040_today_queue_390x844.png'));
  });

  testWidgets('LA-0040 empty Home survives 320px + large type', (tester) async {
    await capture(
      tester,
      'la0040_home_empty_320_text150',
      SingleChildScrollView(
        child: SizedBox(
          height: 980,
          child: LivingStudyDeskHome(
            material: null,
            continuation: null,
            sourceText: null,
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
    expect(find.byType(AtelierLearningRail), findsNothing);
    expect(find.byKey(const ValueKey('home-empty-truth')), findsNothing);
  });

  testWidgets('LA-0040 first source acquisition', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
        debugShowCheckedModeBanner: false,
        theme: SesliOgrenTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: LivingDeskReviewScope(child: LearningSliceScreen(runtime: runtime)),
        ),
      ),
    );
    for (var i = 0; i < 30 && find.text('PDF seç').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect(find.text('PDF seç'), findsOneWidget);
    expect(find.text('Metin yapıştır'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/la0040_source_acquisition_390x844.png'));
  });

  testWidgets('LA-0040 first-value intent', (tester) async {
    await capture(
      tester,
      'la0040_first_value_intent_390x844',
      FirstValueIntentSurface(
        material: material,
        sourceText: source,
        sourceVersion: sourceVersion,
        onReadSource: () {},
        onQuickRecap: () {},
        onRecall: () {},
        onListen: () {},
        onFocus: () {},
      ),
    );
    expect(find.text('İLK 60 SANİYE'), findsOneWidget);
    expect(find.text('Kaynağı aç'), findsOneWidget);
    expect(find.byKey(const ValueKey('first-value-recommendation-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('first-intent-companion')), findsOneWidget);
    expect(find.byType(AtelierLearningRail), findsNothing);
  });

  testWidgets('LA-0040 first-value intent survives 320px + large type', (tester) async {
    await capture(
      tester,
      'la0040_first_value_intent_320_text150',
      FirstValueIntentSurface(
        material: material,
        sourceText: source,
        sourceVersion: sourceVersion,
        onReadSource: () {},
        onQuickRecap: () {},
        onRecall: () {},
        onListen: () {},
        onFocus: () {},
      ),
      size: const Size(320, 700),
      textScaler: const TextScaler.linear(1.5),
    );
    expect(find.text('İLK 60 SANİYE'), findsOneWidget);
    expect(find.byKey(const ValueKey('first-intent-companion')), findsOneWidget);
    expect(find.byType(AtelierLearningRail), findsNothing);
    await tester.scrollUntilVisible(find.text('Diğer çalışma yolları'), 180, scrollable: find.byType(Scrollable).last);
    await tester.pump();
    expect(find.text('Diğer çalışma yolları'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('LA-0040 source Reader', (tester) async {
    await capture(
      tester,
      'la0040_reader_390x844',
      AtelierWorkspace(
        material: material,
        sourceText: source,
        sourceVersion: sourceVersion,
        continuation: continuation,
        onReadSource: () {},
        onQuickRecap: () {},
        onUpdateSource: () {},
        onRecall: () {},
        onListen: () {},
        onGroundedExplain: () {},
        onExplain: () {},
        onFlashcards: () {},
        onFocus: () {},
      ),
    );
    expect(
      find.byKey(const ValueKey('la0040-atelier-workspace-update-source')),
      findsOneWidget,
      reason: 'source-update-control-visible',
    );
  });

  testWidgets('LA-0040 Workspace survives 320px + large type', (tester) async {
    await capture(
      tester,
      'la0040_workspace_320_text150',
      AtelierWorkspace(
        material: material,
        sourceText: source,
        sourceVersion: sourceVersion,
        continuation: continuation,
        onReadSource: () {},
        onQuickRecap: () {},
        onUpdateSource: () {},
        onRecall: () {},
        onListen: () {},
        onGroundedExplain: () {},
        onExplain: () {},
        onFlashcards: () {},
        onFocus: () {},
      ),
      size: const Size(320, 700),
      textScaler: const TextScaler.linear(1.5),
    );
    expect(find.byKey(const ValueKey('workspace-compact-companion')), findsOneWidget);
    expect(find.byType(AtelierLearningRail), findsNothing);
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
            onContinueWithoutAccount: () {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Hesabını bağla'), findsOneWidget);
    expect(find.byKey(const ValueKey('account-continue-local')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/la0040_account_entry_390x844.png'));
  });

  testWidgets('LA-0040 source-grounded Flashcards', (tester) async {
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
    const flashcardMaterialId = MaterialId('visual-flashcards');
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: flashcardMaterialId,
      sourceName: material.title,
      text:
          'Fotosentez sırasında bitkiler ışık enerjisini kimyasal enerjiye dönüştürür. '
          'Klorofil ışığın soğurulmasında önemli görev alır. '
          'Karbondioksit ve su kullanılarak glikoz üretimine katkı sağlanır.',
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: SesliOgrenTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: LivingDeskReviewScope(
            child: FlashcardScreen(runtime: runtime, materialId: flashcardMaterialId),
          ),
        ),
      ),
    );
    for (var i = 0; i < 50 && find.byKey(const ValueKey('flashcards-reveal')).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect(find.byKey(const ValueKey('flashcards-reveal')), findsOneWidget);
    expect(find.byKey(const ValueKey('flashcards-companion')), findsOneWidget);
    expect(find.byKey(const ValueKey('flashcards-answer')), findsNothing);
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/la0040_flashcards_390x844.png'));

    await tester.tap(find.byKey(const ValueKey('flashcards-reveal')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(const ValueKey('flashcards-source-evidence')), findsOneWidget);
    expect(find.text('Tekrar gerekli'), findsOneWidget);
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/la0040_flashcards_revealed_390x844.png'));

    for (final expected in ['KART 2 / 3', 'KART 3 / 3']) {
      await tester.tap(find.byKey(const ValueKey('flashcards-remembered')));
      for (var i = 0; i < 50 && find.text(expected).evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 30));
      }
      expect(find.text(expected), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('flashcards-reveal')));
      await tester.pump(const Duration(milliseconds: 180));
    }
    await tester.tap(find.byKey(const ValueKey('flashcards-remembered')));
    for (var i = 0; i < 50 && find.byKey(const ValueKey('flashcards-complete')).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect(find.byKey(const ValueKey('flashcards-complete')), findsOneWidget);
    expect(find.textContaining('ustalık veya kalıcı öğrenme iddiası değildir'), findsOneWidget);
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/la0040_flashcards_complete_390x844.png'));
  });

  testWidgets('LA-0040 Flashcards source-change recovery', (tester) async {
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
    const flashcardMaterialId = MaterialId('visual-flashcards-source-change');
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: flashcardMaterialId,
      sourceName: 'İlk kart kaynağı',
      text:
          'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür. '
          'Klorofil ışığın soğurulmasına yardım eder. '
          'Karbondioksit süreçte önemli bir girdidir.',
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: SesliOgrenTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: LivingDeskReviewScope(
            child: FlashcardScreen(runtime: runtime, materialId: flashcardMaterialId),
          ),
        ),
      ),
    );
    for (var i = 0; i < 50 && find.byKey(const ValueKey('flashcards-reveal')).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.tap(find.byKey(const ValueKey('flashcards-reveal')));
    await tester.pump(const Duration(milliseconds: 180));

    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: flashcardMaterialId,
      sourceName: 'Güncel kart kaynağı',
      text:
          'Hücresel solunum glikozdaki enerjiyi kullanılabilir enerjiye dönüştürür. '
          'Mitokondri hücresel enerji dönüşümünde önemli görev alır. '
          'Oksijenli solunumda oksijen temel girdilerden biridir.',
    );
    await tester.tap(find.byKey(const ValueKey('flashcards-remembered')));
    for (var i = 0; i < 50 && find.byKey(const ValueKey('flashcards-recovery-notice')).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect(find.byKey(const ValueKey('flashcards-inline-error')), findsNothing);
    expect(find.text('Güncel kart kaynağı'), findsOneWidget);
    expect(find.text('Önceki kart yanıtı kaydedilmedi. Güncel kaynaktan devam ediyorsun.'), findsOneWidget);
    expect(find.byKey(const ValueKey('flashcards-answer')), findsNothing);
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/la0040_flashcards_source_changed_390x844.png'));
  });

  testWidgets('LA-0040 Flashcards survives 320px + large type', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
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
    const flashcardMaterialId = MaterialId('visual-flashcards-large');
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: flashcardMaterialId,
      sourceName: 'Fotosentez ve ışık enerjisi için uzun çalışma notu',
      text:
          'Fotosentez sırasında bitkiler ışık enerjisini kimyasal enerjiye dönüştürür. '
          'Klorofil ışığın soğurulmasında önemli görev alır. '
          'Karbondioksit ve su kullanılarak glikoz üretimine katkı sağlanır.',
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: SesliOgrenTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5), disableAnimations: true),
          child: LivingDeskReviewScope(
            child: FlashcardScreen(runtime: runtime, materialId: flashcardMaterialId),
          ),
        ),
      ),
    );
    for (var i = 0; i < 50 && find.byKey(const ValueKey('flashcards-reveal')).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect(find.byKey(const ValueKey('flashcards-reveal')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/la0040_flashcards_320_text150.png'));

    await tester.tap(find.byKey(const ValueKey('flashcards-reveal')));
    await tester.pump(const Duration(milliseconds: 220));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('flashcards-source-evidence')),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('flashcards-source-evidence')), findsOneWidget);
    expect(find.text('Tekrar gerekli'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/la0040_flashcards_revealed_320_text150.png'));
  });

  testWidgets('LA-0040 source-grounded Quiz / Practice Test', (tester) async {
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
    const quizMaterialId = MaterialId('visual-quiz');
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: quizMaterialId,
      sourceName: material.title,
      text:
          'Fotosentez sırasında bitkiler ışık enerjisini kimyasal enerjiye dönüştürür. '
          'Klorofil ışığın soğurulmasında önemli görev alır. '
          'Karbondioksit ve su kullanılarak glikoz üretimine katkı sağlanır.',
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: SesliOgrenTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: LivingDeskReviewScope(
            child: QuizScreen(runtime: runtime, materialId: quizMaterialId),
          ),
        ),
      ),
    );
    for (var i = 0; i < 60 && find.byKey(const ValueKey('quiz-submit')).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect(find.byKey(const ValueKey('quiz-submit')), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz-source-evidence')), findsNothing);
    expect(find.byKey(const ValueKey('quiz-companion')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/la0040_quiz_390x844.png'));

    await tester.tap(find.byKey(const ValueKey('quiz-option-0')).hitTestable());
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('quiz-submit')));
    for (var i = 0; i < 60 && find.byKey(const ValueKey('quiz-source-evidence')).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect(find.text('Doğru.'), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz-source-evidence')), findsOneWidget);
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/la0040_quiz_feedback_390x844.png'));

    await tester.tap(find.byKey(const ValueKey('quiz-next')));
    for (var i = 0; i < 60 && find.text('SORU 2 / 3').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.tap(find.byKey(const ValueKey('quiz-unknown')));
    for (var i = 0; i < 60 && find.byKey(const ValueKey('quiz-source-evidence')).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.tap(find.byKey(const ValueKey('quiz-next')));
    for (var i = 0; i < 60 && find.text('SORU 3 / 3').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.tap(find.byKey(const ValueKey('quiz-unknown')));
    for (var i = 0; i < 60 && find.byKey(const ValueKey('quiz-source-evidence')).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.tap(find.byKey(const ValueKey('quiz-next')));
    for (var i = 0; i < 60 && find.byKey(const ValueKey('quiz-complete')).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect(find.byKey(const ValueKey('quiz-complete')), findsOneWidget);
    expect(find.text('1 doğru · 0 yanlış · 2 bilmiyorum'), findsOneWidget);
    expect(
      find.textContaining('genel ustalık, sınav hazır oluşu veya kalıcı öğrenme iddiası değildir'),
      findsOneWidget,
    );
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/la0040_quiz_complete_390x844.png'));
  });

  testWidgets('LA-0040 Quiz source-change recovery', (tester) async {
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
    const quizMaterialId = MaterialId('visual-quiz-source-change');
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: quizMaterialId,
      sourceName: 'İlk quiz kaynağı',
      text:
          'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür. '
          'Klorofil ışığın soğurulmasına yardım eder. '
          'Karbondioksit süreçte önemli bir girdidir.',
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: SesliOgrenTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: LivingDeskReviewScope(
            child: QuizScreen(runtime: runtime, materialId: quizMaterialId),
          ),
        ),
      ),
    );
    for (var i = 0; i < 60 && find.byKey(const ValueKey('quiz-submit')).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.tap(find.byKey(const ValueKey('quiz-option-0')).hitTestable());
    await tester.pump();

    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: quizMaterialId,
      sourceName: 'Güncel quiz kaynağı',
      text:
          'Hücresel solunum glikozdaki enerjiyi kullanılabilir enerjiye dönüştürür. '
          'Mitokondri hücresel enerji dönüşümünde önemli görev alır. '
          'Oksijenli solunumda oksijen temel girdilerden biridir.',
    );
    await tester.tap(find.byKey(const ValueKey('quiz-submit')));
    for (var i = 0; i < 60 && find.byKey(const ValueKey('quiz-recovery-notice')).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect(find.text('Güncel quiz kaynağı'), findsWidgets);
    expect(find.text('Önceki quiz yanıtı kaydedilmedi. Güncel kaynaktan devam ediyorsun.'), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz-source-evidence')), findsNothing);
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/la0040_quiz_source_changed_390x844.png'));
  });

  testWidgets('LA-0040 Quiz survives 320px + large type', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
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
    const quizMaterialId = MaterialId('visual-quiz-large');
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: quizMaterialId,
      sourceName: 'Fotosentez ve ışık enerjisi için uzun quiz çalışma notu',
      text:
          'Fotosentez sırasında bitkiler ışık enerjisini kimyasal enerjiye dönüştürür. '
          'Klorofil ışığın soğurulmasında önemli görev alır. '
          'Karbondioksit ve su kullanılarak glikoz üretimine katkı sağlanır.',
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: SesliOgrenTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5), disableAnimations: true),
          child: LivingDeskReviewScope(
            child: QuizScreen(runtime: runtime, materialId: quizMaterialId),
          ),
        ),
      ),
    );
    for (var i = 0; i < 60 && find.byKey(const ValueKey('quiz-submit')).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect(find.byKey(const ValueKey('quiz-submit')), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz-companion')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/la0040_quiz_320_text150.png'));

    final option = find.byKey(const ValueKey('quiz-option-0'));
    for (var i = 0; i < 8 && option.hitTestable().evaluate().isEmpty; i++) {
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -120), warnIfMissed: false);
      await tester.pump();
    }
    expect(option.hitTestable(), findsOneWidget);
    await tester.tap(option.hitTestable());
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('quiz-submit')));
    for (var i = 0; i < 60 && find.byKey(const ValueKey('quiz-source-evidence')).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    final evidence = find.byKey(const ValueKey('quiz-source-evidence'));
    for (var i = 0; i < 8 && evidence.hitTestable().evaluate().isEmpty; i++) {
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -120), warnIfMissed: false);
      await tester.pump();
    }
    expect(evidence.hitTestable(), findsOneWidget);
    await tester.pump();
    expect(find.byKey(const ValueKey('quiz-next')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/la0040_quiz_feedback_320_text150.png'));
  });

  testWidgets('LA-0040 Study Plan summary and source reconciliation', (tester) async {
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
    const planMaterialId = MaterialId('visual-study-plan');
    final first = await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: planMaterialId,
      sourceName: 'Fizik ara sınav notu',
      text:
          'Momentum bir cismin kütlesi ile hızının çarpımıdır. '
          'İtme momentum değişimiyle ilişkilidir ve enerji korunumu ayrı bir fizik ilkesidir.',
    );
    await store.saveStudyTarget(
      learner: runtime.learner,
      target: StudyTargetRecord(
        id: const StudyTargetId('visual-study-target'),
        title: 'Fizik ara sınavı',
        targetDate: DateTime.utc(2026, 10, 27),
        materials: [
          StudyTargetMaterialBinding(
            materialId: planMaterialId,
            sourceVersionId: first.sourceVersion.identity.sourceVersionId,
            ordinal: 0,
          ),
        ],
        createdAt: DateTime.utc(2026, 10, 13, 8),
        updatedAt: DateTime.utc(2026, 10, 13, 8),
      ),
    );

    Future<void> pumpPlan({TextScaler textScaler = TextScaler.noScaling}) async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: SesliOgrenTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true, textScaler: textScaler),
            child: child!,
          ),
          home: LivingDeskReviewScope(child: StudyPlanScreen(runtime: runtime)),
        ),
      );
      for (var i = 0; i < 80 && find.text('Fizik ara sınavı').evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 30));
      }
      expect(find.text('Fizik ara sınavı'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    await pumpPlan();
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/la0040_study_plan_390x844.png'));

    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: planMaterialId,
      sourceName: 'Fizik ara sınav notu · güncel',
      text:
          'Enerjinin korunumu kapalı sistemde toplam enerjinin değişmediğini söyler. '
          'Kinetik ve potansiyel enerji farklı biçimler arasında dönüşebilir.',
    );
    tester.view.physicalSize = const Size(320, 700);
    await pumpPlan(textScaler: const TextScaler.linear(1.5));
    expect(find.textContaining('Eski sürümden yeni görev üretmiyoruz'), findsOneWidget);
    final changedSource = find.text('Kaynak değişti');
    final summaryScroll = find.byKey(const ValueKey('study-plan-summary-scroll'));
    expect(summaryScroll, findsOneWidget);
    for (var i = 0; i < 12 && changedSource.evaluate().isEmpty; i++) {
      await tester.drag(summaryScroll, const Offset(0, -140), warnIfMissed: false);
      await tester.pump();
    }
    expect(changedSource, findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/la0040_study_plan_reconcile_320_text150.png'));
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
        theme: SesliOgrenTheme.light(),
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

  testWidgets('LA-0040 source-first Listen survives 320px + large type', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
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
    const listenMaterialId = MaterialId('visual-listen-large-type');
    const longTitle = 'Fotosentez: ışık enerjisi ve hücresel dönüşüm için uzun çalışma notu';
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: listenMaterialId,
      text: source,
      sourceName: longTitle,
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: SesliOgrenTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5), disableAnimations: true),
          child: LivingDeskReviewScope(
            child: ListenScreen(
              runtime: runtime,
              materialId: listenMaterialId,
              speechOutput: const _NoopSpeechOutput(),
              onRecall: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(longTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/la0040_listen_320_text150.png'));
  });

  testWidgets('LA-0040 real source Reader', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: SesliOgrenTheme.light(),
        home: LivingDeskReviewScope(
          child: SourceReaderScreen(
            title: material.title,
            sourceText: source,
            sourceVersion: sourceVersion,
            onListen: () {},
            onRecap: () {},
            onRecall: () {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AtelierLearningRail), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/la0040_source_reader_390x844.png'));
  });

  testWidgets('LA-0040 real source Reader survives 320px + large type', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: SesliOgrenTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5), disableAnimations: true),
          child: LivingDeskReviewScope(
            child: SourceReaderScreen(
              title: material.title,
              sourceText: source,
              onListen: () {},
              onRecap: () {},
              onRecall: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Kaynağı kapat ve hatırla'), findsOneWidget);
    expect(find.byType(AtelierLearningRail), findsNothing);
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/la0040_source_reader_320_text150.png'));
  });

  testWidgets('LA-0040 secondary learning tools', (tester) async {
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
    const toolMaterialId = MaterialId('visual-secondary-tools');
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: toolMaterialId,
      text: source,
      sourceName: material.title,
    );
    final currentSource = await store.currentSourceVersion(learner: runtime.learner, materialId: toolMaterialId);
    expect(currentSource, isNotNull);
    final sourceForTools = currentSource!;

    Future<void> captureScreen(String name, Widget child) async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: SesliOgrenTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: LivingDeskReviewScope(child: child),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/$name.png'));
    }

    await captureScreen('la0040_quick_recap_390x844', QuickRecapScreen(runtime: runtime, materialId: toolMaterialId));
    await captureScreen(
      'la0040_focus_390x844',
      FocusScreen(runtime: runtime, source: sourceForTools, sourceText: source),
    );
    await captureScreen('la0040_explain_back_390x844', ExplainBackScreen(runtime: runtime, source: sourceForTools));
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
            promptText: '_____ sırasında bitkiler ışık enerjisini kimyasal enerjiye dönüştürür.',
            anchor: SourceAnchor(startOffset: 75, endOffset: 84),
            ruleVersion: RecallLearningService.promptRuleVersion,
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

  testWidgets('LA-0040 integrated shell Home Progress Profile', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
      accountOverview: const _VisualAccountOverviewGateway(),
    );
    final ingested = await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: const MaterialId('visual-shell-material'),
      text: source,
      sourceName: 'Fotosentez: ışık ve enerji',
    );
    final prompt = await recall.createCurrentPrompt(learner: runtime.learner, materialId: ingested.material.id);
    final attempt = await recall.openAttempt(learner: runtime.learner, actionId: prompt.id);
    await recall.submit(
      learner: runtime.learner,
      actionId: prompt.id,
      attemptId: attempt.attempt.attemptId,
      disposition: RecallResponseDisposition.answer,
      answer: 'Fotosentez',
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: SesliOgrenTheme.light(),
        home: LivingDeskReviewScope(child: ProductShellScreen(runtime: runtime)),
      ),
    );
    for (var i = 0; i < 40 && find.text('Kaldığın yer hazır.').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/la0040_shell_home_390x844.png'));

    await tester.tap(find.text('Kütüphane'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('library-material-list')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/la0040_shell_library_390x844.png'));

    await tester.tap(find.text('İlerleme'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('İlerleme'), findsWidgets);
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/la0040_shell_progress_390x844.png'));

    await tester.tap(find.text('Profil'));
    for (var i = 0; i < 40 && find.text('Ücretsiz plan').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Profil ve Ayarlar'), findsOneWidget);
    expect(find.text('Ücretsiz plan'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/la0040_shell_profile_390x844.png'));
  });

  testWidgets('LA-0040 source-evidence Result', (tester) async {
    await capture(
      tester,
      'la0040_result_390x844',
      SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: AtelierResult(
          result: result,
          answerInMemory: 'Fotosentez',
          onContinue: () {},
          sourceVersion: sourceVersion,
        ),
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
            promptText: '_____ sırasında bitkiler ışık enerjisini kimyasal enerjiye dönüştürür.',
            anchor: SourceAnchor(startOffset: 75, endOffset: 84),
            ruleVersion: RecallLearningService.promptRuleVersion,
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
        child: AtelierResult(
          result: result,
          answerInMemory: 'Fotosentez',
          onContinue: () {},
          sourceVersion: sourceVersion,
        ),
      ),
      size: const Size(320, 700),
      textScaler: const TextScaler.linear(1.5),
    );
  });
}
