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

class _SucceededSummaryGateway extends SupabaseSourceSummaryGateway {
  const _SucceededSummaryGateway();

  @override
  Future<ServerSummaryStatus> status(String jobId) async =>
      const ServerSummaryStatus(state: 'SUCCEEDED', summary: 'ready');
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

  testWidgets('Explain uses persisted server material identity for a local source', (tester) async {
    final store = await SqliteSourceStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    addTearDown(store.close);

    final ingest = SourceIngestService(
      store: store,
      pdfTextExtractor: const _UnusedPdfExtractor(),
    );
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

    const serverMaterialId = '11111111-1111-4111-8111-111111111111';
    await store.saveSummaryJob(
      learner: AppRuntime.localM5LearnerFixture,
      materialId: localMaterialId,
      sourceVersionId: source!.identity.sourceVersionId,
      serverMaterialId: serverMaterialId,
      jobId: '22222222-2222-4222-8222-222222222222',
    );

    final explain = _RecordingExplainGateway();
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(
        sourceStore: store,
        learningStore: store.learningTruthStore(),
      ),
      telemetry: store.operationalTelemetry(),
      explain: explain,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ExplainScreen(
          runtime: runtime,
          source: source,
          summaryGateway: const _SucceededSummaryGateway(),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('Sunucu materyaline bağlı açıklama'));

    expect(explain.lastRequest, isNotNull);
    expect(explain.lastRequest!.materialId.value, serverMaterialId);
    expect(explain.lastRequest!.sourceVersionId, source.identity.sourceVersionId);
    expect(explain.lastRequest!.sourceContentDigest, source.identity.contentDigest);
    final expectedGroundingHash = sha256
        .convert(utf8.encode('Fotosentez ışık enerjisinin kimyasal enerjiye dönüşmesine yardımcı olur.'))
        .toString();
    expect(explain.lastRequest!.groundingContentHash, expectedGroundingHash);
    expect(explain.lastRequest!.groundingContentHash, isNot(source.identity.contentDigest));
  });
}
