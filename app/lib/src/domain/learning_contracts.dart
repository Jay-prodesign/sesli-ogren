/// Stable identifiers that keep learning truth tied to one authoritative source.
extension type const MaterialId(String value) {}

extension type const SourceVersionId(String value) {}

enum SourceTrustClass { userProvided, authoritativeReference, aiInterpretation }

enum SourceMediaType { pastedText, pdf }

class SourceAnchor {
  const SourceAnchor({
    required this.startOffset,
    required this.endOffset,
    this.pageNumber,
  });

  final int startOffset;
  final int endOffset;
  final int? pageNumber;

  Map<String, Object?> toJson() => {
    'startOffset': startOffset,
    'endOffset': endOffset,
    'pageNumber': pageNumber,
  };

  factory SourceAnchor.fromJson(Map<String, Object?> json) => SourceAnchor(
    startOffset: json['startOffset']! as int,
    endOffset: json['endOffset']! as int,
    pageNumber: json['pageNumber'] as int?,
  );
}

/// A source version identity is immutable once admitted into the learning loop.
class SourceVersionIdentity {
  const SourceVersionIdentity({
    required this.materialId,
    required this.sourceVersionId,
    required this.contentDigest,
    required this.trustClass,
  });

  final MaterialId materialId;
  final SourceVersionId sourceVersionId;
  final String contentDigest;
  final SourceTrustClass trustClass;
}

class SourceVersionRecord {
  const SourceVersionRecord({
    required this.identity,
    required this.mediaType,
    required this.sourceName,
    required this.extractedText,
    required this.anchors,
    required this.createdAt,
    this.supersededBy,
    this.deletedAt,
  });

  final SourceVersionIdentity identity;
  final SourceMediaType mediaType;
  final String sourceName;
  final String extractedText;
  final List<SourceAnchor> anchors;
  final DateTime createdAt;
  final SourceVersionId? supersededBy;
  final DateTime? deletedAt;

  bool get isCurrent => supersededBy == null && deletedAt == null;
}
