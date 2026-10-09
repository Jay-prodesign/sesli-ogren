import '../domain/learning_contracts.dart';

/// Product-owned boundary for generated teaching interpretation.
///
/// Implementations must run generation server-side. No provider credential or
/// provider SDK type belongs in the Flutter client.
abstract interface class GroundedExplainGateway {
  Future<GroundedExplainResult> explain(GroundedExplainRequest request);
}

class GroundedExplainRequest {
  const GroundedExplainRequest({
    required this.materialId,
    required this.sourceVersionId,
    required this.sourceContentDigest,
    required this.groundingContentHash,
    required this.outputLocale,
  });

  final MaterialId materialId;
  final SourceVersionId sourceVersionId;

  /// Local source identity digest. This may represent raw PDF bytes and is
  /// intentionally distinct from the server grounding hash below.
  final String sourceContentDigest;

  /// SHA-256 of the exact normalized text sent to the server material boundary.
  final String groundingContentHash;
  final String outputLocale;
}

sealed class GroundedExplainResult {
  const GroundedExplainResult();
}

class GroundedExplainReady extends GroundedExplainResult {
  const GroundedExplainReady({
    required this.sourceVersionId,
    required this.sourceContentDigest,
    required this.explanation,
    required this.keyPoints,
    required this.language,
    required this.executionRef,
  });

  final SourceVersionId sourceVersionId;
  final String sourceContentDigest;
  final String explanation;
  final List<String> keyPoints;
  final String language;
  final String executionRef;

  bool matches(SourceVersionIdentity source) =>
      sourceVersionId == source.sourceVersionId && sourceContentDigest == source.contentDigest;
}

class GroundedExplainUnavailable extends GroundedExplainResult {
  const GroundedExplainUnavailable({required this.reason});

  final GroundedExplainUnavailableReason reason;
}

enum GroundedExplainUnavailableReason { providerNotConfigured, sourceUnavailable, staleSource, temporaryFailure }

/// Safe production default until a live server-side provider is authorized.
class UnavailableGroundedExplainGateway implements GroundedExplainGateway {
  const UnavailableGroundedExplainGateway();

  @override
  Future<GroundedExplainResult> explain(GroundedExplainRequest request) async =>
      const GroundedExplainUnavailable(reason: GroundedExplainUnavailableReason.providerNotConfigured);
}
