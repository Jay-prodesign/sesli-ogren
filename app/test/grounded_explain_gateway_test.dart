import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sesli_ogren/src/generation/grounded_explain_gateway.dart';

void main() {
  const source = SourceVersionIdentity(
    materialId: MaterialId('material-1'),
    sourceVersionId: SourceVersionId('source-v2'),
    contentDigest: 'digest-v2',
    trustClass: SourceTrustClass.userProvided,
    knowledgeClass: SourceKnowledgeClass.learnerOwned,
  );

  test('generated explanation is accepted only for the exact source version and digest', () {
    const result = GroundedExplainReady(
      sourceVersionId: SourceVersionId('source-v2'),
      sourceContentDigest: 'digest-v2',
      explanation: 'Kaynağa bağlı açıklama',
      keyPoints: ['Birinci nokta'],
      language: 'tr-TR',
      executionRef: 'test:1',
    );

    expect(result.matches(source), isTrue);
    expect(
      GroundedExplainReady(
        sourceVersionId: const SourceVersionId('source-v1'),
        sourceContentDigest: 'digest-v1',
        explanation: result.explanation,
        keyPoints: result.keyPoints,
        language: result.language,
        executionRef: 'test:stale',
      ).matches(source),
      isFalse,
    );
  });

  test('production default fails closed when no server provider is configured', () async {
    const gateway = UnavailableGroundedExplainGateway();
    final result = await gateway.explain(
      const GroundedExplainRequest(
        materialId: MaterialId('material-1'),
        sourceVersionId: SourceVersionId('source-v2'),
        sourceContentDigest: 'digest-v2',
        groundingContentHash: 'grounding-v2',
        outputLocale: 'tr-TR',
      ),
    );

    expect(result, isA<GroundedExplainUnavailable>());
    expect((result as GroundedExplainUnavailable).reason, GroundedExplainUnavailableReason.providerNotConfigured);
  });
}
