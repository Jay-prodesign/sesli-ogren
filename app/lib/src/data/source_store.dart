import '../domain/authenticated_learner.dart';
import '../domain/learning_contracts.dart';

abstract interface class SourceStore {
  Future<SourceVersionRecord?> currentSourceVersion({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  });

  Future<SourceVersionRecord?> sourceVersion({
    required AuthenticatedLearner learner,
    required SourceVersionId sourceVersionId,
  });

  Future<List<SourceVersionRecord>> sourceVersions({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  });

  /// Persists one immutable source version.
  ///
  /// Repeating the same learner/material/version is idempotent. A different
  /// version for the same material supersedes the previous current version.
  Future<SourceVersionRecord> persistSourceVersion({
    required AuthenticatedLearner learner,
    required SourceVersionRecord sourceVersion,
  });

  Future<void> deleteMaterial({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    required DateTime deletedAt,
  });

  Future<void> close();
}
