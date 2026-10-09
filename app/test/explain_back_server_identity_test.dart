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
import 'package:sesli_ogren/src/generation/supabase_source_summary_gateway.dart';
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
  final List<ExplainBackRequest> requests = <ExplainBackRequest>[];

  @override
  Future<ExplainBackResult> evaluate(ExplainBackRequest request) async {
    lastRequest = request;
    requests.add(request);
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

class _RecordingSourceGateway extends SupabaseSourceSummaryGateway {
  _RecordingSourceGateway({required this.createdServerMaterialId});

  final String createdServerMaterialId;
  final List<String> deletedServerMaterialIds = <String>[];
  var ensureCalls = 0;

  @override
  Future<bool> deleteServerMaterial(String serverMaterialId) async {
    deletedServerMaterialIds.add(serverMaterialId);
    return true;
  }

  @override
  Future<String> ensureServerMaterial({required SourceIngestResult source}) async {
    ensureCalls += 1;
    return createdServerMaterialId;
  }
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder, {int maxPumps = 100}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Expected Explain-back widget was not reached within bounded pumps.');
}

Future<void> _pumpUntilCondition(
  WidgetTester tester,
  bool Function() condition, {
  int maxPumps = 100,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (condition()) return;
  }
  fail('Expected Explain-back condition was not reached within bounded pumps.');
}

void main() {
  sqfliteFfiInit();

  testWidgets('Explain-back uses server material UUID and normalized grounding hash', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);

    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
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
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
      explainBack: explainBack,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ExplainBackScreen(runtime: runtime, source: source),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Fotosentezde ışık enerjisi kimyasal enerjiye dönüşür.');
    await _tapVisible(tester, find.text('Anlatımımı değerlendir'));
    await _pumpUntilFound(tester, find.text('Temel fikir doğru, bir bağlantı eksik.'));

    expect(find.text('Temel fikir doğru, bir bağlantı eksik.'), findsOneWidget);
    expect(explainBack.lastRequest, isNotNull);
    expect(explainBack.lastRequest!.materialId.value, serverMaterialId);
    expect(explainBack.lastRequest!.sourceVersionId, source.identity.sourceVersionId);
    expect(explainBack.lastRequest!.sourceContentDigest, source.identity.contentDigest);

    final expectedGroundingHash = sha256
        .convert(utf8.encode('Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür.'))
        .toString();
    expect(explainBack.lastRequest!.groundingContentHash, expectedGroundingHash);

    final firstAttemptId = explainBack.lastRequest!.attemptId;
    await _tapVisible(tester, find.text('Tekrar kendi cümlelerimle anlat'));
    await _pumpUntilFound(tester, find.text('Anlatımımı değerlendir'));
    await tester.enterText(find.byType(TextField), 'Fotosentezde ışık enerjisi kimyasal enerjiye dönüşür.');
    await _tapVisible(tester, find.text('Anlatımımı değerlendir'));
    await _pumpUntilCondition(tester, () => explainBack.requests.length == 2);

    expect(explainBack.requests, hasLength(2));
    expect(explainBack.lastRequest!.attemptId, firstAttemptId);
  });

  testWidgets('Explain-back deletes stale server source before rebinding a newer local source', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);

    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    const materialId = MaterialId('explain-back-stale-binding-material');
    final first = await ingest.ingestPastedText(
      learner: AppRuntime.localM5LearnerFixture,
      materialId: materialId,
      text: 'Eski kaynak sürümü.',
      sourceName: 'Biyoloji notu',
    );
    const oldServerMaterialId = '66666666-6666-4666-8666-666666666666';
    await store.saveServerMaterialBinding(
      learner: AppRuntime.localM5LearnerFixture,
      materialId: materialId,
      sourceVersionId: first.sourceVersion.identity.sourceVersionId,
      serverMaterialId: oldServerMaterialId,
    );

    final second = await ingest.ingestPastedText(
      learner: AppRuntime.localM5LearnerFixture,
      materialId: materialId,
      text: 'Yeni kaynak sürümü fotosentezin enerji dönüşümünü anlatır.',
      sourceName: 'Biyoloji notu',
    );
    const newServerMaterialId = '77777777-7777-4777-8777-777777777777';
    final sourceGateway = _RecordingSourceGateway(createdServerMaterialId: newServerMaterialId);
    final explainBack = _RecordingExplainBackGateway();
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
      explainBack: explainBack,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ExplainBackScreen(runtime: runtime, source: second.sourceVersion, sourceGateway: sourceGateway),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür.');
    await _tapVisible(tester, find.text('Anlatımımı değerlendir'));
    await _pumpUntilCondition(
      tester,
      () => sourceGateway.ensureCalls == 1 && explainBack.lastRequest != null,
    );

    expect(sourceGateway.deletedServerMaterialIds, [oldServerMaterialId]);
    expect(sourceGateway.ensureCalls, 1);
    expect(explainBack.lastRequest?.materialId.value, newServerMaterialId);
    expect(
      await store.summaryServerMaterialId(
        learner: runtime.learner,
        materialId: materialId,
        sourceVersionId: second.sourceVersion.identity.sourceVersionId,
      ),
      newServerMaterialId,
    );
    expect(
      await store.summaryServerMaterialId(
        learner: runtime.learner,
        materialId: materialId,
        sourceVersionId: first.sourceVersion.identity.sourceVersionId,
      ),
      isNull,
    );
  });
}
