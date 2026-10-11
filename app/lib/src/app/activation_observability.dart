import '../domain/learning_contracts.dart';
import '../domain/learning_truth.dart';
import '../domain/operational_event.dart';
import 'app_runtime.dart';

extension ActivationObservabilityRuntime on AppRuntime {
  Future<List<OperationalEvent>> _eventsForMaterial(MaterialId materialId) async {
    try {
      final events = await telemetry.events(learner: learner);
      return events.where((event) => event.materialId == materialId).toList(growable: false);
    } catch (_) {
      return const <OperationalEvent>[];
    }
  }

  Future<void> _recordActivationOnce({
    required OperationalEventType type,
    required MaterialId materialId,
    SourceVersionId? sourceVersionId,
    String? reasonCode,
    LearnerEvidenceId? evidenceId,
    RecallOutcome? outcome,
    RecallStateKind? stateKind,
  }) async {
    try {
      final events = await _eventsForMaterial(materialId);
      if (events.any((event) => event.type == type)) return;
      await telemetry.record(
        learner: learner,
        event: OperationalEvent(
          type: type,
          phase: OperationalEventPhase.completed,
          materialId: materialId,
          sourceVersionId: sourceVersionId,
          evidenceId: evidenceId,
          outcome: outcome,
          stateKind: stateKind,
          reasonCode: reasonCode,
          createdAt: DateTime.now().toUtc(),
        ),
      );
    } catch (_) {
      // Activation telemetry is observational only and never blocks learning truth.
    }
  }

  Future<void> recordActivationSourceAdded({
    required MaterialId materialId,
    required String sourceKind,
  }) => _recordActivationOnce(
    type: OperationalEventType.sourceAdded,
    materialId: materialId,
    reasonCode: sourceKind,
  );

  Future<void> recordActivationSourceReady({
    required MaterialId materialId,
    required SourceVersionId sourceVersionId,
    required String sourceKind,
  }) => _recordActivationOnce(
    type: OperationalEventType.sourceReady,
    materialId: materialId,
    sourceVersionId: sourceVersionId,
    reasonCode: sourceKind,
  );

  Future<void> recordActivationActionStart({
    required MaterialId materialId,
    required String action,
    SourceVersionId? sourceVersionId,
  }) async {
    try {
      final resolvedSourceVersionId =
          sourceVersionId ??
          (await store.currentSourceVersion(learner: learner, materialId: materialId))?.identity.sourceVersionId;
      final events = await _eventsForMaterial(materialId);
      OperationalEvent? firstAction;
      for (final event in events) {
        if (event.type == OperationalEventType.firstActionSelected) {
          firstAction = event;
          break;
        }
      }

      if (firstAction == null) {
        await _recordActivationOnce(
          type: OperationalEventType.firstActionSelected,
          materialId: materialId,
          sourceVersionId: resolvedSourceVersionId,
          reasonCode: action,
        );
      }
      if (!events.any((event) => event.type == OperationalEventType.firstValueStarted)) {
        await _recordActivationOnce(
          type: OperationalEventType.firstValueStarted,
          materialId: materialId,
          sourceVersionId: resolvedSourceVersionId,
          reasonCode: firstAction?.reasonCode ?? action,
        );
      }
      if (firstAction != null &&
          firstAction.reasonCode != null &&
          firstAction.reasonCode != action &&
          !events.any((event) => event.type == OperationalEventType.secondModeUsed)) {
        await _recordActivationOnce(
          type: OperationalEventType.secondModeUsed,
          materialId: materialId,
          sourceVersionId: resolvedSourceVersionId,
          reasonCode: action,
        );
      }
    } catch (_) {
      // Best-effort activation observation only.
    }
  }

  Future<void> recordActivationFirstValue({
    required MaterialId materialId,
    required String action,
    SourceVersionId? sourceVersionId,
  }) => _recordActivationOnce(
    type: OperationalEventType.firstValueCompleted,
    materialId: materialId,
    sourceVersionId: sourceVersionId,
    reasonCode: action,
  );

  Future<void> recordActivationFirstEvidence({
    required MaterialId materialId,
    required SourceVersionId sourceVersionId,
    required LearnerEvidenceId evidenceId,
    required RecallOutcome outcome,
    required RecallStateKind stateKind,
  }) => _recordActivationOnce(
    type: OperationalEventType.firstActiveEvidence,
    materialId: materialId,
    sourceVersionId: sourceVersionId,
    evidenceId: evidenceId,
    outcome: outcome,
    stateKind: stateKind,
    reasonCode: 'recall',
  );

  Future<void> recordActivationReturnIfStarted({required MaterialId materialId}) async {
    try {
      final events = await _eventsForMaterial(materialId);
      if (!events.any((event) => event.type == OperationalEventType.firstActionSelected) ||
          events.any((event) => event.type == OperationalEventType.returnToSameMaterial)) {
        return;
      }
      await _recordActivationOnce(
        type: OperationalEventType.returnToSameMaterial,
        materialId: materialId,
        reasonCode: 'workspace_reopen',
      );
    } catch (_) {
      // Best-effort activation observation only.
    }
  }
}
