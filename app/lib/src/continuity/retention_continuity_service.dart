import '../data/sqlite_source_store.dart';
import '../domain/authenticated_learner.dart';
import '../domain/learning_contracts.dart';
import '../domain/retention_schedule.dart';
import 'retention_continuity_gateway.dart';

enum RetentionContinuityDisposition { inSync, pushedLocal, pulledRemote, conflict, unavailable }

class RetentionContinuityItemResult {
  const RetentionContinuityItemResult({
    required this.scheduleId,
    required this.disposition,
    this.message,
  });

  final RetentionScheduleId scheduleId;
  final RetentionContinuityDisposition disposition;
  final String? message;
}

class RetentionContinuitySummary {
  const RetentionContinuitySummary({required this.results});

  final List<RetentionContinuityItemResult> results;

  int get conflicts =>
      results.where((item) => item.disposition == RetentionContinuityDisposition.conflict).length;
  int get unavailable =>
      results.where((item) => item.disposition == RetentionContinuityDisposition.unavailable).length;
}

class RetentionContinuityService {
  const RetentionContinuityService({required this.store, required this.gateway});

  final SqliteSourceStore store;
  final RetentionContinuityGateway gateway;

  Future<RetentionContinuitySummary> syncAll({required AuthenticatedLearner learner}) async {
    if (!learner.isAuthenticated) return const RetentionContinuitySummary(results: []);
    final materials = await store.activeMaterials(learner: learner);
    final results = <RetentionContinuityItemResult>[];
    for (final material in materials) {
      results.addAll(await syncMaterial(learner: learner, materialId: material.id));
    }
    return RetentionContinuitySummary(results: results);
  }

  Future<List<RetentionContinuityItemResult>> syncMaterial({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  }) async {
    if (!learner.isAuthenticated) return const [];
    final current = await store.currentSourceVersion(learner: learner, materialId: materialId);
    if (current == null) return const [];

    try {
      final remote = await gateway.readMaterial(learner: learner, materialId: materialId);
      if (remote.any(
        (item) =>
            item.schedule.materialId != materialId ||
            item.schedule.sourceVersionId != current.identity.sourceVersionId,
      )) {
        throw const RetentionContinuityException(
          'Cloud retention belongs to a stale source.',
          kind: RetentionContinuityFailureKind.conflict,
        );
      }

      final local = await store.retentionSyncStatesForMaterial(
        learner: learner,
        materialId: materialId,
        sourceVersionId: current.identity.sourceVersionId,
      );
      final localById = {for (final item in local) item.schedule.id: item};
      final remoteById = {for (final item in remote) item.schedule.id: item};
      final ids = <RetentionScheduleId>{...localById.keys, ...remoteById.keys};

      final results = <RetentionContinuityItemResult>[];
      for (final id in ids) {
        results.add(
          await _reconcile(
            learner: learner,
            local: localById[id],
            remote: remoteById[id],
            scheduleId: id,
          ),
        );
      }
      return results;
    } on RetentionContinuityException catch (error) {
      final local = await store.retentionSyncStatesForMaterial(
        learner: learner,
        materialId: materialId,
        sourceVersionId: current.identity.sourceVersionId,
      );
      final fallbackId = local.isEmpty
          ? RetentionPolicy.scheduleIdFor(
              current.identity.sourceVersionId,
              const SourceAnchor(startOffset: 0, endOffset: 1),
            )
          : local.first.schedule.id;
      return [
        RetentionContinuityItemResult(
          scheduleId: fallbackId,
          disposition: error.kind == RetentionContinuityFailureKind.conflict
              ? RetentionContinuityDisposition.conflict
              : RetentionContinuityDisposition.unavailable,
          message: error.message,
        ),
      ];
    }
  }

