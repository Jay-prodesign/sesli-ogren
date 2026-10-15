import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/supabase_learner_auth.dart';
import '../domain/authenticated_learner.dart';
import 'product_analytics.dart';
import 'product_analytics_gateway.dart';

class SupabaseProductAnalyticsGateway implements ProductAnalyticsGateway {
  const SupabaseProductAnalyticsGateway();

  @override
  Future<void> record({
    required AuthenticatedLearner learner,
    required ProductAnalyticsEnvelope envelope,
    String? serverMaterialId,
  }) async {
    if (!learner.isAuthenticated) {
      throw const ProductAnalyticsGatewayException('Product analytics sync requires an authenticated learner.');
    }

    try {
      final client = await SupabaseLearnerAuth.clientForAuthenticatedRuntime();
      final user = client.auth.currentSession?.user;
      if (user == null || user.id != learner.id.value) {
        throw const ProductAnalyticsGatewayException('Analytics session does not match the learner.');
      }

      await client.rpc<String>(
        'record_product_event',
        params: {
          'p_event_id': envelope.eventId,
          'p_schema_version': envelope.event.schemaVersion,
          'p_session_id': envelope.sessionId,
          'p_event_type': envelope.event.type.wireValue,
          'p_phase': envelope.event.phase.name,
          'p_client_material_id': envelope.event.materialId?.value,
          'p_server_material_id': serverMaterialId,
          'p_source_version_id': envelope.event.sourceVersionId?.value,
          'p_surface': envelope.event.surface?.wireValue,
          'p_capability': envelope.event.capability?.wireValue,
          'p_outcome_class': envelope.event.outcomeClass,
          'p_reason_code': envelope.event.reasonCode,
          'p_duration_ms': envelope.event.durationMs,
          'p_quantity': envelope.event.quantity,
          'p_occurred_at': envelope.event.createdAt.toUtc().toIso8601String(),
        },
      );
    } on ProductAnalyticsGatewayException {
      rethrow;
    } on PostgrestException catch (error) {
      throw ProductAnalyticsGatewayException(error.message);
    } catch (_) {
      throw const ProductAnalyticsGatewayException('Product analytics sync is temporarily unavailable.');
    }
  }
}
