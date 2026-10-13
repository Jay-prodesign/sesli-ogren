import '../domain/authenticated_learner.dart';
import '../domain/learning_contracts.dart';

enum CloudContinuityFailureKind {
  authenticationRequired,
  unavailable,
  conflict,
  staleSource,
  unsupportedSource,
  invalidPayload,
}

class CloudContinuityException implements Exception {
  const CloudContinuityException(this.message, {required this.kind});

  final String message;
  final CloudContinuityFailureKind kind;

  @override
  String toString() => 'CloudContinuityException: $message';
}

class CloudMaterialSnapshot {
  const CloudMaterialSnapshot({
    required this.serverMaterialId,
    required this.materialId,
    required this.title,
    required this.serverSourceAssetId,
    required this.sourceVersionId,
    required this.serverSourceVersion,
    required this.sourceContentHash,
    required this.mediaType,
    required this.mimeType,
    required this.byteSize,
    required this.inlineText,
    required this.serverExtractedContentId,
    required this.normalizedText,
    required this.anchors,
    required this.materialUpdatedAt,
    required this.sourceCreatedAt,
  });

  final String serverMaterialId;
  final MaterialId materialId;
  final String title;
  final String serverSourceAssetId;
  final SourceVersionId sourceVersionId;
  final int serverSourceVersion;
  final String sourceContentHash;
  final SourceMediaType mediaType;
  final String mimeType;
  final int byteSize;
  final String? inlineText;
  final String serverExtractedContentId;
  final String normalizedText;
  final List<SourceAnchor> anchors;
  final DateTime materialUpdatedAt;
  final DateTime sourceCreatedAt;
}

abstract interface class CloudContinuityGateway {
  Future<List<CloudMaterialSnapshot>> listMaterials({required AuthenticatedLearner learner});

  Future<CloudMaterialSnapshot?> readMaterial({required AuthenticatedLearner learner, required MaterialId materialId});

  Future<CloudMaterialSnapshot> ensureTextSource({
    required AuthenticatedLearner learner,
    required SourceIngestResult source,
    SourceVersionId? expectedPreviousSourceVersionId,
  });
}

class UnavailableCloudContinuityGateway implements CloudContinuityGateway {
  const UnavailableCloudContinuityGateway();

  Never _unavailable() => throw const CloudContinuityException(
    'Cloud continuity is unavailable for this runtime.',
    kind: CloudContinuityFailureKind.unavailable,
  );

  @override
  Future<CloudMaterialSnapshot> ensureTextSource({
    required AuthenticatedLearner learner,
    required SourceIngestResult source,
    SourceVersionId? expectedPreviousSourceVersionId,
  }) async => _unavailable();

  @override
  Future<List<CloudMaterialSnapshot>> listMaterials({required AuthenticatedLearner learner}) async => _unavailable();

  @override
  Future<CloudMaterialSnapshot?> readMaterial({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  }) async => _unavailable();
}
