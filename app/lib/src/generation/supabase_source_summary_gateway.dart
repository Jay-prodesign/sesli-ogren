
import '../auth/supabase_learner_auth.dart';
import '../domain/learning_contracts.dart';

/// First server handoff for an extracted, learner-owned text source.
/// A PDF is sent as extracted text, never mislabeled as an uploaded PDF.
/// The returned UUID is the server material identity, not the local SQLite ID.
class SupabaseSourceSummaryGateway {
  const SupabaseSourceSummaryGateway();

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
    final serverMaterialId = await client.rpc<String>(
      'create_text_material',
      params: {'p_title': source.material.title, 'p_text': normalizedText},
    );
    if (serverMaterialId.isEmpty) {
      throw const ServerSummarySubmissionException('Server material was not created.');
    }
    final jobId = await client.rpc<String>(
      'request_summary',
      params: {
        'p_material_id': serverMaterialId,
        'p_idempotency_key': 'summary:initial:$serverMaterialId',
        'p_regenerate': false,
      },
    );
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
