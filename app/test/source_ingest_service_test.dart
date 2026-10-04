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
  Future<ExtractedPdf> extract(bytes, {required String sourceName}) {
    throw UnimplementedError();
  }
}

void main() {
  sqfliteFfiInit();

  late SqliteSourceStore store;
  late SourceIngestService service;
  const learnerA = AuthenticatedLearner(id: LearnerId('learner-a'));
  const learnerB = AuthenticatedLearner(id: LearnerId('learner-b'));
  const material = MaterialId('material-1');

  setUp(() async {
    store = await SqliteSourceStore.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    service = SourceIngestService(
      store: store,
      pdfTextExtractor: const _UnusedPdfExtractor(),
      now: () => DateTime.utc(2026, 10, 4, 10),
    );
  });

  tearDown(() => store.close());

  test('same pasted source retry is idempotent', () async {
    final first = await service.ingestPastedText(
      learner: learnerA,
      materialId: material,
      text: '  İlk satır\r\nİkinci satır  ',
    );
    final retry = await service.ingestPastedText(
      learner: learnerA,
      materialId: material,
      text: 'İlk satır\nİkinci satır',
    );

    expect(retry.identity.sourceVersionId, first.identity.sourceVersionId);
    expect(
      await store.sourceVersions(learner: learnerA, materialId: material),
      hasLength(1),
    );
    expect(retry.extractedText, 'İlk satır\nİkinci satır');
  });

  test('new content supersedes previous current version without rewriting it', () async {
    final first = await service.ingestPastedText(
      learner: learnerA,
      materialId: material,
      text: 'Version one',
    );
    final second = await service.ingestPastedText(
      learner: learnerA,
      materialId: material,
      text: 'Version two',
    );

    final versions = await store.sourceVersions(
      learner: learnerA,
      materialId: material,
    );
    expect(versions, hasLength(2));
    expect(versions.first.identity.sourceVersionId, first.identity.sourceVersionId);
    expect(versions.first.supersededBy, second.identity.sourceVersionId);
    expect(versions.first.extractedText, 'Version one');
    expect(
      (await store.currentSourceVersion(
        learner: learnerA,
        materialId: material,
      ))!
          .identity
          .sourceVersionId,
      second.identity.sourceVersionId,
    );
  });

  test('guessed source version from another learner is fail-closed', () async {
    final source = await service.ingestPastedText(
      learner: learnerA,
      materialId: material,
      text: 'Tenant-owned source',
    );

    expect(
      await store.sourceVersion(
        learner: learnerB,
        sourceVersionId: source.identity.sourceVersionId,
      ),
      isNull,
    );
  });

  test('deleted material no longer resolves as current truth', () async {
    await service.ingestPastedText(
      learner: learnerA,
      materialId: material,
      text: 'Delete me',
    );
    await store.deleteMaterial(
      learner: learnerA,
      materialId: material,
      deletedAt: DateTime.utc(2026, 10, 4, 11),
    );

    expect(
      await store.currentSourceVersion(
        learner: learnerA,
        materialId: material,
      ),
      isNull,
    );
  });
}
