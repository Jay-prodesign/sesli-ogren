import '../domain/authenticated_learner.dart';
import '../domain/operational_event.dart';

abstract interface class OperationalTelemetry {
  Future<void> record({required AuthenticatedLearner learner, required OperationalEvent event});

  Future<List<OperationalEvent>> events({required AuthenticatedLearner learner});
}
