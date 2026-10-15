import '../domain/authenticated_learner.dart';
import '../domain/learning_contracts.dart';

enum ProductAnalyticsEventName {
  appOpened,
  materialProcessingStarted,
  materialProcessingCompleted,
  materialProcessingFailed,
  learningActionStarted,
  retrievalAttempted,
  retrievalSucceeded,
  retrievalFailed,
  nextBestActionSelected,
  materialWorkspaceOpened,
  sourceEvidenceOpened,
  readerSessionCompleted,
  audioStarted,
  audioCompleted,
  flashcardResponseRecorded,
  quizAnswered,
  quotaChecked,
  quotaLimitReached,
  paywallViewed,
  networkRecovery,
  appError,
}

extension ProductAnalyticsEventNameWire on ProductAnalyticsEventName {
  String get wireValue => switch (this) {
    ProductAnalyticsEventName.appOpened => 'app_opened',
    ProductAnalyticsEventName.materialProcessingStarted => 'material_processing_started',
    ProductAnalyticsEventName.materialProcessingCompleted => 'material_processing_completed',
    ProductAnalyticsEventName.materialProcessingFailed => 'material_processing_failed',
    ProductAnalyticsEventName.learningActionStarted => 'learning_action_started',
    ProductAnalyticsEventName.retrievalAttempted => 'retrieval_attempted',
    ProductAnalyticsEventName.retrievalSucceeded => 'retrieval_succeeded',
    ProductAnalyticsEventName.retrievalFailed => 'retrieval_failed',
    ProductAnalyticsEventName.nextBestActionSelected => 'next_best_action_selected',
    ProductAnalyticsEventName.materialWorkspaceOpened => 'material_workspace_opened',
    ProductAnalyticsEventName.sourceEvidenceOpened => 'source_evidence_opened',
    ProductAnalyticsEventName.readerSessionCompleted => 'reader_session_completed',
    ProductAnalyticsEventName.audioStarted => 'audio_started',
    ProductAnalyticsEventName.audioCompleted => 'audio_completed',
    ProductAnalyticsEventName.flashcardResponseRecorded => 'flashcard_response_recorded',
    ProductAnalyticsEventName.quizAnswered => 'quiz_answered',
    ProductAnalyticsEventName.quotaChecked => 'quota_checked',
    ProductAnalyticsEventName.quotaLimitReached => 'quota_limit_reached',
    ProductAnalyticsEventName.paywallViewed => 'paywall_viewed',
    ProductAnalyticsEventName.networkRecovery => 'network_recovery',
    ProductAnalyticsEventName.appError => 'app_error',
  };

  static ProductAnalyticsEventName fromWire(String value) => switch (value) {
    'app_opened' => ProductAnalyticsEventName.appOpened,
    'material_processing_started' => ProductAnalyticsEventName.materialProcessingStarted,
    'material_processing_completed' => ProductAnalyticsEventName.materialProcessingCompleted,
    'material_processing_failed' => ProductAnalyticsEventName.materialProcessingFailed,
    'learning_action_started' => ProductAnalyticsEventName.learningActionStarted,
    'retrieval_attempted' => ProductAnalyticsEventName.retrievalAttempted,
    'retrieval_succeeded' => ProductAnalyticsEventName.retrievalSucceeded,
    'retrieval_failed' => ProductAnalyticsEventName.retrievalFailed,
    'next_best_action_selected' => ProductAnalyticsEventName.nextBestActionSelected,
    'material_workspace_opened' => ProductAnalyticsEventName.materialWorkspaceOpened,
    'source_evidence_opened' => ProductAnalyticsEventName.sourceEvidenceOpened,
    'reader_session_completed' => ProductAnalyticsEventName.readerSessionCompleted,
    'audio_started' => ProductAnalyticsEventName.audioStarted,
    'audio_completed' => ProductAnalyticsEventName.audioCompleted,
    'flashcard_response_recorded' => ProductAnalyticsEventName.flashcardResponseRecorded,
    'quiz_answered' => ProductAnalyticsEventName.quizAnswered,
    'quota_checked' => ProductAnalyticsEventName.quotaChecked,
    'quota_limit_reached' => ProductAnalyticsEventName.quotaLimitReached,
    'paywall_viewed' => ProductAnalyticsEventName.paywallViewed,
    'network_recovery' => ProductAnalyticsEventName.networkRecovery,
    'app_error' => ProductAnalyticsEventName.appError,
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
    required this.name,
    required this.createdAt,
    this.phase,
    this.materialId,
    this.sourceVersionId,
    this.surface,
    this.capability,
    this.outcomeClass,
    this.reasonCode,
    this.failureClass,
    this.ruleVersion,
    this.policyVersion,
    this.durationMs,
    this.quantity,
    this.eventVersion = 1,
  });

  final int eventVersion;
  final ProductAnalyticsEventName name;
  final ProductAnalyticsPhase? phase;
  final DateTime createdAt;
  final MaterialId? materialId;
  final SourceVersionId? sourceVersionId;
  final ProductAnalyticsSurface? surface;
  final ProductAnalyticsCapability? capability;
  final String? outcomeClass;
  final String? reasonCode;
  final String? failureClass;
  final String? ruleVersion;
  final String? policyVersion;
  final int? durationMs;
  final num? quantity;
}

class ProductAnalyticsEnvelope {
  const ProductAnalyticsEnvelope({
    required this.eventId,
    required this.sessionId,
    required this.environment,
    required this.event,
    this.appVersion,
    this.platform,
    this.locale,
  });

  final String eventId;
  final String sessionId;
  final String environment;
  final String? appVersion;
  final String? platform;
  final String? locale;
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
