import '../domain/authenticated_learner.dart';
import '../domain/learning_contracts.dart';
import '../domain/passive_resume.dart';

enum PassiveResumeFailureKind { authenticationRequired, unavailable, conflict, staleSource, invalidPayload }

class PassiveResumeException implements Exception {
  const PassiveResumeException(this.message, {required this.kind});

  final String message;
  final PassiveResumeFailureKind kind;

  @override
  String toString() => 'PassiveResumeException: $message';
}

abstract interface class PassiveResumeGateway {
  Future<List<PassiveResumeRemoteState>> read({required AuthenticatedLearner learner, required MaterialId materialId});

  Future<PassiveResumeRemoteState> write({
    required AuthenticatedLearner learner,
    required PassiveResumeLocalState local,
    required int? expectedRevision,
    required String clientUpdateId,
  });
}

class UnavailablePassiveResumeGateway implements PassiveResumeGateway {
  const UnavailablePassiveResumeGateway();

  Never _unavailable() => throw const PassiveResumeException(
    'Passive resume continuity is unavailable for this runtime.',
    kind: PassiveResumeFailureKind.unavailable,
  );

  @override
  Future<List<PassiveResumeRemoteState>> read({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  }) async => _unavailable();

  @override
  Future<PassiveResumeRemoteState> write({
    required AuthenticatedLearner learner,
    required PassiveResumeLocalState local,
    required int? expectedRevision,
    required String clientUpdateId,
  }) async => _unavailable();
}
