import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/supabase_learner_auth.dart';
import 'grounded_explain_gateway.dart';

/// Authenticated client adapter over the server-authoritative LA-0025 RPCs.
/// Provider credentials never enter this client.
class SupabaseGroundedExplainGateway implements GroundedExplainGateway {
  const SupabaseGroundedExplainGateway();

  @override
  Future<GroundedExplainResult> explain(GroundedExplainRequest request) async {
    // Local SQLite identifiers are not server UUIDs.
    final serverMaterialId = request.materialId.value;
    final uuidPattern = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}');
    if (serverMaterialId.length != 36 || !uuidPattern.hasMatch(serverMaterialId)) {
      return const GroundedExplainUnavailable(reason: GroundedExplainUnavailableReason.sourceUnavailable);
    }
    try {
      final client = await SupabaseLearnerAuth.clientForAuthenticatedRuntime();
      final jobId = await client.rpc<String>(
        'request_grounded_explain',
        params: {
          'p_material_id': request.materialId.value,
          'p_source_content_hash': request.groundingContentHash,
          'p_idempotency_key': _idempotencyKey(request),
        },
      );
      final jobs = await client.from('generation_jobs').select('state,failure_class').eq('id', jobId).limit(1);
      if (jobs.isEmpty) {
        return const GroundedExplainUnavailable(reason: GroundedExplainUnavailableReason.temporaryFailure);
      }
      final jobState = jobs.first['state'] as String;
      final failureClass = jobs.first['failure_class'] as String?;
      if (failureClass == 'reconciliation_required' || jobState == 'FAILED_FINAL' || jobState == 'CANCELLED') {
        return const GroundedExplainUnavailable(reason: GroundedExplainUnavailableReason.temporaryFailure);
      }
      if (jobState == 'FAILED_RETRYABLE') {
        await client.rpc<String>('retry_generation_job', params: {'p_job_id': jobId});
      }
      if (jobState == 'QUEUED' || jobState == 'PROCESSING' || jobState == 'FAILED_RETRYABLE') {
        final response = await client.functions.invoke('generation-worker', body: {'job_id': jobId});
        if (response.status < 200 || response.status >= 300) {
          return const GroundedExplainUnavailable(reason: GroundedExplainUnavailableReason.temporaryFailure);
        }
      }

      // Generation is asynchronous. A newly queued Explain artifact will not exist on
      // the first read; give the worker a bounded window before showing Retry.
      List<dynamic> rows = <dynamic>[];
      for (var attempt = 0; attempt < 6; attempt++) {
        if (attempt > 0) {
          await Future<void>.delayed(const Duration(seconds: 2));
        }
        rows = await client.rpc<List<dynamic>>(
          'read_grounded_explain',
          params: {'p_material_id': request.materialId.value, 'p_source_content_hash': request.groundingContentHash},
        );
        if (rows.isNotEmpty) break;
      }
      if (rows.isEmpty) {
        return const GroundedExplainUnavailable(reason: GroundedExplainUnavailableReason.temporaryFailure);
      }

      final row = Map<String, dynamic>.from(rows.first as Map);
      final content = Map<String, dynamic>.from(row['content'] as Map);
      // Explain V1 intentionally reuses the validated summary.v1 artifact authority.
      // The canonical artifact payload key is therefore `summary`, not `explanation`.
      final explanation = (content['summary'] as String?)?.trim() ?? '';
      final rawPoints = content['key_points'];
      final keyPoints = rawPoints is List
          ? rawPoints.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
          : <String>[];
      final language = (content['language'] as String?)?.trim() ?? request.outputLocale;
      final digest = (row['source_content_hash'] as String?) ?? '';

      if (explanation.isEmpty || digest != request.groundingContentHash) {
        return const GroundedExplainUnavailable(reason: GroundedExplainUnavailableReason.staleSource);
      }

      return GroundedExplainReady(
        sourceVersionId: request.sourceVersionId,
        sourceContentDigest: request.sourceContentDigest,
        explanation: explanation,
        keyPoints: keyPoints,
        language: language,
        executionRef: (row['provider_execution_ref'] as String?) ?? 'server:artifact',
      );
    } on PostgrestException catch (error) {
      if (error.message.contains('stale_source')) {
        return const GroundedExplainUnavailable(reason: GroundedExplainUnavailableReason.staleSource);
      }
      if (error.message.contains('material_not_found')) {
        return const GroundedExplainUnavailable(reason: GroundedExplainUnavailableReason.sourceUnavailable);
      }
      return const GroundedExplainUnavailable(reason: GroundedExplainUnavailableReason.temporaryFailure);
    } catch (_) {
      return const GroundedExplainUnavailable(reason: GroundedExplainUnavailableReason.temporaryFailure);
    }
  }

  static String _idempotencyKey(GroundedExplainRequest request) {
    final digest = request.groundingContentHash.length <= 24
        ? request.groundingContentHash
        : request.groundingContentHash.substring(0, 24);
    return 'explain:${request.materialId.value}:$digest';
  }
}
