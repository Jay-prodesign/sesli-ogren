import 'learning_contracts.dart';

class FlashcardSetId {
  const FlashcardSetId(this.value);

  final String value;

  @override
  bool operator ==(Object other) => other is FlashcardSetId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

class FlashcardId {
  const FlashcardId(this.value);

  final String value;

  @override
  bool operator ==(Object other) => other is FlashcardId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

enum FlashcardResponse { again, remembered }

class FlashcardRecord {
  const FlashcardRecord({
    required this.id,
    required this.setId,
    required this.ordinal,
    required this.front,
    required this.back,
    required this.sourceAnchor,
    required this.sourceExcerpt,
  });

  final FlashcardId id;
  final FlashcardSetId setId;
  final int ordinal;
  final String front;
  final String back;
  final SourceAnchor sourceAnchor;
  final String sourceExcerpt;
}

class FlashcardSetRecord {
  const FlashcardSetRecord({
    required this.id,
    required this.materialId,
    required this.sourceVersionId,
    required this.generationVersion,
    required this.createdAt,
    required this.cards,
  });

  final FlashcardSetId id;
  final MaterialId materialId;
  final SourceVersionId sourceVersionId;
  final String generationVersion;
  final DateTime createdAt;
  final List<FlashcardRecord> cards;
}

class FlashcardReviewState {
  const FlashcardReviewState({
    required this.cardId,
    required this.reviewCount,
    required this.rememberedCount,
    required this.againCount,
    required this.lastResponse,
    required this.lastReviewedAt,
  });

  final FlashcardId cardId;
  final int reviewCount;
  final int rememberedCount;
  final int againCount;
  final FlashcardResponse lastResponse;
  final DateTime lastReviewedAt;
}

class FlashcardResponseCommit {
  const FlashcardResponseCommit({required this.review, required this.session});

  final FlashcardReviewState review;
  final FlashcardSessionState session;
}

class FlashcardSessionState {
  const FlashcardSessionState({
    required this.setId,
    required this.cursorIndex,
    required this.rememberedCount,
    required this.againCount,
    required this.isCompleted,
    required this.updatedAt,
  });

  factory FlashcardSessionState.initial(FlashcardSetId setId) => FlashcardSessionState(
    setId: setId,
    cursorIndex: 0,
    rememberedCount: 0,
    againCount: 0,
    isCompleted: false,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  final FlashcardSetId setId;
  final int cursorIndex;
  final int rememberedCount;
  final int againCount;
  final bool isCompleted;
  final DateTime updatedAt;
}

class FlashcardStudyState {
  const FlashcardStudyState({required this.set, required this.reviews, required this.session});

  final FlashcardSetRecord set;
  final Map<FlashcardId, FlashcardReviewState> reviews;
  final FlashcardSessionState session;

  FlashcardRecord? get currentCard {
    if (session.isCompleted || session.cursorIndex < 0 || session.cursorIndex >= set.cards.length) return null;
    return set.cards[session.cursorIndex];
  }
}
