import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/account/entitlement_access_gateway.dart';
import 'package:sesli_ogren/src/app/app_runtime.dart';
import 'package:sesli_ogren/src/app/explain_back_screen.dart';
import 'package:sesli_ogren/src/app/explain_screen.dart';
import 'package:sesli_ogren/src/app/focus_screen.dart';
import 'package:sesli_ogren/src/app/quick_recap_screen.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/domain/authenticated_learner.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sesli_ogren/src/generation/grounded_explain_gateway.dart';
import 'package:sesli_ogren/src/generation/supabase_source_summary_gateway.dart';
import 'package:sesli_ogren/src/learning/explain_back_gateway.dart';
import 'package:sesli_ogren/src/learning/focus_help_gateway.dart';
import 'package:sesli_ogren/src/learning/recall_learning_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _UnusedPdfExtractor implements PdfTextExtractor {
  const _UnusedPdfExtractor();

  @override
  Future<ExtractedPdf> extract(Uint8List bytes, {required String sourceName}) {
    throw UnimplementedError();
  }
}

class _FixedEntitlementGateway implements EntitlementAccessGateway {
  _FixedEntitlementGateway(this.result);

  final EntitlementAccess result;
  int calls = 0;

  @override
  Future<EntitlementAccess> check({
    required AuthenticatedLearner learner,
    required EntitlementCapability capability,
  }) async {
    calls += 1;
    return EntitlementAccess(
      capability: capability,
      kind: result.kind,
      reason: result.reason,
      plan: result.plan,
      entitlementStatus: result.entitlementStatus,
      reconciliationState: result.reconciliationState,
      renewalState: result.renewalState,
      periodStart: result.periodStart,
      consumed: result.consumed,
      limit: result.limit,
      effectiveUntil: result.effectiveUntil,
      lastAuthoritativeVerificationAt: result.lastAuthoritativeVerificationAt,
    );
  }
}

class _RecordingSummaryGateway extends SupabaseSourceSummaryGateway {
  var submitCalls = 0;

  @override
  Future<ServerSummarySubmission> submit({required SourceIngestResult source}) async {
    submitCalls += 1;
    return const ServerSummarySubmission(
      materialId: '11111111-1111-4111-8111-111111111111',
      jobId: '22222222-2222-4222-8222-222222222222',
    );
  }

  @override
  Future<ServerSummaryStatus> status(String jobId) async => const ServerSummaryStatus(
    state: 'SUCCEEDED',
    summary: 'Kaydedilmiş özet quota sınırından sonra da açılır.',
    keyPoints: ['Mevcut içerik kilitlenmez.'],
  );

  @override
  Future<bool> dispatch(String jobId) async => true;
}

class _NeverExplainGateway implements GroundedExplainGateway {
  int calls = 0;

  @override
  Future<GroundedExplainResult> explain(GroundedExplainRequest request) async {
    calls += 1;
    throw StateError('entitlement gate should stop Explain generation');
  }
}

class _NeverExplainBackGateway implements ExplainBackGateway {
  int calls = 0;

  @override
  Future<ExplainBackResult> evaluate(ExplainBackRequest request) async {
    calls += 1;
    throw StateError('entitlement gate should stop Explain-back evaluation');
  }
}

class _NeverFocusGateway implements FocusHelpGateway {
  int calls = 0;

  @override
  Future<FocusHelpResult> help(FocusHelpRequest request) async {
    calls += 1;
    throw StateError('quota fallback should not call Focus generation');
  }
}

EntitlementAccess _quotaReached(EntitlementCapability capability) => EntitlementAccess(
  capability: capability,
  kind: EntitlementAccessKind.denied,
  reason: EntitlementAccessReason.quotaReached,
  plan: 'free',
  entitlementStatus: 'active',
  reconciliationState: 'verified',
  renewalState: 'none',
  periodStart: DateTime.utc(2026, 10, 15),
  consumed: 1,
  limit: 1,
);

EntitlementAccess _purchasePending(EntitlementCapability capability) => EntitlementAccess(
  capability: capability,
  kind: EntitlementAccessKind.pending,
  reason: EntitlementAccessReason.purchasePending,
  plan: 'free',
  entitlementStatus: 'active',
  reconciliationState: 'purchase_pending',
  renewalState: 'none',
  periodStart: DateTime.utc(2026, 10, 15),
  consumed: 0,
  limit: 0,
);

EntitlementAccess _entitlementMissing(EntitlementCapability capability) => EntitlementAccess(
  capability: capability,
  kind: EntitlementAccessKind.unavailable,
  reason: EntitlementAccessReason.entitlementMissing,
  plan: 'unknown',
  entitlementStatus: 'missing',
  reconciliationState: 'verified',
  renewalState: 'none',
  periodStart: DateTime.utc(2026, 10, 15),
  consumed: 0,
  limit: 0,
);

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder, {int maxPumps = 100}) async {
  for (var i = 0; i < maxPumps && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 30));
  }
  expect(finder, findsOneWidget);
}

