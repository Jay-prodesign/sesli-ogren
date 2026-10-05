import '../domain/learning_contracts.dart';

class ExplainBackAttemptId {
  const ExplainBackAttemptId(this.value);
  final String value;

  @override
  bool operator ==(Object other) => other is ExplainBackAttemptId && other.value == value;
  @override
  int get hashCode => value.hashCode;
}

enum ExplainBackEvaluationKind {
  sufficient,
  gapDetected,
  notEvaluable,
  unavailable,
}

class ExplainBackRequest {
  const ExplainBackRequest({
    required this.attemptId,
    required this.materialId,
    required this.sourceVersionId,
    required this.sourceContentDigest,
    required this.response,
    required this.outputLocale,
  });

  final ExplainBackAttemptId attemptId;
  final MaterialId materialId;
  final SourceVersionId sourceVersionId;
  final String sourceContentDigest;
  final String response;
  final String outputLocale;
}

sealed class ExplainBackResult {
  const ExplainBackResult();
}

class ExplainBackEvaluated extends ExplainBackResult {
  const ExplainBackEvaluated({
    required this.attemptId,
    required this.sourceVersionId,
    required this.sourceContentDigest,
    required this.kind,
    required this.feedback,
    required this.targetedRepair,
    required this.executionRef,
  });

  final ExplainBackAttemptId attemptId;
  final SourceVersionId sourceVersionId;
  final String sourceContentDigest;
  final ExplainBackEvaluationKind kind;
  final String feedback;
  final String targetedRepair;
  final String executionRef;

  bool matches(SourceVersionIdentity source) =>
      sourceVersionId == source.sourceVersionId &&
      sourceContentDigest == source.contentDigest;
}

class ExplainBackUnavailable extends ExplainBackResult {
  const ExplainBackUnavailable(this.reason);
  final String reason;
}

abstract interface class ExplainBackGateway {
  Future<ExplainBackResult> evaluate(ExplainBackRequest request);
}

/// Safe production default until the server-side semantic evaluator is
/// separately configured. It never infers learning from client heuristics.
class UnavailableExplainBackGateway implements ExplainBackGateway {
  const UnavailableExplainBackGateway();

  @override
  Future<ExplainBackResult> evaluate(ExplainBackRequest request) async =>
      const ExplainBackUnavailable(
        'Yanıtın anlamını güvenilir biçimde değerlendirecek servis henüz etkin değil.',
      );
}
