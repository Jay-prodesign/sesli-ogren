import '../domain/authenticated_learner.dart';
import '../domain/learning_contracts.dart';
import '../domain/learning_truth.dart';

abstract interface class LearningTruthStore {
  Future<RecallAction> persistRecallAction({
    required AuthenticatedLearner learner,
    required RecallAction action,
  });

  Future<RecallAction?> recallAction({
    required AuthenticatedLearner learner,
    required RecallActionId actionId,
  });

  Future<LearnerEvidence?> evidenceForAttempt({
    required AuthenticatedLearner learner,
    required RecallAttemptId attemptId,
  });

  Future<List<LearnerEvidence>> evidenceForMaterial({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    required SourceVersionId sourceVersionId,
  });

  Future<LearnerState?> learnerState({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  });

  /// Persists evidence first and updates the derived state in the same
  /// transaction. A replay of the same attempt is idempotent; a conflicting
  /// replay fails closed.
  Future<RecallAttemptResult> persistEvidenceAndState({
    required AuthenticatedLearner learner,
    required LearnerEvidence evidence,
    required RecallStateKind stateKind,
    required String stateRuleVersion,
    required NextLearningAction nextAction,
  });
}

class LearningTruthConflict implements Exception {
  const LearningTruthConflict(this.message);

  final String message;

  @override
  String toString() => 'LearningTruthConflict: $message';
}
