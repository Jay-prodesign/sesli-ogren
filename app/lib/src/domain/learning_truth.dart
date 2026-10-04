import 'learning_contracts.dart';

class RecallActionId {
  const RecallActionId(this.value);

  final String value;

  @override
  bool operator ==(Object other) =>
      other is RecallActionId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

class RecallAttemptId {
  const RecallAttemptId(this.value);

  final String value;

  @override
  bool operator ==(Object other) =>
      other is RecallAttemptId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

class ActiveRecallAttempt {
  const ActiveRecallAttempt({
    required this.attemptId,
    required this.actionId,
    required this.materialId,
    required this.sourceVersionId,
    required this.openedAt,
  });

  final RecallAttemptId attemptId;
  final RecallActionId actionId;
  final MaterialId materialId;
  final SourceVersionId sourceVersionId;
  final DateTime openedAt;
}

class RecallAttemptSession {
  const RecallAttemptSession({
    required this.attempt,
    required this.assistance,
  });

  final ActiveRecallAttempt attempt;
  final RecallAssistance assistance;
}

class LearnerEvidenceId {
  const LearnerEvidenceId(this.value);

  final String value;

  @override
  bool operator ==(Object other) =>
      other is LearnerEvidenceId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

enum RecallResponseDisposition { answer, unknown }

enum RecallAssistance { none, hint, answerExposed }

enum RecallOutcome {
  correct,
  helpedCorrect,
  answerExposed,
  partial,
  incorrect,
  unknown,
}

enum RecallStateKind { notAssessed, needsReview, developing, retrievedOnce }

enum NextLearningActionKind {
  reviewSourceThenRecall,
  retryRecallWithoutHint,
  repeatRecallLater,
}

class RecallPrompt {
  const RecallPrompt({
    required this.id,
    required this.materialId,
    required this.sourceVersionId,
    required this.promptText,
    required this.anchor,
    required this.ruleVersion,
  });

  final RecallActionId id;
  final MaterialId materialId;
  final SourceVersionId sourceVersionId;
  final String promptText;
  final SourceAnchor anchor;
  final String ruleVersion;
}

class RecallAction {
  const RecallAction({
    required this.id,
    required this.materialId,
    required this.sourceVersionId,
    required this.extractedContentId,
    required this.promptText,
    required this.expectedAnswer,
    required this.anchor,
    required this.ruleVersion,
    required this.createdAt,
  });

  final RecallActionId id;
  final MaterialId materialId;
  final SourceVersionId sourceVersionId;
  final ExtractedContentId extractedContentId;
  final String promptText;
  final String expectedAnswer;
  final SourceAnchor anchor;
  final String ruleVersion;
  final DateTime createdAt;

  RecallPrompt toPrompt() => RecallPrompt(
    id: id,
    materialId: materialId,
    sourceVersionId: sourceVersionId,
    promptText: promptText,
    anchor: anchor,
    ruleVersion: ruleVersion,
  );
}

class LearnerEvidence {
  const LearnerEvidence({
    required this.id,
    required this.attemptId,
    required this.actionId,
    required this.materialId,
    required this.sourceVersionId,
    required this.extractedContentId,
    required this.outcome,
    required this.assistance,
    required this.responseDigest,
    required this.responseLength,
    required this.ruleVersion,
    required this.createdAt,
  });

  final LearnerEvidenceId id;
  final RecallAttemptId attemptId;
  final RecallActionId actionId;
  final MaterialId materialId;
  final SourceVersionId sourceVersionId;
  final ExtractedContentId extractedContentId;
  final RecallOutcome outcome;
  final RecallAssistance assistance;

  /// SHA-256 of the normalized short recall response.
  ///
  /// Raw free text is intentionally not duplicated into ordinary learning
  /// projections or analytics. The bounded evidence record keeps the outcome,
  /// assistance semantics, digest, length and evaluator version.
  final String responseDigest;
  final int responseLength;
  final String ruleVersion;
  final DateTime createdAt;

  bool get helpUsed => assistance != RecallAssistance.none;
}

class LearnerState {
  const LearnerState({
    required this.materialId,
    required this.sourceVersionId,
    required this.kind,
    required this.evidenceCount,
    required this.latestEvidenceId,
    required this.ruleVersion,
    required this.updatedAt,
  });

  final MaterialId materialId;
  final SourceVersionId sourceVersionId;
  final RecallStateKind kind;

  /// Factual evidence row count, not a score and never a mastery percentage.
  final int evidenceCount;
  final LearnerEvidenceId latestEvidenceId;
  final String ruleVersion;
  final DateTime updatedAt;
}

class NextLearningAction {
  const NextLearningAction({
    required this.materialId,
    required this.sourceVersionId,
    required this.latestEvidenceId,
    required this.kind,
    required this.reasonCode,
    required this.reasonText,
    required this.policyVersion,
    required this.createdAt,
  });

