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
  static const evidenceRuleVersion = 'recall-evidence-v1';
  static const stateRuleVersion = 'recall-state-v1';

  final SourceStore _sourceStore;
  final LearningTruthStore _learningStore;
  final DateTime Function() _now;

  Future<RecallAction> createCurrentAction({
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
    return _learningStore.persistRecallAction(
      learner: learner,
      action: action,
    );
  }

  Future<RecallAttemptResult> submit({
    required AuthenticatedLearner learner,
    required RecallActionId actionId,
    required RecallAttemptId attemptId,
    required RecallResponseDisposition disposition,
    String answer = '',
    bool hintUsed = false,
  }) async {
    if (attemptId.value.trim().isEmpty) {
      throw const RecallLearningException('Attempt ID cannot be empty.');
    }

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

    final normalizedAnswer = disposition == RecallResponseDisposition.unknown
        ? ''
        : _normalizeAnswer(answer);
    final outcome = _evaluate(
      expected: action.expectedAnswer,
      normalizedAnswer: normalizedAnswer,
      disposition: disposition,
      hintUsed: hintUsed,
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
    final evidence = LearnerEvidence(
      id: LearnerEvidenceId('ev_${evidenceIdDigest.substring(0, 32)}'),
      attemptId: attemptId,
      actionId: action.id,
      materialId: action.materialId,
      sourceVersionId: action.sourceVersionId,
      extractedContentId: action.extractedContentId,
      outcome: outcome,
      helpUsed: hintUsed,
      responseDigest: responseDigest,
      responseLength: normalizedAnswer.length,
      ruleVersion: evidenceRuleVersion,
      createdAt: _now().toUtc(),
    );

    final stateKind = _stateForOutcome(outcome);
    final persisted = await _learningStore.persistEvidenceAndState(
      learner: learner,
      evidence: evidence,
      stateKind: stateKind,
      stateRuleVersion: stateRuleVersion,
    );
    return RecallAttemptResult(
      evidence: persisted.evidence,
      state: persisted.state,
      nextAction: _nextActionFor(persisted.state.kind),
    );
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
        return word.length >= 5 &&
            !_stopWords.contains(_normalizeAnswer(word));
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
    required bool hintUsed,
  }) {
    if (disposition == RecallResponseDisposition.unknown ||
        normalizedAnswer.isEmpty) {
      return RecallOutcome.unknown;
    }
    final normalizedExpected = _normalizeAnswer(expected);
    if (normalizedAnswer == normalizedExpected) {
      return hintUsed ? RecallOutcome.helpedCorrect : RecallOutcome.correct;
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
      RecallOutcome.incorrect || RecallOutcome.unknown =>
        RecallStateKind.needsReview,
    };
  }

  static NextLearningAction _nextActionFor(RecallStateKind state) {
    return switch (state) {
      RecallStateKind.retrievedOnce => const NextLearningAction(
        kind: NextLearningActionKind.continueToNextRecall,
        reasonCode: 'UNASSISTED_RETRIEVAL_CORRECT',
        reasonText:
            'Bu kavramı bir kez ipucusuz geri çağırdın. Bu ustalık kanıtı değil; sıradaki kısa hatırlamaya geç.',
      ),
      RecallStateKind.developing => const NextLearningAction(
        kind: NextLearningActionKind.retryRecallWithoutHint,
        reasonCode: 'PARTIAL_OR_HELPED_RETRIEVAL',
        reasonText:
            'Yanıt kısmen doğru ya da ipucuyla geldi. Aynı kavramı kısa süre sonra ipucusuz yeniden dene.',
      ),
      RecallStateKind.needsReview => const NextLearningAction(
        kind: NextLearningActionKind.reviewSourceThenRecall,
        reasonCode: 'RETRIEVAL_NOT_ESTABLISHED',
        reasonText:
            'Bu denemede güvenilir geri çağırma oluşmadı. Kaynak bölümünü gözden geçirip yeniden dene.',
      ),
      RecallStateKind.notAssessed => const NextLearningAction(
        kind: NextLearningActionKind.reviewSourceThenRecall,
        reasonCode: 'NO_ACTIVE_EVIDENCE',
        reasonText:
            'Henüz aktif öğrenme kanıtı yok. Önce kısa bir geri çağırma denemesi yap.',
      ),
    };
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
