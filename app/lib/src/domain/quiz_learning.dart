import 'learning_contracts.dart';

class QuizSetId {
  const QuizSetId(this.value);
  final String value;

  @override
  bool operator ==(Object other) => other is QuizSetId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

class QuizQuestionId {
  const QuizQuestionId(this.value);
  final String value;

  @override
  bool operator ==(Object other) => other is QuizQuestionId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

enum QuizAnswerKind { selected, unknown }

class QuizQuestionRecord {
  const QuizQuestionRecord({
    required this.id,
    required this.setId,
    required this.ordinal,
    required this.prompt,
    required this.options,
    required this.correctOptionIndex,
    required this.sourceAnchor,
    required this.sourceExcerpt,
  });

  final QuizQuestionId id;
  final QuizSetId setId;
  final int ordinal;
  final String prompt;
  final List<String> options;
  final int correctOptionIndex;
  final SourceAnchor sourceAnchor;
  final String sourceExcerpt;
}

class QuizSetRecord {
  const QuizSetRecord({
    required this.id,
    required this.materialId,
    required this.sourceVersionId,
    required this.generationVersion,
    required this.createdAt,
    required this.questions,
  });

  final QuizSetId id;
  final MaterialId materialId;
  final SourceVersionId sourceVersionId;
  final String generationVersion;
  final DateTime createdAt;
  final List<QuizQuestionRecord> questions;
}

class QuizQuestionReviewState {
  const QuizQuestionReviewState({
    required this.questionId,
    required this.answerCount,
    required this.correctCount,
    required this.incorrectCount,
    required this.unknownCount,
    required this.lastAnswerKind,
    required this.lastSelectedOptionIndex,
    required this.lastIsCorrect,
    required this.lastAnsweredAt,
  });

  final QuizQuestionId questionId;
  final int answerCount;
  final int correctCount;
  final int incorrectCount;
  final int unknownCount;
  final QuizAnswerKind lastAnswerKind;
  final int? lastSelectedOptionIndex;
  final bool? lastIsCorrect;
  final DateTime lastAnsweredAt;
}

class QuizSessionState {
  const QuizSessionState({
    required this.setId,
    required this.cursorIndex,
    required this.correctCount,
    required this.incorrectCount,
    required this.unknownCount,
    required this.isCompleted,
    required this.updatedAt,
  });

  factory QuizSessionState.initial(QuizSetId setId) => QuizSessionState(
    setId: setId,
    cursorIndex: 0,
    correctCount: 0,
    incorrectCount: 0,
    unknownCount: 0,
    isCompleted: false,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  final QuizSetId setId;
  final int cursorIndex;
  final int correctCount;
  final int incorrectCount;
  final int unknownCount;
  final bool isCompleted;
  final DateTime updatedAt;
}

class QuizAnswerCommit {
  const QuizAnswerCommit({required this.review, required this.session});

  final QuizQuestionReviewState review;
  final QuizSessionState session;
}

class QuizStudyState {
  const QuizStudyState({required this.set, required this.reviews, required this.session});

  final QuizSetRecord set;
  final Map<QuizQuestionId, QuizQuestionReviewState> reviews;
  final QuizSessionState session;

  QuizQuestionRecord? get currentQuestion {
    if (session.isCompleted || session.cursorIndex < 0 || session.cursorIndex >= set.questions.length) return null;
    return set.questions[session.cursorIndex];
  }
}
