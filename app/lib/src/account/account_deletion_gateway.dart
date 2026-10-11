import '../domain/authenticated_learner.dart';

abstract interface class AccountDeletionGateway {
  Future<void> deleteAccount({required AuthenticatedLearner learner});
}

class AccountDeletionException implements Exception {
  const AccountDeletionException(this.message);

  final String message;

  @override
  String toString() => 'AccountDeletionException: $message';
}

class UnavailableAccountDeletionGateway implements AccountDeletionGateway {
  const UnavailableAccountDeletionGateway();

  @override
  Future<void> deleteAccount({required AuthenticatedLearner learner}) {
    throw const AccountDeletionException('Account deletion is unavailable.');
  }
}
