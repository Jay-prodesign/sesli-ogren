import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../data/sqlite_source_store.dart';
import '../domain/authenticated_learner.dart';
import '../domain/flashcard_learning.dart';
import '../domain/learning_contracts.dart';

class FlashcardLearningException implements Exception {
  const FlashcardLearningException(this.message);

  final String message;

  @override
  String toString() => 'FlashcardLearningException: $message';
}

class FlashcardLearningService {
  const FlashcardLearningService({required this.store, DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const generationVersion = 'flashcards-cloze-v2-source-lead';
  static const maxCards = 6;

  final SqliteSourceStore store;
  final DateTime Function() _now;

  Future<FlashcardStudyState> openCurrentSet({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  }) async {
    final source = await store.currentSourceVersion(learner: learner, materialId: materialId);
    if (source == null) {
      throw const FlashcardLearningException('Kartlar için güncel bir kaynak bulunamadı.');
    }
    final extracted = await store.extractedContentForSource(
      learner: learner,
      sourceVersionId: source.identity.sourceVersionId,
    );
    if (extracted == null || !extracted.isValid || extracted.normalizedText.trim().isEmpty) {
      throw const FlashcardLearningException('Güncel kaynak kart üretmek için okunabilir metin içermiyor.');
    }

    var set = await store.flashcardSet(
      learner: learner,
      materialId: materialId,
      sourceVersionId: source.identity.sourceVersionId,
      generationVersion: generationVersion,
    );
    if (set == null) {
      final candidate = _buildSet(
        materialId: materialId,
        sourceVersionId: source.identity.sourceVersionId,
        extracted: extracted,
        createdAt: _now().toUtc(),
      );
      await store.saveFlashcardSet(learner: learner, set: candidate);
      set = await store.flashcardSet(
        learner: learner,
        materialId: materialId,
        sourceVersionId: source.identity.sourceVersionId,
        generationVersion: generationVersion,
      );
    }
    if (set == null || set.cards.isEmpty) {
      throw const FlashcardLearningException('Bu kaynak için güvenilir kartlar oluşturulamadı.');
    }

    final reviews = await store.flashcardReviews(learner: learner, setId: set.id);
    final session = await store.flashcardSession(learner: learner, setId: set.id);
    return FlashcardStudyState(
      set: set,
      reviews: {for (final review in reviews) review.cardId: review},
      session: session ?? FlashcardSessionState.initial(set.id),
    );
  }

  Future<FlashcardStudyState> recordResponse({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    required FlashcardSetId setId,
    required FlashcardId cardId,
    required FlashcardResponse response,
    required bool answerWasRevealed,
  }) async {
    if (!answerWasRevealed) {
      throw const FlashcardLearningException('Kart yanıtı, cevap görülmeden kaydedilemez.');
    }
    final state = await openCurrentSet(learner: learner, materialId: materialId);
    if (state.set.id != setId) {
      throw const FlashcardLearningException('Kart seti güncel kaynakla eşleşmiyor.');
    }
    final current = state.currentCard;
    if (current == null || current.id != cardId) {
      throw const FlashcardLearningException('Kart yanıtı aktif kartla eşleşmiyor.');
    }
    final committed = await store.recordFlashcardResponse(
      learner: learner,
      set: state.set,
      card: current,
      response: response,
      reviewedAt: _now().toUtc(),
    );
    return FlashcardStudyState(
      set: state.set,
      reviews: {...state.reviews, committed.review.cardId: committed.review},
      session: committed.session,
    );
  }

  Future<FlashcardStudyState> restartSession({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  }) async {
    final state = await openCurrentSet(learner: learner, materialId: materialId);
    final session = await store.resetFlashcardSession(learner: learner, set: state.set, updatedAt: _now().toUtc());
    return FlashcardStudyState(set: state.set, reviews: state.reviews, session: session);
  }

  Future<FlashcardStudyState> startScheduledReview({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    required SourceVersionId sourceVersionId,
    required SourceAnchor sourceAnchor,
  }) async {
    final state = await openCurrentSet(learner: learner, materialId: materialId);
    if (state.set.sourceVersionId != sourceVersionId) {
      throw const FlashcardLearningException('Planlanan kart tekrarı artık güncel kaynak sürümüne ait değil.');
    }
    final matches = state.set.cards
        .where((card) => _sameAnchor(card.sourceAnchor, sourceAnchor))
        .toList(growable: false);
    if (matches.length != 1) {
      throw const FlashcardLearningException('Planlanan kartın kaynak noktası güncel sette bulunamadı.');
    }
    final target = matches.single;
    final session = await store.resetFlashcardSession(
      learner: learner,
      set: state.set,
      updatedAt: _now().toUtc(),
      cursorIndex: target.ordinal,
    );
    return FlashcardStudyState(set: state.set, reviews: state.reviews, session: session);
  }

  static bool _sameAnchor(SourceAnchor left, SourceAnchor right) =>
      left.startOffset == right.startOffset && left.endOffset == right.endOffset && left.pageNumber == right.pageNumber;

  FlashcardSetRecord _buildSet({
    required MaterialId materialId,
    required SourceVersionId sourceVersionId,
    required ExtractedContentRecord extracted,
    required DateTime createdAt,
  }) {
    final candidates = _findCandidates(extracted);
    if (candidates.isEmpty) {
      throw const FlashcardLearningException('Kaynak, kart üretmek için yeterli kavram içermiyor.');
    }
    final setDigest = sha256.convert(utf8.encode('${sourceVersionId.value}\u0000$generationVersion')).toString();
    final setId = FlashcardSetId('fcs_${setDigest.substring(0, 32)}');

    final cards = <FlashcardRecord>[];
    for (var index = 0; index < candidates.length && cards.length < maxCards; index++) {
      final candidate = candidates[index];
      final cardDigest = sha256
          .convert(
            utf8.encode(
              '${setId.value}\u0000${candidate.sentenceStart}\u0000'
              '${candidate.wordStartInSentence}\u0000${candidate.answer.toLowerCase()}',
            ),
          )
          .toString();
      cards.add(
        FlashcardRecord(
          id: FlashcardId('fc_${cardDigest.substring(0, 32)}'),
          setId: setId,
          ordinal: cards.length,
          front: candidate.sentence.replaceRange(candidate.wordStartInSentence, candidate.wordEndInSentence, '_____'),
          back: candidate.answer,
          sourceAnchor: SourceAnchor(
            startOffset: candidate.sentenceStart,
            endOffset: candidate.sentenceEnd,
            pageNumber: candidate.pageNumber,
          ),
          sourceExcerpt: candidate.sentence,
        ),
      );
    }

    return FlashcardSetRecord(
      id: setId,
      materialId: materialId,
      sourceVersionId: sourceVersionId,
      generationVersion: generationVersion,
      createdAt: createdAt,
      cards: cards,
    );
  }

  static List<_FlashcardCandidate> _findCandidates(ExtractedContentRecord extracted) {
    final candidates = <_FlashcardCandidate>[];
    final usedAnswers = <String>{};

    for (final sentenceMatch in RegExp(r'[^.!?\n]+[.!?]?').allMatches(extracted.normalizedText)) {
      final rawSentence = sentenceMatch.group(0)!;
      final leftTrimmed = rawSentence.trimLeft();
      final sentence = leftTrimmed.trimRight();
      if (sentence.length < 24 || sentence.length > 320) continue;

      final leadingWhitespace = rawSentence.length - leftTrimmed.length;
      final sentenceStart = sentenceMatch.start + leadingWhitespace;
      final words = RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşü]+').allMatches(sentence).where((match) {
        final word = match.group(0)!;
        final normalized = word.toLowerCase().replaceAll('İ', 'i').replaceAll('I', 'ı');
        return word.length >= 5 && !_stopWords.contains(normalized);
      }).toList();
      if (words.isEmpty) continue;

      // Prefer the first meaningful source term in the sentence instead of
      // an arbitrary longest inflected word. This keeps deterministic local
      // cloze cards closer to the sentence's subject or leading concept.
      final selected = words.first;
      final answer = selected.group(0)!;
      final normalizedAnswer = answer.toLowerCase().replaceAll('İ', 'i').replaceAll('I', 'ı');
      if (!usedAnswers.add(normalizedAnswer)) continue;

      int? pageNumber;
      for (final anchor in extracted.anchors) {
        if (sentenceStart >= anchor.startOffset && sentenceStart < anchor.endOffset) {
          pageNumber = anchor.pageNumber;
          break;
        }
      }

      candidates.add(
        _FlashcardCandidate(
          sentence: sentence,
          sentenceStart: sentenceStart,
          sentenceEnd: sentenceStart + sentence.length,
          wordStartInSentence: selected.start,
          wordEndInSentence: selected.end,
          answer: answer,
          pageNumber: pageNumber,
        ),
      );
      if (candidates.length >= maxCards) break;
    }
    return candidates;
  }

  static const _stopWords = <String>{
    'ancak',
    'artık',
    'bazen',
    'bunun',
    'çünkü',
    'daha',
    'diğer',
    'doğru',
    'göre',
    'hangi',
    'içinde',
    'kadar',
    'olan',
    'olarak',
    'olduğu',
    'önce',
    'sonra',
    'şekilde',
    'tarafından',
    'üzerinde',
    'vardır',
    'veya',
    'there',
    'which',
    'while',
    'where',
    'their',
    'about',
  };
}

class _FlashcardCandidate {
  const _FlashcardCandidate({
    required this.sentence,
    required this.sentenceStart,
    required this.sentenceEnd,
    required this.wordStartInSentence,
    required this.wordEndInSentence,
    required this.answer,
    required this.pageNumber,
  });

  final String sentence;
  final int sentenceStart;
  final int sentenceEnd;
  final int wordStartInSentence;
  final int wordEndInSentence;
  final String answer;
  final int? pageNumber;
}
