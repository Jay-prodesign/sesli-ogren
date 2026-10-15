import '../auth/supabase_learner_auth.dart';
import 'entitlement_access_gateway.dart';

class SupabaseEntitlementAccessGateway implements EntitlementAccessGateway {
  const SupabaseEntitlementAccessGateway();

  @override
  Future<CapabilityAccessDecision> check(EntitlementCapability capability) async {
    try {
      final client = await SupabaseLearnerAuth.clientForAuthenticatedRuntime();
      if (client.auth.currentSession == null) {
        return CapabilityAccessDecision(
          capability: capability,
          disposition: CapabilityAccessDisposition.unavailable,
          reason: CapabilityAccessReason.unavailable,
        );
      }

      final rows = await client.rpc<List<dynamic>>(
        'entitlement_capability_access',
        params: {'p_capability': capability.wireKey},
      );
      if (rows.length != 1 || rows.first is! Map) {
        return CapabilityAccessDecision(
          capability: capability,
          disposition: CapabilityAccessDisposition.unavailable,
          reason: CapabilityAccessReason.unavailable,
        );
      }

      final row = Map<String, dynamic>.from(rows.first as Map);
      return CapabilityAccessDecision(
        capability: capability,
        disposition: _disposition(row['decision'] as String?),
        reason: _reason(row['reason_code'] as String?),
        plan: row['plan'] as String?,
        entitlementStatus: row['entitlement_status'] as String?,
        limit: _int(row['limit_value']),
        consumed: _int(row['consumed']) ?? 0,
        reserved: _int(row['reserved']) ?? 0,
        remaining: _int(row['remaining']),
        effectiveUntil: _date(row['effective_until']),
        entitlementUpdatedAt: _date(row['entitlement_updated_at']),
      );
    } catch (_) {
      return CapabilityAccessDecision(
        capability: capability,
        disposition: CapabilityAccessDisposition.unavailable,
        reason: CapabilityAccessReason.unavailable,
      );
    }
  }

  static CapabilityAccessDisposition _disposition(String? value) => switch (value) {
    'allowed' => CapabilityAccessDisposition.allowed,
    'blocked' => CapabilityAccessDisposition.blocked,
    _ => CapabilityAccessDisposition.unavailable,
  };

  static CapabilityAccessReason _reason(String? value) => switch (value) {
    'allowed' => CapabilityAccessReason.allowed,
    'quota_reached' => CapabilityAccessReason.quotaReached,
    'capability_not_entitled' => CapabilityAccessReason.capabilityNotEntitled,
    'entitlement_inactive' => CapabilityAccessReason.entitlementInactive,
    'entitlement_missing' => CapabilityAccessReason.entitlementMissing,
    'capability_not_configured' => CapabilityAccessReason.capabilityNotConfigured,
    _ => CapabilityAccessReason.unavailable,
  };

  static int? _int(Object? value) => switch (value) {
    int number => number,
    num number => number.toInt(),
    String text => int.tryParse(text),
    _ => null,
  };

  static DateTime? _date(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }
}
