import 'learning_contracts.dart';

class RecallPromptId {
  const RecallPromptId(this.value);

  final String value;

  @override
  bool operator ==(Object other) =>
      other is RecallPromptId && other.value == value;

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

enum RecallAssistance { none, hint, answerExposed }

enum RecallOutcome {
  independentCorrect,
  supportedCorrect,
  answerExposed,
  partial,
  wrong,
  unknown,
}

enum RetrievalObservation { unknown, needsRepair, supported, independent }

enum EvidenceConfidenceBand { none, singleGroundedObservation }

enum NextLearningActionType {
  recall,
  repairThenRetry,
  retryRecall,
  repeatLater,
}

class RecallPromptRecord {
  const RecallPromptRecord({
    required this.id,
    required this.materialId,
    required this.sourceVersionId,
    required this.extractedContentId,
    required this.promptText,
    required this.expectedAnswer,
    required this.sourceExcerpt,
    required this.sourceAnchor,
    required this.answerAnchor,
    required this.generationRuleVersion,
    required this.createdAt,
  });

  final RecallPromptId id;
  final MaterialId materialId;
  final SourceVersionId sourceVersionId;
  final ExtractedContentId extractedContentId;
  final String promptText;
  final String expectedAnswer;
  final String sourceExcerpt;
  final SourceAnchor sourceAnchor;
  final SourceAnchor answerAnchor;
  final String generationRuleVersion;
  final DateTime createdAt;
}

class LearnerEvidenceRecord {
  const LearnerEvidenceRecord({
    required this.id,
    required this.attemptKey,
    required this.materialId,
    required this.sourceVersionId,
    required this.extractedContentId,
    required this.promptId,
    required this.outcome,
    required this.assistance,
    required this.responseText,
    required this.evaluationRuleVersion,
    required this.promptRuleVersion,
    required this.sourceAnchor,
    required this.occurredAt,
  });

  final LearnerEvidenceId id;
  final String attemptKey;
  final MaterialId materialId;
  final SourceVersionId sourceVersionId;
  final ExtractedContentId extractedContentId;
  final RecallPromptId promptId;
  final RecallOutcome outcome;
  final RecallAssistance assistance;
  final String responseText;
  final String evaluationRuleVersion;
  final String promptRuleVersion;
  final SourceAnchor sourceAnchor;
  final DateTime occurredAt;
}

class LearnerStateRecord {
  const LearnerStateRecord({
    required this.materialId,
    required this.sourceVersionId,
    required this.derivationRuleVersion,
    required this.retrievalObservation,
    required this.evidenceConfidence,
    required this.distinctPromptCount,
    required this.evidenceIds,
    required this.evidenceFingerprint,
    required this.reasonCodes,
    required this.updatedAt,
  });

  final MaterialId materialId;
  final SourceVersionId sourceVersionId;
  final String derivationRuleVersion;
  final RetrievalObservation retrievalObservation;
  final EvidenceConfidenceBand evidenceConfidence;
  final int distinctPromptCount;
  final List<LearnerEvidenceId> evidenceIds;
  final String evidenceFingerprint;
  final List<String> reasonCodes;
  final DateTime updatedAt;
}

class NextLearningActionRecord {
  const NextLearningActionRecord({
    required this.materialId,
    required this.sourceVersionId,
    required this.actionType,
    required this.policyVersion,
    required this.reasonCodes,
    required this.stateEvidenceFingerprint,
    required this.createdAt,
  });

  final MaterialId materialId;
  final SourceVersionId sourceVersionId;
  final NextLearningActionType actionType;
  final String policyVersion;
  final List<String> reasonCodes;
  final String stateEvidenceFingerprint;
  final DateTime createdAt;
}

class LearningSnapshot {
  const LearningSnapshot({
    required this.state,
    required this.nextAction,
  });

  final LearnerStateRecord state;
  final NextLearningActionRecord nextAction;
}

class RecallFeedback {
  const RecallFeedback({
    required this.outcome,
    required this.message,
    required this.sourceExcerpt,
  });

  final RecallOutcome outcome;
  final String message;
  final String sourceExcerpt;
}

class RecallAttemptResult {
  const RecallAttemptResult({
    required this.evidence,
    required this.snapshot,
    required this.feedback,
    required this.isReplay,
  });

  final LearnerEvidenceRecord evidence;
  final LearningSnapshot snapshot;
  final RecallFeedback feedback;
  final bool isReplay;
}
