import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/supabase_learner_auth.dart';
import '../domain/authenticated_learner.dart';
import '../domain/learning_contracts.dart';
import '../domain/retention_schedule.dart';
import 'retention_continuity_gateway.dart';

class SupabaseRetentionContinuityGateway implements RetentionContinuityGateway {
  const SupabaseRetentionContinuityGateway();

  @override
  Future<List<CloudRetentionSnapshot>> readMaterial({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  }) async {
    try {
      final client = await _clientFor(learner);
      final rows = await client.rpc<List<dynamic>>(
        'read_retention_continuity',
        params: {'p_client_material_id': materialId.value},
      );
      return rows.whereType<Map>().map(_snapshot).toList(growable: false);
    } on RetentionContinuityException {
      rethrow;
    } on PostgrestException catch (error) {
      throw _mapError(error);
    } catch (_) {
      throw const RetentionContinuityException(
        'Retention timing could not be read from the cloud.',
        kind: RetentionContinuityFailureKind.invalidPayload,
      );
    }
  }

  @override
  Future<CloudRetentionSnapshot> writeSchedule({
    required AuthenticatedLearner learner,
    required RetentionScheduleRecord schedule,
    required int? expectedRevision,
  }) async {
    if (schedule.latestEvidenceKind == RetentionEvidenceKind.recall) {
      throw const RetentionContinuityException(
        'Recall retention must be advanced by server learner evidence.',
        kind: RetentionContinuityFailureKind.conflict,
      );
    }
    try {
      final client = await _clientFor(learner);
      final rows = await client.rpc<List<dynamic>>(
        'write_retention_continuity',
        params: {
          'p_client_material_id': schedule.materialId.value,
          'p_client_source_id': schedule.sourceVersionId.value,
          'p_source_anchor': schedule.sourceAnchor.toJson(),
          'p_evidence_kind': schedule.latestEvidenceKind.name,
          'p_outcome_band': _outcomeBand(schedule.latestOutcomeBand),
          'p_latest_event_id': schedule.latestEventId,
          'p_review_count': schedule.reviewCount,
          'p_success_streak': schedule.successStreak,
          'p_last_reviewed_at': schedule.lastReviewedAt.toUtc().toIso8601String(),
          'p_expected_revision': expectedRevision,
        },
      );
      if (rows.length != 1 || rows.first is! Map) {
        throw const RetentionContinuityException(
          'Cloud retention write returned an invalid confirmation.',
          kind: RetentionContinuityFailureKind.invalidPayload,
        );
      }
      return _snapshot(rows.first as Map);
    } on RetentionContinuityException {
      rethrow;
    } on PostgrestException catch (error) {
      throw _mapError(error);
    } catch (_) {
      throw const RetentionContinuityException(
        'Retention timing could not be saved to the cloud.',
        kind: RetentionContinuityFailureKind.unavailable,
      );
    }
  }

  static CloudRetentionSnapshot _snapshot(Map raw) {
    final row = Map<String, dynamic>.from(raw);
    final sourceVersionId = SourceVersionId(row['client_source_id'] as String);
    final anchor = SourceAnchor.fromJson(Map<String, Object?>.from(row['source_anchor'] as Map));
    final interval = Duration(seconds: row['interval_seconds'] as int);
    return CloudRetentionSnapshot(
      revision: row['revision'] as int,
      schedule: RetentionScheduleRecord(
        id: RetentionPolicy.scheduleIdFor(sourceVersionId, anchor),
        materialId: MaterialId(row['client_material_id'] as String),
        sourceVersionId: sourceVersionId,
        sourceAnchor: anchor,
        latestEvidenceKind: RetentionEvidenceKind.values.byName(row['latest_evidence_kind'] as String),
        latestOutcomeBand: _parseOutcomeBand(row['latest_outcome_band'] as String),
        latestEventId: row['latest_event_id'] as String,
        reasonCode: row['reason_code'] as String,
        reviewCount: row['review_count'] as int,
        successStreak: row['success_streak'] as int,
        interval: interval,
        dueAt: DateTime.parse(row['due_at'] as String).toUtc(),
        lastReviewedAt: DateTime.parse(row['last_reviewed_at'] as String).toUtc(),
        policyVersion: row['policy_version'] as String,
      ),
    );
  }

  static Future<SupabaseClient> _clientFor(AuthenticatedLearner learner) async {
    if (!learner.isAuthenticated) {
      throw const RetentionContinuityException(
        'Cloud retention requires an authenticated learner.',
        kind: RetentionContinuityFailureKind.authenticationRequired,
      );
    }
    final client = await SupabaseLearnerAuth.clientForAuthenticatedRuntime();
    final user = client.auth.currentSession?.user;
    if (user == null || user.id != learner.id.value) {
      throw const RetentionContinuityException(
        'Authenticated retention session does not match the learner.',
        kind: RetentionContinuityFailureKind.authenticationRequired,
      );
    }
    return client;
  }

  static String _outcomeBand(RetentionOutcomeBand value) => switch (value) {
    RetentionOutcomeBand.independentRetrieval => 'independent_retrieval',
    RetentionOutcomeBand.supportedRetrieval => 'supported_retrieval',
    RetentionOutcomeBand.repairNeeded => 'repair_needed',
    RetentionOutcomeBand.unassessed => 'unassessed',
  };

  static RetentionOutcomeBand _parseOutcomeBand(String value) => switch (value) {
    'independent_retrieval' => RetentionOutcomeBand.independentRetrieval,
    'supported_retrieval' => RetentionOutcomeBand.supportedRetrieval,
    'repair_needed' => RetentionOutcomeBand.repairNeeded,
    'unassessed' => RetentionOutcomeBand.unassessed,
    _ => throw const RetentionContinuityException(
      'Cloud retention returned an invalid outcome band.',
      kind: RetentionContinuityFailureKind.invalidPayload,
    ),
  };

  static RetentionContinuityException _mapError(PostgrestException error) {
    final message = error.message;
    if (message.contains('retention_revision_conflict') ||
        message.contains('retention_event_conflict') ||
        message.contains('retention_event_out_of_order') ||
        message.contains('stale_source') ||
        message.contains('source_conflict')) {
      return const RetentionContinuityException(
        'Retention timing changed on another device. Local timing was preserved.',
        kind: RetentionContinuityFailureKind.conflict,
      );
    }
    if (message.contains('invalid_retention')) {
      return const RetentionContinuityException(
        'Cloud retention payload failed validation.',
        kind: RetentionContinuityFailureKind.invalidPayload,
      );
    }
    return const RetentionContinuityException(
      'Cloud retention is temporarily unavailable.',
      kind: RetentionContinuityFailureKind.unavailable,
    );
  }
}
