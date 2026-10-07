import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/supabase_learner_auth.dart';
import '../domain/authenticated_learner.dart';
import 'account_overview_gateway.dart';

class SupabaseAccountOverviewGateway implements AccountOverviewGateway {
  const SupabaseAccountOverviewGateway();

  @override
  Future<AccountOverview?> load({required AuthenticatedLearner learner}) async {
    try {
      final client = await SupabaseLearnerAuth.clientForAuthenticatedRuntime();
      final account = await client
          .from('accounts')
          .select('locale,status')
          .eq('id', learner.id.value)
          .maybeSingle();
      final entitlement = await client
          .from('entitlements')
          .select('plan,status')
          .eq('account_id', learner.id.value)
          .maybeSingle();
      if (account == null || entitlement == null) return null;

      final rawUsage = await client
          .from('quota_ledger')
          .select('period_start,capability,consumed')
          .eq('account_id', learner.id.value)
          .order('period_start', ascending: false)
          .limit(12);

      final usage = rawUsage.map((row) {
        final value = Map<String, dynamic>.from(row);
        return AccountUsageEntry(
          periodStart: DateTime.parse(value['period_start'] as String),
          capability: value['capability'] as String,
          consumed: value['consumed'] as int,
        );
      }).toList(growable: false);

      return AccountOverview(
        locale: account['locale'] as String? ?? 'tr-TR',
        accountStatus: account['status'] as String? ?? 'unknown',
        plan: entitlement['plan'] as String? ?? 'unknown',
        entitlementStatus: entitlement['status'] as String? ?? 'unknown',
        usage: usage,
      );
    } on PostgrestException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