  Future<RetentionContinuityItemResult> _reconcile({
    required AuthenticatedLearner learner,
    required RetentionScheduleSyncState? local,
    required CloudRetentionSnapshot? remote,
    required RetentionScheduleId scheduleId,
  }) async {
    if (local == null && remote == null) {
      throw StateError('Retention reconciliation requires local or remote state.');
    }

    if (local == null) {
      await store.applyCloudRetentionSchedule(
        learner: learner,
        schedule: remote!.schedule,
        serverRevision: remote.revision,
      );
      return RetentionContinuityItemResult(
        scheduleId: scheduleId,
        disposition: RetentionContinuityDisposition.pulledRemote,
      );
    }

    if (remote == null) {
      if (local.serverRevision != null || local.schedule.latestEvidenceKind == RetentionEvidenceKind.recall) {
        return RetentionContinuityItemResult(
          scheduleId: scheduleId,
          disposition: RetentionContinuityDisposition.conflict,
          message: local.schedule.latestEvidenceKind == RetentionEvidenceKind.recall
              ? 'Canonical Recall retention is missing from the server; local truth was preserved.'
              : 'Cloud retention disappeared after an earlier sync; local timing was preserved.',
        );
      }
      return _pushLocal(learner: learner, local: local, expectedRevision: null);
    }

    if (_sameSchedule(local.schedule, remote.schedule)) {
      await store.markRetentionScheduleSynced(
        learner: learner,
        schedule: local.schedule,
        serverRevision: remote.revision,
      );
      return RetentionContinuityItemResult(
        scheduleId: scheduleId,
        disposition: RetentionContinuityDisposition.inSync,
      );
    }

    // Authenticated Recall evidence is server-canonical. If another device
    // advanced this anchor after the local Recall projection, pull the unified
    // server schedule instead of fabricating a competing local Recall history.
    if (local.schedule.latestEvidenceKind == RetentionEvidenceKind.recall) {
      await store.applyCloudRetentionSchedule(
        learner: learner,
        schedule: remote.schedule,
        serverRevision: remote.revision,
      );
      return RetentionContinuityItemResult(
        scheduleId: scheduleId,
        disposition: RetentionContinuityDisposition.pulledRemote,
      );
    }

    if (local.serverRevision == null) {
      return RetentionContinuityItemResult(
        scheduleId: scheduleId,
        disposition: RetentionContinuityDisposition.conflict,
        message: 'Local and cloud retention histories have no shared sync checkpoint.',
      );
    }

    if (!local.hasLocalChangeSinceSync) {
      await store.applyCloudRetentionSchedule(
        learner: learner,
        schedule: remote.schedule,
        serverRevision: remote.revision,
      );
      return RetentionContinuityItemResult(
        scheduleId: scheduleId,
        disposition: RetentionContinuityDisposition.pulledRemote,
      );
    }

    if (local.serverRevision != remote.revision) {
      return RetentionContinuityItemResult(
        scheduleId: scheduleId,
        disposition: RetentionContinuityDisposition.conflict,
        message: 'This retention anchor changed on two devices after the last sync.',
      );
    }

    return _pushLocal(
      learner: learner,
      local: local,
      expectedRevision: remote.revision,
    );
  }

  Future<RetentionContinuityItemResult> _pushLocal({
    required AuthenticatedLearner learner,
    required RetentionScheduleSyncState local,
    required int? expectedRevision,
  }) async {
    if (local.schedule.latestEvidenceKind == RetentionEvidenceKind.recall) {
      return RetentionContinuityItemResult(
        scheduleId: local.schedule.id,
        disposition: RetentionContinuityDisposition.conflict,
        message: 'Recall retention can only be advanced by canonical server learner evidence.',
      );
    }

    try {
      final saved = await gateway.writeSchedule(
        learner: learner,
        schedule: local.schedule,
        expectedRevision: expectedRevision,
      );
      if (!_sameSchedule(saved.schedule, local.schedule)) {
        throw const RetentionContinuityException(
          'Cloud retention confirmation does not match the local schedule.',
          kind: RetentionContinuityFailureKind.invalidPayload,
        );
      }
      await store.markRetentionScheduleSynced(
        learner: learner,
        schedule: local.schedule,
        serverRevision: saved.revision,
      );
      return RetentionContinuityItemResult(
        scheduleId: local.schedule.id,
        disposition: RetentionContinuityDisposition.pushedLocal,
      );
    } on RetentionContinuityException catch (error) {
      return RetentionContinuityItemResult(
        scheduleId: local.schedule.id,
        disposition: error.kind == RetentionContinuityFailureKind.conflict
            ? RetentionContinuityDisposition.conflict
            : RetentionContinuityDisposition.unavailable,
        message: error.message,
      );
    }
  }

  static bool _sameSchedule(RetentionScheduleRecord left, RetentionScheduleRecord right) =>
      left.id == right.id &&
      left.materialId == right.materialId &&
      left.sourceVersionId == right.sourceVersionId &&
      left.sourceAnchor.startOffset == right.sourceAnchor.startOffset &&
      left.sourceAnchor.endOffset == right.sourceAnchor.endOffset &&
      left.sourceAnchor.pageNumber == right.sourceAnchor.pageNumber &&
      left.latestEvidenceKind == right.latestEvidenceKind &&
      left.latestOutcomeBand == right.latestOutcomeBand &&
      left.latestEventId == right.latestEventId &&
      left.reasonCode == right.reasonCode &&
      left.reviewCount == right.reviewCount &&
      left.successStreak == right.successStreak &&
      left.interval == right.interval &&
      left.dueAt.toUtc() == right.dueAt.toUtc() &&
      left.lastReviewedAt.toUtc() == right.lastReviewedAt.toUtc() &&
      left.policyVersion == right.policyVersion;
}
