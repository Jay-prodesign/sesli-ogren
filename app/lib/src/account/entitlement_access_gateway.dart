enum EntitlementCapability { summary, explain, focus, explainBack }

extension EntitlementCapabilityProduct on EntitlementCapability {
  String get wireKey => switch (this) {
    EntitlementCapability.summary => 'summary',
    EntitlementCapability.explain => 'explain',
    EntitlementCapability.focus => 'focus',
    EntitlementCapability.explainBack => 'explain_back',
  };

  String get label => switch (this) {
    EntitlementCapability.summary => 'Kaynağa bağlı özet',
    EntitlementCapability.explain => 'Kaynağı açıkla',
    EntitlementCapability.focus => 'Odak yardımı',
    EntitlementCapability.explainBack => 'Anlatım değerlendirmesi',
  };
}

enum CapabilityAccessDisposition { allowed, blocked, unavailable }

enum CapabilityAccessReason {
  allowed,
  quotaReached,
  capabilityNotEntitled,
  entitlementInactive,
  entitlementMissing,
  capabilityNotConfigured,
  unavailable,
}

class CapabilityAccessDecision {
  const CapabilityAccessDecision({
    required this.capability,
    required this.disposition,
    required this.reason,
    this.plan,
    this.entitlementStatus,
    this.limit,
    this.consumed = 0,
    this.reserved = 0,
    this.remaining,
    this.effectiveUntil,
    this.entitlementUpdatedAt,
  });

  final EntitlementCapability capability;
  final CapabilityAccessDisposition disposition;
  final CapabilityAccessReason reason;
  final String? plan;
  final String? entitlementStatus;
  final int? limit;
  final int consumed;
  final int reserved;
  final int? remaining;
  final DateTime? effectiveUntil;
  final DateTime? entitlementUpdatedAt;

  bool get isAllowed => disposition == CapabilityAccessDisposition.allowed;
  bool get isBlocked => disposition == CapabilityAccessDisposition.blocked;

  int get authoritativeUsed => consumed + reserved;
}

abstract interface class EntitlementAccessGateway {
  Future<CapabilityAccessDecision> check(EntitlementCapability capability);
}

class UnavailableEntitlementAccessGateway implements EntitlementAccessGateway {
  const UnavailableEntitlementAccessGateway();

  @override
  Future<CapabilityAccessDecision> check(EntitlementCapability capability) async => CapabilityAccessDecision(
    capability: capability,
    disposition: CapabilityAccessDisposition.unavailable,
    reason: CapabilityAccessReason.unavailable,
  );
}
