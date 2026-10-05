import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../data/learning_truth_store.dart';
import '../data/source_store.dart';
import '../domain/authenticated_learner.dart';
import '../domain/learning_contracts.dart';
import '../domain/learning_truth.dart';

class RecallLearningService {
  const RecallLearningService({
    required this._sourceStore,
    required this._learningStore,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const promptRuleVersion = 'recall-cloze-v1';
  static const evidenceRuleVersion = RecallTruthPolicy.evidenceRuleVersion;
  static const stateRuleVersion = RecallTruthPolicy.stateRuleVersion;
  static const nextActionPolicyVersion = RecallTruthPolicy.nextActionPolicyVersion;

  final SourceStore _sourceStore;
  final LearningTruthStore _learningStore;
  final DateTime Function() _now;

  Future<RecallPrompt> createCurrentPrompt({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  }) async {
    final source = await _sourceStore.currentSourceVersion(learner: learner, materialId: materialId);
    if (source == null) {
      throw const RecallLearningException('No current authoritative source is available for recall.');
    }
    final extracted = await _sourceStore.extractedContentForSource(
      learner: learner,
      sourceVersionId: source.identity.sourceVersionId,
    );
    if (extracted == null || !extracted.isValid) {
      throw const RecallLearningException('Current source has no valid extracted content for recall.');
    }

    final action = _buildAction(
      materialId: materialId,
      sourceVersionId: source.identity.sourceVersionId,
      extracted: extracted,
      now: _now().toUtc(),
    );
    final persisted = await _learningStore.persistRecallAction(learner: learner, action: action);
    return persisted.toPrompt();
  }

  Future<RecallAttemptSession> openAttempt({
    required AuthenticatedLearner learner,
    required RecallActionId actionId,
  }) async {
    final action = await _currentAction(learner: learner, actionId: actionId);
    final now = _now().toUtc();
    final existingEvidence = await _learningStore.evidenceForMaterial(
      learner: learner,
      materialId: action.materialId,
      sourceVersionId: action.sourceVersionId,
    );
    final seed = sha256
        .convert(
          utf8.encode(
            '${learner.id.value}\u0000${action.id.value}\u0000'
            '${existingEvidence.length}\u0000${now.microsecondsSinceEpoch}',
          ),
        )
        .toString();
    final proposedAttemptId = RecallAttemptId('attempt-${seed.substring(0, 32)}');
    final active = await _learningStore.openRecallAttempt(
      learner: learner,
      actionId: action.id,
      proposedAttemptId: proposedAttemptId,
      openedAt: now,
    );
    final assistance = await _learningStore.assistanceForAttempt(
      learner: learner,
      attemptId: active.attemptId,
      actionId: active.actionId,
    );
    return RecallAttemptSession(attempt: active, assistance: assistance);
  }

  Future<RecallSupport> requestHint({
    required AuthenticatedLearner learner,
    required RecallActionId actionId,
    required RecallAttemptId attemptId,
  }) async {
    _validateAttemptId(attemptId);
    final action = await _currentAction(learner: learner, actionId: actionId);
    final active = await _learningStore.openRecallAttempt(
      learner: learner,
      actionId: action.id,
      proposedAttemptId: attemptId,
      openedAt: _now().toUtc(),
    );
    if (active.attemptId != attemptId) {
      throw const RecallLearningException('Recall support belongs to a different active attempt.');
    }
    final assistance = await _learningStore.registerAssistance(
      learner: learner,
      attemptId: attemptId,
      actionId: action.id,
      assistance: RecallAssistance.hint,
      recordedAt: _now().toUtc(),
    );
    final firstCharacter = action.expectedAnswer.substring(0, 1);
    return RecallSupport(
      kind: RecallSupportKind.hint,
      text: 'İlk harf: $firstCharacter · ${action.expectedAnswer.length} harf',
      assistance: assistance,
    );
  }

  Future<RecallSupport> revealAnswer({
    required AuthenticatedLearner learner,
    required RecallActionId actionId,
    required RecallAttemptId attemptId,
  }) async {
    _validateAttemptId(attemptId);
    final action = await _currentAction(learner: learner, actionId: actionId);
    final active = await _learningStore.openRecallAttempt(
      learner: learner,
      actionId: action.id,
      proposedAttemptId: attemptId,
      openedAt: _now().toUtc(),
    );
    if (active.attemptId != attemptId) {
      throw const RecallLearningException('Recall support belongs to a different active attempt.');
    }
    final assistance = await _learningStore.registerAssistance(
      learner: learner,
      attemptId: attemptId,
      actionId: action.id,
      assistance: RecallAssistance.answerExposed,
      recordedAt: _now().toUtc(),
    );
    return RecallSupport(kind: RecallSupportKind.answer, text: action.expectedAnswer, assistance: assistance);
  }

  Future<RecallAttemptResult> submit({
    required AuthenticatedLearner learner,
    required RecallActionId actionId,
    required RecallAttemptId attemptId,
    required RecallResponseDisposition disposition,
    String answer = '',
  }) async {
    _validateAttemptId(attemptId);

    final action = await _currentAction(learner: learner, actionId: actionId);
    final extracted = await _sourceStore.extractedContentForSource(
      learner: learner,
      sourceVersionId: action.sourceVersionId,
    );
    if (extracted == null || !extracted.isValid || extracted.id != action.extractedContentId) {
      throw const RecallLearningException('Recall action provenance is no longer valid.');
    }

    final existingEvidence = await _learningStore.evidenceForAttempt(learner: learner, attemptId: attemptId);
    if (existingEvidence == null) {
      final active = await _learningStore.openRecallAttempt(
        learner: learner,
        actionId: action.id,
        proposedAttemptId: attemptId,
        openedAt: _now().toUtc(),
      );
      if (active.attemptId != attemptId) {
        throw const RecallLearningException('Submission does not match the active Recall attempt.');
      }
    }

    final assistance = await _learningStore.assistanceForAttempt(
      learner: learner,
      attemptId: attemptId,
      actionId: action.id,
    );
    final normalizedAnswer = disposition == RecallResponseDisposition.unknown
        ? ''
        : RecallTruthPolicy.normalizeAnswer(answer);
    final outcome = RecallTruthPolicy.evaluate(
      expectedAnswer: action.expectedAnswer,
      response: normalizedAnswer,
      disposition: disposition,
      assistance: assistance,
    );

    final responseDigest = sha256.convert(utf8.encode(normalizedAnswer)).toString();
    final evidenceIdDigest = sha256
        .convert(
          utf8.encode(
            '${learner.id.value}\u0000${attemptId.value}\u0000'
            '${action.id.value}',
          ),
        )
        .toString();
    final now = _now().toUtc();
    final evidence = LearnerEvidence(
      id: LearnerEvidenceId('ev_${evidenceIdDigest.substring(0, 32)}'),
      attemptId: attemptId,
      actionId: action.id,
      materialId: action.materialId,
      sourceVersionId: action.sourceVersionId,
      extractedContentId: action.extractedContentId,
      outcome: outcome,
      assistance: assistance,
      responseDigest: responseDigest,
      responseLength: normalizedAnswer.length,
      ruleVersion: evidenceRuleVersion,
      createdAt: now,
    );

    final stateKind = RecallTruthPolicy.stateForOutcome(outcome);
    final nextAction = RecallTruthPolicy.nextActionFor(
      materialId: action.materialId,
      sourceVersionId: action.sourceVersionId,
      evidenceId: evidence.id,
      outcome: outcome,
      createdAt: now,
    );
    final persisted = await _learningStore.persistEvidenceStateAndNextAction(
      learner: learner,
      evidence: evidence,
      disposition: disposition,
      normalizedResponse: normalizedAnswer,
      stateKind: stateKind,
      stateRuleVersion: stateRuleVersion,
      nextAction: nextAction,
    );
    final excerpt = _sourceExcerpt(extracted, action.anchor);
    return RecallAttemptResult(
      evidence: persisted.evidence,
      state: persisted.state,
      nextAction: persisted.nextAction,
      correctAnswer: action.expectedAnswer,
      sourceExcerpt: excerpt,
    );
  }

  Future<RecallAction> _currentAction({required AuthenticatedLearner learner, required RecallActionId actionId}) async {
    final action = await _learningStore.recallAction(learner: learner, actionId: actionId);
    if (action == null) {
      throw const RecallLearningException('Recall action is missing or belongs to another learner.');
    }
    final currentSource = await _sourceStore.currentSourceVersion(learner: learner, materialId: action.materialId);
    if (currentSource == null || currentSource.identity.sourceVersionId != action.sourceVersionId) {
      throw const RecallLearningException('Recall action is stale because the authoritative source changed.');
    }
    return action;
  }

  static String _sourceExcerpt(ExtractedContentRecord extracted, SourceAnchor anchor) {
    if (anchor.startOffset < 0 ||
        anchor.endOffset <= anchor.startOffset ||
        anchor.endOffset > extracted.normalizedText.length) {
      throw const RecallLearningException('Recall source anchor is outside current extracted content.');
    }
    return extracted.normalizedText.substring(anchor.startOffset, anchor.endOffset);
  }

  Future<LearningContinuation?> repairContinuation({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  }) async {
    final source = await _sourceStore.currentSourceVersion(learner: learner, materialId: materialId);
    if (source == null) {
      return null;
    }

    final evidence = await _learningStore.evidenceForMaterial(
      learner: learner,
      materialId: materialId,
      sourceVersionId: source.identity.sourceVersionId,
    );
    if (evidence.isEmpty) {
      return null;
    }

    final latest = evidence.last;
    final state = LearnerState(
      materialId: materialId,
      sourceVersionId: source.identity.sourceVersionId,
      kind: RecallTruthPolicy.stateForOutcome(latest.outcome),
      evidenceCount: evidence.length,
      latestEvidenceId: latest.id,
      ruleVersion: stateRuleVersion,
      updatedAt: latest.createdAt,
    );
    final nextAction = RecallTruthPolicy.nextActionFor(
      materialId: materialId,
      sourceVersionId: source.identity.sourceVersionId,
      evidenceId: latest.id,
      outcome: latest.outcome,
      createdAt: latest.createdAt,
    );

    return _learningStore.repairDerivedProjection(learner: learner, state: state, nextAction: nextAction);
  }

  Future<LearningContinuation?> reopen({required AuthenticatedLearner learner, required MaterialId materialId}) async {
    final source = await _sourceStore.currentSourceVersion(learner: learner, materialId: materialId);
    if (source == null) {
      return null;
    }
    final state = await _learningStore.learnerState(learner: learner, materialId: materialId);
    final nextAction = await _learningStore.nextLearningAction(learner: learner, materialId: materialId);
    if (state == null && nextAction == null) {
      return null;
    }
    if (state == null ||
        nextAction == null ||
        state.sourceVersionId != source.identity.sourceVersionId ||
        nextAction.sourceVersionId != source.identity.sourceVersionId ||
        nextAction.latestEvidenceId != state.latestEvidenceId) {
      throw const RecallLearningException('Persisted learning continuation is incomplete or stale.');
    }
    return LearningContinuation(state: state, nextAction: nextAction);
  }

  static RecallAction _buildAction({
    required MaterialId materialId,
    required SourceVersionId sourceVersionId,
    required ExtractedContentRecord extracted,
    required DateTime now,
  }) {
    final candidate = _findCandidate(extracted.normalizedText);
    if (candidate == null) {
      throw const RecallLearningException('Source does not contain a suitable bounded recall prompt.');
    }

    SourceAnchor? sourceAnchor;
    for (final anchor in extracted.anchors) {
      if (candidate.sentenceStart >= anchor.startOffset && candidate.sentenceStart < anchor.endOffset) {
        sourceAnchor = anchor;
        break;
      }
    }

    final prompt = candidate.sentence.replaceRange(candidate.wordStartInSentence, candidate.wordEndInSentence, '_____');
    final actionDigest = sha256
        .convert(
          utf8.encode(
            '${sourceVersionId.value}\u0000${extracted.id.value}\u0000'
            '$promptRuleVersion\u0000${candidate.sentenceStart}\u0000'
            '${candidate.expectedAnswer}',
          ),
        )
        .toString();

    return RecallAction(
      id: RecallActionId('ra_${actionDigest.substring(0, 32)}'),
      materialId: materialId,
      sourceVersionId: sourceVersionId,
      extractedContentId: extracted.id,
      promptText: prompt,
      expectedAnswer: candidate.expectedAnswer,
      anchor: SourceAnchor(
        startOffset: candidate.sentenceStart,
        endOffset: candidate.sentenceEnd,
        pageNumber: sourceAnchor?.pageNumber,
      ),
      ruleVersion: promptRuleVersion,
      createdAt: now,
    );
  }

  static _RecallCandidate? _findCandidate(String text) {
    final scan = text.length <= 2400 ? text : text.substring(0, 2400);
    final chunks = scan.split(RegExp(r'[.!?]+'));
    var searchOffset = 0;
    for (final rawChunk in chunks) {
      final sentence = rawChunk.trim();
      if (sentence.length < 20) {
        searchOffset += rawChunk.length + 1;
        continue;
      }
      final sentenceStart = text.indexOf(sentence, searchOffset);
      if (sentenceStart < 0) {
        searchOffset += rawChunk.length + 1;
        continue;
      }

      final matches = RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşü]+').allMatches(sentence).where((match) {
        final word = match.group(0)!;
        return word.length >= 5 && !_stopWords.contains(RecallTruthPolicy.normalizeAnswer(word));
      }).toList();

      if (matches.isNotEmpty) {
        matches.sort((a, b) {
          final lengthOrder = b.group(0)!.length.compareTo(a.group(0)!.length);
          return lengthOrder != 0 ? lengthOrder : a.start.compareTo(b.start);
        });
        final selected = matches.first;
        return _RecallCandidate(
          sentence: sentence,
          sentenceStart: sentenceStart,
          sentenceEnd: sentenceStart + sentence.length,
          wordStartInSentence: selected.start,
          wordEndInSentence: selected.end,
          expectedAnswer: selected.group(0)!,
        );
      }
      searchOffset = sentenceStart + sentence.length + 1;
    }
    return null;
  }

  static void _validateAttemptId(RecallAttemptId attemptId) {
    if (!RegExp(r'^[A-Za-z0-9_.:-]{8,128}$').hasMatch(attemptId.value)) {
      throw const RecallLearningException('Attempt ID must be a stable 8-128 character identifier.');
    }
  }

  static const _stopWords = <String>{
    'ancak',
    'bunun',
    'daha',
    'fakat',
    'gibi',
    'için',
    'ile',
    'olan',
    'olarak',
    'sonra',
    'şekilde',
    'veya',
    'çünkü',
    'the',
    'that',
    'this',
    'with',
    'from',
  };
}

class RecallLearningException implements Exception {
  const RecallLearningException(this.message);

  final String message;

  @override
  String toString() => 'RecallLearningException: $message';
}

class _RecallCandidate {
  const _RecallCandidate({
    required this.sentence,
    required this.sentenceStart,
    required this.sentenceEnd,
    required this.wordStartInSentence,
    required this.wordEndInSentence,
    required this.expectedAnswer,
  });

  final String sentence;
  final int sentenceStart;
  final int sentenceEnd;
  final int wordStartInSentence;
  final int wordEndInSentence;
  final String expectedAnswer;
}
