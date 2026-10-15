import '../account/account_deletion_gateway.dart';
import '../account/account_overview_gateway.dart';
import '../account/entitlement_access_gateway.dart';
import '../account/supabase_account_deletion_gateway.dart';
import '../account/supabase_account_overview_gateway.dart';
import '../account/supabase_entitlement_access_gateway.dart';
import '../continuity/cloud_continuity_gateway.dart';
import '../continuity/cloud_continuity_service.dart';
import '../continuity/passive_resume_continuity_service.dart';
import '../continuity/passive_resume_gateway.dart';
import '../continuity/retention_continuity_gateway.dart';
import '../continuity/retention_continuity_service.dart';
import '../continuity/supabase_cloud_continuity_gateway.dart';
import '../continuity/supabase_passive_resume_gateway.dart';
import '../continuity/supabase_retention_continuity_gateway.dart';
import '../data/operational_telemetry.dart';
import '../data/image_text_extractor.dart';
import '../data/office_text_extractor.dart';
import '../data/pdf_text_extractor.dart';
import '../data/source_ingest_service.dart';
import '../data/sqlite_source_store.dart';
import '../domain/authenticated_learner.dart';
import '../domain/learning_contracts.dart';
import '../learning/authenticated_recall_learning_service.dart';
import '../learning/flashcard_learning_service.dart';
import '../learning/quiz_learning_service.dart';
import '../learning/explain_back_gateway.dart';
import '../learning/focus_help_gateway.dart';
import '../learning/grounded_tutor_service.dart';
import '../learning/recall_learning_service.dart';
import '../learning/supabase_explain_back_gateway.dart';
import '../learning/supabase_focus_help_gateway.dart';
import '../learning/supabase_server_recall_gateway.dart';
import '../generation/grounded_explain_gateway.dart';
import '../generation/supabase_grounded_explain_gateway.dart';

class AccountDeletionLocalCleanupException implements Exception {
  const AccountDeletionLocalCleanupException(this.cause);

  final Object cause;

  @override
  String toString() => 'AccountDeletionLocalCleanupException: $cause';
}

class AppRuntime {
  AppRuntime({
    required this.learner,
    required this.store,
    required this.ingest,
    required this.recall,
    required this.telemetry,
    FlashcardLearningService? flashcards,
    QuizLearningService? quiz,
    GroundedTutorService? tutor,
    CloudContinuityService? continuity,
    PassiveResumeContinuityService? passiveResume,
    RetentionContinuityService? retentionContinuity,
    this.explain = const UnavailableGroundedExplainGateway(),
    this.explainBack = const UnavailableExplainBackGateway(),
    this.focusHelp = const UnavailableFocusHelpGateway(),
    this.accountOverview = const UnavailableAccountOverviewGateway(),
    this.entitlementAccess = const UnavailableEntitlementAccessGateway(),
    this.accountDeletion = const UnavailableAccountDeletionGateway(),
  }) : flashcards = flashcards ?? FlashcardLearningService(store: store),
       quiz = quiz ?? QuizLearningService(store: store),
       tutor = tutor ?? GroundedTutorService(store: store),
       continuity =
           continuity ??
           CloudContinuityService(store: store, ingest: ingest, gateway: const UnavailableCloudContinuityGateway()),
       passiveResume =
           passiveResume ??
           PassiveResumeContinuityService(store: store, gateway: const UnavailablePassiveResumeGateway()),
       retentionContinuity =
           retentionContinuity ??
           RetentionContinuityService(store: store, gateway: const UnavailableRetentionContinuityGateway());

  /// Device-local production namespace. It is explicitly not an account.
  static const localLearner = LearnerIdentity.local();

  /// Explicit M5 authenticated fixture only.
  static const localM5LearnerFixture = LearnerIdentity.authenticated(id: LearnerId('m5-local-authenticated-learner'));

  static const primaryMaterialId = MaterialId('m5-primary-material');

  MaterialId newMaterialId() =>
      MaterialId('material_${DateTime.now().toUtc().microsecondsSinceEpoch}_${learner.id.value.hashCode.abs()}');

  final AuthenticatedLearner learner;
  final SqliteSourceStore store;
  final SourceIngestService ingest;
  final RecallLearningService recall;
  final FlashcardLearningService flashcards;
  final QuizLearningService quiz;
  final GroundedTutorService tutor;
  final CloudContinuityService continuity;
  final PassiveResumeContinuityService passiveResume;
  final RetentionContinuityService retentionContinuity;
  final OperationalTelemetry telemetry;
  final GroundedExplainGateway explain;
  final ExplainBackGateway explainBack;
  final FocusHelpGateway focusHelp;
  final AccountOverviewGateway accountOverview;
  final EntitlementAccessGateway entitlementAccess;
  final AccountDeletionGateway accountDeletion;

