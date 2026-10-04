import '../data/operational_telemetry.dart';
import '../data/pdf_text_extractor.dart';
import '../data/source_ingest_service.dart';
import '../data/sqlite_source_store.dart';
import '../domain/authenticated_learner.dart';
import '../domain/learning_contracts.dart';
import '../learning/recall_learning_service.dart';

class AppRuntime {
  AppRuntime({
    required this.learner,
    required this.store,
    required this.ingest,
    required this.recall,
    required this.telemetry,
  });

  /// Explicit M5 fixture only. It is not a production authentication claim.
  static const localM5LearnerFixture = AuthenticatedLearner(
    id: LearnerId('m5-local-authenticated-learner'),
  );

  static const primaryMaterialId = MaterialId('m5-primary-material');

  final AuthenticatedLearner learner;
  final SqliteSourceStore store;
  final SourceIngestService ingest;
  final RecallLearningService recall;
  final OperationalTelemetry telemetry;

  static Future<AppRuntime> open() async {
    final store = await SqliteSourceStore.open();
    final ingest = SourceIngestService(
      store: store,
      pdfTextExtractor: const PdfrxPdfTextExtractor(),
    );
    final recall = RecallLearningService(
      sourceStore: store,
      learningStore: store.learningTruthStore(),
    );
    return AppRuntime(
      learner: localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: recall,
      telemetry: store.operationalTelemetry(),
    );
  }

  Future<void> close() => store.close();
}
