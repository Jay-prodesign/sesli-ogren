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
  });

  final String locale;
  final String accountStatus;
  final String plan;
  final String entitlementStatus;
  final List<AccountUsageEntry> usage;
}

class AccountUsageEntry {
  const AccountUsageEntry({
    required this.periodStart,
    required this.capability,
    required this.consumed,
  });

  final DateTime periodStart;
  final String capability;
  final int consumed;
}

class UnavailableAccountOverviewGateway implements AccountOverviewGateway {
  const UnavailableAccountOverviewGateway();

  @override
  Future<AccountOverview?> load({required AuthenticatedLearner learner}) async => null;
}
