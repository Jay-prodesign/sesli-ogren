import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../data/learning_truth_store.dart';
import '../data/source_store.dart';
import '../domain/authenticated_learner.dart';
import '../domain/learning_contracts.dart';
import '../domain/learning_truth.dart';

class RecallLearningService {
  const RecallLearningService({
    required SourceStore sourceStore,
    required LearningTruthStore learningStore,
    DateTime Function()? now,
  }) : _sourceStore = sourceStore,
       _learningStore = learningStore,
       _now = now ?? DateTime.now;

  static const promptRuleVersion = 'recall-cloze-v1';
  static const evidenceRuleVersion = 'recall-evidence-v2';
  static const stateRuleVersion = 'recall-state-v2';
  static const nextActionPolicyVersion = 'recall-next-v1';

  final SourceStore _sourceStore;
  final LearningTruthStore _learningStore;
  final DateTime Function() _now;

  Future<RecallPrompt> createCurrentPrompt({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  }) async {
    final source = await _sourceStore.currentSourceVersion(
      learner: learner,
      materialId: materialId,
    );
    if (source == null) {
      throw const RecallLearningException(
        'No current authoritative source is available for recall.',
      );
    }
    final extracted = await _sourceStore.extractedContentForSource(
      learner: learner,
      sourceVersionId: source.identity.sourceVersionId,
    );
    if (extracted == null || !extracted.isValid) {
      throw const RecallLearningException(
        'Current source has no valid extracted content for recall.',
      );
    }

    final action = _buildAction(
      materialId: materialId,
      sourceVersionId: source.identity.sourceVersionId,
      extracted: extracted,
      now: _now().toUtc(),
    );
    final persisted = await _learningStore.persistRecallAction(
      learner: learner,
      action: action,
    );
    return persisted.toPrompt();
  }

  Future<RecallSupport> requestHint({
    required AuthenticatedLearner learner,
    required RecallActionId actionId,
    required RecallAttemptId attemptId,
  }) async {
    _validateAttemptId(attemptId);
    final action = await _currentAction(
      learner: learner,
      actionId: actionId,
    );
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
    final action = await _currentAction(
      learner: learner,
      actionId: actionId,
    );
    final assistance = await _learningStore.registerAssistance(
      learner: learner,
      attemptId: attemptId,
      actionId: action.id,
      assistance: RecallAssistance.answerExposed,
      recordedAt: _now().toUtc(),
    );
    return RecallSupport(
      kind: RecallSupportKind.answer,
      text: action.expectedAnswer,
      assistance: assistance,
    );
  }

