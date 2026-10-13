import 'learning_contracts.dart';

class ReaderAnnotationId {
  const ReaderAnnotationId(this.value);

  final String value;

  @override
  bool operator ==(Object other) => other is ReaderAnnotationId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

enum ReaderAnnotationKind { highlight, note }

class ReaderAnnotationRecord {
  const ReaderAnnotationRecord({
    required this.id,
    required this.materialId,
    required this.sourceVersionId,
    required this.sourceAnchor,
    required this.selectedText,
    required this.selectedTextDigest,
    required this.kind,
    required this.noteText,
    required this.createdAt,
    required this.updatedAt,
    this.invalidatedAt,
  });

  final ReaderAnnotationId id;
  final MaterialId materialId;
  final SourceVersionId sourceVersionId;
  final SourceAnchor sourceAnchor;
  final String selectedText;
  final String selectedTextDigest;
  final ReaderAnnotationKind kind;
  final String? noteText;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? invalidatedAt;

  bool get isStale => invalidatedAt != null;
}