  final MaterialId materialId;
  final SourceVersionId sourceVersionId;
  final LearnerEvidenceId latestEvidenceId;
  final NextLearningActionKind kind;
  final String reasonCode;
  final String reasonText;
  final String policyVersion;
  final DateTime createdAt;
}

enum RecallSupportKind { hint, answer }

class RecallSupport {
  const RecallSupport({
    required this.kind,
    required this.text,
    required this.assistance,
  });

  final RecallSupportKind kind;
  final String text;
  final RecallAssistance assistance;
}

class RecallAttemptResult {
  const RecallAttemptResult({
    required this.evidence,
    required this.state,
    required this.nextAction,
    required this.correctAnswer,
    required this.sourceExcerpt,
  });

  final LearnerEvidence evidence;
  final LearnerState state;
  final NextLearningAction nextAction;
  final String correctAnswer;
  final String sourceExcerpt;
}

class RecallTruthPolicy {
  const RecallTruthPolicy._();

  static const stateRuleVersion = 'recall-state-v2';
  static const nextActionPolicyVersion = 'recall-next-v1';

  static RecallStateKind stateForOutcome(RecallOutcome outcome) {
    return switch (outcome) {
      RecallOutcome.correct => RecallStateKind.retrievedOnce,
      RecallOutcome.helpedCorrect || RecallOutcome.partial =>
        RecallStateKind.developing,
      RecallOutcome.incorrect => RecallStateKind.needsReview,
      RecallOutcome.answerExposed || RecallOutcome.unknown =>
        RecallStateKind.notAssessed,
    };
  }

  static NextLearningAction nextActionFor({
    required MaterialId materialId,
    required SourceVersionId sourceVersionId,
    required LearnerEvidenceId evidenceId,
    required RecallOutcome outcome,
    required DateTime createdAt,
  }) {
    final (kind, reasonCode, reasonText) = switch (outcome) {
      RecallOutcome.correct => (
        NextLearningActionKind.repeatRecallLater,
        'ONE_UNASSISTED_RETRIEVAL_OBSERVED',
        'Bu kavramı bir kez ipucusuz geri çağırdın. Bu ustalık kanıtı değil; daha sonra yeniden hatırlayacağız.',
      ),
      RecallOutcome.helpedCorrect => (
        NextLearningActionKind.retryRecallWithoutHint,
        'HINTED_SUCCESS_NEEDS_UNASSISTED_RETRIEVAL',
        'Doğru yanıta ipucuyla ulaştın. Bunu bağımsız hatırlama saymadan daha sonra ipucusuz yeniden dene.',
      ),
      RecallOutcome.answerExposed => (
        NextLearningActionKind.retryRecallWithoutHint,
        'ANSWER_EXPOSED_NO_RETRIEVAL_CLAIM',
        'Yanıt gösterildiği için geri çağırma kanıtı oluşmadı. Daha sonra kaynağı kapatıp ipucusuz yeniden dene.',
      ),
      RecallOutcome.partial => (
        NextLearningActionKind.retryRecallWithoutHint,
        'PARTIAL_RETRIEVAL_NEEDS_RETRY',
        'Yanıt kısmen yaklaştı. Kaynak geri bildirimini gördükten sonra ipucusuz yeniden dene.',
      ),
      RecallOutcome.incorrect => (
        NextLearningActionKind.reviewSourceThenRecall,
        'INCORRECT_RETRIEVAL_NEEDS_REPAIR',
        'Bu denemede eşleşme oluşmadı. Kaynak bölümünü gözden geçirip yeniden dene.',
      ),
      RecallOutcome.unknown => (
        NextLearningActionKind.reviewSourceThenRecall,
        'NO_EVALUABLE_RETRIEVAL',
        'Bu denemede değerlendirilebilir bir geri çağırma yanıtı yok. Kaynağı gözden geçirip hazır olduğunda yeniden dene.',
      ),
    };
    return NextLearningAction(
      materialId: materialId,
      sourceVersionId: sourceVersionId,
      latestEvidenceId: evidenceId,
      kind: kind,
      reasonCode: reasonCode,
      reasonText: reasonText,
      policyVersion: nextActionPolicyVersion,
      createdAt: createdAt,
    );
  }

  static bool sameNextAction(
    NextLearningAction left,
    NextLearningAction right,
  ) {
    return left.materialId == right.materialId &&
        left.sourceVersionId == right.sourceVersionId &&
        left.latestEvidenceId == right.latestEvidenceId &&
        left.kind == right.kind &&
        left.reasonCode == right.reasonCode &&
        left.reasonText == right.reasonText &&
        left.policyVersion == right.policyVersion &&
        left.createdAt.toUtc() == right.createdAt.toUtc();
  }
}

class LearningContinuation {
  const LearningContinuation({
    required this.state,
    required this.nextAction,
  });

  final LearnerState state;
  final NextLearningAction nextAction;
}
