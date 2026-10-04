import 'learning_contracts.dart';
import 'learning_truth.dart';

enum OperationalEventType {
  runtimeRestore,
  sourceIngest,
  recallPrompt,
  recallAttempt,
  continuationRepair,
}

enum OperationalEventPhase { started, completed, failed }

class OperationalEvent {
  const OperationalEvent({
    required this.type,
    required this.phase,
    required this.createdAt,
    this.materialId,
    this.sourceVersionId,
    this.actionId,
    this.evidenceId,
    this.ruleVersion,
    this.policyVersion,
    this.durationMs,
    this.errorClass,
  });

  final OperationalEventType type;
  final OperationalEventPhase phase;
  final DateTime createdAt;
  final MaterialId? materialId;
  final SourceVersionId? sourceVersionId;
  final RecallActionId? actionId;
  final LearnerEvidenceId? evidenceId;
  final String? ruleVersion;
  final String? policyVersion;
  final int? durationMs;
  final String? errorClass;
}
