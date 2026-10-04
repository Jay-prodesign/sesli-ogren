import 'dart:typed_data';

import '../domain/authenticated_learner.dart';
import '../domain/learning_contracts.dart';

abstract interface class SourceStore {
  Future<MaterialRecord?> material({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  });

  Future<SourceVersionRecord?> currentSourceVersion({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  });

  Future<SourceVersionRecord?> sourceVersion({
    required AuthenticatedLearner learner,
    required SourceVersionId sourceVersionId,
  });

  Future<List<SourceVersionRecord>> sourceVersions({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  });

  Future<ExtractedContentRecord?> extractedContentForSource({
    required AuthenticatedLearner learner,
    required SourceVersionId sourceVersionId,
  });

  Future<SourceIngestResult> persistIngestResult({
    required AuthenticatedLearner learner,
    required MaterialRecord material,
    required SourceVersionRecord sourceVersion,
    required ExtractedContentRecord extractedContent,
    Uint8List? rawSourceBytes,
  });

  Future<void> deleteMaterial({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    required DateTime deletedAt,
  });

  Future<void> close();
}
