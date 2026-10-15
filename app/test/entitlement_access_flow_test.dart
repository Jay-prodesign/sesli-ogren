import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/account/entitlement_access_gateway.dart';
import 'package:sesli_ogren/src/app/app_runtime.dart';
import 'package:sesli_ogren/src/app/explain_screen.dart';
import 'package:sesli_ogren/src/app/focus_screen.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sesli_ogren/src/generation/grounded_explain_gateway.dart';
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

class _BlockedEntitlementGateway implements EntitlementAccessGateway {
  const _BlockedEntitlementGateway();

  @override
  Future<CapabilityAccessDecision> check(EntitlementCapability capability) async => CapabilityAccessDecision(
    capability: capability,
    disposition: CapabilityAccessDisposition.blocked,
    reason: CapabilityAccessReason.quotaReached,
    plan: 'free',
    entitlementStatus: 'active',
    limit: 1,
    consumed: 1,
    remaining: 0,
  );
}

class _RecordingFocusGateway implements FocusHelpGateway {
  int calls = 0;

  @override
  Future<FocusHelpResult> help(FocusHelpRequest request) async {
    calls += 1;
    return FocusHelpReady(
      sourceVersionId: request.sourceVersionId,
      sourceContentDigest: request.sourceContentDigest,
      text: 'Bu yanıt quota blokajında görünmemeli.',
      executionRef: 'test:focus',
    );
  }
}

class _RecordingExplainGateway implements GroundedExplainGateway {
  int calls = 0;

  @override
  Future<GroundedExplainResult> explain(GroundedExplainRequest request) async {
    calls += 1;
    return GroundedExplainReady(
      sourceVersionId: request.sourceVersionId,
      sourceContentDigest: request.sourceContentDigest,
      explanation: 'Bu açıklama quota blokajında görünmemeli.',
      keyPoints: const [],
      language: 'tr-TR',
      executionRef: 'test:explain',
    );
  }
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder, {int maxPumps = 100}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Expected entitlement state was not reached within bounded pumps.');
}

Future<(AppRuntime, SourceVersionRecord, String)> _fixture({
  required FocusHelpGateway focus,
  required GroundedExplainGateway explain,
}) async {
  final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
  final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
  const materialId = MaterialId('entitlement-flow-material');
  final result = await ingest.ingestPastedText(
    learner: AppRuntime.localM5LearnerFixture,
    materialId: materialId,
    text:
        'Klorofil ışığın soğurulmasına yardım eder. Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür.',
    sourceName: 'Entitlement akış notu',
  );
  final runtime = AppRuntime(
    learner: AppRuntime.localM5LearnerFixture,
    store: store,
    ingest: ingest,
    recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
    telemetry: store.operationalTelemetry(),
    focusHelp: focus,
    explain: explain,
    entitlementAccess: const _BlockedEntitlementGateway(),
  );
  return (runtime, result.sourceVersion, result.extractedContent.normalizedText);
}

void main() {
  sqfliteFfiInit();

  testWidgets('blocked Focus AI keeps a local source hint available without calling generation', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final focus = _RecordingFocusGateway();
    final explain = _RecordingExplainGateway();
    final (runtime, source, sourceText) = await _fixture(focus: focus, explain: explain);
    addTearDown(runtime.close);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5), disableAnimations: true),
          child: FocusScreen(runtime: runtime, source: source, sourceText: sourceText),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Klorofil neden önemli?');
    final hint = find.text('İpucu ver');
    await tester.ensureVisible(hint);
    await tester.tap(hint);
    await _pumpUntilFound(tester, find.byKey(const ValueKey('entitlement-access-card')));

    expect(focus.calls, 0);
    expect(find.textContaining('Kaynak ipucu:'), findsOneWidget);
    expect(find.text('Bugünkü üretim sınırına ulaştın'), findsOneWidget);
    expect(find.byKey(const ValueKey('entitlement-safe-back')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('blocked Explain does not create a generated explanation', (tester) async {
    final focus = _RecordingFocusGateway();
    final explain = _RecordingExplainGateway();
    final (runtime, source, _) = await _fixture(focus: focus, explain: explain);
    addTearDown(runtime.close);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
        home: ExplainScreen(runtime: runtime, source: source),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const ValueKey('entitlement-access-card')));

    expect(explain.calls, 0);
    expect(find.text('Bugünkü üretim sınırına ulaştın'), findsOneWidget);
    expect(find.textContaining('daha önce oluşturduğun içerikler açık kalır'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
