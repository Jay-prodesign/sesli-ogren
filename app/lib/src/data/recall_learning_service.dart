import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../domain/authenticated_learner.dart';
import '../domain/learning_contracts.dart';
import '../domain/learning_loop.dart';
import 'learning_store.dart';
import 'source_store.dart';

class RecallPreparationException implements Exception {
  const RecallPreparationException(this.message);

  final String message;

  @override
  String toString() => 'RecallPreparationException: $message';
}

class RecallSubmission {
  const RecallSubmission({
    required this.attemptKey,
    required this.responseText,
    this.assistance = RecallAssistance.none,
    this.declaredUnknown = false,
  });

  final String attemptKey;
  final String responseText;
  final RecallAssistance assistance;
  final bool declaredUnknown;
}

class RecallLearningService {
  const RecallLearningService({
    required SourceStore sourceStore,
    required LearningStore learningStore,
    DateTime Function()? now,
  }) : _sourceStore = sourceStore,
       _learningStore = learningStore,
       _now = now ?? DateTime.now;

  static const promptRuleVersion = 'recall-cloze-v1';
  static const evaluationRuleVersion = 'recall-eval-v1';
  static const stateRuleVersion = 'recall-state-v1';
  static const nextActionPolicyVersion = 'recall-next-v1';

  final SourceStore _sourceStore;
  final LearningStore _learningStore;
  final DateTime Function() _now;

  Future<RecallPromptRecord> prepareRecall({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  }) async {
    final source = await _sourceStore.currentSourceVersion(
      learner: learner,
      materialId: materialId,
    );
    if (source == null) {
      throw const RecallPreparationException(
        'No current authoritative source is available for Recall.',
      );
    }

    final extraction = await _sourceStore.extractedContentForSource(
      learner: learner,
      sourceVersionId: source.identity.sourceVersionId,
    );
    if (extraction == null || !extraction.isValid) {
      throw const RecallPreparationException(
        'Current source has no valid extracted content.',
      );
    }

    final prompt = _buildPrompt(
      materialId: materialId,
      sourceVersionId: source.identity.sourceVersionId,
      extraction: extraction,
      createdAt: _now().toUtc(),
    );
    return _learningStore.persistRecallPrompt(
      learner: learner,
      prompt: prompt,
    );
  }

  Future<RecallAttemptResult> submitRecall({
    required AuthenticatedLearner learner,
    required RecallPromptId promptId,
    required RecallSubmission submission,
  }) async {
    _validateAttemptKey(submission.attemptKey);

    final prompt = await _learningStore.recallPrompt(
      learner: learner,
      promptId: promptId,
    );
    if (prompt == null) {
      throw const RecallPreparationException(
        'Recall prompt is missing, stale or no longer current.',
      );
    }

    final currentSource = await _sourceStore.currentSourceVersion(
      learner: learner,
      materialId: prompt.materialId,
    );
    if (currentSource == null ||
        currentSource.identity.sourceVersionId != prompt.sourceVersionId) {
      throw const RecallPreparationException(
        'Recall prompt no longer belongs to the current source version.',
      );
    }

    final outcome = _evaluate(prompt: prompt, submission: submission);
    final evidence = _buildEvidence(
      learner: learner,
      prompt: prompt,
      submission: submission,
      outcome: outcome,
      occurredAt: _now().toUtc(),
    );

    final write = await _learningStore.persistLearnerEvidence(
      learner: learner,
      evidence: evidence,
    );
    final snapshot = await rebuildSnapshot(
      learner: learner,
      materialId: prompt.materialId,
      sourceVersionId: prompt.sourceVersionId,
    );

    return RecallAttemptResult(
      evidence: write.evidence,
      snapshot: snapshot,
      feedback: _feedback(prompt: prompt, outcome: write.evidence.outcome),
      isReplay: write.isReplay,
    );
  }

