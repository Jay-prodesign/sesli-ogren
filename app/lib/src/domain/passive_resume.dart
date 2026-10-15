import 'learning_contracts.dart';

enum PassiveResumeSurface { reader, listen }

class PassiveResumeLocalState {
  const PassiveResumeLocalState({
    required this.materialId,
    required this.sourceVersionId,
    required this.surface,
    required this.readerProgress,
    required this.listenChunkIndex,
    required this.updatedAt,
    required this.serverRevision,
    required this.syncedLocalUpdatedAt,
  });

  final MaterialId materialId;
  final SourceVersionId sourceVersionId;
  final PassiveResumeSurface surface;
  final double? readerProgress;
  final int? listenChunkIndex;
  final DateTime updatedAt;
  final int? serverRevision;
  final DateTime? syncedLocalUpdatedAt;

  bool get hasLocalChangeSinceSync =>
      serverRevision == null || syncedLocalUpdatedAt == null || syncedLocalUpdatedAt!.toUtc() != updatedAt.toUtc();
}

class PassiveResumeRemoteState {
  const PassiveResumeRemoteState({
    required this.materialId,
    required this.sourceVersionId,
    required this.surface,
    required this.readerProgress,
    required this.listenChunkIndex,
    required this.revision,
    required this.updatedAt,
  });

  final MaterialId materialId;
  final SourceVersionId sourceVersionId;
  final PassiveResumeSurface surface;
  final double? readerProgress;
  final int? listenChunkIndex;
  final int revision;
  final DateTime updatedAt;
}
