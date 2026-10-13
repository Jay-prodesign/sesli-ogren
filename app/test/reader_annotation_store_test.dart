import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/domain/authenticated_learner.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sesli_ogren/src/domain/reader_annotation.dart';
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

  test('Reader annotations are current-source, learner-namespaced, local truth but never learner evidence', () async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    const local = LearnerIdentity.local();
    const account = LearnerIdentity.authenticated(id: LearnerId('reader-account'));
    const materialId = MaterialId('reader-annotations');
    const text = 'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür. Klorofil ışığın soğurulmasına yardım eder.';

    final ingested = await ingest.ingestPastedText(
      learner: local,
      materialId: materialId,
      sourceName: 'Biyoloji',
      text: text,
    );
    final sourceVersionId = ingested.sourceVersion.identity.sourceVersionId;
    final start = text.indexOf('ışık enerjisini');
    final end = start + 'ışık enerjisini'.length;
    final anchor = SourceAnchor(startOffset: start, endOffset: end);

    final highlight = await store.upsertReaderAnnotation(
      learner: local,
      materialId: materialId,
      sourceVersionId: sourceVersionId,
      sourceAnchor: anchor,
      selectedText: text.substring(start, end),
      kind: ReaderAnnotationKind.highlight,
      updatedAt: DateTime.utc(2026, 10, 13, 12),
    );
    final note = await store.upsertReaderAnnotation(
      learner: local,
      materialId: materialId,
      sourceVersionId: sourceVersionId,
      sourceAnchor: anchor,
      selectedText: text.substring(start, end),
      kind: ReaderAnnotationKind.note,
      noteText: 'Enerji dönüşümünü tekrar sor.',
      updatedAt: DateTime.utc(2026, 10, 13, 12, 1),
    );

    final annotations = await store.readerAnnotationsForSource(
      learner: local,
      materialId: materialId,
      sourceVersionId: sourceVersionId,
    );
    expect(annotations.map((item) => item.id), containsAll([highlight.id, note.id]));
    expect(
      annotations.where((item) => item.kind == ReaderAnnotationKind.note).single.noteText,
      'Enerji dönüşümünü tekrar sor.',
    );
    expect(
      await store.readerAnnotationsForSource(
        learner: account,
        materialId: materialId,
        sourceVersionId: sourceVersionId,
      ),
      isEmpty,
    );
    expect(
      await store.learningTruthStore().evidenceForMaterial(
        learner: local,
        materialId: materialId,
        sourceVersionId: sourceVersionId,
      ),
      isEmpty,
    );
  });

  test('Reader annotation fails closed when text and exact source anchor do not match', () async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    const learner = LearnerIdentity.local();
    const materialId = MaterialId('reader-anchor-fail');
    const text = 'Klorofil ışığın soğurulmasına yardım eder.';
    final ingested = await ingest.ingestPastedText(
      learner: learner,
      materialId: materialId,
      sourceName: 'Kaynak',
      text: text,
    );

    await expectLater(
      store.upsertReaderAnnotation(
        learner: learner,
        materialId: materialId,
        sourceVersionId: ingested.sourceVersion.identity.sourceVersionId,
        sourceAnchor: const SourceAnchor(startOffset: 0, endOffset: 8),
        selectedText: 'Fotosente',
        kind: ReaderAnnotationKind.highlight,
        updatedAt: DateTime.utc(2026, 10, 13, 12),
      ),
      throwsA(isA<SourceStoreConflict>()),
    );
  });

  test('source replacement invalidates old annotations instead of rebinding them', () async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    const learner = LearnerIdentity.local();
    const materialId = MaterialId('reader-source-replacement');
    const firstText = 'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür.';

    final first = await ingest.ingestPastedText(
      learner: learner,
      materialId: materialId,
      sourceName: 'İlk kaynak',
      text: firstText,
    );
    const selected = 'Fotosentez';
    await store.upsertReaderAnnotation(
      learner: learner,
      materialId: materialId,
      sourceVersionId: first.sourceVersion.identity.sourceVersionId,
      sourceAnchor: const SourceAnchor(startOffset: 0, endOffset: selected.length),
      selectedText: selected,
      kind: ReaderAnnotationKind.highlight,
      updatedAt: DateTime.utc(2026, 10, 13, 12),
    );

    final second = await ingest.ingestPastedText(
      learner: learner,
      materialId: materialId,
      sourceName: 'Yeni kaynak',
      text: 'Hücresel solunum kimyasal enerjiyi kullanılabilir enerjiye dönüştürür.',
    );
    final secondSourceId = second.sourceVersion.identity.sourceVersionId;
    expect(
      await store.readerAnnotationsForSource(learner: learner, materialId: materialId, sourceVersionId: secondSourceId),
      isEmpty,
    );
    expect(
      await store.staleReaderAnnotationCount(
        learner: learner,
        materialId: materialId,
        currentSourceVersionId: secondSourceId,
      ),
      1,
    );
  });
}
