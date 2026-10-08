import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/account/account_deletion_gateway.dart';
import 'package:sesli_ogren/src/account/account_overview_gateway.dart';
import 'package:sesli_ogren/src/app/app_runtime.dart';
import 'package:sesli_ogren/src/app/learning_slice_screen.dart';
import 'package:sesli_ogren/src/app/listen_screen.dart';
import 'package:sesli_ogren/src/app/product_shell_screen.dart';
import 'package:sesli_ogren/src/app/profile_surface.dart';
import 'package:sesli_ogren/src/app/sesli_ogren_app.dart';
import 'package:sesli_ogren/src/auth/supabase_learner_auth.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/learning/recall_learning_service.dart';
import 'package:sesli_ogren/src/generation/grounded_explain_gateway.dart';
import 'package:sesli_ogren/src/speech/device_speech_output.dart';
import 'package:sesli_ogren/src/domain/authenticated_learner.dart';
import 'package:sesli_ogren/src/domain/learning_truth.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sesli_ogren/src/domain/operational_event.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _UnusedPdfExtractor implements PdfTextExtractor {
  const _UnusedPdfExtractor();

  @override
  Future<ExtractedPdf> extract(Uint8List bytes, {required String sourceName}) {
    throw UnimplementedError();
  }
}

class _ReadyExplainGateway implements GroundedExplainGateway {
  const _ReadyExplainGateway();

  @override
  Future<GroundedExplainResult> explain(GroundedExplainRequest request) async => GroundedExplainReady(
    sourceVersionId: request.sourceVersionId,
    sourceContentDigest: request.sourceContentDigest,
    explanation: 'Fotosentez, bitkinin ışık enerjisini kimyasal enerjiye dönüştürmesine yardımcı olan süreçtir.',
    keyPoints: const ['Işık enerjisi kullanılır', 'Kimyasal enerji depolanır'],
    language: 'tr-TR',
    executionRef: 'test:grounded-explain',
  );
}

class _RecordingAccountDeletionGateway implements AccountDeletionGateway {
  int calls = 0;

  @override
  Future<void> deleteAccount({required AuthenticatedLearner learner}) async {
    calls += 1;
  }
}

class _FailingAccountDeletionGateway implements AccountDeletionGateway {
  const _FailingAccountDeletionGateway();

  @override
  Future<void> deleteAccount({required AuthenticatedLearner learner}) {
    throw const AccountDeletionException('test failure');
  }
}

class _ReadyAccountOverviewGateway implements AccountOverviewGateway {
  const _ReadyAccountOverviewGateway();

  @override
  Future<AccountOverview?> load({required AuthenticatedLearner learner}) async => AccountOverview(
    locale: 'tr-TR',
    accountStatus: 'active',
    plan: 'free',
    entitlementStatus: 'active',
    usage: [AccountUsageEntry(periodStart: DateTime.utc(2026, 10, 1), capability: 'grounded_explain', consumed: 3)],
  );
}

class _FakeSpeechOutput implements SpeechOutput {
  String? lastText;
  VoidCallback? _onDone;

  @override
  Future<void> speak(
    String text, {
    required String locale,
    required VoidCallback onStart,
    required VoidCallback onDone,
    required ValueChanged<Object> onError,
  }) async {
    lastText = text;
    _onDone = onDone;
    onStart();
  }

  void complete() {
    final callback = _onDone;
    _onDone = null;
    callback?.call();
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

Widget testShell(AppRuntime runtime) {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: LearningSliceScreen(runtime: runtime),
    ),
  );
}

Future<void> pumpUntilFound(WidgetTester tester, Finder finder, {int maxPumps = 100}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  fail('Expected widget was not reached within bounded pumps.');
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

Future<void> pumpUntilGone(WidgetTester tester, Finder finder, {int maxPumps = 100}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isEmpty) {
      return;
    }
  }
  fail('Expected widget did not disappear within bounded pumps.');
}

