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

  Future<NextLearningAction?> nextLearningAction({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  });

  /// Persists evidence first, then the derived state and next action in the
  /// same transaction. A replay of the same attempt is idempotent; a
  /// conflicting replay fails closed.
  Future<PersistedLearningTruth> persistEvidenceStateAndNextAction({
    required AuthenticatedLearner learner,
    required LearnerEvidence evidence,
    required RecallStateKind stateKind,
    required String stateRuleVersion,
    required NextLearningAction nextAction,
  });

  /// Rebuilds only derived state/next-action projections from already durable
  /// canonical evidence. It never inserts or rewrites LearnerEvidence.
  Future<LearningContinuation> repairDerivedProjection({
    required AuthenticatedLearner learner,
    required LearnerState state,
    required NextLearningAction nextAction,
  });
}

class LearningTruthConflict implements Exception {
  const LearningTruthConflict(this.message);

  final String message;

  @override
  String toString() => 'LearningTruthConflict: $message';
}

class PersistedLearningTruth {
  const PersistedLearningTruth({
    required this.evidence,
    required this.state,
    required this.nextAction,
  });

  final LearnerEvidence evidence;
  final LearnerState state;
  final NextLearningAction nextAction;
}
