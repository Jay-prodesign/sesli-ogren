class MaterialId {
  const MaterialId(this.value);

  final String value;

  @override
  bool operator ==(Object other) => other is MaterialId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

class SourceVersionId {
  const SourceVersionId(this.value);

  final String value;

  @override
  bool operator ==(Object other) => other is SourceVersionId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

class ExtractedContentId {
  const ExtractedContentId(this.value);

  final String value;

  @override
  bool operator ==(Object other) => other is ExtractedContentId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

enum SourceTrustClass { userProvided, authoritativeReference, aiInterpretation }

enum SourceKnowledgeClass { learnerOwned, trustedPlatform }

enum SourceMediaType { pastedText, pdf }

enum MaterialLifecycleStatus { active, deleted }

enum MaterialProcessingState { none, ready, failed }

class SourceAnchor {
  const SourceAnchor({required this.startOffset, required this.endOffset, this.pageNumber});

  final int startOffset;
  final int endOffset;
  final int? pageNumber;

  Map<String, Object?> toJson() => {'startOffset': startOffset, 'endOffset': endOffset, 'pageNumber': pageNumber};

  factory SourceAnchor.fromJson(Map<String, Object?> json) => SourceAnchor(
    startOffset: json['startOffset']! as int,
    endOffset: json['endOffset']! as int,
    pageNumber: json['pageNumber'] as int?,
  );
}

class MaterialRecord {
  const MaterialRecord({
    required this.id,
    required this.title,
    required this.mediaType,
    required this.lifecycleStatus,
    required this.processingState,
    required this.createdAt,
    required this.updatedAt,
    this.currentSourceVersionId,
    this.deletedAt,
  });

  final MaterialId id;
  final String title;
  final SourceMediaType mediaType;
  final MaterialLifecycleStatus lifecycleStatus;
  final MaterialProcessingState processingState;
  final SourceVersionId? currentSourceVersionId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isActive => lifecycleStatus == MaterialLifecycleStatus.active && deletedAt == null;
}

class SourceVersionIdentity {
  const SourceVersionIdentity({
    required this.materialId,
    required this.sourceVersionId,
    required this.contentDigest,
    required this.trustClass,
    required this.knowledgeClass,
  });

  final MaterialId materialId;
  final SourceVersionId sourceVersionId;
  final String contentDigest;
  final SourceTrustClass trustClass;
  final SourceKnowledgeClass knowledgeClass;
}

class SourceVersionRecord {
  const SourceVersionRecord({
    required this.identity,
    required this.mediaType,
    required this.sourceName,
    required this.mimeType,
    required this.byteSize,
    required this.createdAt,
    this.inlineText,
    this.supersededBy,
    this.revokedAt,
  });

  final SourceVersionIdentity identity;
  final SourceMediaType mediaType;
  final String sourceName;
  final String mimeType;
  final int byteSize;
  final String? inlineText;
  final DateTime createdAt;
  final SourceVersionId? supersededBy;
  final DateTime? revokedAt;

  bool get isCurrent => supersededBy == null && revokedAt == null;
}

class ExtractedContentRecord {
  const ExtractedContentRecord({
    required this.id,
    required this.sourceVersionId,
    required this.normalizedText,
    required this.method,
    required this.methodVersion,
    required this.anchors,
    required this.warnings,
    required this.sourceContentDigest,
    required this.createdAt,
    this.invalidatedAt,
  });

  final ExtractedContentId id;
  final SourceVersionId sourceVersionId;
  final String normalizedText;
  final String method;
  final String methodVersion;
  final List<SourceAnchor> anchors;
  final List<String> warnings;
  final String sourceContentDigest;
  final DateTime createdAt;
  final DateTime? invalidatedAt;

  bool get isValid => invalidatedAt == null;
}

class SourceIngestResult {
  const SourceIngestResult({required this.material, required this.sourceVersion, required this.extractedContent});

  final MaterialRecord material;
  final SourceVersionRecord sourceVersion;
  final ExtractedContentRecord extractedContent;
}