Future<(SqliteSourceStore, SourceIngestService, SourceIngestResult)> _source({
  required MaterialId materialId,
  String text =
      'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür. Bitki bu süreçte karbondioksit ve su kullanır.',
}) async {
  final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
  final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
  final source = await ingest.ingestPastedText(
    learner: AppRuntime.localM5LearnerFixture,
    materialId: materialId,
    text: text,
    sourceName: 'Biyoloji notu',
  );
  return (store, ingest, source);
}

AppRuntime _runtime({
  required SqliteSourceStore store,
  required SourceIngestService ingest,
  required EntitlementAccessGateway entitlement,
  GroundedExplainGateway? explain,
  ExplainBackGateway? explainBack,
  FocusHelpGateway? focus,
}) {
  return AppRuntime(
    learner: AppRuntime.localM5LearnerFixture,
    store: store,
    ingest: ingest,
    recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
    telemetry: store.operationalTelemetry(),
    entitlementAccess: entitlement,
    explain: explain ?? const UnavailableGroundedExplainGateway(),
    explainBack: explainBack ?? const UnavailableExplainBackGateway(),
    focusHelp: focus ?? const UnavailableFocusHelpGateway(),
  );
}

void main() {
  sqfliteFfiInit();

  testWidgets('Quick Recap quota denial blocks new generation and stays usable at 320px large text', (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const materialId = MaterialId('entitlement-recap-denied');
    final (store, ingest, _) = await _source(materialId: materialId);
    addTearDown(store.close);
    final entitlement = _FixedEntitlementGateway(_quotaReached(EntitlementCapability.summary));
    final summary = _RecordingSummaryGateway();
    final runtime = _runtime(store: store, ingest: ingest, entitlement: entitlement);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true, textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: QuickRecapScreen(runtime: runtime, materialId: materialId, summaryGateway: summary),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const ValueKey('quick-recap-create')));
    await tester.ensureVisible(find.byKey(const ValueKey('quick-recap-create')));
    await tester.tap(find.byKey(const ValueKey('quick-recap-create')));
    await _pumpUntilFound(tester, find.byKey(const ValueKey('entitlement-access-boundary')));

    expect(entitlement.calls, 1);
    expect(summary.submitCalls, 0);
    expect(find.textContaining('sınırına ulaştın'), findsOneWidget);
    expect(find.byKey(const ValueKey('entitlement-access-usage')), findsOneWidget);
    expect(find.byKey(const ValueKey('entitlement-access-return')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('purchase pending blocks new generation without presenting another upgrade offer', (tester) async {
    const materialId = MaterialId('entitlement-recap-purchase-pending');
    final (store, ingest, _) = await _source(materialId: materialId);
    addTearDown(store.close);
    final entitlement = _FixedEntitlementGateway(_purchasePending(EntitlementCapability.summary));
    final summary = _RecordingSummaryGateway();
    final runtime = _runtime(store: store, ingest: ingest, entitlement: entitlement);

    await tester.pumpWidget(
      MaterialApp(
        home: QuickRecapScreen(runtime: runtime, materialId: materialId, summaryGateway: summary),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const ValueKey('quick-recap-create')));
    await tester.tap(find.byKey(const ValueKey('quick-recap-create')));
    await _pumpUntilFound(tester, find.byKey(const ValueKey('entitlement-access-boundary')));

    expect(entitlement.calls, 1);
    expect(summary.submitCalls, 0);
    expect(find.text('Plan durumun doğrulanıyor'), findsOneWidget);
    expect(find.textContaining('Satın alma sonucu henüz sunucu tarafından doğrulanmadı'), findsOneWidget);
    expect(find.textContaining('Daha yüksek bir plan'), findsNothing);
    expect(find.byKey(const ValueKey('entitlement-access-retry')), findsOneWidget);
    expect(find.byKey(const ValueKey('entitlement-access-return')), findsOneWidget);
  });

  testWidgets('missing entitlement truth fails closed without presenting a paywall', (tester) async {
    const materialId = MaterialId('entitlement-recap-missing');
    final (store, ingest, _) = await _source(materialId: materialId);
    addTearDown(store.close);
    final entitlement = _FixedEntitlementGateway(_entitlementMissing(EntitlementCapability.summary));
    final summary = _RecordingSummaryGateway();
    final runtime = _runtime(store: store, ingest: ingest, entitlement: entitlement);

    await tester.pumpWidget(
      MaterialApp(
        home: QuickRecapScreen(runtime: runtime, materialId: materialId, summaryGateway: summary),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const ValueKey('quick-recap-create')));
    await tester.tap(find.byKey(const ValueKey('quick-recap-create')));
    await _pumpUntilFound(tester, find.byKey(const ValueKey('entitlement-access-boundary')));

    expect(entitlement.calls, 1);
    expect(summary.submitCalls, 0);
    expect(find.text('Plan bilgisi şu anda doğrulanamıyor'), findsOneWidget);
    expect(find.textContaining('plan kaydı güvenilir biçimde doğrulanamadı'), findsOneWidget);
    expect(find.textContaining('Daha yüksek bir plan'), findsNothing);
    expect(find.byKey(const ValueKey('entitlement-access-retry')), findsOneWidget);
    expect(find.byKey(const ValueKey('entitlement-access-return')), findsOneWidget);
  });

  testWidgets('cached Quick Recap stays accessible after generation quota is exhausted', (tester) async {
    const materialId = MaterialId('entitlement-recap-cached');
    final (store, ingest, source) = await _source(materialId: materialId);
    addTearDown(store.close);
    await store.saveSummaryJob(
      learner: AppRuntime.localM5LearnerFixture,
      materialId: materialId,
      sourceVersionId: source.sourceVersion.identity.sourceVersionId,
      serverMaterialId: '11111111-1111-4111-8111-111111111111',
      jobId: '22222222-2222-4222-8222-222222222222',
    );
    await store.saveCachedSummaryResult(
      learner: AppRuntime.localM5LearnerFixture,
      materialId: materialId,
      sourceVersionId: source.sourceVersion.identity.sourceVersionId,
      jobId: '22222222-2222-4222-8222-222222222222',
      summary: 'Kaydedilmiş özet quota sınırından sonra da açılır.',
      keyPoints: const ['Mevcut içerik kilitlenmez.'],
      cachedAt: DateTime.utc(2026, 10, 15, 8),
    );

    final entitlement = _FixedEntitlementGateway(_quotaReached(EntitlementCapability.summary));
    final summary = _RecordingSummaryGateway();
    final runtime = _runtime(store: store, ingest: ingest, entitlement: entitlement);

    await tester.pumpWidget(
      MaterialApp(
        home: QuickRecapScreen(runtime: runtime, materialId: materialId, summaryGateway: summary),
      ),
    );
    await _pumpUntilFound(tester, find.text('Kaydedilmiş özet quota sınırından sonra da açılır.'));

    expect(entitlement.calls, 0);
    expect(find.byKey(const ValueKey('entitlement-access-boundary')), findsNothing);
    expect(find.text('Kaydedilmiş özet quota sınırından sonra da açılır.'), findsOneWidget);
  });

  testWidgets('Explain quota denial never starts generated explanation', (tester) async {
    const materialId = MaterialId('entitlement-explain-denied');
    final (store, ingest, source) = await _source(materialId: materialId);
    addTearDown(store.close);
    final entitlement = _FixedEntitlementGateway(_quotaReached(EntitlementCapability.explain));
    final explain = _NeverExplainGateway();
    final runtime = _runtime(store: store, ingest: ingest, entitlement: entitlement, explain: explain);

    await tester.pumpWidget(
      MaterialApp(
        home: ExplainScreen(runtime: runtime, source: source.sourceVersion),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const ValueKey('entitlement-access-boundary')));

    expect(entitlement.calls, 1);
    expect(explain.calls, 0);
    expect(find.textContaining('Kaynağa dayalı açıklama sınırına ulaştın'), findsOneWidget);
  });

  testWidgets('Explain-back quota denial records no learner evaluation', (tester) async {
    const materialId = MaterialId('entitlement-explain-back-denied');
    final (store, ingest, source) = await _source(materialId: materialId);
    addTearDown(store.close);
    final entitlement = _FixedEntitlementGateway(_quotaReached(EntitlementCapability.explainBack));
    final explainBack = _NeverExplainBackGateway();
    final runtime = _runtime(store: store, ingest: ingest, entitlement: entitlement, explainBack: explainBack);

    await tester.pumpWidget(
      MaterialApp(
        home: ExplainBackScreen(runtime: runtime, source: source.sourceVersion),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür.');
    await tester.tap(find.text('Anlatımımı değerlendir'));
    await _pumpUntilFound(tester, find.byKey(const ValueKey('entitlement-access-boundary')));

    expect(entitlement.calls, 1);
    expect(explainBack.calls, 0);
    expect(find.textContaining('Anlatım değerlendirme sınırına ulaştın'), findsOneWidget);
  });

  testWidgets('Focus hint falls back to current source when AI quota is exhausted', (tester) async {
    const materialId = MaterialId('entitlement-focus-hint-fallback');
    final (store, ingest, source) = await _source(materialId: materialId);
    addTearDown(store.close);
    final entitlement = _FixedEntitlementGateway(_quotaReached(EntitlementCapability.focus));
    final focus = _NeverFocusGateway();
    final runtime = _runtime(store: store, ingest: ingest, entitlement: entitlement, focus: focus);

    await tester.pumpWidget(
      MaterialApp(
        home: FocusScreen(
          runtime: runtime,
          source: source.sourceVersion,
          sourceText: source.extractedContent.normalizedText,
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Karbondioksit süreçte nasıl kullanılır?');
    await tester.ensureVisible(find.text('İpucu ver'));
    await tester.tap(find.text('İpucu ver'));
    await _pumpUntilFound(tester, find.textContaining('Kaynak ipucu'));

    expect(entitlement.calls, 1);
    expect(focus.calls, 0);
    expect(find.byKey(const ValueKey('entitlement-access-boundary')), findsNothing);
    expect(find.textContaining('Kaynak ipucu'), findsOneWidget);
  });
}
