import 'dart:typed_data';

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
    required this.sourceName,
    required this.mimeType,
    required this.byteSize,
    required this.storageBucket,
    required this.storagePath,
    required this.inlineText,
    required this.serverExtractedContentId,
    required this.normalizedText,
    required this.extractionMethod,
    required this.extractionMethodVersion,
    required this.anchors,
    required this.warnings,
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
  final String sourceName;
  final String mimeType;
  final int byteSize;
  final String? storageBucket;
  final String? storagePath;
  final String? inlineText;
  final String serverExtractedContentId;
  final String normalizedText;
  final String extractionMethod;
  final String extractionMethodVersion;
  final List<SourceAnchor> anchors;
  final List<String> warnings;
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

  Future<CloudMaterialSnapshot> ensureMediaSource({
    required AuthenticatedLearner learner,
    required SourceIngestResult source,
    required Uint8List rawSourceBytes,
    SourceVersionId? expectedPreviousSourceVersionId,
  });

  Future<Uint8List> downloadMediaSource({
    required AuthenticatedLearner learner,
    required CloudMaterialSnapshot source,
  });

  Future<void> cleanupSupersededMedia({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
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
  Future<CloudMaterialSnapshot> ensureMediaSource({
    required AuthenticatedLearner learner,
    required SourceIngestResult source,
    required Uint8List rawSourceBytes,
    SourceVersionId? expectedPreviousSourceVersionId,
  }) async => _unavailable();

  @override
  Future<Uint8List> downloadMediaSource({
    required AuthenticatedLearner learner,
    required CloudMaterialSnapshot source,
  }) async => _unavailable();

  @override
  Future<void> cleanupSupersededMedia({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  }) async => _unavailable();

  @override
  Future<List<CloudMaterialSnapshot>> listMaterials({required AuthenticatedLearner learner}) async => _unavailable();

  @override
  Future<CloudMaterialSnapshot?> readMaterial({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  }) async => _unavailable();
}
