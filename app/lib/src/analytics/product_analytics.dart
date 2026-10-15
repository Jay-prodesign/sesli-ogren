import '../domain/authenticated_learner.dart';
import '../domain/learning_contracts.dart';

enum ProductAnalyticsEventType {
  runtimeRestore,
  sourceIngest,
  recallPrompt,
  recallAttempt,
  continuationRepair,
  materialOpened,
  readerSession,
  listenSession,
  flashcardReview,
  quizAnswer,
  entitlementBoundary,
  continuitySync,
}

extension ProductAnalyticsEventTypeWire on ProductAnalyticsEventType {
  String get wireValue => switch (this) {
    ProductAnalyticsEventType.runtimeRestore => 'runtime_restore',
    ProductAnalyticsEventType.sourceIngest => 'source_ingest',
    ProductAnalyticsEventType.recallPrompt => 'recall_prompt',
    ProductAnalyticsEventType.recallAttempt => 'recall_attempt',
    ProductAnalyticsEventType.continuationRepair => 'continuation_repair',
    ProductAnalyticsEventType.materialOpened => 'material_opened',
    ProductAnalyticsEventType.readerSession => 'reader_session',
    ProductAnalyticsEventType.listenSession => 'listen_session',
    ProductAnalyticsEventType.flashcardReview => 'flashcard_review',
    ProductAnalyticsEventType.quizAnswer => 'quiz_answer',
    ProductAnalyticsEventType.entitlementBoundary => 'entitlement_boundary',
    ProductAnalyticsEventType.continuitySync => 'continuity_sync',
  };

  static ProductAnalyticsEventType fromWire(String value) => switch (value) {
    'runtime_restore' => ProductAnalyticsEventType.runtimeRestore,
    'source_ingest' => ProductAnalyticsEventType.sourceIngest,
    'recall_prompt' => ProductAnalyticsEventType.recallPrompt,
    'recall_attempt' => ProductAnalyticsEventType.recallAttempt,
    'continuation_repair' => ProductAnalyticsEventType.continuationRepair,
    'material_opened' => ProductAnalyticsEventType.materialOpened,
    'reader_session' => ProductAnalyticsEventType.readerSession,
    'listen_session' => ProductAnalyticsEventType.listenSession,
    'flashcard_review' => ProductAnalyticsEventType.flashcardReview,
    'quiz_answer' => ProductAnalyticsEventType.quizAnswer,
    'entitlement_boundary' => ProductAnalyticsEventType.entitlementBoundary,
    'continuity_sync' => ProductAnalyticsEventType.continuitySync,
    _ => throw FormatException('unsupported_product_analytics_event:$value'),
  };
}

enum ProductAnalyticsPhase { started, completed, failed, viewed }

enum ProductAnalyticsSurface {
  home,
  workspace,
  sourceEditor,
  reader,
  listen,
  recall,
  flashcards,
  quiz,
  profile,
  entitlement,
}

extension ProductAnalyticsSurfaceWire on ProductAnalyticsSurface {
  String get wireValue => switch (this) {
    ProductAnalyticsSurface.sourceEditor => 'source_editor',
    _ => name,
  };

  static ProductAnalyticsSurface fromWire(String value) => switch (value) {
    'source_editor' => ProductAnalyticsSurface.sourceEditor,
    _ => ProductAnalyticsSurface.values.byName(value),
  };
}

enum ProductAnalyticsCapability {
  sourceProcessing,
  summary,
  explain,
  focus,
  explainBack,
  reader,
  listen,
  recall,
  flashcards,
  quiz,
  continuity,
}

extension ProductAnalyticsCapabilityWire on ProductAnalyticsCapability {
  String get wireValue => switch (this) {
    ProductAnalyticsCapability.sourceProcessing => 'source_processing',
    ProductAnalyticsCapability.explainBack => 'explain_back',
    _ => name,
  };

  static ProductAnalyticsCapability fromWire(String value) => switch (value) {
    'source_processing' => ProductAnalyticsCapability.sourceProcessing,
    'explain_back' => ProductAnalyticsCapability.explainBack,
    _ => ProductAnalyticsCapability.values.byName(value),
  };
}

class ProductAnalyticsEvent {
  const ProductAnalyticsEvent({
    required this.type,
    required this.phase,
    required this.createdAt,
    this.materialId,
    this.sourceVersionId,
    this.surface,
    this.capability,
    this.outcomeClass,
    this.reasonCode,
    this.durationMs,
    this.quantity,
    this.schemaVersion = 1,
  });

  final int schemaVersion;
  final ProductAnalyticsEventType type;
  final ProductAnalyticsPhase phase;
  final DateTime createdAt;
  final MaterialId? materialId;
  final SourceVersionId? sourceVersionId;
  final ProductAnalyticsSurface? surface;
  final ProductAnalyticsCapability? capability;
  final String? outcomeClass;
  final String? reasonCode;
  final int? durationMs;
  final num? quantity;
}

class ProductAnalyticsEnvelope {
  const ProductAnalyticsEnvelope({required this.eventId, required this.sessionId, required this.event});

  final String eventId;
  final String sessionId;
  final ProductAnalyticsEvent event;
}

abstract interface class ProductAnalytics {
  String get sessionId;

  Future<void> record({required AuthenticatedLearner learner, required ProductAnalyticsEvent event});

  Future<void> flush({required AuthenticatedLearner learner});
}

class UnavailableProductAnalytics implements ProductAnalytics {
  const UnavailableProductAnalytics();

  @override
  String get sessionId => 'session_unavailable';

  @override
  Future<void> record({required AuthenticatedLearner learner, required ProductAnalyticsEvent event}) async {}

  @override
  Future<void> flush({required AuthenticatedLearner learner}) async {}
}
