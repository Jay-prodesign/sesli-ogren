import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/app_runtime.dart';
import 'package:sesli_ogren/src/app/learning_slice_screen.dart';
import 'package:sesli_ogren/src/app/product_shell_screen.dart';
import 'package:sesli_ogren/src/app/sesli_ogren_app.dart';
import 'package:sesli_ogren/src/auth/supabase_learner_auth.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/learning/recall_learning_service.dart';
import 'package:sesli_ogren/src/generation/grounded_explain_gateway.dart';
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

void main() {
  sqfliteFfiInit();

  test('production auth fails closed when Supabase config is absent', () async {
    await expectLater(SupabaseLearnerAuth.authenticate(), throwsA(isA<LearnerAuthConfigurationException>()));
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
    await pumpUntilFound(tester, find.text('Şimdi ne yapmalı?'));

    expect(find.text('Kütüphane'), findsOneWidget);
    expect(find.text('Materyalin'), findsOneWidget);
    expect(find.text('Fotosentez çalışma notu'), findsWidgets);

    await tapVisible(tester, find.text('Fotosentez çalışma notu').last);
    await pumpUntilFound(tester, find.text('Öğrenme durumu'));

    expect(find.text('Öğrenme durumu'), findsOneWidget);
    expect(find.text('Henüz ölçülmedi'), findsOneWidget);
    expect(find.text('Hızlı bakış'), findsOneWidget);
    expect(find.text('Açıkla'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -420));
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
    await tester.drag(find.byType(Scrollable).last, const Offset(0, 420));
    await tester.pumpAndSettle();
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
    await pumpUntilFound(tester, find.text('Şimdi ne yapmalı?'));
    await tapVisible(tester, find.text('Devam et'));
    await pumpUntilFound(tester, find.text('Son materyal'));

    expect(find.text('Son materyal'), findsOneWidget);
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

    expect(find.text('Silinecek materyal'), findsNothing);
    expect(find.text('Korunacak materyal'), findsOneWidget);
    expect(
      await store.material(learner: runtime.learner, materialId: const MaterialId('delete-recent')),
      isNull,
    );

    await tapVisible(tester, find.text('Ana Sayfa').last);
    await pumpUntilFound(tester, find.text('Şimdi ne yapmalı?'));
    await tapVisible(tester, find.text('Devam et'));
    await pumpUntilFound(tester, find.text('Korunacak materyal'));
    expect(find.text('Korunacak materyal'), findsOneWidget);
  });

  testWidgets('SQLite reopen preserves material and canonical continuation', (tester) async {
    const path = '/tmp/sesli-ogren-continuity-reopen.db';
    await databaseFactoryFfiNoIsolate.deleteDatabase(path);
    addTearDown(() => databaseFactoryFfiNoIsolate.deleteDatabase(path));

    var store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: path);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    final learner = AppRuntime.localM5LearnerFixture;
    await ingest.ingestPastedText(
      learner: learner,
      materialId: const MaterialId('restart-material'),
      text: 'Uygulama yeniden açıldığında bu materyal ve öğrenme durumu kalıcı olmalıdır.',
      sourceName: 'Restart materyali',
    );
    final recall = RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore());
    final prompt = await recall.createCurrentPrompt(learner: learner, materialId: const MaterialId('restart-material'));
    final action = await store.learningTruthStore().recallAction(learner: learner, actionId: prompt.id);
    expect(action, isNotNull);
    final session = await recall.openAttempt(learner: learner, actionId: action!.id);
    await recall.submit(
      learner: learner,
      actionId: action.id,
      attemptId: session.attempt.attemptId,
      disposition: RecallResponseDisposition.answer,
      answer: action.expectedAnswer,
    );
    await store.close();

    store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: path);
    addTearDown(store.close);
    final reopened = RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore());
    final continuation = await reopened.reopen(learner: learner, materialId: const MaterialId('restart-material'));
    final material = await store.material(learner: learner, materialId: const MaterialId('restart-material'));

    expect(material?.title, 'Restart materyali');
    expect(continuation?.state.kind, RecallStateKind.retrievedOnce);
    expect(continuation?.nextAction.reasonText, isNotEmpty);
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