  Future<RecallAttemptResult> submit({
    required AuthenticatedLearner learner,
    required RecallActionId actionId,
    required RecallAttemptId attemptId,
    required RecallResponseDisposition disposition,
    String answer = '',
  }) async {
    _validateAttemptId(attemptId);

    final action = await _currentAction(
      learner: learner,
      actionId: actionId,
    );
    final extracted = await _sourceStore.extractedContentForSource(
      learner: learner,
      sourceVersionId: action.sourceVersionId,
    );
    if (extracted == null ||
        !extracted.isValid ||
        extracted.id != action.extractedContentId) {
      throw const RecallLearningException(
        'Recall action provenance is no longer valid.',
      );
    }

    final assistance = await _learningStore.assistanceForAttempt(
      learner: learner,
      attemptId: attemptId,
      actionId: action.id,
    );
    final normalizedAnswer = disposition == RecallResponseDisposition.unknown
        ? ''
        : _normalizeAnswer(answer);
    final outcome = _evaluate(
      expected: action.expectedAnswer,
      normalizedAnswer: normalizedAnswer,
      disposition: disposition,
      assistance: assistance,
    );

    final responseDigest = sha256
        .convert(utf8.encode(normalizedAnswer))
        .toString();
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

    final stateKind = _stateForOutcome(outcome);
    final nextAction = _nextActionFor(
      materialId: action.materialId,
      sourceVersionId: action.sourceVersionId,
      evidenceId: evidence.id,
      outcome: outcome,
      now: now,
    );
    final persisted = await _learningStore.persistEvidenceStateAndNextAction(
      learner: learner,
      evidence: evidence,
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

  Future<RecallAction> _currentAction({
    required AuthenticatedLearner learner,
    required RecallActionId actionId,
  }) async {
    final action = await _learningStore.recallAction(
      learner: learner,
      actionId: actionId,
    );
    if (action == null) {
      throw const RecallLearningException(
        'Recall action is missing or belongs to another learner.',
      );
    }
    final currentSource = await _sourceStore.currentSourceVersion(
      learner: learner,
      materialId: action.materialId,
    );
    if (currentSource == null ||
        currentSource.identity.sourceVersionId != action.sourceVersionId) {
      throw const RecallLearningException(
        'Recall action is stale because the authoritative source changed.',
      );
    }
    return action;
  }

  static String _sourceExcerpt(
    ExtractedContentRecord extracted,
    SourceAnchor anchor,
  ) {
    if (anchor.startOffset < 0 ||
        anchor.endOffset <= anchor.startOffset ||
        anchor.endOffset > extracted.normalizedText.length) {
      throw const RecallLearningException(
        'Recall source anchor is outside current extracted content.',
      );
    }
    return extracted.normalizedText.substring(
      anchor.startOffset,
      anchor.endOffset,
    );
  }

  Future<LearningContinuation?> repairContinuation({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  }) async {
    final source = await _sourceStore.currentSourceVersion(
      learner: learner,
      materialId: materialId,
    );
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
      kind: _stateForOutcome(latest.outcome),
      evidenceCount: evidence.length,
      latestEvidenceId: latest.id,
      ruleVersion: stateRuleVersion,
      updatedAt: latest.createdAt,
    );
    final nextAction = _nextActionFor(
      materialId: materialId,
      sourceVersionId: source.identity.sourceVersionId,
      evidenceId: latest.id,
      outcome: latest.outcome,
      now: latest.createdAt,
    );

    return _learningStore.repairDerivedProjection(
      learner: learner,
      state: state,
      nextAction: nextAction,
    );
  }

  Future<LearningContinuation?> reopen({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  }) async {
    final source = await _sourceStore.currentSourceVersion(
      learner: learner,
      materialId: materialId,
    );
    if (source == null) {
      return null;
    }
    final state = await _learningStore.learnerState(
      learner: learner,
      materialId: materialId,
    );
    final nextAction = await _learningStore.nextLearningAction(
      learner: learner,
      materialId: materialId,
    );
    if (state == null && nextAction == null) {
      return null;
    }
    if (state == null ||
        nextAction == null ||
        state.sourceVersionId != source.identity.sourceVersionId ||
        nextAction.sourceVersionId != source.identity.sourceVersionId ||
        nextAction.latestEvidenceId != state.latestEvidenceId) {
      throw const RecallLearningException(
        'Persisted learning continuation is incomplete or stale.',
      );
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
      throw const RecallLearningException(
        'Source does not contain a suitable bounded recall prompt.',
      );
    }

    SourceAnchor? sourceAnchor;
    for (final anchor in extracted.anchors) {
      if (candidate.sentenceStart >= anchor.startOffset &&
          candidate.sentenceStart < anchor.endOffset) {
        sourceAnchor = anchor;
        break;
      }
    }

    final prompt = candidate.sentence.replaceRange(
      candidate.wordStartInSentence,
      candidate.wordEndInSentence,
      '_____',
    );
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

      final matches = RegExp(
        r'[A-Za-zÇĞİÖŞÜçğıöşü]+',
      ).allMatches(sentence).where((match) {
        final word = match.group(0)!;
        return word.length >= 5 && !_stopWords.contains(_normalizeAnswer(word));
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

  static RecallOutcome _evaluate({
    required String expected,
    required String normalizedAnswer,
    required RecallResponseDisposition disposition,
    required RecallAssistance assistance,
  }) {
    if (disposition == RecallResponseDisposition.unknown ||
        normalizedAnswer.isEmpty) {
      return RecallOutcome.unknown;
    }
    if (assistance == RecallAssistance.answerExposed) {
      return RecallOutcome.answerExposed;
    }

    final normalizedExpected = _normalizeAnswer(expected);
    if (normalizedAnswer == normalizedExpected) {
      return assistance == RecallAssistance.hint
          ? RecallOutcome.helpedCorrect
          : RecallOutcome.correct;
    }
    if (normalizedExpected.length >= 5 &&
        _editDistance(normalizedAnswer, normalizedExpected) <= 1) {
      return RecallOutcome.partial;
    }
    return RecallOutcome.incorrect;
  }

  static RecallStateKind _stateForOutcome(RecallOutcome outcome) {
    return switch (outcome) {
      RecallOutcome.correct => RecallStateKind.retrievedOnce,
      RecallOutcome.helpedCorrect || RecallOutcome.partial =>
        RecallStateKind.developing,
      RecallOutcome.incorrect => RecallStateKind.needsReview,
      RecallOutcome.answerExposed || RecallOutcome.unknown =>
        RecallStateKind.notAssessed,
    };
  }

  static NextLearningAction _nextActionFor({
    required MaterialId materialId,
    required SourceVersionId sourceVersionId,
    required LearnerEvidenceId evidenceId,
    required RecallOutcome outcome,
    required DateTime now,
  }) {
    final (kind, reasonCode, reasonText) = switch (outcome) {
      RecallOutcome.correct => (
        NextLearningActionKind.repeatRecallLater,
        'ONE_UNASSISTED_RETRIEVAL_OBSERVED',
        'Bu kavramı bir kez ipucusuz geri çağırdın. Bu ustalık kanıtı değil; daha sonra yeniden hatırlayacağız.',
      ),
      RecallOutcome.helpedCorrect => (
        NextLearningActionKind.retryRecallWithoutHint,
        'HINTED_SUCCESS_NEEDS_UNASSISTED_RETRIEVAL',
        'Doğru yanıta ipucuyla ulaştın. Bunu bağımsız hatırlama saymadan daha sonra ipucusuz yeniden dene.',
      ),
      RecallOutcome.answerExposed => (
        NextLearningActionKind.retryRecallWithoutHint,
        'ANSWER_EXPOSED_NO_RETRIEVAL_CLAIM',
        'Yanıt gösterildiği için geri çağırma kanıtı oluşmadı. Daha sonra kaynağı kapatıp ipucusuz yeniden dene.',
      ),
      RecallOutcome.partial => (
        NextLearningActionKind.retryRecallWithoutHint,
        'PARTIAL_RETRIEVAL_NEEDS_RETRY',
        'Yanıt kısmen yaklaştı. Kaynak geri bildirimini gördükten sonra ipucusuz yeniden dene.',
      ),
      RecallOutcome.incorrect => (
        NextLearningActionKind.reviewSourceThenRecall,
        'INCORRECT_RETRIEVAL_NEEDS_REPAIR',
        'Bu denemede eşleşme oluşmadı. Kaynak bölümünü gözden geçirip yeniden dene.',
      ),
      RecallOutcome.unknown => (
        NextLearningActionKind.reviewSourceThenRecall,
        'NO_EVALUABLE_RETRIEVAL',
        'Bu denemede değerlendirilebilir bir geri çağırma yanıtı yok. Kaynağı gözden geçirip hazır olduğunda yeniden dene.',
      ),
    };
    return NextLearningAction(
      materialId: materialId,
      sourceVersionId: sourceVersionId,
      latestEvidenceId: evidenceId,
      kind: kind,
      reasonCode: reasonCode,
      reasonText: reasonText,
      policyVersion: nextActionPolicyVersion,
      createdAt: now,
    );
  }

  static void _validateAttemptId(RecallAttemptId attemptId) {
    if (!RegExp(r'^[A-Za-z0-9_.:-]{8,128}
    return value
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-zçğıöşü0-9]+'), '')
        .trim();
  }

  static int _editDistance(String left, String right) {
    if (left == right) {
      return 0;
    }
    if (left.isEmpty) {
      return right.length;
    }
    if (right.isEmpty) {
      return left.length;
    }

    var previous = List<int>.generate(right.length + 1, (index) => index);
    for (var i = 0; i < left.length; i++) {
      final current = List<int>.filled(right.length + 1, 0);
      current[0] = i + 1;
      for (var j = 0; j < right.length; j++) {
        final substitution = previous[j] + (left[i] == right[j] ? 0 : 1);
        final insertion = current[j] + 1;
        final deletion = previous[j + 1] + 1;
        current[j + 1] = [
          substitution,
          insertion,
          deletion,
        ].reduce((a, b) => a < b ? a : b);
      }
      previous = current;
    }
    return previous.last;
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
).hasMatch(attemptId.value)) {
      throw const RecallLearningException(
        'Attempt ID must be a stable 8-128 character identifier.',
      );
    }
  }

  static String _normalizeAnswer(String value) {
    return value
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-zçğıöşü0-9]+'), '')
        .trim();
  }

  static int _editDistance(String left, String right) {
    if (left == right) {
      return 0;
    }
    if (left.isEmpty) {
      return right.length;
    }
    if (right.isEmpty) {
      return left.length;
    }

    var previous = List<int>.generate(right.length + 1, (index) => index);
    for (var i = 0; i < left.length; i++) {
      final current = List<int>.filled(right.length + 1, 0);
      current[0] = i + 1;
      for (var j = 0; j < right.length; j++) {
        final substitution = previous[j] + (left[i] == right[j] ? 0 : 1);
        final insertion = current[j] + 1;
        final deletion = previous[j + 1] + 1;
        current[j + 1] = [
          substitution,
          insertion,
          deletion,
        ].reduce((a, b) => a < b ? a : b);
      }
      previous = current;
    }
    return previous.last;
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
