import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/domain/authenticated_learner.dart';
import 'package:sesli_ogren/src/domain/grounded_tutor.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sesli_ogren/src/learning/grounded_tutor_service.dart';
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

  test('Tutor persists learner-namespaced source-supported turns and never invents evidence', () async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    final service = GroundedTutorService(store: store, now: () => DateTime.utc(2026, 10, 13, 12));
    const learner = LearnerIdentity.local();
    const materialId = MaterialId('tutor-material');

    await ingest.ingestPastedText(
      learner: learner,
      materialId: materialId,
      sourceName: 'Fotosentez notu',
      text:
          'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür. '
          'Klorofil ışığın soğurulmasına yardım eder. '
          'Karbondioksit süreçte önemli bir girdidir.',
    );
    final opened = await service.openThread(learner: learner, materialId: materialId);
    final answered = await service.ask(
      learner: learner,
      threadId: opened.thread.id,
      question: 'Klorofil ne işe yarar?',
    );

    expect(answered.turns, hasLength(2));
    expect(answered.turns.first.role, GroundedTutorTurnRole.learner);
    final tutor = answered.turns.last;
    expect(tutor.role, GroundedTutorTurnRole.tutor);
    expect(tutor.supportState, GroundedTutorSupportState.sourceSupported);
    expect(tutor.sourceExcerpt, contains('Klorofil'));
    expect(tutor.sourceAnchor, isNotNull);
    final learningStore = store.learningTruthStore();
    expect(await learningStore.learnerState(learner: learner, materialId: materialId), isNull);
    expect(await learningStore.nextLearningAction(learner: learner, materialId: materialId), isNull);
    expect(
      await learningStore.evidenceForMaterial(
        learner: learner,
        materialId: materialId,
        sourceVersionId: answered.thread.sourceVersionId,
      ),
      isEmpty,
    );
  });

  test('Tutor says unsupported instead of fabricating an answer', () async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    final service = GroundedTutorService(store: store, now: () => DateTime.utc(2026, 10, 13, 12, 30));
    const learner = LearnerIdentity.local();
    const materialId = MaterialId('unsupported-tutor');

    await ingest.ingestPastedText(
      learner: learner,
      materialId: materialId,
      sourceName: 'Kısa not',
      text: 'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür.',
    );
    final opened = await service.openThread(learner: learner, materialId: materialId);
    final answered = await service.ask(
      learner: learner,
      threadId: opened.thread.id,
      question: 'Roma İmparatorluğu neden yıkıldı?',
    );
    final tutor = answered.turns.last;
    expect(tutor.supportState, GroundedTutorSupportState.sourceUnsupported);
    expect(tutor.sourceAnchor, isNull);
    expect(tutor.sourceExcerpt, isNull);
    expect(tutor.text, contains('yeterli dayanak bulamadım'));
  });

  test('Reader context anchors pronoun-like questions to the exact selected source', () async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    final service = GroundedTutorService(store: store, now: () => DateTime.utc(2026, 10, 13, 13));
    const learner = LearnerIdentity.local();
    const materialId = MaterialId('context-tutor');
    const text =
        'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür. '
        'Klorofil ışığın soğurulmasına yardım eder.';
    await ingest.ingestPastedText(learner: learner, materialId: materialId, sourceName: 'Bağlam notu', text: text);
    final start = text.indexOf('Klorofil');
    final anchor = SourceAnchor(startOffset: start, endOffset: text.length);
    final opened = await service.openThread(learner: learner, materialId: materialId, contextAnchor: anchor);
    final answered = await service.ask(
      learner: learner,
      threadId: opened.thread.id,
      question: 'Bunu biraz açar mısın?',
    );
    final tutor = answered.turns.last;
    expect(tutor.supportState, GroundedTutorSupportState.sourceSupported);
    expect(tutor.sourceAnchor?.startOffset, start);
    expect(tutor.sourceExcerpt, text.substring(start));
  });

  test('Reader context does not make an unrelated question look source-supported', () async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    final service = GroundedTutorService(store: store, now: () => DateTime.utc(2026, 10, 13, 13, 30));
    const learner = LearnerIdentity.local();
    const materialId = MaterialId('context-unrelated-tutor');
    const text =
        'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür. '
        'Klorofil ışığın soğurulmasına yardım eder.';
    await ingest.ingestPastedText(learner: learner, materialId: materialId, sourceName: 'Bağlam notu', text: text);
    final start = text.indexOf('Klorofil');
    final anchor = SourceAnchor(startOffset: start, endOffset: text.length);
    final opened = await service.openThread(learner: learner, materialId: materialId, contextAnchor: anchor);
    final answered = await service.ask(
      learner: learner,
      threadId: opened.thread.id,
      question: 'Roma İmparatorluğu neden yıkıldı?',
    );
    final tutor = answered.turns.last;
    expect(tutor.supportState, GroundedTutorSupportState.sourceUnsupported);
    expect(tutor.sourceAnchor, isNull);
    expect(tutor.sourceExcerpt, isNull);
  });

  test('Source replacement invalidates old Tutor grounding without rebinding conversation', () async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    final service = GroundedTutorService(store: store, now: () => DateTime.utc(2026, 10, 13, 14));
    const learner = LearnerIdentity.local();
    const materialId = MaterialId('stale-tutor');

    await ingest.ingestPastedText(
      learner: learner,
      materialId: materialId,
      sourceName: 'Sürüm 1',
      text: 'Klorofil ışığın soğurulmasına yardım eder.',
    );
    final opened = await service.openThread(learner: learner, materialId: materialId);

    await ingest.ingestPastedText(
      learner: learner,
      materialId: materialId,
      sourceName: 'Sürüm 2',
      text: 'Mitokondri hücresel enerji dönüşümünde görev alır.',
    );

    expect(await store.groundedTutorThread(learner: learner, threadId: opened.thread.id), isNull);
    await expectLater(
      service.ask(learner: learner, threadId: opened.thread.id, question: 'Klorofil ne yapar?'),
      throwsA(isA<GroundedTutorException>()),
    );
  });
}
