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

class _RecordingPdfExtractor implements PdfTextExtractor {
  int calls = 0;

  @override
  Future<ExtractedPdf> extract(Uint8List bytes, {required String sourceName}) async {
    calls++;
    return const ExtractedPdf(
      text: 'PDF text',
      anchors: [SourceAnchor(startOffset: 0, endOffset: 8, pageNumber: 1)],
      pageCount: 1,
    );
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
    store = await SqliteSourceStore.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    service = SourceIngestService(
      store: store,
      pdfTextExtractor: const _UnusedPdfExtractor(),
      now: () => DateTime.utc(2026, 10, 4, 10),
    );
  });

  tearDown(() => store.close());

  test('active materials are learner scoped, newest first, and exclude deleted', () async {
    const older = MaterialId('material-older');
    const newer = MaterialId('material-newer');
    await service.ingestPastedText(learner: learnerA, materialId: older, text: 'Older');
    service = SourceIngestService(
      store: store,
      pdfTextExtractor: const _UnusedPdfExtractor(),
      now: () => DateTime.utc(2026, 10, 4, 11),
    );
    await service.ingestPastedText(learner: learnerA, materialId: newer, text: 'Newer');
    await service.ingestPastedText(learner: learnerB, materialId: const MaterialId('other-user'), text: 'Private');

    expect((await store.activeMaterials(learner: learnerA)).map((item) => item.id), [newer, older]);
    expect(await store.activeMaterials(learner: learnerB), hasLength(1));

    await store.deleteMaterial(learner: learnerA, materialId: newer, deletedAt: DateTime.utc(2026, 10, 4, 12));
    expect((await store.activeMaterials(learner: learnerA)).map((item) => item.id), [older]);
  });

  test('reader progress is learner and source-version scoped', () async {
    final first = await service.ingestPastedText(
      learner: learnerA,
      materialId: material,
      text: 'Uzun bir kaynak metninin ilk sürümü.',
    );
    final firstUpdatedAt = DateTime.utc(2026, 10, 10, 8);
    await store.saveReaderResumeProgress(
      learner: learnerA,
      materialId: material,
      sourceVersionId: first.sourceVersion.identity.sourceVersionId,
      progress: 0.42,
      updatedAt: firstUpdatedAt,
    );

    expect(
      await store.readerResumeProgress(
        learner: learnerA,
        materialId: material,
        sourceVersionId: first.sourceVersion.identity.sourceVersionId,
      ),
      closeTo(0.42, 0.0001),
    );
    expect(
      await store.readerResumeUpdatedAt(
        learner: learnerA,
        materialId: material,
        sourceVersionId: first.sourceVersion.identity.sourceVersionId,
      ),
      firstUpdatedAt,
    );
    expect(
      await store.readerResumeProgress(
        learner: learnerB,
        materialId: material,
        sourceVersionId: first.sourceVersion.identity.sourceVersionId,
      ),
      0,
    );

    final second = await service.ingestPastedText(
      learner: learnerA,
      materialId: material,
      text: 'Uzun bir kaynak metninin yeni ve farklı sürümü.',
    );
    expect(
      await store.readerResumeProgress(
        learner: learnerA,
        materialId: material,
        sourceVersionId: second.sourceVersion.identity.sourceVersionId,
      ),
      0,
    );
  });

  test('same pasted source retry is idempotent', () async {
    const sourceText = '  İlk satır\r\nİkinci satır  ';
    final first = await service.ingestPastedText(learner: learnerA, materialId: material, text: sourceText);
    final retry = await service.ingestPastedText(learner: learnerA, materialId: material, text: sourceText);

    expect(retry.sourceVersion.identity.sourceVersionId, first.sourceVersion.identity.sourceVersionId);
    expect(await store.sourceVersions(learner: learnerA, materialId: material), hasLength(1));
    expect(retry.extractedContent.normalizedText, 'İlk satır\nİkinci satır');
    expect(retry.material.currentSourceVersionId, retry.sourceVersion.identity.sourceVersionId);
  });

  test('source text change creates a new exact source version', () async {
    final first = await service.ingestPastedText(learner: learnerA, materialId: material, text: 'Satır 1\r\nSatır 2');
    final second = await service.ingestPastedText(learner: learnerA, materialId: material, text: 'Satır 1\nSatır 2');

    expect(second.sourceVersion.identity.sourceVersionId, isNot(first.sourceVersion.identity.sourceVersionId));
    expect(first.extractedContent.normalizedText, second.extractedContent.normalizedText);
  });

  test('new content supersedes old source and invalidates old extraction', () async {
    final first = await service.ingestPastedText(learner: learnerA, materialId: material, text: 'Version one');
    final second = await service.ingestPastedText(learner: learnerA, materialId: material, text: 'Version two');

    final versions = await store.sourceVersions(learner: learnerA, materialId: material);
    expect(versions, hasLength(2));
    expect(versions.first.identity.sourceVersionId, first.sourceVersion.identity.sourceVersionId);
    expect(versions.first.supersededBy, second.sourceVersion.identity.sourceVersionId);
    expect(
      await store.extractedContentForSource(
        learner: learnerA,
        sourceVersionId: first.sourceVersion.identity.sourceVersionId,
      ),
      isNull,
    );
    expect(
      (await store.currentSourceVersion(learner: learnerA, materialId: material))!.identity.sourceVersionId,
      second.sourceVersion.identity.sourceVersionId,
    );
  });

  test('retry of superseded source fails closed instead of becoming current', () async {
    await service.ingestPastedText(learner: learnerA, materialId: material, text: 'Old source');
    await service.ingestPastedText(learner: learnerA, materialId: material, text: 'New source');

    await expectLater(
      service.ingestPastedText(learner: learnerA, materialId: material, text: 'Old source'),
      throwsA(isA<SourceStoreConflict>()),
    );
  });

  test('guessed identifiers cannot cross learner boundary', () async {
    final source = await service.ingestPastedText(learner: learnerA, materialId: material, text: 'Tenant-owned source');

    expect(
      await store.sourceVersion(learner: learnerB, sourceVersionId: source.sourceVersion.identity.sourceVersionId),
      isNull,
    );
    expect(await store.material(learner: learnerB, materialId: material), isNull);
  });

  test('deleted material revokes source and extracted truth', () async {
    final source = await service.ingestPastedText(learner: learnerA, materialId: material, text: 'Delete me');
    await store.deleteMaterial(learner: learnerA, materialId: material, deletedAt: DateTime.utc(2026, 10, 4, 11));

    expect(await store.material(learner: learnerA, materialId: material), isNull);
    expect(await store.currentSourceVersion(learner: learnerA, materialId: material), isNull);
    expect(
      await store.sourceVersion(learner: learnerA, sourceVersionId: source.sourceVersion.identity.sourceVersionId),
      isNull,
    );
    expect(
      await store.extractedContentForSource(
        learner: learnerA,
        sourceVersionId: source.sourceVersion.identity.sourceVersionId,
      ),
      isNull,
    );
  });

  test('deleted material keeps a tombstone and cannot be silently reused', () async {
    final source = await service.ingestPastedText(
      learner: learnerA,
      materialId: material,
      text: 'Delete and do not resurrect',
    );
    await store.deleteMaterial(learner: learnerA, materialId: material, deletedAt: DateTime.utc(2026, 10, 4, 11));

    final versions = await store.sourceVersions(learner: learnerA, materialId: material);
    expect(versions, hasLength(1));
    expect(versions.single.identity.sourceVersionId, source.sourceVersion.identity.sourceVersionId);
    expect(versions.single.revokedAt, isNotNull);
    expect(versions.single.sourceName, 'Deleted source');
    expect(versions.single.inlineText, isNull);

    await expectLater(
      service.ingestPastedText(learner: learnerA, materialId: material, text: 'Delete and do not resurrect'),
      throwsA(isA<SourceStoreConflict>()),
    );
  });

  test('learner purge removes only the selected learner local data', () async {
    const sharedMaterial = MaterialId('shared-local-material');
    await service.ingestPastedText(
      learner: learnerA,
      materialId: sharedMaterial,
      text: 'Learner A local data must be purged.',
    );
    await service.ingestPastedText(
      learner: learnerB,
      materialId: sharedMaterial,
      text: 'Learner B local data must remain.',
    );

    await store.purgeLearnerData(learner: learnerA);

    expect(await store.material(learner: learnerA, materialId: sharedMaterial), isNull);
    expect(await store.activeMaterials(learner: learnerA), isEmpty);
    expect(await store.material(learner: learnerB, materialId: sharedMaterial), isNotNull);
  });

  test('oversized pasted text fails before persistence', () async {
    final bounded = SourceIngestService(
      store: store,
      pdfTextExtractor: const _UnusedPdfExtractor(),
      maxTextCharacters: 4,
    );

    await expectLater(
      bounded.ingestPastedText(learner: learnerA, materialId: material, text: '12345'),
      throwsA(isA<SourceIngestException>()),
    );
    expect(await store.material(learner: learnerA, materialId: material), isNull);
  });

  test('malformed PDF fails before parser execution', () async {
    final extractor = _RecordingPdfExtractor();
    final bounded = SourceIngestService(store: store, pdfTextExtractor: extractor);

    await expectLater(
      bounded.ingestPdf(
        learner: learnerA,
        materialId: material,
        bytes: Uint8List.fromList([1, 2, 3, 4, 5]),
        originalName: 'fake.pdf',
      ),
      throwsA(isA<SourceIngestException>()),
    );
    expect(extractor.calls, 0);
  });

  test('oversized PDF fails before parser execution', () async {
    final extractor = _RecordingPdfExtractor();
    final bounded = SourceIngestService(store: store, pdfTextExtractor: extractor, maxPdfBytes: 5);

    await expectLater(
      bounded.ingestPdf(
        learner: learnerA,
        materialId: material,
        bytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31]),
        originalName: 'large.pdf',
      ),
      throwsA(isA<SourceIngestException>()),
    );
    expect(extractor.calls, 0);
  });
}
