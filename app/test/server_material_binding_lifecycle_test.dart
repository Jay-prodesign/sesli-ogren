import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/domain/authenticated_learner.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _UnusedPdfExtractor implements PdfTextExtractor {
  const _UnusedPdfExtractor();

  @override
  Future<ExtractedPdf> extract(Uint8List bytes, {required String sourceName}) {
    throw UnimplementedError();
  }
}

void main() {
  sqfliteFfiInit();

  test('summary cleanup keeps reusable server material identity', () async {
    final store = await SqliteSourceStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    addTearDown(store.close);

    const learner = AuthenticatedLearner(id: LearnerId('binding-lifecycle-learner'));
    const materialId = MaterialId('binding-lifecycle-material');
    final ingest = SourceIngestService(
      store: store,
      pdfTextExtractor: const _UnusedPdfExtractor(),
    );

    await ingest.ingestPastedText(
      learner: learner,
      materialId: materialId,
      text: 'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür.',
      sourceName: 'Biyoloji notu',
    );

    final source = await store.currentSourceVersion(
      learner: learner,
      materialId: materialId,
    );
    expect(source, isNotNull);

    await store.saveSummaryJob(
      learner: learner,
      materialId: materialId,
      sourceVersionId: source!.identity.sourceVersionId,
      serverMaterialId: '11111111-1111-4111-8111-111111111111',
      jobId: '22222222-2222-4222-8222-222222222222',
    );

    await store.clearSummaryJob(
      learner: learner,
      materialId: materialId,
    );

    expect(
      await store.summaryJobId(
        learner: learner,
        materialId: materialId,
        sourceVersionId: source.identity.sourceVersionId,
      ),
      isNull,
    );
    expect(
      await store.summaryServerMaterialId(
        learner: learner,
        materialId: materialId,
        sourceVersionId: source.identity.sourceVersionId,
      ),
      '11111111-1111-4111-8111-111111111111',
    );

    await store.clearServerMaterialBinding(
      learner: learner,
      materialId: materialId,
    );

    expect(
      await store.summaryServerMaterialId(
        learner: learner,
        materialId: materialId,
      ),
      isNull,
    );
  });
}
