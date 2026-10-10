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
      final account = await client.from('accounts').select('locale,status').eq('id', learner.id.value).maybeSingle();
      final entitlement = await client
          .from('entitlements')
          .select('plan,status,limits')
          .eq('account_id', learner.id.value)
          .maybeSingle();
      if (account == null || entitlement == null) return null;

      final now = DateTime.now().toUtc();
      final periodStart =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final rawUsage = await client
          .from('quota_ledger')
          .select('period_start,capability,consumed')
          .eq('account_id', learner.id.value)
          .eq('period_start', periodStart)
          .order('capability');

      final usage = rawUsage
          .map((row) {
            final value = Map<String, dynamic>.from(row);
            return AccountUsageEntry(
              periodStart: DateTime.parse(value['period_start'] as String),
              capability: value['capability'] as String,
              consumed: value['consumed'] as int,
            );
          })
          .toList(growable: false);

      final dailyLimits = <String, int>{};
      final rawLimits = entitlement['limits'];
      if (rawLimits is Map) {
        for (final entry in rawLimits.entries) {
          final key = entry.key;
          final value = entry.value;
          if (key is String && value is int && value >= 0) {
            dailyLimits[key] = value;
          }
        }
      }

      return AccountOverview(
        locale: account['locale'] as String? ?? 'tr-TR',
        accountStatus: account['status'] as String? ?? 'unknown',
        plan: entitlement['plan'] as String? ?? 'unknown',
        entitlementStatus: entitlement['status'] as String? ?? 'unknown',
        usage: usage,
        dailyLimits: Map.unmodifiable(dailyLimits),
      );
    } on PostgrestException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
