import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/supabase_learner_auth.dart';
import '../domain/authenticated_learner.dart';
import 'account_deletion_gateway.dart';

class SupabaseAccountDeletionGateway implements AccountDeletionGateway {
  const SupabaseAccountDeletionGateway();

  @override
  Future<void> deleteAccount({required AuthenticatedLearner learner}) async {
    final client = await SupabaseLearnerAuth.clientForAuthenticatedRuntime();
    final session = client.auth.currentSession;
    if (session == null || session.user.id != learner.id.value) {
      throw const AccountDeletionException('Authenticated learner session does not match the deletion request.');
    }

    try {
      final response = await client.functions.invoke(
        'delete-account',
        body: const {'confirmation': 'DELETE_MY_ACCOUNT'},
      );
      final data = response.data;
      if (data is! Map || data['deleted'] != true) {
        throw const AccountDeletionException('Server did not confirm account deletion.');
      }

      try {
        await client.auth.signOut(scope: SignOutScope.local);
      } catch (_) {}
    } on AccountDeletionException {
      rethrow;
    } catch (_) {
      throw const AccountDeletionException('Account deletion could not be completed.');
    }
  }
}
