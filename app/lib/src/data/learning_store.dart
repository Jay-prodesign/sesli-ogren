import '../domain/authenticated_learner.dart';
import '../domain/learning_contracts.dart';
import '../domain/learning_loop.dart';

class EvidenceIdempotencyConflict implements Exception {
  const EvidenceIdempotencyConflict(this.message);

  final String message;

  @override
  String toString() => 'EvidenceIdempotencyConflict: $message';
}

class EvidenceWriteResult {
  const EvidenceWriteResult({
    required this.evidence,
    required this.isReplay,
  });

  final LearnerEvidenceRecord evidence;
  final bool isReplay;
}

abstract interface class LearningStore {
  Future<RecallPromptRecord> persistRecallPrompt({
    required AuthenticatedLearner learner,
    required RecallPromptRecord prompt,
  });

  Future<RecallPromptRecord?> recallPrompt({
    required AuthenticatedLearner learner,
    required RecallPromptId promptId,
  });

  Future<EvidenceWriteResult> persistLearnerEvidence({
    required AuthenticatedLearner learner,
    required LearnerEvidenceRecord evidence,
  });

  Future<List<LearnerEvidenceRecord>> evidenceForSource({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    required SourceVersionId sourceVersionId,
  });

  Future<void> persistLearningSnapshot({
    required AuthenticatedLearner learner,
    required LearningSnapshot snapshot,
  });

  Future<LearnerStateRecord?> learnerState({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    required SourceVersionId sourceVersionId,
  });

  Future<NextLearningActionRecord?> nextLearningAction({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    required SourceVersionId sourceVersionId,
  });
}
