import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/supabase_learner_auth.dart';
import 'grounded_explain_gateway.dart';

/// Authenticated client adapter over the server-authoritative LA-0025 RPCs.
/// Provider credentials never enter this client.
class SupabaseGroundedExplainGateway implements GroundedExplainGateway {
  const SupabaseGroundedExplainGateway();

  @override
  Future<GroundedExplainResult> explain(GroundedExplainRequest request) async {
    try {
      final client = await SupabaseLearnerAuth.clientForAuthenticatedRuntime();
      await client.rpc<Object?>(
        'request_grounded_explain',
        params: {
          'p_material_id': request.materialId.value,
          'p_source_content_hash': request.sourceContentDigest,
          'p_idempotency_key': _idempotencyKey(request),
        },
      );

      final rows = await client.rpc<List<dynamic>>(
        'read_grounded_explain',
        params: {
          'p_material_id': request.materialId.value,
          'p_source_content_hash': request.sourceContentDigest,
        },
      );
      if (rows.isEmpty) {
        return const GroundedExplainUnavailable(reason: GroundedExplainUnavailableReason.temporaryFailure);
      }

      final row = Map<String, dynamic>.from(rows.first as Map);
      final content = Map<String, dynamic>.from(row['content'] as Map);
      final explanation = (content['summary'] as String?)?.trim() ?? '';
      final rawPoints = content['key_points'];
      final keyPoints = rawPoints is List
          ? rawPoints.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
          : <String>[];
      final language = (content['language'] as String?)?.trim() ?? request.outputLocale;
      final digest = (row['source_content_hash'] as String?) ?? '';

      if (explanation.isEmpty || digest != request.sourceContentDigest) {
        return const GroundedExplainUnavailable(reason: GroundedExplainUnavailableReason.staleSource);
      }

      return GroundedExplainReady(
        sourceVersionId: request.sourceVersionId,
        sourceContentDigest: digest,
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
    final digest = request.sourceContentDigest.length <= 24
        ? request.sourceContentDigest
        : request.sourceContentDigest.substring(0, 24);
    return 'explain:${request.materialId.value}:$digest';
  }
}