  static Future<AppRuntime> open({required AuthenticatedLearner learner}) async {
    final store = await SqliteSourceStore.open();
    final ingest = SourceIngestService(
      store: store,
      pdfTextExtractor: const PdfrxPdfTextExtractor(),
      officeTextExtractor: const OpenXmlOfficeTextExtractor(),
      imageTextExtractor: const MlKitImageTextExtractor(),
    );
    final continuity = CloudContinuityService(
      store: store,
      ingest: ingest,
      gateway: const SupabaseCloudContinuityGateway(),
    );
    final retentionContinuity = RetentionContinuityService(
      store: store,
      gateway: const SupabaseRetentionContinuityGateway(),
    );
    final recall = AuthenticatedRecallLearningService(
      store: store,
      continuity: continuity,
      gateway: const SupabaseServerRecallGateway(),
      retentionContinuity: retentionContinuity,
    );
    return AppRuntime(
      learner: learner,
      store: store,
      ingest: ingest,
      recall: recall,
      telemetry: store.operationalTelemetry(),
      continuity: continuity,
      passiveResume: PassiveResumeContinuityService(store: store, gateway: const SupabasePassiveResumeGateway()),
      retentionContinuity: retentionContinuity,
      explain: const SupabaseGroundedExplainGateway(),
      explainBack: const SupabaseExplainBackGateway(),
      focusHelp: const SupabaseFocusHelpGateway(),
      accountOverview: const SupabaseAccountOverviewGateway(),
      entitlementAccess: const SupabaseEntitlementAccessGateway(),
      accountDeletion: const SupabaseAccountDeletionGateway(),
    );
  }

  static Future<AppRuntime> openLocal() async {
    final store = await SqliteSourceStore.open();
    final ingest = SourceIngestService(
      store: store,
      pdfTextExtractor: const PdfrxPdfTextExtractor(),
      officeTextExtractor: const OpenXmlOfficeTextExtractor(),
      imageTextExtractor: const MlKitImageTextExtractor(),
    );
    final recall = RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore());
    return AppRuntime(
      learner: localLearner,
      store: store,
      ingest: ingest,
      recall: recall,
      telemetry: store.operationalTelemetry(),
    );
  }

  /// Rebinds the already-open local data plane to an authenticated namespace.
  ///
  /// The SQLite handle and local learning services are deliberately reused so
  /// account connection cannot close or overwrite the device-local namespace.
  /// Cloud-capable gateways are enabled only for a verified authenticated
  /// identity.
  AppRuntime asAuthenticated(AuthenticatedLearner authenticatedLearner) {
    if (!authenticatedLearner.isAuthenticated) {
      throw ArgumentError.value(authenticatedLearner.kind, 'authenticatedLearner', 'Expected authenticated identity.');
    }
    final authenticatedContinuity = CloudContinuityService(
      store: store,
      ingest: ingest,
      gateway: const SupabaseCloudContinuityGateway(),
    );
    final authenticatedRetention = RetentionContinuityService(
      store: store,
      gateway: const SupabaseRetentionContinuityGateway(),
    );
    return AppRuntime(
      learner: authenticatedLearner,
      store: store,
      ingest: ingest,
      recall: AuthenticatedRecallLearningService(
        store: store,
        continuity: authenticatedContinuity,
        gateway: const SupabaseServerRecallGateway(),
        retentionContinuity: authenticatedRetention,
      ),
      telemetry: telemetry,
      continuity: authenticatedContinuity,
      passiveResume: PassiveResumeContinuityService(store: store, gateway: const SupabasePassiveResumeGateway()),
      retentionContinuity: authenticatedRetention,
      explain: const SupabaseGroundedExplainGateway(),
      explainBack: const SupabaseExplainBackGateway(),
      focusHelp: const SupabaseFocusHelpGateway(),
      accountOverview: const SupabaseAccountOverviewGateway(),
      entitlementAccess: const SupabaseEntitlementAccessGateway(),
      accountDeletion: const SupabaseAccountDeletionGateway(),
    );
  }

  /// Returns to the device-local namespace without reopening or closing the
  /// shared SQLite data plane. Local and authenticated rows remain separated by
  /// learner_id, so neither namespace fabricates or absorbs the other's truth.
  AppRuntime asLocal() => AppRuntime(
    learner: localLearner,
    store: store,
    ingest: ingest,
    recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
    telemetry: telemetry,
  );

  Future<int> syncAuthenticatedLearningContinuity() async {
    final service = recall;
    if (!learner.isAuthenticated || service is! AuthenticatedRecallLearningService) return 0;
    return service.syncLatestContinuity(learner: learner);
  }

  Future<List<RetentionContinuityItemResult>> syncRetentionForMaterial(MaterialId materialId) {
    if (!learner.isAuthenticated) {
      return Future.value(const <RetentionContinuityItemResult>[]);
    }
    return retentionContinuity.syncMaterial(learner: learner, materialId: materialId);
  }

  Future<PassiveResumeSyncSummary> syncAuthenticatedPassiveResumeContinuity() {
    if (!learner.isAuthenticated) return Future.value(const PassiveResumeSyncSummary(results: []));
    return passiveResume.syncAll(learner: learner);
  }

  Future<List<PassiveResumeSyncResult>> syncPassiveResumeForMaterial(MaterialId materialId) {
    if (!learner.isAuthenticated) return Future.value(const <PassiveResumeSyncResult>[]);
    return passiveResume.syncMaterial(learner: learner, materialId: materialId);
  }

  Future<void> deleteAccount() async {
    await accountDeletion.deleteAccount(learner: learner);
    try {
      await store.purgeLearnerData(learner: learner);
    } catch (error) {
      // Remote deletion has already been confirmed at this point. Surface a
      // distinct state so callers never resubmit the destructive remote action.
      throw AccountDeletionLocalCleanupException(error);
    }
  }

  Future<void> retryDeletedAccountLocalCleanup() => store.purgeLearnerData(learner: learner);

  Future<void> close() => store.close();
}
