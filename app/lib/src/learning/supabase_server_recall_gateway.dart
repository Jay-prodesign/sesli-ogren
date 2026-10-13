import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/supabase_learner_auth.dart';
import '../domain/authenticated_learner.dart';
import '../domain/learning_contracts.dart';
import '../domain/learning_truth.dart';
import '../domain/retention_schedule.dart';
import 'recall_learning_service.dart';
import 'server_recall_gateway.dart';

class SupabaseServerRecallGateway implements ServerRecallGateway {
  const SupabaseServerRecallGateway();

  @override
  Future<ServerRecallAction> createAction({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    SourceAnchor? anchor,
  }) async {
    try {
      final client = await _clientFor(learner);
      final rows = await client.rpc<List<dynamic>>(
        'create_recall_continuity_action',
        params: {'p_client_material_id': materialId.value, 'p_source_anchor': anchor?.toJson()},
      );
      if (rows.length != 1 || rows.first is! Map) {
        throw const RecallLearningException('Server Recall action was not created.');
      }
      final row = Map<String, dynamic>.from(rows.first as Map);
      return ServerRecallAction(
        id: RecallActionId(row['action_id'] as String),
        materialId: MaterialId(row['client_material_id'] as String),
        sourceVersionId: SourceVersionId(row['client_source_id'] as String),
        promptText: row['prompt_text'] as String,
        anchor: SourceAnchor.fromJson(Map<String, Object?>.from(row['source_anchor'] as Map)),
        ruleVersion: row['prompt_contract'] as String,
      );
    } on RecallLearningException {
      rethrow;
    } on PostgrestException catch (error) {
      throw _mapError(error);
    } catch (_) {
      throw const RecallLearningException('Server Recall action could not be opened.');
    }
  }

