// Canonical client models for the Architecture Proof (LA-0013).
//
// They decode exactly what the owner can read through RLS: the `library_items` projection,
// persisted `artifacts` rows and the client-visible `generation_jobs` columns. The Summary is a
// versioned Artifact with lineage, never a string field on the material.

class LibraryItem {
  const LibraryItem({
    required this.materialId,
    required this.title,
    required this.processingState,
    this.summaryArtifactId,
    this.summaryVersion,
  });

  factory LibraryItem.fromRow(Map<String, dynamic> row) => LibraryItem(
    materialId: row['material_id'] as String,
    title: row['title'] as String,
    processingState: row['processing_state'] as String,
    summaryArtifactId: row['summary_artifact_id'] as String?,
    summaryVersion: row['summary_version'] as int?,
  );

  final String materialId;
  final String title;
  final String processingState;
  final String? summaryArtifactId;
  final int? summaryVersion;

  bool get hasSummary => summaryArtifactId != null;
}

class SummaryArtifact {
  const SummaryArtifact({
    required this.id,
    required this.materialId,
    required this.version,
    required this.generationJobId,
    required this.generationAttemptId,
    required this.summary,
    required this.keyPoints,
    required this.language,
    required this.aiGenerated,
  });

  factory SummaryArtifact.fromRow(Map<String, dynamic> row) {
    if (row['artifact_type'] != 'SUMMARY') {
      throw FormatException('not a SUMMARY artifact: ${row['artifact_type']}');
    }
    if (row['content_schema_version'] != 1) {
      throw FormatException(
        'unsupported summary schema ${row['content_schema_version']}',
      );
    }
    final content = row['content'] as Map<String, dynamic>;
    return SummaryArtifact(
      id: row['id'] as String,
      materialId: row['material_id'] as String,
      version: row['version'] as int,
      generationJobId: row['generation_job_id'] as String,
      generationAttemptId: row['generation_attempt_id'] as String,
      summary: content['summary'] as String,
      keyPoints: List<String>.from(content['key_points'] as List),
      language: content['language'] as String,
      aiGenerated: row['trust_class'] == 'AI_GENERATED',
    );
  }

  final String id;
  final String materialId;
  final int version;
  final String generationJobId;
  final String generationAttemptId;
  final String summary;
  final List<String> keyPoints;
  final String language;

  /// D-036 trust class: generated content must be distinguishable from user sources.
  final bool aiGenerated;
}

/// User-visible processing status derived from the canonical GenerationJob state.
enum ProcessingView {
  queued,
  processing,
  success,
  failedRetryable,
  checking,
  failedFinal,
}

class GenerationJobView {
  const GenerationJobView({
    required this.jobId,
    required this.state,
    this.failureClass,
  });

  factory GenerationJobView.fromRow(Map<String, dynamic> row) =>
      GenerationJobView(
        jobId: row['id'] as String,
        state: row['state'] as String,
        failureClass: row['failure_class'] as String?,
      );

  final String jobId;
  final String state;
  final String? failureClass;

  ProcessingView get view => switch (state) {
    'QUEUED' => ProcessingView.queued,
    'PROCESSING' => ProcessingView.processing,
    'SUCCEEDED' || 'PARTIAL' => ProcessingView.success,
    // An ambiguous dispatch is being reconciled server-side; offering "retry" could double-charge.
    'FAILED_RETRYABLE' when failureClass == 'reconciliation_required' =>
      ProcessingView.checking,
    'FAILED_RETRYABLE' => ProcessingView.failedRetryable,
    _ => ProcessingView.failedFinal,
  };

  /// Only a plain retryable failure offers a user retry (server enforces the same rule).
  bool get canRetry => view == ProcessingView.failedRetryable;
}

/// Port to the backend. Production: supabase_flutter (PostgREST reads + RPC calls). Not implemented in the spike.
abstract interface class MaterialRepository {
  Future<List<LibraryItem>> library();
  Future<SummaryArtifact?> summary(String artifactId);
  Future<GenerationJobView> job(String jobId);
  Future<void> retry(String jobId);
}
