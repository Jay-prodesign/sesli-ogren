import '../domain/authenticated_learner.dart';
import '../domain/learning_contracts.dart';
import '../domain/learning_truth.dart';
import '../domain/retention_schedule.dart';

class ServerRecallAction {
  const ServerRecallAction({
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

  RecallPrompt toPrompt() => RecallPrompt(
    id: id,
    materialId: materialId,
    sourceVersionId: sourceVersionId,
    promptText: promptText,
    anchor: anchor,
    ruleVersion: ruleVersion,
  );
}

class ServerRecallProjection {
  const ServerRecallProjection({
    required this.actionId,
    required this.attemptId,
    required this.evidenceId,
    required this.outcome,
    required this.stateKind,
    required this.evidenceCount,
    required this.nextReasonCode,
    required this.assistance,
    required this.responseDigest,
    required this.responseLength,
    required this.evidenceRuleVersion,
    required this.evidenceCreatedAt,
    required this.correctAnswer,
    required this.sourceExcerpt,
    required this.materialId,
    required this.sourceVersionId,
    required this.promptText,
    required this.anchor,
  });

  final RecallActionId actionId;
  final RecallAttemptId attemptId;
  final LearnerEvidenceId evidenceId;
  final RecallOutcome outcome;
  final RecallStateKind stateKind;
  final int evidenceCount;
  final String nextReasonCode;
  final RecallAssistance assistance;
  final String responseDigest;
  final int responseLength;
  final String evidenceRuleVersion;
  final DateTime evidenceCreatedAt;
  final String correctAnswer;
  final String sourceExcerpt;
  final MaterialId materialId;
  final SourceVersionId sourceVersionId;
  final String promptText;
  final SourceAnchor anchor;
}

class ServerRecallSubmission {
  const ServerRecallSubmission({
    required this.evidenceId,
    required this.outcome,
    required this.stateKind,
    required this.evidenceCount,
    required this.nextReasonCode,
    required this.assistance,
    required this.responseDigest,
    required this.responseLength,
    required this.evidenceRuleVersion,
    required this.evidenceCreatedAt,
    required this.normalizedResponse,
    required this.correctAnswer,
    required this.sourceExcerpt,
    required this.materialId,
    required this.sourceVersionId,
    required this.promptText,
    required this.anchor,
  });

  final LearnerEvidenceId evidenceId;
  final RecallOutcome outcome;
  final RecallStateKind stateKind;
  final int evidenceCount;
  final String nextReasonCode;
  final RecallAssistance assistance;
  final String responseDigest;
  final int responseLength;
  final String evidenceRuleVersion;
  final DateTime evidenceCreatedAt;
  final String normalizedResponse;
  final String correctAnswer;
  final String sourceExcerpt;
  final MaterialId materialId;
  final SourceVersionId sourceVersionId;
  final String promptText;
  final SourceAnchor anchor;
}

abstract interface class ServerRecallGateway {
  Future<ServerRecallAction> createAction({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    SourceAnchor? anchor,
  });

  Future<RecallAssistance> openAttempt({
    required AuthenticatedLearner learner,
    required RecallActionId actionId,
    required RecallAttemptId attemptId,
  });

  Future<String> requestHint({
    required AuthenticatedLearner learner,
    required RecallActionId actionId,
    required RecallAttemptId attemptId,
  });

  Future<String> revealAnswer({
    required AuthenticatedLearner learner,
    required RecallActionId actionId,
    required RecallAttemptId attemptId,
  });

  Future<ServerRecallSubmission> submit({
    required AuthenticatedLearner learner,
    required RecallActionId actionId,
    required RecallAttemptId attemptId,
    required RecallResponseDisposition disposition,
    required String answer,
  });

  Future<ServerRecallProjection?> readLatest({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  });

  Future<List<RetentionScheduleRecord>> readRetention({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  });
}
