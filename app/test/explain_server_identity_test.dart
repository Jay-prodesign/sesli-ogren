import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/app_runtime.dart';
import 'package:sesli_ogren/src/app/explain_screen.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sesli_ogren/src/generation/grounded_explain_gateway.dart';
import 'package:sesli_ogren/src/generation/supabase_source_summary_gateway.dart';
import 'package:sesli_ogren/src/learning/recall_learning_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _UnusedPdfExtractor implements PdfTextExtractor {
  const _UnusedPdfExtractor();

  @override
  Future<ExtractedPdf> extract(Uint8List bytes, {required String sourceName}) {
    throw UnimplementedError();
  }
}

class _RecordingServerMaterialGateway extends SupabaseSourceSummaryGateway {
  _RecordingServerMaterialGateway(this.serverMaterialId);

  final String serverMaterialId;
  int ensureCalls = 0;

  @override
  Future<String> ensureServerMaterial({required SourceIngestResult source}) async {
    ensureCalls++;
    return serverMaterialId;
  }

  @override
  Future<ServerSummarySubmission> submit({required SourceIngestResult source}) {
    throw StateError('Explain must not create a Quick Recap job.');
  }
}

class _RecordingExplainGateway implements GroundedExplainGateway {
  GroundedExplainRequest? lastRequest;

  @override
  Future<GroundedExplainResult> explain(GroundedExplainRequest request) async {
    lastRequest = request;
    return GroundedExplainReady(
      sourceVersionId: request.sourceVersionId,
      sourceContentDigest: request.sourceContentDigest,
      explanation: 'Sunucu materyaline bağlı açıklama',
      keyPoints: const ['Kaynak kimliği korundu'],
      language: 'tr-TR',
      executionRef: 'test:server-material',
    );
  }
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder, {int maxPumps = 100}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Expected widget was not reached within bounded pumps.');
}

void main() {
  sqfliteFfiInit();

  testWidgets('Explain provider failure keeps the learner moving through Recall or back to the material', (
    tester,
  ) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);

    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    const materialId = MaterialId('explain-recovery-material');
    await ingest.ingestPastedText(
      learner: AppRuntime.localM5LearnerFixture,
      materialId: materialId,
      text: 'Fotosentez sırasında klorofil ışığın soğurulmasına yardım eder.',
      sourceName: 'Kurtarma notu',
    );
    final source = await store.currentSourceVersion(learner: AppRuntime.localM5LearnerFixture, materialId: materialId);
    expect(source, isNotNull);

    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ExplainScreen(runtime: runtime, source: source!),
      ),
    );
    await _pumpUntilFound(tester, find.text('Açıklama henüz hazır değil'));

    expect(find.text('Hatırla ile devam et'), findsOneWidget);
    expect(find.text('Materyale dön'), findsOneWidget);

    await tester.tap(find.text('Hatırla ile devam et'));
    await _pumpUntilFound(tester, find.text('Hatırla'));
    expect(find.text('Hatırla'), findsOneWidget);
  });

  testWidgets('Explain uses persisted server material identity for a local source', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);

    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    const localMaterialId = MaterialId('local-explain-material');
    await ingest.ingestPastedText(
      learner: AppRuntime.localM5LearnerFixture,
      materialId: localMaterialId,
      text: '  Fotosentez ışık enerjisinin kimyasal enerjiye dönüşmesine yardımcı olur.\r\n',
      sourceName: 'Biyoloji notu',
    );
    final source = await store.currentSourceVersion(
      learner: AppRuntime.localM5LearnerFixture,
      materialId: localMaterialId,
    );
    expect(source, isNotNull);
    final boundSource = source!;

    const serverMaterialId = '11111111-1111-4111-8111-111111111111';
    final serverMaterialGateway = _RecordingServerMaterialGateway(serverMaterialId);
    final explain = _RecordingExplainGateway();
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
      explain: explain,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ExplainScreen(runtime: runtime, source: boundSource, summaryGateway: serverMaterialGateway),
      ),
    );
    await _pumpUntilFound(tester, find.text('Sunucu materyaline bağlı açıklama'));

    expect(serverMaterialGateway.ensureCalls, 1);
    expect(
      await store.summaryJobId(
        learner: AppRuntime.localM5LearnerFixture,
        materialId: localMaterialId,
        sourceVersionId: boundSource.identity.sourceVersionId,
      ),
      isNull,
    );
    expect(
      await store.summaryServerMaterialId(
        learner: AppRuntime.localM5LearnerFixture,
        materialId: localMaterialId,
        sourceVersionId: boundSource.identity.sourceVersionId,
      ),
      serverMaterialId,
    );
    expect(explain.lastRequest, isNotNull);
    expect(explain.lastRequest!.materialId.value, serverMaterialId);
    expect(explain.lastRequest!.sourceVersionId, boundSource.identity.sourceVersionId);
    expect(explain.lastRequest!.sourceContentDigest, boundSource.identity.contentDigest);
    final expectedGroundingHash = sha256
        .convert(utf8.encode('Fotosentez ışık enerjisinin kimyasal enerjiye dönüşmesine yardımcı olur.'))
        .toString();
    expect(explain.lastRequest!.groundingContentHash, expectedGroundingHash);
    expect(explain.lastRequest!.groundingContentHash, isNot(boundSource.identity.contentDigest));
  });
}
