import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sesli_ogren/src/learning/explain_back_gateway.dart';

void main() {
  const source = SourceVersionIdentity(
    materialId: MaterialId('material-1'),
    sourceVersionId: SourceVersionId('source-v2'),
    contentDigest: 'digest-v2',
    trustClass: SourceTrustClass.userProvided,
    knowledgeClass: SourceKnowledgeClass.learnerOwned,
  );

  test('evaluated Explain-back is accepted only for exact source version and digest', () {
    const result = ExplainBackEvaluated(
      attemptId: ExplainBackAttemptId('explain-attempt-1'),
      sourceVersionId: SourceVersionId('source-v2'),
      sourceContentDigest: 'digest-v2',
      kind: ExplainBackEvaluationKind.gapDetected,
      feedback: 'Temel fikir var.',
      targetedRepair: 'Enerji dönüşümünü netleştir.',
      executionRef: 'test:evaluator',
    );

    expect(result.matches(source), isTrue);
    expect(
      const ExplainBackEvaluated(
        attemptId: ExplainBackAttemptId('explain-attempt-1'),
        sourceVersionId: SourceVersionId('source-v1'),
        sourceContentDigest: 'digest-v1',
        kind: ExplainBackEvaluationKind.sufficient,
        feedback: 'stale',
        targetedRepair: '',
        executionRef: 'test:stale',
      ).matches(source),
      isFalse,
    );
  });

  test('production default does not infer semantic learning on device', () async {
    const gateway = UnavailableExplainBackGateway();
    final result = await gateway.evaluate(
      const ExplainBackRequest(
        attemptId: ExplainBackAttemptId('explain-attempt-2'),
        materialId: MaterialId('material-1'),
        sourceVersionId: SourceVersionId('source-v2'),
        sourceContentDigest: 'digest-v2',
        groundingContentHash: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        response: 'Kendi cümlelerimle açıklamam.',
        outputLocale: 'tr-TR',
      ),
    );

    expect(result, isA<ExplainBackUnavailable>());
  });
}
