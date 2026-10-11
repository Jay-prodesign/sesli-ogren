import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/domain/authenticated_learner.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _TwoPagePdfExtractor implements PdfTextExtractor {
  const _TwoPagePdfExtractor();

  @override
  Future<ExtractedPdf> extract(Uint8List bytes, {required String sourceName}) async {
    if (bytes.isEmpty || sourceName.isEmpty) {
      throw StateError('PDF fixture input must be non-empty.');
    }
    return const ExtractedPdf(
      text:
          'Learning evidence page one\n\n'
          'Second page keeps provenance',
      anchors: [
        SourceAnchor(startOffset: 0, endOffset: 26, pageNumber: 1),
        SourceAnchor(startOffset: 28, endOffset: 56, pageNumber: 2),
      ],
      pageCount: 2,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test('PDF ingest keeps extracted page provenance across store reopen', () async {
    final bytes = await File('test/fixtures/two_page_text.pdf').readAsBytes();
    final temp = await Directory.systemTemp.createTemp('sesli-ogren-source-');
    final databasePath = '${temp.path}/source.db';
    const learner = AuthenticatedLearner(id: LearnerId('pdf-learner'));
    const materialId = MaterialId('pdf-material');
    SqliteSourceStore? store;

    try {
      store = await SqliteSourceStore.open(factory: databaseFactoryFfi, path: databasePath);
      final service = SourceIngestService(
        store: store,
        pdfTextExtractor: const _TwoPagePdfExtractor(),
        now: () => DateTime.utc(2026, 10, 4, 12),
      );

      final result = await service.ingestPdf(
        learner: learner,
        materialId: materialId,
        bytes: bytes,
        originalName: '../two_page_text.pdf',
      );

      expect(result.sourceVersion.sourceName, 'two_page_text.pdf');
      expect(result.sourceVersion.mimeType, 'application/pdf');
      expect(result.sourceVersion.byteSize, bytes.length);
      expect(result.extractedContent.normalizedText, contains('Learning evidence page one'));
      expect(result.extractedContent.normalizedText, contains('Second page keeps provenance'));
      expect(result.extractedContent.anchors.map((anchor) => anchor.pageNumber), [1, 2]);

      final sourceVersionId = result.sourceVersion.identity.sourceVersionId;
      await store.close();
      store = null;

      store = await SqliteSourceStore.open(factory: databaseFactoryFfi, path: databasePath);
      final reopenedSource = await store.currentSourceVersion(learner: learner, materialId: materialId);
      final reopenedExtraction = await store.extractedContentForSource(
        learner: learner,
        sourceVersionId: sourceVersionId,
      );

      expect(reopenedSource?.identity.sourceVersionId, sourceVersionId);
      expect(reopenedExtraction?.sourceVersionId, sourceVersionId);
      expect(reopenedExtraction?.anchors.map((anchor) => anchor.pageNumber), [1, 2]);
    } finally {
      await store?.close();
      await temp.delete(recursive: true);
    }
  });
}
