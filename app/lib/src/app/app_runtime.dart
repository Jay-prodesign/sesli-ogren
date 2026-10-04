import '../data/pdf_text_extractor.dart';
import '../data/source_ingest_service.dart';
import '../data/sqlite_source_store.dart';
import '../domain/authenticated_learner.dart';
import '../domain/learning_contracts.dart';
import '../learning/recall_learning_service.dart';

class AppRuntime {
  AppRuntime({
    required this.store,
    required this.ingest,
    required this.recall,
  });

  /// M5 keeps auth behind the domain boundary without introducing production
  /// credentials. The real account/session provider replaces this injected
  /// identity when the account tranche is admitted.
  static const learner = AuthenticatedLearner(
    id: LearnerId('m5-local-authenticated-learner'),
  );

  static const primaryMaterialId = MaterialId('m5-primary-material');

  final SqliteSourceStore store;
  final SourceIngestService ingest;
  final RecallLearningService recall;

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
    return AppRuntime(store: store, ingest: ingest, recall: recall);
  }

  Future<void> close() => store.close();
}
