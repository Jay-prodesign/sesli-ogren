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

enum RecallOutcome {
  correct,
  helpedCorrect,
  partial,
  incorrect,
  unknown,
}

enum RecallStateKind {
  notAssessed,
  needsReview,
  developing,
  retrievedOnce,
}

enum NextLearningActionKind {
  reviewSourceThenRecall,
  retryRecallWithoutHint,
  continueToNextRecall,
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
    required this.helpUsed,
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
  final bool helpUsed;

  /// SHA-256 of the normalized short recall response.
  ///
  /// The raw learner response is intentionally not persisted for this bounded
  /// M5 action because it is unnecessary for deterministic state derivation.
  final String responseDigest;
  final int responseLength;
  final String ruleVersion;
  final DateTime createdAt;
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
  final int evidenceCount;
  final LearnerEvidenceId latestEvidenceId;
  final String ruleVersion;
  final DateTime updatedAt;
}

class NextLearningAction {
  const NextLearningAction({
    required this.kind,
    required this.reasonCode,
    required this.reasonText,
  });

  final NextLearningActionKind kind;
  final String reasonCode;
  final String reasonText;
}

class RecallAttemptResult {
  const RecallAttemptResult({
    required this.evidence,
    required this.state,
    required this.nextAction,
  });

  final LearnerEvidence evidence;
  final LearnerState state;
  final NextLearningAction nextAction;
}
