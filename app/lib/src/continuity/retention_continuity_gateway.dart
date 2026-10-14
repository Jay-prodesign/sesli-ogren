import '../domain/authenticated_learner.dart';
import '../domain/learning_contracts.dart';
import '../domain/retention_schedule.dart';

class CloudRetentionSnapshot {
  const CloudRetentionSnapshot({required this.schedule, required this.revision});

  final RetentionScheduleRecord schedule;
  final int revision;
}

enum RetentionContinuityFailureKind { conflict, unavailable, invalidPayload, authenticationRequired }

class RetentionContinuityException implements Exception {
  const RetentionContinuityException(this.message, {required this.kind});

  final String message;
  final RetentionContinuityFailureKind kind;

  @override
  String toString() => 'RetentionContinuityException: $message';
}

abstract interface class RetentionContinuityGateway {
  Future<List<CloudRetentionSnapshot>> readMaterial({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  });

  Future<CloudRetentionSnapshot> writeSchedule({
    required AuthenticatedLearner learner,
    required RetentionScheduleRecord schedule,
    required int? expectedRevision,
  });
}

class UnavailableRetentionContinuityGateway implements RetentionContinuityGateway {
  const UnavailableRetentionContinuityGateway();

  @override
  Future<List<CloudRetentionSnapshot>> readMaterial({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  }) {
    throw const RetentionContinuityException(
      'Cloud retention continuity is unavailable.',
      kind: RetentionContinuityFailureKind.unavailable,
    );
  }

  @override
  Future<CloudRetentionSnapshot> writeSchedule({
    required AuthenticatedLearner learner,
    required RetentionScheduleRecord schedule,
    required int? expectedRevision,
  }) {
    throw const RetentionContinuityException(
      'Cloud retention continuity is unavailable.',
      kind: RetentionContinuityFailureKind.unavailable,
    );
  }
}
