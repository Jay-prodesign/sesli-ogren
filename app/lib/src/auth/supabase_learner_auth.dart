import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/authenticated_learner.dart';

class SupabaseLearnerAuth {
  SupabaseLearnerAuth._();

  static const _projectUrl = String.fromEnvironment('SUPABASE_URL');
  static const _publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static SupabaseClient? _client;
  static Future<SupabaseClient>? _initializing;

  static Future<AuthenticatedLearner?> restoreSession() async {
    final client = await _clientForConfiguredProject();
    final currentUser = client.auth.currentSession?.user;
    if (currentUser == null) return null;
    return AuthenticatedLearner(id: LearnerId(currentUser.id));
  }

  static Future<void> requestEmailOtp(String email) async {
    final normalized = _normalizedEmail(email);
    final client = await _clientForConfiguredProject();
    try {
      await client.auth.signInWithOtp(email: normalized, shouldCreateUser: true);
    } catch (_) {
      throw const LearnerAuthenticationException('Giriş kodu gönderilemedi.');
    }
  }

  static Future<AuthenticatedLearner> verifyEmailOtp({required String email, required String token}) async {
    final normalized = _normalizedEmail(email);
    final normalizedToken = token.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(normalizedToken)) {
      throw const LearnerAuthenticationException('Giriş kodu 6 haneli olmalı.');
    }

    final client = await _clientForConfiguredProject();
    try {
      final response = await client.auth.verifyOTP(email: normalized, token: normalizedToken, type: OtpType.email);
      final user = response.user;
      final session = response.session;
      if (user == null || session == null) {
        throw const LearnerAuthenticationException('Doğrulama tamamlandı ancak güvenli oturum açılamadı.');
      }
      return AuthenticatedLearner(id: LearnerId(user.id));
    } on LearnerAuthenticationException {
      rethrow;
    } catch (_) {
      throw const LearnerAuthenticationException('Giriş kodu doğrulanamadı.');
    }
  }

  static Future<SupabaseClient> clientForAuthenticatedRuntime() => _clientForConfiguredProject();

  static Future<SupabaseClient> _clientForConfiguredProject() async {
    if (_projectUrl.trim().isEmpty || _publishableKey.trim().isEmpty) {
      throw const LearnerAuthConfigurationException('Supabase client configuration is missing.');
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

  static String _normalizedEmail(String email) {
    final normalized = email.trim().toLowerCase();
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(normalized) || normalized.length > 254) {
      throw const LearnerAuthenticationException('Geçerli bir e-posta adresi gir.');
    }
    return normalized;
  }

  static Future<SupabaseClient> _initializeClient() async {
    try {
      await Supabase.initialize(url: _projectUrl, publishableKey: _publishableKey);
      return Supabase.instance.client;
    } catch (_) {
      throw const LearnerAuthenticationException('Authentication service could not be initialized.');
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
