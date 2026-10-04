import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/authenticated_learner.dart';

class SupabaseLearnerAuth {
  SupabaseLearnerAuth._();

  static const _projectUrl = String.fromEnvironment('SUPABASE_URL');
  static const _publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static SupabaseClient? _client;
  static Future<SupabaseClient>? _initializing;

  static Future<AuthenticatedLearner> authenticate() async {
    final client = await _clientForConfiguredProject();
    final currentUser = client.auth.currentSession?.user;
    if (currentUser != null) {
      return AuthenticatedLearner(id: LearnerId(currentUser.id));
    }

    try {
      final response = await client.auth.signInAnonymously();
      final user = response.user;
      final session = response.session;
      if (user == null || session == null) {
        throw const LearnerAuthenticationException(
          'Authentication completed without a durable session.',
        );
      }
      return AuthenticatedLearner(id: LearnerId(user.id));
    } on LearnerAuthenticationException {
      rethrow;
    } catch (_) {
      throw const LearnerAuthenticationException(
        'A learner session could not be established.',
      );
    }
  }

  static Future<SupabaseClient> _clientForConfiguredProject() async {
    if (_projectUrl.trim().isEmpty || _publishableKey.trim().isEmpty) {
      throw const LearnerAuthConfigurationException(
        'Supabase client configuration is missing.',
      );
    }

    final existing = _client;
    if (existing != null) {
      return existing;
    }

    final initializing = _initializing ??= _initializeClient();
    try {
      final client = await initializing;
      _client = client;
      return client;
    } finally {
      _initializing = null;
    }
  }

  static Future<SupabaseClient> _initializeClient() async {
    try {
      await Supabase.initialize(
        url: _projectUrl,
        anonKey: _publishableKey,
      );
      return Supabase.instance.client;
    } catch (_) {
      throw const LearnerAuthenticationException(
        'Authentication service could not be initialized.',
      );
    }
  }
}

class LearnerAuthConfigurationException implements Exception {
  const LearnerAuthConfigurationException(this.message);

  final String message;

  @override
  String toString() => 'LearnerAuthConfigurationException: $message';
}

class LearnerAuthenticationException implements Exception {
  const LearnerAuthenticationException(this.message);

  final String message;

  @override
  String toString() => 'LearnerAuthenticationException: $message';
}
