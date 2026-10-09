import '../auth/supabase_learner_auth.dart';
import '../domain/learning_contracts.dart';

/// First server handoff for an extracted, learner-owned text source.
/// A PDF is sent as extracted text, never mislabeled as an uploaded PDF.
/// The returned UUID is the server material identity, not the local SQLite ID.
class SupabaseSourceSummaryGateway {
  const SupabaseSourceSummaryGateway();

  Future<ServerSummaryStatus> status(String jobId) async {
    final client = await SupabaseLearnerAuth.clientForAuthenticatedRuntime();
    if (client.auth.currentSession == null) {
      throw const ServerSummarySubmissionException('Authentication required.');
    }
    final rows = await client.from('generation_jobs').select('state,failure_class').eq('id', jobId).limit(1);
    if (rows.isEmpty) throw const ServerSummarySubmissionException('Summary job not found.');
    final state = rows.first['state'] as String;
    if (state == 'SUCCEEDED') {
      final artifacts = await client
          .from('artifacts')
          .select('content')
          .eq('generation_job_id', jobId)
          .eq('status', 'available')
          .limit(1);
      if (artifacts.isEmpty) return const ServerSummaryStatus(state: 'PROCESSING');
      final content = Map<String, dynamic>.from(artifacts.first['content'] as Map);
      return ServerSummaryStatus(
        state: state,
        summary: content['summary'] as String?,
        keyPoints: (content['key_points'] as List<dynamic>? ?? const []).whereType<String>().toList(growable: false),
      );
    }
    return ServerSummaryStatus(state: state, failureClass: rows.first['failure_class'] as String?);
  }

  /// Best-effort wake-up for this learner's exact queued job.
  /// The server re-verifies auth and ownership; provider/service credentials
  /// never enter the Flutter client.
  Future<bool> dispatch(String jobId) async {
    try {
      final client = await SupabaseLearnerAuth.clientForAuthenticatedRuntime();
      if (client.auth.currentSession == null) return false;
      final response = await client.functions.invoke('generation-worker', body: {'job_id': jobId});
      final data = response.data;
      return response.status >= 200 && response.status < 300 && data is Map && data['status'] is String;
    } catch (_) {
      return false;
    }
  }

  /// Explicit retry is permitted only when the canonical server job says the
  /// prior attempt is retryable. Ambiguous provider outcomes remain blocked by
  /// retry_generation_job and require reconciliation instead of blind resend.
  Future<bool> retry(String jobId) async {
    try {
      final client = await SupabaseLearnerAuth.clientForAuthenticatedRuntime();
      if (client.auth.currentSession == null) return false;
      await client.rpc<String>('retry_generation_job', params: {'p_job_id': jobId});
      return dispatch(jobId);
    } catch (_) {
      return false;
    }
  }

  /// Removes a server-side text mirror owned by the current learner.
  /// If RLS no longer exposes the row, it is already absent/deleted for this learner.
  Future<bool> deleteServerMaterial(String serverMaterialId) async {
    try {
      final client = await SupabaseLearnerAuth.clientForAuthenticatedRuntime();
      if (client.auth.currentSession == null) return false;
      final rows = await client.from('materials').select('id').eq('id', serverMaterialId).limit(1);
      if (rows.isEmpty) return true;
      await client.rpc('delete_material', params: {'p_material_id': serverMaterialId});
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Ensures the learner has one server text mirror for this exact local
  /// source version without creating a Summary generation job.
  Future<String> ensureServerMaterial({required SourceIngestResult source}) async {
    final normalizedText = source.extractedContent.normalizedText.trim();
    if (normalizedText.isEmpty || normalizedText.length > 200000) {
      throw const ServerSummarySubmissionException('Source text is empty or too large.');
    }
    final client = await SupabaseLearnerAuth.clientForAuthenticatedRuntime();
    if (client.auth.currentSession == null) {
      throw const ServerSummarySubmissionException('Authentication required.');
    }
    final serverMaterialId = await client.rpc<String>(
      'ensure_text_material',
      params: {
        'p_title': source.material.title,
        'p_text': normalizedText,
        'p_client_source_id': source.sourceVersion.identity.sourceVersionId.value,
      },
    );
    if (serverMaterialId.isEmpty) {
      throw const ServerSummarySubmissionException('Server material was not created.');
    }
    return serverMaterialId;
  }

  Future<ServerSummarySubmission> submit({required SourceIngestResult source}) async {
    final normalizedText = source.extractedContent.normalizedText.trim();
    if (normalizedText.isEmpty || normalizedText.length > 200000) {
      throw const ServerSummarySubmissionException('Source text is empty or too large.');
    }
    final client = await SupabaseLearnerAuth.clientForAuthenticatedRuntime();
    final session = client.auth.currentSession;
    if (session == null) {
      throw const ServerSummarySubmissionException('Authentication required.');
    }
    final rows = await client.rpc<List<dynamic>>(
      'submit_text_summary',
      params: {
        'p_title': source.material.title,
        'p_text': normalizedText,
        'p_client_source_id': source.sourceVersion.identity.sourceVersionId.value,
      },
    );
    if (rows.length != 1 || rows.first is! Map) {
      throw const ServerSummarySubmissionException('Server summary request was not created.');
    }
    final row = Map<String, dynamic>.from(rows.first as Map);
    final serverMaterialId = row['material_id'] as String? ?? '';
    final jobId = row['job_id'] as String? ?? '';
    if (serverMaterialId.isEmpty || jobId.isEmpty) {
      throw const ServerSummarySubmissionException('Server summary identity is missing.');
    }
    return ServerSummarySubmission(materialId: serverMaterialId, jobId: jobId);
  }
}

class ServerSummarySubmission {
  const ServerSummarySubmission({required this.materialId, required this.jobId});

  final String materialId;
  final String jobId;
}

class ServerSummarySubmissionException implements Exception {
  const ServerSummarySubmissionException(this.message);

  final String message;
}

class ServerSummaryStatus {
  const ServerSummaryStatus({required this.state, this.summary, this.keyPoints = const [], this.failureClass});
  final String state;
  final String? summary;
  final List<String> keyPoints;
  final String? failureClass;
  bool get isTerminal =>
      state == 'SUCCEEDED' || state == 'FAILED_FINAL' || state == 'FAILED_RETRYABLE' || state == 'CANCELLED';
}
