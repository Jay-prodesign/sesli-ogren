import '../domain/authenticated_learner.dart';

abstract interface class AccountOverviewGateway {
  Future<AccountOverview?> load({required AuthenticatedLearner learner});
}

class AccountOverview {
  const AccountOverview({
    required this.locale,
    required this.accountStatus,
    required this.plan,
    required this.entitlementStatus,
    required this.usage,
    this.dailyLimits = const {},
    this.reconciliationState = 'unknown',
    this.renewalState = 'unknown',
    this.effectiveUntil,
    this.lastAuthoritativeVerificationAt,
  });

  final String locale;
  final String accountStatus;
  final String plan;
  final String entitlementStatus;
  final List<AccountUsageEntry> usage;
  final Map<String, int> dailyLimits;
  final String reconciliationState;
  final String renewalState;
  final DateTime? effectiveUntil;
  final DateTime? lastAuthoritativeVerificationAt;

  int? dailyLimitForCapability(String capability) {
    final key = switch (capability) {
      'summary' => 'summary_daily',
      'explain' || 'grounded_explain' => 'explain_daily',
      'focus' => 'focus_daily',
      'explain_back' => 'explain_back_daily',
      _ => null,
    };
    return key == null ? null : dailyLimits[key];
  }
}

class AccountUsageEntry {
  const AccountUsageEntry({required this.periodStart, required this.capability, required this.consumed});

  final DateTime periodStart;
  final String capability;
  final int consumed;
}

class UnavailableAccountOverviewGateway implements AccountOverviewGateway {
  const UnavailableAccountOverviewGateway();

  @override
  Future<AccountOverview?> load({required AuthenticatedLearner learner}) async => null;
}