  Future<LearningSnapshot> rebuildSnapshot({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    required SourceVersionId sourceVersionId,
  }) async {
    final currentSource = await _sourceStore.currentSourceVersion(
      learner: learner,
      materialId: materialId,
    );
    if (currentSource == null ||
        currentSource.identity.sourceVersionId != sourceVersionId) {
      throw const RecallPreparationException(
        'Learner state cannot be projected from a stale source version.',
      );
    }

    final evidence = await _learningStore.evidenceForSource(
      learner: learner,
      materialId: materialId,
      sourceVersionId: sourceVersionId,
    );
    if (evidence.isEmpty) {
      throw const RecallPreparationException(
        'Learner state requires durable active-learning evidence.',
      );
    }

    final state = _deriveState(
      materialId: materialId,
      sourceVersionId: sourceVersionId,
      evidence: evidence,
      updatedAt: _now().toUtc(),
    );
    final nextAction = _selectNextAction(
      state: state,
      createdAt: _now().toUtc(),
    );
    final snapshot = LearningSnapshot(state: state, nextAction: nextAction);
    await _learningStore.persistLearningSnapshot(
      learner: learner,
      snapshot: snapshot,
    );
    return snapshot;
  }

  static RecallPromptRecord _buildPrompt({
    required MaterialId materialId,
    required SourceVersionId sourceVersionId,
    required ExtractedContentRecord extraction,
    required DateTime createdAt,
  }) {
    final selection = _selectSentence(extraction.normalizedText);
    final tokens = _tokenMatches(selection.text);
    if (tokens.length < 6) {
      throw const RecallPreparationException(
        'Source does not contain enough bounded text for a meaningful Recall.',
      );
    }

    final answerTokenCount = tokens.length >= 10 ? 3 : 2;
    final firstAnswerToken = tokens[tokens.length - answerTokenCount];
    final lastAnswerToken = tokens.last;
    final answerStartLocal = firstAnswerToken.start;
    final answerEndLocal = lastAnswerToken.end;
    final expectedAnswer = selection.text.substring(
      answerStartLocal,
      answerEndLocal,
    );
    final promptText =
        'Boşluğu kaynaktan hatırlayarak tamamla: '
        '${selection.text.replaceRange(answerStartLocal, answerEndLocal, '_____')}';

    final sentenceStart = selection.startOffset;
    final sentenceEnd = selection.endOffset;
    final answerStart = sentenceStart + answerStartLocal;
    final answerEnd = sentenceStart + answerEndLocal;
    final pageNumber = _pageForOffset(extraction.anchors, sentenceStart);

    final promptDigest = sha256
        .convert(
          utf8.encode(
            '${sourceVersionId.value}\u0000'
            '${extraction.id.value}\u0000$sentenceStart\u0000$sentenceEnd\u0000'
            '$answerStart\u0000$answerEnd\u0000$promptRuleVersion',
          ),
        )
        .toString();

    return RecallPromptRecord(
      id: RecallPromptId('rp_${promptDigest.substring(0, 32)}'),
      materialId: materialId,
      sourceVersionId: sourceVersionId,
      extractedContentId: extraction.id,
      promptText: promptText,
      expectedAnswer: expectedAnswer,
      sourceExcerpt: selection.text,
      sourceAnchor: SourceAnchor(
        startOffset: sentenceStart,
        endOffset: sentenceEnd,
        pageNumber: pageNumber,
      ),
      answerAnchor: SourceAnchor(
        startOffset: answerStart,
        endOffset: answerEnd,
        pageNumber: pageNumber,
      ),
      generationRuleVersion: promptRuleVersion,
      createdAt: createdAt,
    );
  }

  static RecallOutcome _evaluate({
    required RecallPromptRecord prompt,
    required RecallSubmission submission,
  }) {
    if (submission.declaredUnknown || submission.responseText.trim().isEmpty) {
      return RecallOutcome.unknown;
    }
    if (submission.assistance == RecallAssistance.answerExposed) {
      return RecallOutcome.answerExposed;
    }

    final expected = _normalizedTokens(prompt.expectedAnswer);
    final actual = _normalizedTokens(submission.responseText);
    if (actual == expected) {
      return submission.assistance == RecallAssistance.none
          ? RecallOutcome.independentCorrect
          : RecallOutcome.supportedCorrect;
    }

    final expectedSet = expected.split(' ').where((token) => token.isNotEmpty).toSet();
    final actualSet = actual.split(' ').where((token) => token.isNotEmpty).toSet();
    if (expectedSet.isNotEmpty) {
      final overlap = expectedSet.intersection(actualSet).length / expectedSet.length;
      if (overlap >= 0.5) {
        return RecallOutcome.partial;
      }
    }
    return RecallOutcome.wrong;
  }

