import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/data/image_text_extractor.dart';
import 'package:sesli_ogren/src/data/office_text_extractor.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/domain/authenticated_learner.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _UnusedPdfExtractor implements PdfTextExtractor {
  const _UnusedPdfExtractor();

  @override
  Future<ExtractedPdf> extract(Uint8List bytes, {required String sourceName}) => throw UnimplementedError();
}

class _OfficeExtractor implements OfficeTextExtractor {
  const _OfficeExtractor();

  @override
  Future<ExtractedOfficeText> extract(Uint8List bytes, {required String sourceName}) async {
    return const ExtractedOfficeText(
      text: 'Slayt bir.\n\nSlayt iki.',
      anchors: [
        SourceAnchor(startOffset: 0, endOffset: 10, pageNumber: 1),
        SourceAnchor(startOffset: 12, endOffset: 22, pageNumber: 2),
      ],
      format: OfficeSourceFormat.pptx,
      unitCount: 2,
      warnings: ['PPTX_SLIDE_TEXT_ONLY'],
    );
  }
}

class _LegacyOfficeExtractor implements OfficeTextExtractor {
  const _LegacyOfficeExtractor();

  @override
  Future<ExtractedOfficeText> extract(Uint8List bytes, {required String sourceName}) async {
    return const ExtractedOfficeText(
      text: 'Eski Word ders notu',
      anchors: [SourceAnchor(startOffset: 0, endOffset: 19)],
      format: OfficeSourceFormat.doc,
      unitCount: 1,
      warnings: ['LEGACY_DOC_TEXT_ONLY'],
    );
  }
}

class _ImageExtractor implements ImageTextExtractor {
  const _ImageExtractor();

  @override
  Future<ExtractedImageText> extract(Uint8List bytes, {required String sourceName}) async {
    return const ExtractedImageText(
      text: 'Fotoğraftaki ders notu',
      anchors: [SourceAnchor(startOffset: 0, endOffset: 22, pageNumber: 1)],
      warnings: ['OCR_TEXT_REQUIRES_SOURCE_CHECK'],
    );
  }
}

void main() {
  sqfliteFfiInit();

  test('Office ingest enters the canonical source-version and extracted-content pipeline', () async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final service = SourceIngestService(
      store: store,
      pdfTextExtractor: const _UnusedPdfExtractor(),
      officeTextExtractor: const _OfficeExtractor(),
      imageTextExtractor: const _ImageExtractor(),
      now: () => DateTime.utc(2026, 10, 13, 10),
    );
    const learner = LearnerIdentity.local();
    const materialId = MaterialId('pptx-material');

    final result = await service.ingestOffice(
      learner: learner,
      materialId: materialId,
      bytes: Uint8List.fromList([0x50, 0x4b, 0x03, 0x04, 1, 2, 3]),
      originalName: 'Biyoloji.pptx',
    );

    expect(result.material.mediaType, SourceMediaType.presentation);
    expect(result.sourceVersion.mediaType, SourceMediaType.presentation);
    expect(result.sourceVersion.sourceName, 'Biyoloji.pptx');
    expect(result.sourceVersion.mimeType, 'application/vnd.openxmlformats-officedocument.presentationml.presentation');
    expect(result.extractedContent.normalizedText, 'Slayt bir.\n\nSlayt iki.');
    expect(result.extractedContent.anchors.map((anchor) => anchor.pageNumber), [1, 2]);
    expect(result.extractedContent.warnings, contains('PPTX_SLIDE_TEXT_ONLY'));
    expect(
      (await store.currentSourceVersion(learner: learner, materialId: materialId))!.identity.sourceVersionId,
      result.sourceVersion.identity.sourceVersionId,
    );
  });

  test('legacy DOC ingest records truthful OLE provenance in the canonical source pipeline', () async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final service = SourceIngestService(
      store: store,
      pdfTextExtractor: const _UnusedPdfExtractor(),
      officeTextExtractor: const _LegacyOfficeExtractor(),
      imageTextExtractor: const _ImageExtractor(),
      now: () => DateTime.utc(2026, 10, 13, 10, 30),
    );
    const learner = LearnerIdentity.local();
    const materialId = MaterialId('legacy-doc-material');

    final result = await service.ingestOffice(
      learner: learner,
      materialId: materialId,
      bytes: Uint8List.fromList([0xd0, 0xcf, 0x11, 0xe0, 1, 2, 3]),
      originalName: 'Tarih.doc',
    );

    expect(result.material.mediaType, SourceMediaType.document);
    expect(result.sourceVersion.mimeType, 'application/msword');
    expect(result.extractedContent.method, 'office_legacy_ole_text');
    expect(result.extractedContent.methodVersion, 'legacy-ole-v1');
    expect(result.extractedContent.warnings, contains('LEGACY_DOC_TEXT_ONLY'));
  });

  test('image OCR stays user-provided source truth and carries an explicit OCR warning', () async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final service = SourceIngestService(
      store: store,
      pdfTextExtractor: const _UnusedPdfExtractor(),
      officeTextExtractor: const _OfficeExtractor(),
      imageTextExtractor: const _ImageExtractor(),
      now: () => DateTime.utc(2026, 10, 13, 11),
    );
    const learner = LearnerIdentity.local();
    const materialId = MaterialId('image-material');

    final result = await service.ingestImage(
      learner: learner,
      materialId: materialId,
      bytes: Uint8List.fromList([0xff, 0xd8, 0xff, 1, 2, 3]),
      originalName: 'tahta-notu.jpg',
    );

    expect(result.material.mediaType, SourceMediaType.image);
    expect(result.sourceVersion.identity.trustClass, SourceTrustClass.userProvided);
    expect(result.sourceVersion.identity.knowledgeClass, SourceKnowledgeClass.learnerOwned);
    expect(result.extractedContent.method, 'mlkit_ocr');
    expect(result.extractedContent.warnings, contains('OCR_TEXT_REQUIRES_SOURCE_CHECK'));
    expect(result.extractedContent.anchors.single.pageNumber, 1);
  });

  test('replacing an Office source with an image creates a distinct current source version', () async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final service = SourceIngestService(
      store: store,
      pdfTextExtractor: const _UnusedPdfExtractor(),
      officeTextExtractor: const _OfficeExtractor(),
      imageTextExtractor: const _ImageExtractor(),
      now: () => DateTime.utc(2026, 10, 13, 12),
    );
    const learner = LearnerIdentity.local();
    const materialId = MaterialId('replacement-material');

    final office = await service.ingestOffice(
      learner: learner,
      materialId: materialId,
      bytes: Uint8List.fromList([0x50, 0x4b, 0x03, 0x04, 9]),
      originalName: 'notlar.pptx',
    );
    final image = await service.ingestImage(
      learner: learner,
      materialId: materialId,
      bytes: Uint8List.fromList([0x89, 0x50, 0x4e, 0x47, 9]),
      originalName: 'notlar.png',
    );

    expect(image.sourceVersion.identity.sourceVersionId, isNot(office.sourceVersion.identity.sourceVersionId));
    final versions = await store.sourceVersions(learner: learner, materialId: materialId);
    expect(versions, hasLength(2));
    expect(versions.first.supersededBy, image.sourceVersion.identity.sourceVersionId);
  });
}