  @override
  Future<RecallAssistance> openAttempt({
    required AuthenticatedLearner learner,
    required RecallActionId actionId,
    required RecallAttemptId attemptId,
  }) async {
    try {
      final client = await _clientFor(learner);
      final assistance = await client.rpc<String>(
        'open_recall_continuity_attempt',
        params: {'p_action_id': actionId.value, 'p_attempt_id': attemptId.value},
      );
      return _assistance(assistance);
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<String> requestHint({
    required AuthenticatedLearner learner,
    required RecallActionId actionId,
    required RecallAttemptId attemptId,
  }) async {
    try {
      final client = await _clientFor(learner);
      return await client.rpc<String>(
        'reveal_recall_hint',
        params: {'p_action_id': actionId.value, 'p_attempt_id': attemptId.value},
      );
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<String> revealAnswer({
    required AuthenticatedLearner learner,
    required RecallActionId actionId,
    required RecallAttemptId attemptId,
  }) async {
    try {
      final client = await _clientFor(learner);
      return await client.rpc<String>(
        'reveal_recall_answer',
        params: {'p_action_id': actionId.value, 'p_attempt_id': attemptId.value},
      );
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<ServerRecallSubmission> submit({
    required AuthenticatedLearner learner,
    required RecallActionId actionId,
    required RecallAttemptId attemptId,
    required RecallResponseDisposition disposition,
    required String answer,
  }) async {
    try {
      final client = await _clientFor(learner);
      final rows = await client.rpc<List<dynamic>>(
        'submit_recall_continuity_attempt',
        params: {
          'p_action_id': actionId.value,
          'p_attempt_id': attemptId.value,
          'p_response_disposition': disposition == RecallResponseDisposition.unknown ? 'unknown' : 'answer',
          'p_answer': answer,
        },
      );
      if (rows.length != 1 || rows.first is! Map) {
        throw const RecallLearningException('Server Recall result was not returned.');
      }
      final row = Map<String, dynamic>.from(rows.first as Map);
      return ServerRecallSubmission(
        evidenceId: LearnerEvidenceId(row['evidence_id'] as String),
        outcome: _outcome(row['outcome'] as String),
        stateKind: _state(row['state_kind'] as String),
        evidenceCount: row['evidence_count'] as int,
        nextReasonCode: row['next_reason_code'] as String,
        assistance: _assistance(row['assistance'] as String),
        responseDigest: row['response_digest'] as String,
        responseLength: row['response_length'] as int,
        evidenceRuleVersion: row['evidence_rule_version'] as String,
        evidenceCreatedAt: DateTime.parse(row['evidence_created_at'] as String).toUtc(),
        normalizedResponse: row['normalized_response'] as String,
        correctAnswer: row['correct_answer'] as String,
        sourceExcerpt: row['source_excerpt'] as String,
        materialId: MaterialId(row['client_material_id'] as String),
        sourceVersionId: SourceVersionId(row['client_source_id'] as String),
        promptText: row['action_prompt'] as String,
        anchor: SourceAnchor.fromJson(Map<String, Object?>.from(row['source_anchor'] as Map)),
      );
    } on RecallLearningException {
      rethrow;
    } on PostgrestException catch (error) {
      throw _mapError(error);
    } catch (_) {
      throw const RecallLearningException('Server Recall result could not be read.');
    }
  }

  @override
  Future<ServerRecallProjection?> readLatest({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  }) async {
    try {
      final client = await _clientFor(learner);
      final rows = await client.rpc<List<dynamic>>(
        'read_latest_recall_continuity',
        params: {'p_client_material_id': materialId.value},
      );
      if (rows.isEmpty) return null;
      if (rows.length != 1 || rows.first is! Map) {
        throw const RecallLearningException('Server Recall projection is malformed.');
      }
      final row = Map<String, dynamic>.from(rows.first as Map);
      return ServerRecallProjection(
        actionId: RecallActionId(row['action_id'] as String),
        attemptId: RecallAttemptId(row['attempt_id'] as String),
        evidenceId: LearnerEvidenceId(row['evidence_id'] as String),
        outcome: _outcome(row['outcome'] as String),
        stateKind: _state(row['state_kind'] as String),
        evidenceCount: row['evidence_count'] as int,
        nextReasonCode: row['next_reason_code'] as String,
        assistance: _assistance(row['assistance'] as String),
        responseDigest: row['response_digest'] as String,
        responseLength: row['response_length'] as int,
        evidenceRuleVersion: row['evidence_rule_version'] as String,
        evidenceCreatedAt: DateTime.parse(row['evidence_created_at'] as String).toUtc(),
        correctAnswer: row['correct_answer'] as String,
        sourceExcerpt: row['source_excerpt'] as String,
        materialId: MaterialId(row['client_material_id'] as String),
        sourceVersionId: SourceVersionId(row['client_source_id'] as String),
        promptText: row['action_prompt'] as String,
        anchor: SourceAnchor.fromJson(Map<String, Object?>.from(row['source_anchor'] as Map)),
      );
    } on RecallLearningException {
      rethrow;
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<List<RetentionScheduleRecord>> readRetention({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  }) async {
    try {
      final client = await _clientFor(learner);
      final rows = await client.rpc<List<dynamic>>(
        'read_recall_retention_continuity',
        params: {'p_client_material_id': materialId.value},
      );
      return rows.whereType<Map>().map((raw) {
        final row = Map<String, dynamic>.from(raw);
        final sourceVersionId = SourceVersionId(row['client_source_id'] as String);
        final anchor = SourceAnchor.fromJson(Map<String, Object?>.from(row['source_anchor'] as Map));
        final latestEvidenceId = row['latest_evidence_id'] as String;
        final interval = Duration(seconds: row['interval_seconds'] as int);
        return RetentionScheduleRecord(
          id: RetentionPolicy.scheduleIdFor(sourceVersionId, anchor),
          materialId: MaterialId(row['client_material_id'] as String),
          sourceVersionId: sourceVersionId,
          sourceAnchor: anchor,
          latestEvidenceKind: RetentionEvidenceKind.recall,
          latestOutcomeBand: _outcomeBand(row['latest_outcome_band'] as String),
          latestEventId: 'server-recall:$latestEvidenceId',
          reasonCode: row['reason_code'] as String,
          reviewCount: row['review_count'] as int,
          successStreak: row['success_streak'] as int,
          interval: interval,
          dueAt: DateTime.parse(row['due_at'] as String).toUtc(),
          lastReviewedAt: DateTime.parse(row['last_reviewed_at'] as String).toUtc(),
          policyVersion: row['policy_version'] as String,
        );
      }).toList(growable: false);
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  static Future<SupabaseClient> _clientFor(AuthenticatedLearner learner) async {
    if (!learner.isAuthenticated) {
      throw const RecallLearningException('Server Recall requires an authenticated learner.');
    }
    final client = await SupabaseLearnerAuth.clientForAuthenticatedRuntime();
    final user = client.auth.currentSession?.user;
    if (user == null || user.id != learner.id.value) {
      throw const RecallLearningException('Authenticated Recall session does not match the learner.');
    }
    return client;
  }

  static RecallAssistance _assistance(String value) => switch (value) {
    'none' => RecallAssistance.none,
    'hint' => RecallAssistance.hint,
    'answer_exposed' => RecallAssistance.answerExposed,
    _ => throw const RecallLearningException('Server Recall returned invalid assistance truth.'),
  };

  static RecallOutcome _outcome(String value) => switch (value) {
    'correct' => RecallOutcome.correct,
    'helped_correct' => RecallOutcome.helpedCorrect,
    'answer_exposed' => RecallOutcome.answerExposed,
    'partial' => RecallOutcome.partial,
    'incorrect' => RecallOutcome.incorrect,
    'unknown' => RecallOutcome.unknown,
    _ => throw const RecallLearningException('Server Recall returned an invalid outcome.'),
  };

  static RecallStateKind _state(String value) => switch (value) {
    'not_assessed' => RecallStateKind.notAssessed,
    'needs_review' => RecallStateKind.needsReview,
    'developing' => RecallStateKind.developing,
    'retrieved_once' => RecallStateKind.retrievedOnce,
    _ => throw const RecallLearningException('Server Recall returned an invalid learner state.'),
  };

  static RetentionOutcomeBand _outcomeBand(String value) => switch (value) {
    'independent_retrieval' => RetentionOutcomeBand.independentRetrieval,
    'supported_retrieval' => RetentionOutcomeBand.supportedRetrieval,
    'repair_needed' => RetentionOutcomeBand.repairNeeded,
    'unassessed' => RetentionOutcomeBand.unassessed,
    _ => throw const RecallLearningException('Server Recall returned invalid retention truth.'),
  };

  static RecallLearningException _mapError(PostgrestException error) {
    final message = error.message;
    if (message.contains('stale') || message.contains('source_conflict')) {
      return const RecallLearningException('Recall source changed on another device. Reopen the current source.');
    }
    if (message.contains('material_not_found')) {
      return const RecallLearningException('Current source is not available for server Recall yet.');
    }
    if (message.contains('attempt_id_reused')) {
      return const RecallLearningException('Recall attempt no longer matches the active server attempt.');
    }
    return const RecallLearningException('Server Recall is temporarily unavailable.');
  }
}