  static LearnerEvidenceRecord _buildEvidence({
    required AuthenticatedLearner learner,
    required RecallPromptRecord prompt,
    required RecallSubmission submission,
    required RecallOutcome outcome,
    required DateTime occurredAt,
  }) {
    final evidenceDigest = sha256
        .convert(
          utf8.encode(
            '${learner.id.value}\u0000${prompt.materialId.value}\u0000'
            '${prompt.id.value}\u0000${submission.attemptKey}',
          ),
        )
        .toString();
    return LearnerEvidenceRecord(
      id: LearnerEvidenceId('ev_${evidenceDigest.substring(0, 32)}'),
      attemptKey: submission.attemptKey,
      materialId: prompt.materialId,
      sourceVersionId: prompt.sourceVersionId,
      extractedContentId: prompt.extractedContentId,
      promptId: prompt.id,
      outcome: outcome,
      assistance: submission.assistance,
      responseText: submission.responseText,
      evaluationRuleVersion: evaluationRuleVersion,
      promptRuleVersion: prompt.generationRuleVersion,
      sourceAnchor: prompt.sourceAnchor,
      occurredAt: occurredAt,
    );
  }

  static LearnerStateRecord _deriveState({
    required MaterialId materialId,
    required SourceVersionId sourceVersionId,
    required List<LearnerEvidenceRecord> evidence,
    required DateTime updatedAt,
  }) {
    final sorted = [...evidence]
      ..sort((a, b) {
        final time = a.occurredAt.compareTo(b.occurredAt);
        return time != 0 ? time : a.id.value.compareTo(b.id.value);
      });
    final latest = sorted.last;
    final distinctPrompts = sorted.map((item) => item.promptId.value).toSet();
    final evidenceIds = sorted.map((item) => item.id).toList(growable: false);
    final fingerprint = sha256
        .convert(
          utf8.encode(
            [
              stateRuleVersion,
              sourceVersionId.value,
              ...evidenceIds.map((id) => id.value),
            ].join('\u0000'),
          ),
        )
        .toString();

    final (observation, reason) = switch (latest.outcome) {
      RecallOutcome.independentCorrect => (
        RetrievalObservation.independent,
        'ONE_INDEPENDENT_RECALL_OBSERVED',
      ),
      RecallOutcome.supportedCorrect || RecallOutcome.answerExposed => (
        RetrievalObservation.supported,
        'LATEST_RECALL_REQUIRED_ASSISTANCE',
      ),
      RecallOutcome.partial => (
        RetrievalObservation.needsRepair,
        'LATEST_RECALL_PARTIAL',
      ),
      RecallOutcome.wrong => (
        RetrievalObservation.needsRepair,
        'LATEST_RECALL_INCORRECT',
      ),
      RecallOutcome.unknown => (
        RetrievalObservation.unknown,
        'LATEST_RECALL_UNKNOWN',
      ),
    };

    return LearnerStateRecord(
      materialId: materialId,
      sourceVersionId: sourceVersionId,
      derivationRuleVersion: stateRuleVersion,
      retrievalObservation: observation,
      evidenceConfidence: EvidenceConfidenceBand.singleGroundedObservation,
      distinctPromptCount: distinctPrompts.length,
      evidenceIds: evidenceIds,
      evidenceFingerprint: fingerprint,
      reasonCodes: [reason],
      updatedAt: updatedAt,
    );
  }

  static NextLearningActionRecord _selectNextAction({
    required LearnerStateRecord state,
    required DateTime createdAt,
  }) {
    final (actionType, reason) = switch (state.retrievalObservation) {
      RetrievalObservation.unknown => (
        NextLearningActionType.repairThenRetry,
        'UNKNOWN_REQUIRES_EXPLANATION_BEFORE_RETRY',
      ),
      RetrievalObservation.needsRepair => (
        NextLearningActionType.repairThenRetry,
        'RECALL_GAP_REQUIRES_REPAIR',
      ),
      RetrievalObservation.supported => (
        NextLearningActionType.retryRecall,
        'SUPPORTED_SUCCESS_NEEDS_UNASSISTED_RETRIEVAL',
      ),
      RetrievalObservation.independent => (
        NextLearningActionType.repeatLater,
        'INDEPENDENT_RECALL_OBSERVED_REPEAT_LATER',
      ),
    };
    return NextLearningActionRecord(
      materialId: state.materialId,
      sourceVersionId: state.sourceVersionId,
      actionType: actionType,
      policyVersion: nextActionPolicyVersion,
      reasonCodes: [reason, ...state.reasonCodes],
      stateEvidenceFingerprint: state.evidenceFingerprint,
      createdAt: createdAt,
    );
  }

