import '../domain/authenticated_learner.dart';

enum EntitlementCapability { summary, explain, focus, explainBack }

extension EntitlementCapabilityWire on EntitlementCapability {
  String get wireValue => switch (this) {
    EntitlementCapability.summary => 'summary',
    EntitlementCapability.explain => 'explain',
    EntitlementCapability.focus => 'focus',
    EntitlementCapability.explainBack => 'explain_back',
  };

  String get displayLabel => switch (this) {
    EntitlementCapability.summary => 'Hızlı özet',
    EntitlementCapability.explain => 'Kaynağa dayalı açıklama',
    EntitlementCapability.focus => 'Odak AI yardımı',
    EntitlementCapability.explainBack => 'Anlatım değerlendirme',
  };
}

enum EntitlementAccessKind { allowed, denied, pending, unavailable }

enum EntitlementAccessReason {
  entitled,
  quotaReached,
  capabilityNotEntitled,
  entitlementInactive,
  entitlementMissing,
  purchasePending,
  restorePending,
  reconciliationError,
  accessPreservedDuringReconciliation,
  graceAccessPreserved,
  activeUntilExpiry,
  verificationUnavailable,
  unknown,
}

class EntitlementAccess {
  const EntitlementAccess({
    required this.capability,
    required this.kind,
    required this.reason,
    required this.plan,
    required this.entitlementStatus,
    required this.reconciliationState,
    required this.renewalState,
    required this.periodStart,
    required this.consumed,
    required this.limit,
    this.effectiveUntil,
    this.lastAuthoritativeVerificationAt,
  });

  final EntitlementCapability capability;
  final EntitlementAccessKind kind;
  final EntitlementAccessReason reason;
  final String plan;
  final String entitlementStatus;
  final String reconciliationState;
  final String renewalState;
  final DateTime periodStart;
  final int consumed;
  final int limit;
  final DateTime? effectiveUntil;
  final DateTime? lastAuthoritativeVerificationAt;

  bool get isAllowed => kind == EntitlementAccessKind.allowed;

  bool get shouldShowUpgradeBoundary =>
      kind == EntitlementAccessKind.denied &&
      (reason == EntitlementAccessReason.quotaReached ||
          reason == EntitlementAccessReason.capabilityNotEntitled ||
          reason == EntitlementAccessReason.entitlementInactive ||
          reason == EntitlementAccessReason.entitlementMissing);
}

abstract interface class EntitlementAccessGateway {
  Future<EntitlementAccess> check({
    required AuthenticatedLearner learner,
    required EntitlementCapability capability,
  });
}

class UnavailableEntitlementAccessGateway implements EntitlementAccessGateway {
  const UnavailableEntitlementAccessGateway();

  @override
  Future<EntitlementAccess> check({
    required AuthenticatedLearner learner,
    required EntitlementCapability capability,
  }) async {
    final now = DateTime.now().toUtc();
    return EntitlementAccess(
      capability: capability,
      kind: EntitlementAccessKind.unavailable,
      reason: EntitlementAccessReason.verificationUnavailable,
      plan: 'unknown',
      entitlementStatus: 'unknown',
      reconciliationState: 'unknown',
      renewalState: 'unknown',
      periodStart: DateTime.utc(now.year, now.month, now.day),
      consumed: 0,
      limit: 0,
    );
  }
}
