/// Stable identifiers that keep learning truth tied to one authoritative source.
///
/// These types are deliberately small. Rich ingest/evidence behavior is added by
/// the admitted M5 tasks only when the concrete vertical slice needs it.
extension type const MaterialId(String value) {}
extension type const SourceVersionId(String value) {}

enum SourceTrustClass {
  userProvided,
  authoritativeReference,
  aiInterpretation,
}

/// A source version is immutable once admitted into the learning loop.
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