  static RecallFeedback _feedback({
    required RecallPromptRecord prompt,
    required RecallOutcome outcome,
  }) {
    final message = switch (outcome) {
      RecallOutcome.independentCorrect =>
        'Doğru. Bu yanıtı yardım almadan hatırladın.',
      RecallOutcome.supportedCorrect =>
        'Doğru; ancak ipucu kullandığın için bunu bağımsız hatırlama olarak saymıyoruz.',
      RecallOutcome.answerExposed =>
        'Yanıtı gördün. Şimdi kaynağı kapatıp daha sonra yeniden hatırlamayı deneyeceğiz.',
      RecallOutcome.partial =>
        'Kısmen yaklaştın. Kaynaktaki ifadeyi karşılaştırıp yeniden dene.',
      RecallOutcome.wrong =>
        'Bu kez eşleşmedi. Kaynaktaki ifadeyi inceleyip yeniden deneyebilirsin.',
      RecallOutcome.unknown =>
        'Bilmiyor olman sorun değil. Kaynaktaki ifadeyi görüp sonra tekrar deneyebilirsin.',
    };
    return RecallFeedback(
      outcome: outcome,
      message: message,
      sourceExcerpt: prompt.sourceExcerpt,
    );
  }

  static _SentenceSelection _selectSentence(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      throw const RecallPreparationException('Extracted source text is empty.');
    }

    var start = 0;
    while (start < normalized.length) {
      var end = start;
      while (end < normalized.length &&
          normalized[end] != '.' &&
          normalized[end] != '!' &&
          normalized[end] != '?' &&
          normalized[end] != '\n') {
        end++;
      }
      if (end < normalized.length &&
          (normalized[end] == '.' ||
              normalized[end] == '!' ||
              normalized[end] == '?')) {
        end++;
      }
      final candidate = normalized.substring(start, end).trim();
      final leadingTrim = normalized.substring(start, end).indexOf(candidate);
      final candidateStart = start + (leadingTrim < 0 ? 0 : leadingTrim);
      if (candidate.length >= 30 && _tokenMatches(candidate).length >= 6) {
        return _SentenceSelection(
          text: candidate,
          startOffset: candidateStart,
          endOffset: candidateStart + candidate.length,
        );
      }
      start = end + 1;
    }

    if (normalized.length >= 30 && _tokenMatches(normalized).length >= 6) {
      final bounded = normalized.length <= 220
          ? normalized
          : normalized.substring(0, 220).trimRight();
      return _SentenceSelection(
        text: bounded,
        startOffset: 0,
        endOffset: bounded.length,
      );
    }

    throw const RecallPreparationException(
      'Source does not contain enough bounded text for a meaningful Recall.',
    );
  }

  static List<RegExpMatch> _tokenMatches(String value) =>
      RegExp(r'[\p{L}\p{N}]+', unicode: true).allMatches(value).toList();

  static String _normalizedTokens(String value) => _tokenMatches(
    value.toLowerCase(),
  ).map((match) => match.group(0)!).join(' ');

  static int? _pageForOffset(List<SourceAnchor> anchors, int offset) {
    for (final anchor in anchors) {
      if (offset >= anchor.startOffset && offset < anchor.endOffset) {
        return anchor.pageNumber;
      }
    }
    return null;
  }

  static void _validateAttemptKey(String value) {
    if (!RegExp(r'^[A-Za-z0-9_.:-]{8,128}$').hasMatch(value)) {
      throw const RecallPreparationException(
        'Attempt key must be a stable 8-128 character identifier.',
      );
    }
  }
}

class _SentenceSelection {
  const _SentenceSelection({
    required this.text,
    required this.startOffset,
    required this.endOffset,
  });

  final String text;
  final int startOffset;
  final int endOffset;
}
