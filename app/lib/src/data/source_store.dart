import '../domain/authenticated_learner.dart';
import '../domain/learning_contracts.dart';

/// Persistence seam required by the admitted M5 source journey.
///
/// The store is learner-scoped by contract. Concrete local/test and backend
/// adapters are introduced only when LA-0019 needs them.
abstract interface class SourceStore {
  Future<SourceVersionIdentity?> currentSourceVersion({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  });

  Future<void> persistSourceVersion({
    required AuthenticatedLearner learner,
    required SourceVersionIdentity sourceVersion,
  });
}
