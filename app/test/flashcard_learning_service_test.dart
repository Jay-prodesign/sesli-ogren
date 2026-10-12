import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/domain/authenticated_learner.dart';
import 'package:sesli_ogren/src/domain/flashcard_learning.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sesli_ogren/src/learning/flashcard_learning_service.dart';
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

  test('flashcards stay source-grounded, stable and resume review state', () async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    final service = FlashcardLearningService(
      store: store,
      now: () => DateTime.utc(2026, 10, 12, 12),
    );
    const learner = LearnerIdentity.local();
    const materialId = MaterialId('flashcard-material');

    await ingest.ingestPastedText(
      learner: learner,
      materialId: materialId,
      sourceName: 'Fotosentez notu',
      text:
          'Fotosentez sırasında bitkiler ışık enerjisini kimyasal enerjiye dönüştürür. '
          'Klorofil ışığın soğurulmasında önemli görev alır. '
          'Karbondioksit ve su kullanılarak glikoz üretimine katkı sağlanır. '
          'Oksijen süreç sonunda çevreye bırakılabilir.',
    );

    final first = await service.openCurrentSet(learner: learner, materialId: materialId);
    expect(first.set.cards.length, greaterThanOrEqualTo(3));
    expect(first.session.cursorIndex, 0);
    expect(first.session.isCompleted, isFalse);
    expect(first.currentCard, isNotNull);
    expect(first.currentCard!.sourceExcerpt, contains(first.currentCard!.back));
    expect(first.currentCard!.front, contains('_____'));

    final reopened = await service.openCurrentSet(learner: learner, materialId: materialId);
    expect(reopened.set.id, first.set.id);
    expect(reopened.set.cards.map((card) => card.id), first.set.cards.map((card) => card.id));

    await expectLater(
      () => service.recordResponse(
        learner: learner,
        materialId: materialId,
        setId: first.set.id,
        cardId: first.currentCard!.id,
        response: FlashcardResponse.remembered,
        answerWasRevealed: false,
      ),
      throwsA(isA<FlashcardLearningException>()),
    );

    final afterOne = await service.recordResponse(
      learner: learner,
      materialId: materialId,
      setId: first.set.id,
      cardId: first.currentCard!.id,
      response: FlashcardResponse.remembered,
      answerWasRevealed: true,
    );
    expect(afterOne.session.cursorIndex, 1);
    expect(afterOne.session.rememberedCount, 1);
    expect(afterOne.reviews[first.currentCard!.id]?.reviewCount, 1);
    expect(afterOne.reviews[first.currentCard!.id]?.lastResponse, FlashcardResponse.remembered);

    final durable = await service.openCurrentSet(learner: learner, materialId: materialId);
    expect(durable.session.cursorIndex, 1);
    expect(durable.reviews[first.currentCard!.id]?.rememberedCount, 1);
  });

  test('source update creates a new set and never inherits old review state', () async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    final service = FlashcardLearningService(store: store);
    const learner = LearnerIdentity.local();
    const materialId = MaterialId('flashcard-source-update');

    await ingest.ingestPastedText(
      learner: learner,
      materialId: materialId,
      sourceName: 'İlk sürüm',
      text:
          'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür. '
          'Klorofil ışığın soğurulmasına yardım eder. '
          'Karbondioksit süreçte önemli bir girdidir.',
    );
    final first = await service.openCurrentSet(learner: learner, materialId: materialId);
    final firstCard = first.currentCard!;
    await service.recordResponse(
      learner: learner,
      materialId: materialId,
      setId: first.set.id,
      cardId: firstCard.id,
      response: FlashcardResponse.again,
      answerWasRevealed: true,
    );

    await ingest.ingestPastedText(
      learner: learner,
      materialId: materialId,
      sourceName: 'İkinci sürüm',
      text:
          'Hücresel solunum glikozdaki kimyasal enerjiyi kullanılabilir enerjiye dönüştürür. '
          'Mitokondri ökaryot hücrelerde enerji dönüşümünde görev alır. '
          'Oksijenli solunumda oksijen önemli bir girdidir.',
    );

    final second = await service.openCurrentSet(learner: learner, materialId: materialId);
    expect(second.set.id, isNot(first.set.id));
    expect(second.set.sourceVersionId, isNot(first.set.sourceVersionId));
    expect(second.session.cursorIndex, 0);
    expect(second.reviews, isEmpty);
  });
}
