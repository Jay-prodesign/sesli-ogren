import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/data/learning_truth_store.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/domain/authenticated_learner.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sesli_ogren/src/domain/learning_truth.dart';
import 'package:sesli_ogren/src/learning/recall_learning_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _UnusedPdfExtractor implements PdfTextExtractor {
  const _UnusedPdfExtractor();

  @override
  Future<ExtractedPdf> extract(Uint8List bytes, {required String sourceName}) {
    throw UnimplementedError();
  }
}

void main() {
  sqfliteFfiInit();

  const learnerA = AuthenticatedLearner(id: LearnerId('learner-a'));
  const learnerB = AuthenticatedLearner(id: LearnerId('learner-b'));
  const materialId = MaterialId('material-recall');

  late SqliteSourceStore sourceStore;
  late SourceIngestService ingest;
  late RecallLearningService recall;

  setUp(() async {
    sourceStore = await SqliteSourceStore.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    ingest = SourceIngestService(
      store: sourceStore,
      pdfTextExtractor: const _UnusedPdfExtractor(),
      now: () => DateTime.utc(2026, 10, 4, 12),
    );
    recall = RecallLearningService(
      sourceStore: sourceStore,
      learningStore: sourceStore.learningTruthStore(),
      now: () => DateTime.utc(2026, 10, 4, 12, 5),
    );
    await ingest.ingestPastedText(
      learner: learnerA,
      materialId: materialId,
      text:
          'Fotosentez sırasında klorofil ışık enerjisini kimyasal enerjiye '
          'dönüştürmeye yardımcı olur. Bitkiler bu süreçte karbondioksit kullanır.',
      sourceName: 'Biyoloji notu',
    );
  });

  tearDown(() => sourceStore.close());

  Future<RecallAction> storedAction(RecallPrompt prompt) async {
    final action = await sourceStore.learningTruthStore().recallAction(
      learner: learnerA,
      actionId: prompt.id,
    );
    expect(action, isNotNull);
    return action!;
  }

  test(
    'creating Recall prompt exposes no answer and creates no learning truth',
    () async {
      final prompt = await recall.createCurrentPrompt(
        learner: learnerA,
        materialId: materialId,
      );

      expect(prompt.promptText, contains('_____'));
      expect(prompt.anchor.startOffset, greaterThanOrEqualTo(0));

      final learningStore = sourceStore.learningTruthStore();
      final source = await sourceStore.currentSourceVersion(
        learner: learnerA,
        materialId: materialId,
      );
      expect(
        await learningStore.evidenceForMaterial(
          learner: learnerA,
          materialId: materialId,
          sourceVersionId: source!.identity.sourceVersionId,
        ),
        isEmpty,
      );
      expect(
        await learningStore.learnerState(
          learner: learnerA,
          materialId: materialId,
        ),
        isNull,
      );
      expect(
        await learningStore.nextLearningAction(
          learner: learnerA,
          materialId: materialId,
        ),
        isNull,
      );
    },
  );

  test(
    'unassisted correct Recall records one observation, never mastery',
    () async {
      final prompt = await recall.createCurrentPrompt(
        learner: learnerA,
        materialId: materialId,
      );
      final action = await storedAction(prompt);
      final result = await recall.submit(
        learner: learnerA,
        actionId: prompt.id,
        attemptId: const RecallAttemptId('attempt-correct'),
        disposition: RecallResponseDisposition.answer,
        answer: action.expectedAnswer,
      );

      expect(result.evidence.outcome, RecallOutcome.correct);
      expect(result.evidence.assistance, RecallAssistance.none);
      expect(result.state.kind, RecallStateKind.retrievedOnce);
      expect(result.state.evidenceCount, 1);
      expect(result.nextAction.kind, NextLearningActionKind.repeatRecallLater);
      expect(result.nextAction.reasonCode, 'ONE_UNASSISTED_RETRIEVAL_OBSERVED');
      expect(
        result.nextAction.policyVersion,
        RecallLearningService.nextActionPolicyVersion,
      );
    },
  );

  test('hinted correct Recall remains developing', () async {
    final prompt = await recall.createCurrentPrompt(
      learner: learnerA,
      materialId: materialId,
    );
    final action = await storedAction(prompt);
    const attemptId = RecallAttemptId('attempt-helped');
    final support = await recall.requestHint(
      learner: learnerA,
      actionId: prompt.id,
      attemptId: attemptId,
    );
    expect(support.assistance, RecallAssistance.hint);

    final result = await recall.submit(
      learner: learnerA,
      actionId: prompt.id,
      attemptId: attemptId,
      disposition: RecallResponseDisposition.answer,
      answer: action.expectedAnswer,
    );

    expect(result.evidence.outcome, RecallOutcome.helpedCorrect);
    expect(result.evidence.assistance, RecallAssistance.hint);
    expect(result.state.kind, RecallStateKind.developing);
    expect(
      result.nextAction.kind,
      NextLearningActionKind.retryRecallWithoutHint,
    );
  });

  test('answer exposure never becomes retrieval success', () async {
    final prompt = await recall.createCurrentPrompt(
      learner: learnerA,
      materialId: materialId,
    );
    final action = await storedAction(prompt);
    const attemptId = RecallAttemptId('attempt-exposed');
    final support = await recall.revealAnswer(
      learner: learnerA,
      actionId: prompt.id,
      attemptId: attemptId,
    );
    expect(support.assistance, RecallAssistance.answerExposed);

    final result = await recall.submit(
      learner: learnerA,
      actionId: prompt.id,
      attemptId: attemptId,
      disposition: RecallResponseDisposition.answer,
      answer: action.expectedAnswer,
    );

    expect(result.evidence.outcome, RecallOutcome.answerExposed);
    expect(result.state.kind, RecallStateKind.notAssessed);
    expect(result.nextAction.reasonCode, 'ANSWER_EXPOSED_NO_RETRIEVAL_CLAIM');
  });

  test('store rejects evidence that lies about recorded assistance', () async {
    final prompt = await recall.createCurrentPrompt(
      learner: learnerA,
      materialId: materialId,
    );
    final action = await storedAction(prompt);
    const attemptId = RecallAttemptId('attempt-store-guard');

    await recall.requestHint(
      learner: learnerA,
      actionId: prompt.id,
      attemptId: attemptId,
    );

    final learningStore = sourceStore.learningTruthStore();
    const fabricatedEvidenceId = LearnerEvidenceId('ev_fabricated_store_guard');
    final fabricatedEvidence = LearnerEvidence(
      id: fabricatedEvidenceId,
      attemptId: attemptId,
      actionId: prompt.id,
      materialId: action.materialId,
      sourceVersionId: action.sourceVersionId,
      extractedContentId: action.extractedContentId,
      outcome: RecallOutcome.correct,
      assistance: RecallAssistance.none,
      responseDigest: 'fabricated',
      responseLength: 10,
      ruleVersion: RecallLearningService.evidenceRuleVersion,
      createdAt: DateTime.utc(2026, 10, 4, 12, 5),
    );
    final fabricatedNext = NextLearningAction(
      materialId: action.materialId,
      sourceVersionId: action.sourceVersionId,
      latestEvidenceId: fabricatedEvidenceId,
      kind: NextLearningActionKind.repeatRecallLater,
      reasonCode: 'FABRICATED',
      reasonText: 'must be rejected',
      policyVersion: RecallLearningService.nextActionPolicyVersion,
      createdAt: DateTime.utc(2026, 10, 4, 12, 5),
    );

    await expectLater(
      learningStore.persistEvidenceStateAndNextAction(
        learner: learnerA,
        evidence: fabricatedEvidence,
        disposition: RecallResponseDisposition.answer,
        normalizedResponse: 'fabricated',
        stateKind: RecallStateKind.retrievedOnce,
        stateRuleVersion: RecallLearningService.stateRuleVersion,
        nextAction: fabricatedNext,
      ),
      throwsA(isA<LearningTruthConflict>()),
    );
  });

  test(
    'answer exposure dominates an earlier hint for the same attempt',
    () async {
      final prompt = await recall.createCurrentPrompt(
        learner: learnerA,
        materialId: materialId,
      );
      const attemptId = RecallAttemptId('attempt-support-escalation');

      final hinted = await recall.requestHint(
        learner: learnerA,
        actionId: prompt.id,
        attemptId: attemptId,
      );
      final exposed = await recall.revealAnswer(
        learner: learnerA,
        actionId: prompt.id,
        attemptId: attemptId,
      );

      expect(hinted.assistance, RecallAssistance.hint);
      expect(exposed.assistance, RecallAssistance.answerExposed);
      expect(
        await sourceStore.learningTruthStore().assistanceForAttempt(
          learner: learnerA,
          attemptId: attemptId,
          actionId: prompt.id,
        ),
        RecallAssistance.answerExposed,
      );
    },
  );

  test(
    'store rejects fabricated positive state for incorrect evidence',
    () async {
      final prompt = await recall.createCurrentPrompt(
        learner: learnerA,
        materialId: materialId,
      );
      final action = await storedAction(prompt);
      const attemptId = RecallAttemptId('attempt-fake-state');
      const evidenceId = LearnerEvidenceId('ev_fake_positive_state');
      final normalizedWrongResponse =
          '${RecallTruthPolicy.normalizeAnswer(action.expectedAnswer)}zz';
      final evidence = LearnerEvidence(
        id: evidenceId,
        attemptId: attemptId,
        actionId: prompt.id,
        materialId: action.materialId,
        sourceVersionId: action.sourceVersionId,
        extractedContentId: action.extractedContentId,
        outcome: RecallOutcome.incorrect,
        assistance: RecallAssistance.none,
        responseDigest: sha256
            .convert(utf8.encode(normalizedWrongResponse))
            .toString(),
        responseLength: normalizedWrongResponse.length,
        ruleVersion: RecallLearningService.evidenceRuleVersion,
        createdAt: DateTime.utc(2026, 10, 4, 12, 6),
      );
      final fakeNext = NextLearningAction(
        materialId: action.materialId,
        sourceVersionId: action.sourceVersionId,
        latestEvidenceId: evidenceId,
        kind: NextLearningActionKind.repeatRecallLater,
        reasonCode: 'ONE_UNASSISTED_RETRIEVAL_OBSERVED',
        reasonText: 'fabricated positive continuation',
        policyVersion: RecallLearningService.nextActionPolicyVersion,
        createdAt: evidence.createdAt,
      );

      await expectLater(
        sourceStore.learningTruthStore().persistEvidenceStateAndNextAction(
          learner: learnerA,
          evidence: evidence,
          disposition: RecallResponseDisposition.answer,
          normalizedResponse: normalizedWrongResponse,
          stateKind: RecallStateKind.retrievedOnce,
          stateRuleVersion: RecallLearningService.stateRuleVersion,
          nextAction: fakeNext,
        ),
        throwsA(isA<LearningTruthConflict>()),
      );
    },
  );

  test('near answer is partial rather than silently correct', () async {
    final prompt = await recall.createCurrentPrompt(
      learner: learnerA,
      materialId: materialId,
    );
    final action = await storedAction(prompt);
    final answer = action.expectedAnswer;
    final nearAnswer = answer.substring(0, answer.length - 1);

    final result = await recall.submit(
      learner: learnerA,
      actionId: prompt.id,
      attemptId: const RecallAttemptId('attempt-partial'),
      disposition: RecallResponseDisposition.answer,
      answer: nearAnswer,
    );

    expect(result.evidence.outcome, RecallOutcome.partial);
    expect(result.state.kind, RecallStateKind.developing);
  });

  test(
    'unknown remains unassessed while incorrect becomes needs-review',
    () async {
      final prompt = await recall.createCurrentPrompt(
        learner: learnerA,
        materialId: materialId,
      );

      final unknown = await recall.submit(
        learner: learnerA,
        actionId: prompt.id,
        attemptId: const RecallAttemptId('attempt-unknown'),
        disposition: RecallResponseDisposition.unknown,
      );
      expect(unknown.evidence.outcome, RecallOutcome.unknown);
      expect(unknown.state.kind, RecallStateKind.notAssessed);
      expect(unknown.nextAction.reasonCode, 'NO_EVALUABLE_RETRIEVAL');

      final incorrect = await recall.submit(
        learner: learnerA,
        actionId: prompt.id,
        attemptId: const RecallAttemptId('attempt-incorrect'),
        disposition: RecallResponseDisposition.answer,
        answer: 'tamamenyanlis',
      );
      expect(incorrect.evidence.outcome, RecallOutcome.incorrect);
      expect(incorrect.state.kind, RecallStateKind.needsReview);
      expect(incorrect.state.evidenceCount, 2);
    },
  );

  test(
    'store rejects support that is not attached to the active attempt',
    () async {
      final prompt = await recall.createCurrentPrompt(
        learner: learnerA,
        materialId: materialId,
      );

      await expectLater(
        sourceStore.learningTruthStore().registerAssistance(
          learner: learnerA,
          attemptId: const RecallAttemptId('attempt-no-active'),
          actionId: prompt.id,
          assistance: RecallAssistance.hint,
          recordedAt: DateTime.utc(2026, 10, 4, 12, 5),
        ),
        throwsA(isA<LearningTruthConflict>()),
      );
    },
  );

  test(
    'completed Recall opens a distinct next attempt under a fixed clock',
    () async {
      final prompt = await recall.createCurrentPrompt(
        learner: learnerA,
        materialId: materialId,
      );
      final action = await storedAction(prompt);

      final firstSession = await recall.openAttempt(
        learner: learnerA,
        actionId: prompt.id,
      );
      final first = await recall.submit(
        learner: learnerA,
        actionId: prompt.id,
        attemptId: firstSession.attempt.attemptId,
        disposition: RecallResponseDisposition.answer,
        answer: action.expectedAnswer,
      );
      final secondSession = await recall.openAttempt(
        learner: learnerA,
        actionId: prompt.id,
      );

      expect(secondSession.attempt.attemptId, isNot(first.evidence.attemptId));
      expect(secondSession.assistance, RecallAssistance.none);
    },
  );

  test(
    'same attempt replay is idempotent including persisted next action',
    () async {
      final prompt = await recall.createCurrentPrompt(
        learner: learnerA,
        materialId: materialId,
      );
      final action = await storedAction(prompt);

      final first = await recall.submit(
        learner: learnerA,
        actionId: prompt.id,
        attemptId: const RecallAttemptId('attempt-replay'),
        disposition: RecallResponseDisposition.answer,
        answer: action.expectedAnswer,
      );
      final replay = await recall.submit(
        learner: learnerA,
        actionId: prompt.id,
        attemptId: const RecallAttemptId('attempt-replay'),
        disposition: RecallResponseDisposition.answer,
        answer: action.expectedAnswer,
      );

      expect(replay.evidence.id, first.evidence.id);
      expect(replay.state.evidenceCount, 1);
      expect(replay.nextAction.reasonCode, first.nextAction.reasonCode);
      expect(replay.nextAction.policyVersion, first.nextAction.policyVersion);
    },
  );

  test('conflicting replay of same attempt ID fails closed', () async {
    final prompt = await recall.createCurrentPrompt(
      learner: learnerA,
      materialId: materialId,
    );
    final action = await storedAction(prompt);

    await recall.submit(
      learner: learnerA,
      actionId: prompt.id,
      attemptId: const RecallAttemptId('attempt-conflict'),
      disposition: RecallResponseDisposition.answer,
      answer: action.expectedAnswer,
    );

    await expectLater(
      recall.submit(
        learner: learnerA,
        actionId: prompt.id,
        attemptId: const RecallAttemptId('attempt-conflict'),
        disposition: RecallResponseDisposition.answer,
        answer: 'farkliyanit',
      ),
      throwsA(isA<LearningTruthConflict>()),
    );
  });

  test('another learner cannot read or submit the action', () async {
    final prompt = await recall.createCurrentPrompt(
      learner: learnerA,
      materialId: materialId,
    );
    final learningStore = sourceStore.learningTruthStore();

    expect(
      await learningStore.recallAction(learner: learnerB, actionId: prompt.id),
      isNull,
    );
    await expectLater(
      recall.submit(
        learner: learnerB,
        actionId: prompt.id,
        attemptId: const RecallAttemptId('attempt-other-user'),
        disposition: RecallResponseDisposition.answer,
        answer: 'guessed',
      ),
      throwsA(isA<RecallLearningException>()),
    );
  });

  test(
    'repeating one easy prompt cannot escalate state beyond one observation',
    () async {
      final prompt = await recall.createCurrentPrompt(
        learner: learnerA,
        materialId: materialId,
      );
      final action = await storedAction(prompt);

      final first = await recall.submit(
        learner: learnerA,
        actionId: prompt.id,
        attemptId: const RecallAttemptId('attempt-farm-1'),
        disposition: RecallResponseDisposition.answer,
        answer: action.expectedAnswer,
      );
      final second = await recall.submit(
        learner: learnerA,
        actionId: prompt.id,
        attemptId: const RecallAttemptId('attempt-farm-2'),
        disposition: RecallResponseDisposition.answer,
        answer: action.expectedAnswer,
      );

      expect(first.state.kind, RecallStateKind.retrievedOnce);
      expect(second.state.kind, RecallStateKind.retrievedOnce);
      expect(second.state.evidenceCount, 2);
      expect(second.nextAction.kind, NextLearningActionKind.repeatRecallLater);
    },
  );

  test('source supersession clears current state and next action', () async {
    final prompt = await recall.createCurrentPrompt(
      learner: learnerA,
      materialId: materialId,
    );
    final action = await storedAction(prompt);
    await recall.submit(
      learner: learnerA,
      actionId: prompt.id,
      attemptId: const RecallAttemptId('attempt-before-source-change'),
      disposition: RecallResponseDisposition.answer,
      answer: action.expectedAnswer,
    );

    await ingest.ingestPastedText(
      learner: learnerA,
      materialId: materialId,
      text:
          'Yeni kaynak sürümü farklı bir kavram seti içerir ve önceki '
          'öğrenme durumunu güncel kaynak için geçersiz kılar.',
      sourceName: 'Biyoloji notu',
    );

    final learningStore = sourceStore.learningTruthStore();
    expect(
      await learningStore.learnerState(
        learner: learnerA,
        materialId: materialId,
      ),
      isNull,
    );
    expect(
      await learningStore.nextLearningAction(
        learner: learnerA,
        materialId: materialId,
      ),
      isNull,
    );
    await expectLater(
      recall.submit(
        learner: learnerA,
        actionId: prompt.id,
        attemptId: const RecallAttemptId('attempt-stale-action'),
        disposition: RecallResponseDisposition.answer,
        answer: action.expectedAnswer,
      ),
      throwsA(isA<RecallLearningException>()),
    );
  });

  test(
    'material deletion removes active Recall truth and continuation',
    () async {
      final prompt = await recall.createCurrentPrompt(
        learner: learnerA,
        materialId: materialId,
      );
      final action = await storedAction(prompt);
      final result = await recall.submit(
        learner: learnerA,
        actionId: prompt.id,
        attemptId: const RecallAttemptId('attempt-delete'),
        disposition: RecallResponseDisposition.answer,
        answer: action.expectedAnswer,
      );

      await sourceStore.deleteMaterial(
        learner: learnerA,
        materialId: materialId,
        deletedAt: DateTime.utc(2026, 10, 4, 13),
      );

      final learningStore = sourceStore.learningTruthStore();
      expect(
        await learningStore.recallAction(
          learner: learnerA,
          actionId: prompt.id,
        ),
        isNull,
      );
      expect(
        await learningStore.evidenceForAttempt(
          learner: learnerA,
          attemptId: result.evidence.attemptId,
        ),
        isNull,
      );
      expect(
        await learningStore.learnerState(
          learner: learnerA,
          materialId: materialId,
        ),
        isNull,
      );
      expect(
        await learningStore.nextLearningAction(
          learner: learnerA,
          materialId: materialId,
        ),
        isNull,
      );
    },
  );

  test(
    'continuation repair rebuilds projections without adding evidence',
    () async {
      final prompt = await recall.createCurrentPrompt(
        learner: learnerA,
        materialId: materialId,
      );
      final action = await storedAction(prompt);
      final result = await recall.submit(
        learner: learnerA,
        actionId: prompt.id,
        attemptId: const RecallAttemptId('attempt-repair'),
        disposition: RecallResponseDisposition.answer,
        answer: action.expectedAnswer,
      );

      final source = await sourceStore.currentSourceVersion(
        learner: learnerA,
        materialId: materialId,
      );
      final before = await sourceStore.learningTruthStore().evidenceForMaterial(
        learner: learnerA,
        materialId: materialId,
        sourceVersionId: source!.identity.sourceVersionId,
      );

      final repaired = await recall.repairContinuation(
        learner: learnerA,
        materialId: materialId,
      );
      final after = await sourceStore.learningTruthStore().evidenceForMaterial(
        learner: learnerA,
        materialId: materialId,
        sourceVersionId: source.identity.sourceVersionId,
      );

      expect(repaired, isNotNull);
      expect(repaired!.state.latestEvidenceId, result.evidence.id);
      expect(repaired.state.evidenceCount, before.length);
      expect(repaired.nextAction.reasonCode, result.nextAction.reasonCode);
      expect(
        repaired.nextAction.policyVersion,
        result.nextAction.policyVersion,
      );
      expect(after.map((item) => item.id), before.map((item) => item.id));
    },
  );

  test(
    'evidence state and next action survive database close and reopen',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'sesli-ogren-learning-',
      );
      final databasePath = '${temp.path}/learning.db';
      SqliteSourceStore? persistentStore;

      try {
        persistentStore = await SqliteSourceStore.open(
          factory: databaseFactoryFfi,
          path: databasePath,
        );
        final persistentIngest = SourceIngestService(
          store: persistentStore,
          pdfTextExtractor: const _UnusedPdfExtractor(),
          now: () => DateTime.utc(2026, 10, 4, 14),
        );
        var persistentRecall = RecallLearningService(
          sourceStore: persistentStore,
          learningStore: persistentStore.learningTruthStore(),
          now: () => DateTime.utc(2026, 10, 4, 14, 5),
        );
        await persistentIngest.ingestPastedText(
          learner: learnerA,
          materialId: materialId,
          text:
              'Mitokondri hücresel solunum sırasında kullanılabilir enerji '
              'üretimine katkı sağlar.',
        );
        final prompt = await persistentRecall.createCurrentPrompt(
          learner: learnerA,
          materialId: materialId,
        );
        final internalAction = await persistentStore
            .learningTruthStore()
            .recallAction(learner: learnerA, actionId: prompt.id);
        final result = await persistentRecall.submit(
          learner: learnerA,
          actionId: prompt.id,
          attemptId: const RecallAttemptId('attempt-persist'),
          disposition: RecallResponseDisposition.answer,
          answer: internalAction!.expectedAnswer,
        );
        await persistentStore.close();
        persistentStore = null;

        persistentStore = await SqliteSourceStore.open(
          factory: databaseFactoryFfi,
          path: databasePath,
        );
        persistentRecall = RecallLearningService(
          sourceStore: persistentStore,
          learningStore: persistentStore.learningTruthStore(),
          now: () => DateTime.utc(2026, 10, 4, 14, 10),
        );
        final continuation = await persistentRecall.reopen(
          learner: learnerA,
          materialId: materialId,
        );

        expect(continuation, isNotNull);
        expect(continuation!.state.kind, RecallStateKind.retrievedOnce);
        expect(continuation.state.evidenceCount, 1);
        expect(
          continuation.nextAction.reasonCode,
          result.nextAction.reasonCode,
        );
        expect(
          continuation.nextAction.policyVersion,
          result.nextAction.policyVersion,
        );
        expect(continuation.nextAction.latestEvidenceId, result.evidence.id);
      } finally {
        await persistentStore?.close();
        await temp.delete(recursive: true);
      }
    },
  );
}
