import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/app_runtime.dart';
import 'package:sesli_ogren/src/app/quick_recap_screen.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
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

class _RecordingSummaryGateway extends SupabaseSourceSummaryGateway {
  _RecordingSummaryGateway({required this.serverMaterialId});

  final String serverMaterialId;
  final List<String> deletedMaterialIds = <String>[];
  var submitCalls = 0;

  @override
  Future<bool> deleteServerMaterial(String serverMaterialId) async {
    deletedMaterialIds.add(serverMaterialId);
    return true;
  }

  @override
  Future<ServerSummarySubmission> submit({required SourceIngestResult source}) async {
    submitCalls += 1;
    return ServerSummarySubmission(materialId: serverMaterialId, jobId: '22222222-2222-4222-8222-222222222222');
  }

  @override
  Future<bool> dispatch(String jobId) async => true;

  @override
  Future<ServerSummaryStatus> status(String jobId) async => const ServerSummaryStatus(
    state: 'SUCCEEDED',
    summary: 'Kaynağa bağlı kısa özet.',
    keyPoints: ['Aynı server material yeniden kullanıldı.'],
  );
}

class _DispatchFailureGateway extends _RecordingSummaryGateway {
  _DispatchFailureGateway({required super.serverMaterialId});

  @override
  Future<bool> dispatch(String jobId) async => throw StateError('offline');

  @override
  Future<ServerSummaryStatus> status(String jobId) async => const ServerSummaryStatus(state: 'QUEUED');
}

void main() {
  sqfliteFfiInit();

  testWidgets('Quick Recap reuses current-source server material created by Explain', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);

    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    const materialId = MaterialId('quick-recap-shared-server-material');
    await ingest.ingestPastedText(
      learner: AppRuntime.localM5LearnerFixture,
      materialId: materialId,
      text: 'Fotosentez ışık enerjisinin kimyasal enerjiye dönüşmesini sağlar.',
      sourceName: 'Biyoloji notu',
    );
    final source = await store.currentSourceVersion(learner: AppRuntime.localM5LearnerFixture, materialId: materialId);
    expect(source, isNotNull);

    const serverMaterialId = '11111111-1111-4111-8111-111111111111';
    await store.saveServerMaterialBinding(
      learner: AppRuntime.localM5LearnerFixture,
      materialId: materialId,
      sourceVersionId: source!.identity.sourceVersionId,
      serverMaterialId: serverMaterialId,
    );

    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
    );
    final gateway = _RecordingSummaryGateway(serverMaterialId: serverMaterialId);

    await tester.pumpWidget(
      MaterialApp(
        home: QuickRecapScreen(runtime: runtime, materialId: materialId, summaryGateway: gateway),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Özet oluştur'));
    await tester.pumpAndSettle();

    expect(gateway.submitCalls, 1);
    expect(gateway.deletedMaterialIds, isEmpty);
    expect(find.text('Kaynağa bağlı kısa özet.'), findsOneWidget);
    // A generated, persisted recap must be usable outside the app.
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedText = (call.arguments as Map<Object?, Object?>)['text'] as String?;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.tap(find.text('Özeti kopyala'));
    await tester.pumpAndSettle();
    expect(copiedText, contains('Kaynağa bağlı kısa özet.'));
    expect(copiedText, contains('Hızlı özet —'));
    expect(copiedText, contains('Sesli Öğren'));
    expect(copiedText, contains('AI tarafından oluşturulan özet'));
    expect(copiedText, contains('Aynı server material yeniden kullanıldı.'));
    expect(find.text('Özet panoya kopyalandı'), findsOneWidget);
    expect(find.text('Paylaş'), findsOneWidget);

    expect(
      await store.summaryServerMaterialId(
        learner: runtime.learner,
        materialId: materialId,
        sourceVersionId: source.identity.sourceVersionId,
      ),
      serverMaterialId,
    );
  });
  testWidgets('Quick Recap shows recoverable error when dispatch throws', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    const materialId = MaterialId('quick-recap-dispatch-error');
    await ingest.ingestPastedText(
      learner: AppRuntime.localM5LearnerFixture,
      materialId: materialId,
      text: 'Fotosentez ışık enerjisinin kimyasal enerjiye dönüşmesini sağlar.',
      sourceName: 'Biyoloji notu',
    );
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
    );
    final gateway = _DispatchFailureGateway(serverMaterialId: '11111111-1111-4111-8111-111111111111');
    await tester.pumpWidget(
      MaterialApp(
        home: QuickRecapScreen(runtime: runtime, materialId: materialId, summaryGateway: gateway),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Özet oluştur'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(find.textContaining('Sunucuya ulaşılamadı'), findsOneWidget);
    expect(find.text('İşlemi başlatmayı tekrar dene'), findsOneWidget);
  });
}

