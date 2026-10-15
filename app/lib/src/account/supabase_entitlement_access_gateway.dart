import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/supabase_learner_auth.dart';
import '../domain/authenticated_learner.dart';
import 'entitlement_access_gateway.dart';

class SupabaseEntitlementAccessGateway implements EntitlementAccessGateway {
  const SupabaseEntitlementAccessGateway();

  @override
  Future<EntitlementAccess> check({
    required AuthenticatedLearner learner,
    required EntitlementCapability capability,
  }) async {
    if (!learner.isAuthenticated) {
      return _unavailable(capability);
    }
    try {
      final client = await SupabaseLearnerAuth.clientForAuthenticatedRuntime();
      final rows = await client.rpc<List<dynamic>>(
        'get_capability_access',
        params: {'p_capability': capability.wireValue},
      );
      if (rows.length != 1 || rows.single is! Map) {
        return _unavailable(capability);
      }
      final row = Map<String, dynamic>.from(rows.single as Map);
      return EntitlementAccess(
        capability: capability,
        kind: _kind(row['decision'] as String?),
        reason: _reason(row['reason'] as String?),
        plan: row['plan'] as String? ?? 'unknown',
        entitlementStatus: row['entitlement_status'] as String? ?? 'unknown',
        reconciliationState: row['reconciliation_state'] as String? ?? 'unknown',
        renewalState: row['renewal_state'] as String? ?? 'unknown',
        periodStart: _date(row['period_start']) ?? _todayUtc(),
        consumed: _integer(row['consumed']),
        limit: _integer(row['limit_value']),
        effectiveUntil: _date(row['effective_until']),
        lastAuthoritativeVerificationAt: _date(row['last_authoritative_verification_at']),
      );
    } on PostgrestException {
      return _unavailable(capability);
    } catch (_) {
      return _unavailable(capability);
    }
  }

  static EntitlementAccessKind _kind(String? value) => switch (value) {
    'allowed' => EntitlementAccessKind.allowed,
    'denied' => EntitlementAccessKind.denied,
    'pending' => EntitlementAccessKind.pending,
    _ => EntitlementAccessKind.unavailable,
  };

  static EntitlementAccessReason _reason(String? value) => switch (value) {
    'entitled' => EntitlementAccessReason.entitled,
    'quota_reached' => EntitlementAccessReason.quotaReached,
    'capability_not_entitled' => EntitlementAccessReason.capabilityNotEntitled,
    'entitlement_inactive' => EntitlementAccessReason.entitlementInactive,
    'entitlement_missing' => EntitlementAccessReason.entitlementMissing,
    'purchase_pending' => EntitlementAccessReason.purchasePending,
    'restore_pending' => EntitlementAccessReason.restorePending,
    'reconciliation_error' => EntitlementAccessReason.reconciliationError,
    'access_preserved_during_reconciliation' => EntitlementAccessReason.accessPreservedDuringReconciliation,
    'grace_access_preserved' => EntitlementAccessReason.graceAccessPreserved,
    'active_until_expiry' => EntitlementAccessReason.activeUntilExpiry,
    _ => EntitlementAccessReason.unknown,
  };

  static int _integer(Object? value) => value is num ? value.toInt() : 0;

  static DateTime? _date(Object? value) {
    if (value is DateTime) return value.toUtc();
    if (value is String) return DateTime.tryParse(value)?.toUtc();
    return null;
  }

  static DateTime _todayUtc() {
    final now = DateTime.now().toUtc();
    return DateTime.utc(now.year, now.month, now.day);
  }

  static EntitlementAccess _unavailable(EntitlementCapability capability) {
    return EntitlementAccess(
      capability: capability,
      kind: EntitlementAccessKind.unavailable,
      reason: EntitlementAccessReason.verificationUnavailable,
      plan: 'unknown',
      entitlementStatus: 'unknown',
      reconciliationState: 'unknown',
      renewalState: 'unknown',
      periodStart: _todayUtc(),
      consumed: 0,
      limit: 0,
    );
  }
}