void main() {
  sqfliteFfiInit();

  test('production auth restore fails closed when Supabase config is absent', () async {
    await expectLater(SupabaseLearnerAuth.restoreSession(), throwsA(isA<LearnerAuthConfigurationException>()));
  });

  testWidgets('production app does not open learner data without auth config', (tester) async {
    await tester.pumpWidget(const SesliOgrenApp());
    await pumpUntilFound(tester, find.text('Uygulama bağlantısı henüz yapılandırılmadı.'));

    expect(find.text('Uygulama bağlantısı henüz yapılandırılmadı.'), findsOneWidget);
    expect(find.textContaining('Öğrenme verisi açılmadı'), findsOneWidget);
  });

  testWidgets('production learning slice boots at truthful source entry', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);

    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor()),
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
    );

    await tester.pumpWidget(testShell(runtime));
    await pumpUntilFound(tester, find.text('Çalışma materyalini ekle'));

    expect(find.text('Sesli Öğren'), findsOneWidget);
    expect(find.text('Çalışma materyalini ekle'), findsOneWidget);
    expect(find.text('Hatırlama başlat'), findsOneWidget);
    expect(find.text('İpucu'), findsNothing);
  });

  testWidgets('source to Recall result persists and reopens as one continuation', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);

    final ingest = SourceIngestService(
      store: store,
      pdfTextExtractor: const _UnusedPdfExtractor(),
      now: () => DateTime.utc(2026, 10, 4, 16),
    );
    final recall = RecallLearningService(
      sourceStore: store,
      learningStore: store.learningTruthStore(),
      now: () => DateTime.utc(2026, 10, 4, 16, 1),
    );
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
          'Fotosentez sırasında klorofil ışık enerjisini kimyasal enerjiye '
          'dönüştürmeye yardımcı olur. Bitkiler bu süreçte karbondioksit kullanır.',
      sourceName: 'Biyoloji notu',
    );
    final prompt = await recall.createCurrentPrompt(learner: runtime.learner, materialId: AppRuntime.primaryMaterialId);
    final action = await store.learningTruthStore().recallAction(learner: runtime.learner, actionId: prompt.id);
    expect(action, isNotNull);

    await tester.pumpWidget(testShell(runtime));
    await pumpUntilFound(tester, find.text('Hatırla'));

    expect(find.text('Hatırla'), findsOneWidget);
    await tester.enterText(find.byType(TextField), action!.expectedAnswer);
    await tapVisible(tester, find.text('Yanıtla'));
    await pumpUntilFound(tester, find.text('İpucusuz hatırladın'));

    expect(find.text('İpucusuz hatırladın'), findsOneWidget);
    expect(find.text('Sıradaki adım'), findsOneWidget);
    await tapVisible(tester, find.text('Devam et'));
    await pumpUntilFound(tester, find.text('Devam noktası'));
    expect(find.text('Devam noktası'), findsOneWidget);

    final events = await store.operationalTelemetry().events(learner: runtime.learner);
    expect(
      events.any(
        (event) =>
            event.schemaVersion == 1 &&
            event.type == OperationalEventType.recallAttempt &&
            event.phase == OperationalEventPhase.completed &&
            event.attemptId != null &&
            event.evidenceId != null &&
            event.outcome == RecallOutcome.correct &&
            event.stateKind == RecallStateKind.retrievedOnce &&
            event.reasonCode == 'ONE_UNASSISTED_RETRIEVAL_OBSERVED' &&
            event.ruleVersion == RecallLearningService.evidenceRuleVersion &&
            event.policyVersion == RecallLearningService.nextActionPolicyVersion &&
            event.durationMs != null,
      ),
      isTrue,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: LearningSliceScreen(key: const ValueKey('reopened-slice'), runtime: runtime),
        ),
      ),
    );
    await pumpUntilFound(tester, find.text('Devam noktası'));

    expect(find.text('Devam noktası'), findsOneWidget);
    expect(find.textContaining('ONE_UNASSISTED_RETRIEVAL_OBSERVED'), findsNothing);
    expect(find.textContaining('Neden:'), findsNothing);
  });

  testWidgets('full product shell opens one coherent grounded material workspace', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);

    final ingest = SourceIngestService(
      store: store,
      pdfTextExtractor: const _UnusedPdfExtractor(),
      now: () => DateTime.utc(2026, 10, 5, 19),
    );
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
    );

    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: AppRuntime.primaryMaterialId,
      text:
          'Fotosentez, bitkilerin ışık enerjisini kullanarak karbondioksit ve sudan '
          'kimyasal enerji depolamasına yardımcı olan süreçtir.',
      sourceName: 'Fotosentez çalışma notu',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: ProductShellScreen(runtime: runtime),
        ),
      ),
    );
    await pumpUntilFound(tester, find.text('KALDIĞIN MATERYAL'));

    expect(find.text('Kütüphane'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-continuation-hero')), findsOneWidget);
    expect(find.text('KALDIĞIN MATERYAL'), findsOneWidget);
    expect(find.text('Fotosentez çalışma notu'), findsWidgets);

    await tapVisible(tester, find.text('Fotosentez çalışma notu').last);
    await pumpUntilFound(tester, find.text('Öğrenme durumu'));

    expect(find.text('Öğrenme durumu'), findsOneWidget);
    expect(find.text('Henüz ölçülmedi'), findsOneWidget);
    expect(find.text('SIRADAKİ ADIM'), findsOneWidget);
    expect(find.text('Hatırla ile devam'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Odaklan'), 260, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    expect(find.text('Odaklan'), findsOneWidget);
    await tapVisible(tester, find.text('Odaklan').last);
    await pumpUntilFound(tester, find.text('Kısa odak oturumu'));
    expect(find.text('İpucu ver'), findsOneWidget);
    expect(find.text('Doğrudan açıkla'), findsOneWidget);
    await tapVisible(tester, find.text('İpucu ver'));
    await pumpUntilFound(tester, find.textContaining('henüz etkin değil'));
    expect(find.textContaining('öğrenme kanıtı oluşturmaz'), findsOneWidget);
    Navigator.of(tester.element(find.text('Kısa odak oturumu'))).pop();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Hızlı bakış'), 260, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    expect(find.text('Hızlı bakış'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Açıkla'), -260, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    expect(find.text('Açıkla'), findsOneWidget);
    await tapVisible(tester, find.text('Açıkla'));
    await pumpUntilFound(tester, find.text('Açıklama henüz hazır değil'));
    expect(find.textContaining('yapay bir sonuç göstermiyoruz'), findsOneWidget);
    Navigator.of(tester.element(find.text('Açıklama henüz hazır değil'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Hatırla'), findsWidgets);
    expect(find.text('Dinle'), findsOneWidget);
  });

  testWidgets('Home resumes the most recently active material', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    var now = DateTime.utc(2026, 10, 6, 9);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor(), now: () => now);
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
    );

    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: const MaterialId('older-material'),
      text: 'Eski materyal için yeterince uzun ve anlamlı bir çalışma metni.',
      sourceName: 'Eski materyal',
    );
    now = DateTime.utc(2026, 10, 6, 10);
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: const MaterialId('recent-material'),
      text: 'Son çalışılan materyal için yeterince uzun ve anlamlı bir çalışma metni.',
      sourceName: 'Son materyal',
    );

    await tester.pumpWidget(MaterialApp(home: ProductShellScreen(runtime: runtime)));
    await pumpUntilFound(tester, find.text('KALDIĞIN MATERYAL'));
    await tapVisible(tester, find.text('Devam et'));
    await pumpUntilFound(tester, find.text('Son materyal'));

    expect(find.text('Son materyal'), findsWidgets);
    expect(find.text('Eski materyal'), findsNothing);
  });

  testWidgets('Library deletion removes the selected material and Home falls back safely', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    var now = DateTime.utc(2026, 10, 6, 11);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor(), now: () => now);
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
    );

    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: const MaterialId('delete-older'),
      text: 'Silme sonrası güvenli geri dönüş için eski materyal içeriği.',
      sourceName: 'Korunacak materyal',
    );
    now = DateTime.utc(2026, 10, 6, 12);
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: const MaterialId('delete-recent'),
      text: 'Silinecek son materyal için yeterince uzun bir çalışma metni.',
      sourceName: 'Silinecek materyal',
    );

    await tester.pumpWidget(MaterialApp(home: ProductShellScreen(runtime: runtime)));
    await pumpUntilFound(tester, find.text('Kütüphane'));
    await tapVisible(tester, find.text('Kütüphane').last);
    await pumpUntilFound(tester, find.text('Silinecek materyal'));

    final recentCard = find.ancestor(of: find.text('Silinecek materyal'), matching: find.byType(Card));
    final deleteButton = find.descendant(of: recentCard, matching: find.byTooltip('Materyali sil'));
    expect(deleteButton, findsOneWidget);
    await tapVisible(tester, deleteButton);
    await pumpUntilFound(tester, find.text('Materyali sil?'));
    await tapVisible(tester, find.text('Sil'));
    await pumpUntilFound(tester, find.text('Materyal silindi.'));
    await pumpUntilGone(tester, find.text('Silinecek materyal'));

    expect(find.text('Silinecek materyal'), findsNothing);
    expect(find.text('Korunacak materyal'), findsOneWidget);
    expect(await store.material(learner: runtime.learner, materialId: const MaterialId('delete-recent')), isNull);

    await tapVisible(tester, find.text('Ana Sayfa').last);
    await pumpUntilFound(tester, find.text('KALDIĞIN MATERYAL'));
    await tapVisible(tester, find.text('Devam et'));
    await pumpUntilFound(tester, find.text('Korunacak materyal'));
    expect(find.text('Korunacak materyal'), findsWidgets);
  });

  testWidgets('Listen resumes the exact current source from a durable chunk checkpoint', (tester) async {
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
    final text = List.generate(90, (index) => 'kelime$index').join(' ');
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: const MaterialId('listen-resume'),
      text: text,
      sourceName: 'Dinleme devam notu',
    );
    final source = await store.currentSourceVersion(
      learner: runtime.learner,
      materialId: const MaterialId('listen-resume'),
    );
    expect(source, isNotNull);
    await store.saveListenResumeChunk(
      learner: runtime.learner,
      materialId: const MaterialId('listen-resume'),
      sourceVersionId: source!.identity.sourceVersionId,
      chunkIndex: 1,
      updatedAt: DateTime.utc(2026, 10, 7, 8),
    );

    final speech = _FakeSpeechOutput();
    await tester.pumpWidget(
      MaterialApp(
        home: ListenScreen(runtime: runtime, materialId: const MaterialId('listen-resume'), speechOutput: speech),
      ),
    );
    await pumpUntilFound(tester, find.text('Dinleme devam notu'));
    expect(find.textContaining('bölüm 2 / 2'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -620));
    await tester.pumpAndSettle();
    await pumpUntilFound(tester, find.text('Kaldığın yerden dinle'));

    await tapVisible(tester, find.text('Kaldığın yerden dinle'));
    await tester.pump();
    expect(speech.lastText, isNotNull);

    speech.complete();
    await pumpUntilFound(tester, find.text('Dinlemeye başla'));
    expect(
      await store.listenResumeChunk(
        learner: runtime.learner,
        materialId: const MaterialId('listen-resume'),
        sourceVersionId: source.identity.sourceVersionId,
      ),
      0,
    );
  });

  testWidgets('Progress reports canonical unassessed state without invented mastery', (tester) async {
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
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: AppRuntime.primaryMaterialId,
      text: 'Aktif kanıt oluşmadan ilerleme ustalık iddiası yapmamalıdır.',
      sourceName: 'İlerleme notu',
    );

    await tester.pumpWidget(MaterialApp(home: ProductShellScreen(runtime: runtime)));
    await pumpUntilFound(tester, find.text('İlerleme'));
    await tapVisible(tester, find.text('İlerleme').last);
    await pumpUntilFound(tester, find.text('Henüz ölçülmedi'));
    expect(find.text('İlerleme notu'), findsOneWidget);
    expect(find.text('Henüz ölçülmedi'), findsOneWidget);
    expect(find.textContaining('yapay olarak artırmaz'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('Profile shows only verified plan and usage data', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor()),
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
      accountOverview: const _ReadyAccountOverviewGateway(),
    );

    await tester.pumpWidget(MaterialApp(home: ProductShellScreen(runtime: runtime)));
    await pumpUntilFound(tester, find.text('Profil'));
    await tapVisible(tester, find.text('Profil').last);
    await pumpUntilFound(tester, find.text('Profil ve Ayarlar'));

    expect(find.text('Ücretsiz plan'), findsOneWidget);
    expect(find.text('Plan etkin'), findsOneWidget);
    expect(find.text('Kaynağa dayalı açıklama'), findsOneWidget);
    expect(find.text('3 işlem'), findsOneWidget);
    expect(find.textContaining('tr-TR'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Cihazın Türkçe sesi'), 260, scrollable: find.byType(Scrollable).last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Cihazın Türkçe sesi'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Hesap silme tüm hesap ve öğrenme verilerini kapsar'),
      260,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Hesap silme tüm hesap ve öğrenme verilerini kapsar'), findsOneWidget);
  });

  testWidgets('Profile exposes configured support contact without inventing one', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor()),
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
      accountOverview: const _ReadyAccountOverviewGateway(),
    );

    String? copiedSupportEmail;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileSurface(
            runtime: runtime,
            supportEmail: 'destek@example.com',
            clipboardWriter: (value) async {
              copiedSupportEmail = value;
            },
          ),
        ),
      ),
    );
    await pumpUntilFound(tester, find.text('Profil ve Ayarlar'));
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -900));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('destek@example.com'), findsOneWidget);
    await tapVisible(tester, find.text('Destek e-postasını kopyala'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(copiedSupportEmail, 'destek@example.com');
  });

  testWidgets('Profile fails closed when support contact is not configured', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor()),
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
      accountOverview: const _ReadyAccountOverviewGateway(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileSurface(runtime: runtime, supportEmail: ''),
      ),
    );
    await pumpUntilFound(tester, find.text('Profil ve Ayarlar'));
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -900));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Destek iletişim kanalı henüz yapılandırılmadı'), findsOneWidget);
    expect(find.text('Destek e-postasını kopyala'), findsNothing);
  });

  testWidgets('Profile sign out requires confirmation and preserves learner local data', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    var signOutCalls = 0;
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
      accountOverview: const _ReadyAccountOverviewGateway(),
    );
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: AppRuntime.primaryMaterialId,
      text: 'Çıkış yapmak bu learner verisini silmemelidir.',
      sourceName: 'Korunacak oturum verisi',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ProductShellScreen(
          runtime: runtime,
          onSignOut: () async {
            signOutCalls += 1;
          },
        ),
      ),
    );
    await pumpUntilFound(tester, find.text('Profil'));
    await tapVisible(tester, find.text('Profil').last);
    await pumpUntilFound(tester, find.text('Profil ve Ayarlar'));
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -420));
    await tester.pump(const Duration(milliseconds: 300));
    await tapVisible(tester, find.text('Bu cihazda çıkış yap'));
    await pumpUntilFound(tester, find.text('Bu cihazda çıkış yap?'));

    expect(signOutCalls, 0);
    await tapVisible(tester, find.text('Çıkış yap'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(signOutCalls, 1);
    expect(await store.material(learner: runtime.learner, materialId: AppRuntime.primaryMaterialId), isNotNull);
  });

  testWidgets('account deletion requires explicit confirmation and purges local data after remote success', (
    tester,
  ) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    final deletion = _RecordingAccountDeletionGateway();
    var deletedCallback = false;
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
      accountOverview: const _ReadyAccountOverviewGateway(),
      accountDeletion: deletion,
    );
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: AppRuntime.primaryMaterialId,
      text: 'Hesap silme sonrası bu yerel veri kalmamalıdır.',
      sourceName: 'Silinecek hesap verisi',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ProductShellScreen(runtime: runtime, onAccountDeleted: () => deletedCallback = true),
      ),
    );
    await pumpUntilFound(tester, find.text('Profil'));
    await tapVisible(tester, find.text('Profil').last);
    await pumpUntilFound(tester, find.text('Profil ve Ayarlar'));
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -720));
    await tester.pump(const Duration(milliseconds: 300));
    await tapVisible(tester, find.text('Hesabımı ve verilerimi sil'));
    await pumpUntilFound(tester, find.text('Hesabı ve verileri sil?'));
    await tapVisible(tester, find.text('Devam et'));
    await pumpUntilFound(tester, find.text('Son onay'));
    await tapVisible(tester, find.text('Kalıcı olarak sil'));

    for (var i = 0; i < 20 && !deletedCallback; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(deletion.calls, 1);
    expect(deletedCallback, isTrue);
    expect(await store.activeMaterials(learner: runtime.learner), isEmpty);
  });

  test('failed remote account deletion preserves local learner data', () async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
      accountDeletion: const _FailingAccountDeletionGateway(),
    );
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: AppRuntime.primaryMaterialId,
      text: 'Remote silme başarısızsa yerel veri korunmalıdır.',
    );

    await expectLater(runtime.deleteAccount(), throwsA(isA<AccountDeletionException>()));
    expect(await store.material(learner: runtime.learner, materialId: AppRuntime.primaryMaterialId), isNotNull);
  });

  testWidgets('grounded Explain labels generated interpretation and preserves Recall as active step', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
      explain: const _ReadyExplainGateway(),
    );
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: AppRuntime.primaryMaterialId,
      text: 'Fotosentez ışık enerjisinin kimyasal enerjiye dönüşmesine yardımcı olur.',
      sourceName: 'Biyoloji notu',
    );

    await tester.pumpWidget(MaterialApp(home: ProductShellScreen(runtime: runtime)));
    await pumpUntilFound(tester, find.text('Biyoloji notu'));
    await tapVisible(tester, find.text('Biyoloji notu').last);
    await pumpUntilFound(tester, find.text('Açıkla'));
    await tapVisible(tester, find.text('Açıkla'));
    await pumpUntilFound(tester, find.text('Kaynağına dayalı açıklama'));

    expect(find.textContaining('kaynak metnin kendisi değil'), findsOneWidget);
    expect(find.textContaining('ışık enerjisini kimyasal enerjiye'), findsOneWidget);
    expect(find.text('Önemli noktalar'), findsOneWidget);
    expect(find.textContaining('öğrenme kanıtı oluşturmaz'), findsOneWidget);
    expect(find.text('Hatırla ile dene'), findsOneWidget);
    expect(find.text('Kendi cümlelerinle anlat'), findsOneWidget);
    await tapVisible(tester, find.text('Kendi cümlelerinle anlat'));
    await pumpUntilFound(tester, find.text('Anlatımımı değerlendir'));
    expect(find.textContaining('öğrenme kanıtı veya ustalık iddiası oluşturmaz'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür.');
    await tapVisible(tester, find.text('Anlatımımı değerlendir'));
    await pumpUntilFound(tester, find.text('Henüz güvenilir değerlendirme yok'));
    expect(find.textContaining('öğrenme kanıtı olarak kaydetmiyoruz'), findsOneWidget);
    Navigator.of(tester.element(find.text('Henüz güvenilir değerlendirme yok'))).pop();
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Hatırla ile dene'));
    await pumpUntilFound(tester, find.byType(LearningSliceScreen));
    expect(find.byType(LearningSliceScreen), findsOneWidget);
  });

  testWidgets('answer exposure survives close and reopen without becoming independent', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);

    final ingest = SourceIngestService(
      store: store,
      pdfTextExtractor: const _UnusedPdfExtractor(),
      now: () => DateTime.utc(2026, 10, 4, 17),
    );
    final recall = RecallLearningService(
      sourceStore: store,
      learningStore: store.learningTruthStore(),
      now: () => DateTime.utc(2026, 10, 4, 17, 1),
    );
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
          'Fotosentez sırasında klorofil ışık enerjisini kimyasal enerjiye '
          'dönüştürmeye yardımcı olur. Bitkiler bu süreçte karbondioksit kullanır.',
    );
    final prompt = await recall.createCurrentPrompt(learner: runtime.learner, materialId: AppRuntime.primaryMaterialId);
    final action = await store.learningTruthStore().recallAction(learner: runtime.learner, actionId: prompt.id);
    expect(action, isNotNull);

    await tester.pumpWidget(testShell(runtime));
    await pumpUntilFound(tester, find.text('Hatırla'));
    expect(find.text('Hatırla'), findsOneWidget);

    await tapVisible(tester, find.text('Yanıtı göster'));
    await pumpUntilFound(tester, find.textContaining('Yanıt:'));
    expect(find.textContaining('Yanıt:'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: LearningSliceScreen(key: const ValueKey('reopened-supported-attempt'), runtime: runtime),
        ),
      ),
    );
    await pumpUntilFound(tester, find.text('Hatırla'));

    expect(find.text('Hatırla'), findsOneWidget);
    expect(find.textContaining('yanıt daha önce gösterildi'), findsOneWidget);

    await tester.enterText(find.byType(TextField), action!.expectedAnswer);
    await tapVisible(tester, find.text('Yanıtla'));
    await pumpUntilFound(tester, find.textContaining('geri çağırma başarısı olarak sayılmadı'));

    expect(find.text('İpucusuz hatırladın'), findsNothing);
    expect(find.textContaining('geri çağırma başarısı olarak sayılmadı'), findsOneWidget);
  });

  testWidgets('Reduced Motion keeps the learning slice usable', (tester) async {
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
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: LearningSliceScreen(runtime: runtime),
        ),
      ),
    );
    await pumpUntilFound(tester, find.text('Çalışma materyalini ekle'));

    expect(find.text('Çalışma materyalini ekle'), findsOneWidget);
    expect(find.text('Hatırlama başlat'), findsOneWidget);
  });
}
