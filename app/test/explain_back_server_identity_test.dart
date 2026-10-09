import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/app_runtime.dart';
import 'package:sesli_ogren/src/app/explain_back_screen.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sesli_ogren/src/learning/explain_back_gateway.dart';
import 'package:sesli_ogren/src/learning/recall_learning_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _UnusedPdfExtractor implements PdfTextExtractor {
  const _UnusedPdfExtractor();

  @override
  Future<ExtractedPdf> extract(Uint8List bytes, {required String sourceName}) {
    throw UnimplementedError();
  }
}

class _RecordingExplainBackGateway implements ExplainBackGateway {
  ExplainBackRequest? lastRequest;

  @override
  Future<ExplainBackResult> evaluate(ExplainBackRequest request) async {
    lastRequest = request;
    return ExplainBackEvaluated(
      attemptId: request.attemptId,
      sourceVersionId: request.sourceVersionId,
      sourceContentDigest: request.sourceContentDigest,
      kind: ExplainBackEvaluationKind.gapDetected,
      feedback: 'Temel fikir doğru, bir bağlantı eksik.',
      targetedRepair: 'Enerjinin kimyasal biçimde depolandığını da belirt.',
      executionRef: 'test:explain-back',
    );
  }
}

void main() {
  sqfliteFfiInit();

  testWidgets('Explain-back uses server material UUID and normalized grounding hash', (tester) async {
    final store = await SqliteSourceStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    addTearDown(store.close);

    final ingest = SourceIngestService(
      store: store,
      pdfTextExtractor: const _UnusedPdfExtractor(),
    );
    const localMaterialId = MaterialId('local-explain-back-material');
    await ingest.ingestPastedText(
      learner: AppRuntime.localM5LearnerFixture,
      materialId: localMaterialId,
      text: '  Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür.\r\n',
      sourceName: 'Biyoloji notu',
    );

    final source = await store.currentSourceVersion(
      learner: AppRuntime.localM5LearnerFixture,
      materialId: localMaterialId,
    );
    expect(source, isNotNull);

    const serverMaterialId = '55555555-5555-4555-8555-555555555555';
    await store.saveServerMaterialBinding(
      learner: AppRuntime.localM5LearnerFixture,
      materialId: localMaterialId,
      sourceVersionId: source!.identity.sourceVersionId,
      serverMaterialId: serverMaterialId,
    );

    final explainBack = _RecordingExplainBackGateway();
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(
        sourceStore: store,
        learningStore: store.learningTruthStore(),
      ),
      telemetry: store.operationalTelemetry(),
      explainBack: explainBack,
    );

    await tester.pumpWidget(
      MaterialApp(home: ExplainBackScreen(runtime: runtime, source: source)),
    );
    await tester.enterText(
      find.byType(TextField),
      'Fotosentezde ışık enerjisi kimyasal enerjiye dönüşür.',
    );
    await tester.tap(find.text('Anlatımımı değerlendir'));
    await tester.pumpAndSettle();

    expect(find.text('Temel fikir doğru, bir bağlantı eksik.'), findsOneWidget);
    expect(explainBack.lastRequest, isNotNull);
    expect(explainBack.lastRequest!.materialId.value, serverMaterialId);
    expect(explainBack.lastRequest!.sourceVersionId, source.identity.sourceVersionId);
    expect(explainBack.lastRequest!.sourceContentDigest, source.identity.contentDigest);

    final expectedGroundingHash = sha256
        .convert(utf8.encode('Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür.'))
        .toString();
    expect(explainBack.lastRequest!.groundingContentHash, expectedGroundingHash);
  });
}
