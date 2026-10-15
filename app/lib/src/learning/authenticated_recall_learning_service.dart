import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../continuity/cloud_continuity_service.dart';
import '../continuity/retention_continuity_service.dart';
import '../data/sqlite_source_store.dart';
import '../domain/authenticated_learner.dart';
import '../domain/learning_contracts.dart';
import '../domain/learning_truth.dart';
import 'recall_learning_service.dart';
import 'server_recall_gateway.dart';

class AuthenticatedRecallLearningService extends RecallLearningService {
  AuthenticatedRecallLearningService({
    required this.store,
    required this.continuity,
    required this.gateway,
    this.retentionContinuity,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now,
       super(sourceStore: store, learningStore: store.learningTruthStore(), now: clock);

  final SqliteSourceStore store;
  final CloudContinuityService continuity;
  final ServerRecallGateway gateway;
  final RetentionContinuityService? retentionContinuity;
  final DateTime Function() _now;
  final Map<RecallActionId, ServerRecallAction> _activeActions = <RecallActionId, ServerRecallAction>{};

  @override
  Future<RecallPrompt> createCurrentPrompt({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  }) async {
    await _requireSyncedMaterial(learner: learner, materialId: materialId);
    return _createServerPrompt(learner: learner, materialId: materialId);
  }

  @override
  Future<RecallPrompt> createContextPrompt({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    required SourceVersionId sourceVersionId,
    required SourceAnchor selectedAnchor,
  }) async {
    await _requireSyncedMaterial(learner: learner, materialId: materialId, expectedSourceVersionId: sourceVersionId);
    final extracted = await store.extractedContentForSource(learner: learner, sourceVersionId: sourceVersionId);
    if (extracted == null ||
        !extracted.isValid ||
        selectedAnchor.startOffset < 0 ||
        selectedAnchor.endOffset <= selectedAnchor.startOffset ||
        selectedAnchor.endOffset > extracted.normalizedText.length) {
      throw const RecallLearningException('Reader context is outside the current source.');
    }
    return _createServerPrompt(learner: learner, materialId: materialId, anchor: selectedAnchor);
  }

  @override
  Future<RecallPrompt> createScheduledPrompt({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    required SourceVersionId sourceVersionId,
    required SourceAnchor sourceAnchor,
  }) async {
    await _requireSyncedMaterial(learner: learner, materialId: materialId, expectedSourceVersionId: sourceVersionId);
    return _createServerPrompt(learner: learner, materialId: materialId, anchor: sourceAnchor);
  }

  Future<RecallPrompt> _createServerPrompt({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    SourceAnchor? anchor,
  }) async {
    final action = await gateway.createAction(learner: learner, materialId: materialId, anchor: anchor);
    final source = await store.currentSourceVersion(learner: learner, materialId: materialId);
    if (source == null ||
        action.materialId != materialId ||
        action.sourceVersionId != source.identity.sourceVersionId) {
      throw const RecallLearningException('Server Recall action does not match the current local source.');
    }
    final extracted = await store.extractedContentForSource(learner: learner, sourceVersionId: action.sourceVersionId);
    if (extracted == null ||
        !extracted.isValid ||
        action.anchor.startOffset < 0 ||
        action.anchor.endOffset <= action.anchor.startOffset ||
        action.anchor.endOffset > extracted.normalizedText.length) {
      throw const RecallLearningException('Server Recall action returned invalid source provenance.');
    }
    _activeActions[action.id] = action;
    return action.toPrompt();
  }

  @override
  Future<RecallAttemptSession> openAttempt({
    required AuthenticatedLearner learner,
    required RecallActionId actionId,
  }) async {
    final now = _now().toUtc();
    final seed = sha256
        .convert(utf8.encode('${learner.id.value}\u0000${actionId.value}\u0000${now.microsecondsSinceEpoch}'))
        .toString();
    final attemptId = RecallAttemptId('srv_attempt_${seed.substring(0, 32)}');
    final assistance = await gateway.openAttempt(learner: learner, actionId: actionId, attemptId: attemptId);

    final action = _activeActions[actionId];
    if (action == null) {
      throw const RecallLearningException('Active server Recall action is no longer available. Reopen Recall.');
    }
    return RecallAttemptSession(
      attempt: ActiveRecallAttempt(
        attemptId: attemptId,
        actionId: actionId,
        materialId: action.materialId,
        sourceVersionId: action.sourceVersionId,
        openedAt: now,
      ),
      assistance: assistance,
    );
  }

  @override
  Future<RecallSupport> requestHint({
    required AuthenticatedLearner learner,
    required RecallActionId actionId,
    required RecallAttemptId attemptId,
  }) async {
    final hint = await gateway.requestHint(learner: learner, actionId: actionId, attemptId: attemptId);
    return RecallSupport(
      kind: RecallSupportKind.hint,
      text: 'İlk harf ve uzunluk: $hint',
      assistance: RecallAssistance.hint,
    );
  }

  @override
  Future<RecallSupport> revealAnswer({
    required AuthenticatedLearner learner,
    required RecallActionId actionId,
    required RecallAttemptId attemptId,
  }) async {
    final answer = await gateway.revealAnswer(learner: learner, actionId: actionId, attemptId: attemptId);
    return RecallSupport(kind: RecallSupportKind.answer, text: answer, assistance: RecallAssistance.answerExposed);
  }

  @override
  Future<RecallAttemptResult> submit({
    required AuthenticatedLearner learner,
    required RecallActionId actionId,
    required RecallAttemptId attemptId,
    required RecallResponseDisposition disposition,
    String answer = '',
  }) async {
    final activeAction = _activeActions[actionId];
    if (activeAction == null) {
      throw const RecallLearningException('Active server Recall action is no longer available. Reopen Recall.');
    }
    await _syncRetention(
      learner: learner,
      materialId: activeAction.materialId,
      sourceVersionId: activeAction.sourceVersionId,
    );
    final server = await gateway.submit(
      learner: learner,
      actionId: actionId,
      attemptId: attemptId,
      disposition: disposition,
      answer: answer,
    );
    final normalizedDigest = sha256.convert(utf8.encode(server.normalizedResponse)).toString();
    if (normalizedDigest != server.responseDigest || server.normalizedResponse.length != server.responseLength) {
      throw const RecallLearningException('Server Recall response evidence failed integrity validation.');
    }

    final source = await store.currentSourceVersion(learner: learner, materialId: server.materialId);
    if (source == null || source.identity.sourceVersionId != server.sourceVersionId) {
      throw const RecallLearningException('Server Recall result belongs to a stale local source.');
    }
    final extracted = await store.extractedContentForSource(learner: learner, sourceVersionId: server.sourceVersionId);
    if (extracted == null || !extracted.isValid) {
      throw const RecallLearningException('Server Recall result has no current local source evidence.');
    }
    if (server.anchor.startOffset < 0 ||
        server.anchor.endOffset <= server.anchor.startOffset ||
        server.anchor.endOffset > extracted.normalizedText.length ||
        extracted.normalizedText.substring(server.anchor.startOffset, server.anchor.endOffset) !=
            server.sourceExcerpt) {
      throw const RecallLearningException('Server Recall source evidence does not match the local source.');
    }

    final action = RecallAction(
      id: actionId,
      materialId: server.materialId,
      sourceVersionId: server.sourceVersionId,
      extractedContentId: extracted.id,
      promptText: server.promptText,
      expectedAnswer: server.correctAnswer,
      anchor: server.anchor,
      ruleVersion: 'recall-cloze-v1',
      createdAt: server.evidenceCreatedAt,
    );
    final nextAction = RecallTruthPolicy.nextActionFor(
      materialId: server.materialId,
      sourceVersionId: server.sourceVersionId,
      evidenceId: server.evidenceId,
      outcome: server.outcome,
      createdAt: server.evidenceCreatedAt,
    );
    if (nextAction.reasonCode != server.nextReasonCode) {
      throw const RecallLearningException('Server Recall next action does not match the client contract.');
    }

    final cached = await store.cacheServerVerifiedRecallTruth(
      learner: learner,
      action: action,
      attemptId: attemptId,
      evidenceId: server.evidenceId,
      outcome: server.outcome,
      assistance: server.assistance,
      responseDigest: server.responseDigest,
      responseLength: server.responseLength,
      evidenceRuleVersion: server.evidenceRuleVersion,
      evidenceCreatedAt: server.evidenceCreatedAt,
      stateKind: server.stateKind,
      evidenceCount: server.evidenceCount,
      stateRuleVersion: RecallTruthPolicy.stateRuleVersion,
      nextAction: nextAction,
    );
    await _syncRetention(learner: learner, materialId: server.materialId, sourceVersionId: server.sourceVersionId);

    return RecallAttemptResult(
      evidence: cached.evidence,
      state: cached.state,
      nextAction: cached.nextAction,
      correctAnswer: server.correctAnswer,
      sourceExcerpt: server.sourceExcerpt,
    );
  }

  Future<int> syncLatestContinuity({required AuthenticatedLearner learner}) async {
    if (!learner.isAuthenticated) return 0;
    final materials = await store.activeMaterials(learner: learner);
    var failures = 0;
    for (final material in materials) {
      try {
        final projection = await gateway.readLatest(learner: learner, materialId: material.id);
        if (projection != null) {
          await _cacheProjection(learner: learner, projection: projection);
        }
        final current = await store.currentSourceVersion(learner: learner, materialId: material.id);
        if (current != null) {
          await _syncRetention(
            learner: learner,
            materialId: material.id,
            sourceVersionId: current.identity.sourceVersionId,
          );
        }
      } catch (_) {
        failures += 1;
      }
    }
    return failures;
  }

  Future<void> _cacheProjection({
    required AuthenticatedLearner learner,
    required ServerRecallProjection projection,
  }) async {
    final source = await store.currentSourceVersion(learner: learner, materialId: projection.materialId);
    if (source == null || source.identity.sourceVersionId != projection.sourceVersionId) {
      throw const RecallLearningException('Server Recall projection belongs to a stale local source.');
    }
    final extracted = await store.extractedContentForSource(
      learner: learner,
      sourceVersionId: projection.sourceVersionId,
    );
    if (extracted == null ||
        !extracted.isValid ||
        projection.anchor.startOffset < 0 ||
        projection.anchor.endOffset <= projection.anchor.startOffset ||
        projection.anchor.endOffset > extracted.normalizedText.length ||
        extracted.normalizedText.substring(projection.anchor.startOffset, projection.anchor.endOffset) !=
            projection.sourceExcerpt) {
      throw const RecallLearningException('Server Recall projection source evidence does not match local source.');
    }

    final action = RecallAction(
      id: projection.actionId,
      materialId: projection.materialId,
      sourceVersionId: projection.sourceVersionId,
      extractedContentId: extracted.id,
      promptText: projection.promptText,
      expectedAnswer: projection.correctAnswer,
      anchor: projection.anchor,
      ruleVersion: 'recall-cloze-v1',
      createdAt: projection.evidenceCreatedAt,
    );
    final nextAction = RecallTruthPolicy.nextActionFor(
      materialId: projection.materialId,
      sourceVersionId: projection.sourceVersionId,
      evidenceId: projection.evidenceId,
      outcome: projection.outcome,
      createdAt: projection.evidenceCreatedAt,
    );
    if (nextAction.reasonCode != projection.nextReasonCode) {
      throw const RecallLearningException('Server Recall projection next action is inconsistent.');
    }
    await store.cacheServerVerifiedRecallTruth(
      learner: learner,
      action: action,
      attemptId: projection.attemptId,
      evidenceId: projection.evidenceId,
      outcome: projection.outcome,
      assistance: projection.assistance,
      responseDigest: projection.responseDigest,
      responseLength: projection.responseLength,
      evidenceRuleVersion: projection.evidenceRuleVersion,
      evidenceCreatedAt: projection.evidenceCreatedAt,
      stateKind: projection.stateKind,
      evidenceCount: projection.evidenceCount,
      stateRuleVersion: RecallTruthPolicy.stateRuleVersion,
      nextAction: nextAction,
    );
  }

  Future<void> _syncRetention({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    required SourceVersionId sourceVersionId,
  }) async {
    final unified = retentionContinuity;
    if (unified != null) {
      final results = await unified.syncMaterial(learner: learner, materialId: materialId);
      if (results.any(
        (item) =>
            item.disposition == RetentionContinuityDisposition.conflict ||
            item.disposition == RetentionContinuityDisposition.unavailable,
      )) {
        throw const RecallLearningException(
          'Unified retention timing could not be reconciled without overwriting another device.',
        );
      }
      return;
    }

    // Compatibility path for bounded tests/older injected runtimes. Production
    // authenticated runtime always supplies the unified reconciler.
    final schedules = await gateway.readRetention(learner: learner, materialId: materialId);
    if (schedules.any((item) => item.sourceVersionId != sourceVersionId)) {
      throw const RecallLearningException('Server retention projection belongs to a stale source.');
    }
    await store.replaceServerVerifiedRecallRetention(
      learner: learner,
      materialId: materialId,
      sourceVersionId: sourceVersionId,
      schedules: schedules,
    );
  }

  Future<void> _requireSyncedMaterial({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    SourceVersionId? expectedSourceVersionId,
  }) async {
    if (!learner.isAuthenticated) {
      throw const RecallLearningException('Authenticated Recall requires an account session.');
    }
    final result = await continuity.reconcileMaterial(learner: learner, materialId: materialId);
    if (result.disposition != CloudContinuityDisposition.inSync &&
        result.disposition != CloudContinuityDisposition.pushedLocal &&
        result.disposition != CloudContinuityDisposition.pulledRemote) {
      throw RecallLearningException(result.message ?? 'Current source could not be reconciled for Recall.');
    }
    final current = await store.currentSourceVersion(learner: learner, materialId: materialId);
    if (current == null ||
        (expectedSourceVersionId != null && current.identity.sourceVersionId != expectedSourceVersionId)) {
      throw const RecallLearningException('Recall request belongs to a source version that is no longer current.');
    }
  }
}
