import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/authenticated_learner.dart';

class SupabaseLearnerAuth {
  SupabaseLearnerAuth._();

  // Publishable keys are client credentials, not secrets. Mobile binaries
  // expose them by design; access control still comes from the user's Auth JWT
  // plus RLS/RPC ownership checks. Dart defines remain available for alternate
  // review/staging environments.
  static const _projectUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://detldfcvoxjuqstkaayd.supabase.co',
  );
  static const _publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_iNQgTRI7B2I7VVAWQx4Czg_aUs68WRo',
  );

  static SupabaseClient? _client;
  static Future<SupabaseClient>? _initializing;

  static Future<AuthenticatedLearner?> restoreSession() async {
    final client = await _clientForConfiguredProject();
    final currentUser = client.auth.currentSession?.user;
    if (currentUser == null) return null;
    return AuthenticatedLearner(id: LearnerId(currentUser.id));
  }

  /// Opens a real, RLS-scoped anonymous session without requiring an email.
  /// Anonymous access must be enabled in the configured Supabase project.
  static Future<AuthenticatedLearner> signInAsGuest() async {
    final client = await _clientForConfiguredProject();
    try {
      final response = await client.auth.signInAnonymously();
      final user = response.user;
      if (user == null || response.session == null) {
        throw const LearnerAuthenticationException('Misafir oturumu açılamadı.');
      }
      return AuthenticatedLearner(id: LearnerId(user.id));
    } on LearnerAuthenticationException {
      rethrow;
    } catch (_) {
      throw const LearnerAuthenticationException(
        'Misafir girişi şu anda kullanılamıyor. Yeniden dene veya e-posta ile giriş yap.',
      );
    }
  }

  /// Starts linking an email to the *current* anonymous identity.
  /// Unlike signInWithOtp, this does not intentionally switch learner IDs.
  static Future<bool> isCurrentSessionGuest() async {
    final client = await _clientForConfiguredProject();
    return client.auth.currentUser?.isAnonymous == true;
  }

  static Future<void> requestGuestEmailLink(String email) async {
    final normalized = _normalizedEmail(email);
    final client = await _clientForConfiguredProject();
    final user = client.auth.currentUser;
    if (user == null || !user.isAnonymous) {
      throw const LearnerAuthenticationException('Bağlanacak bir misafir oturumu bulunamadı.');
    }
    try {
      await client.auth.updateUser(UserAttributes(email: normalized));
    } catch (_) {
      throw const LearnerAuthenticationException(
        'E-posta bağlama başlatılamadı. Adres kullanımda olabilir veya bağlantı geçici olarak kullanılamıyor.',
      );
    }
  }

  /// Completes the email-change verification without changing learner ownership.
  static Future<AuthenticatedLearner> verifyGuestEmailLink({
    required String email,
    required String token,
  }) async {
    final normalized = _normalizedEmail(email);
    final normalizedToken = token.trim();
    if (normalizedToken.length != 6 || int.tryParse(normalizedToken) == null) {
      throw const LearnerAuthenticationException('Doğrulama kodu 6 haneli olmalı.');
    }
    final client = await _clientForConfiguredProject();
    final before = client.auth.currentUser;
    if (before == null || !before.isAnonymous) {
      throw const LearnerAuthenticationException('Misafir oturumu artık aktif değil.');
    }
    try {
      await client.auth.verifyOTP(
        email: normalized,
        token: normalizedToken,
        type: OtpType.emailChange,
      );
      final after = client.auth.currentUser;
      if (after == null || after.id != before.id || after.isAnonymous) {
        throw const LearnerAuthenticationException(
          'Hesap kimliği korunarak bağlanamadı. Çıkış yapma veya verileri silme.',
        );
      }
      return AuthenticatedLearner(id: LearnerId(after.id));
    } on LearnerAuthenticationException {
      rethrow;
    } catch (_) {
      throw const LearnerAuthenticationException('E-posta doğrulanamadı. Kodu kontrol et.');
    }
  }

  static Future<void> requestEmailOtp(String email) async {
    final normalized = _normalizedEmail(email);
    final client = await _clientForConfiguredProject();
    if (client.auth.currentUser?.isAnonymous == true) {
      throw const LearnerAuthenticationException(
        'Misafir verilerini korumak için önce hesap bağlama akışını kullan.',
      );
    }
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

  static Future<void> signOutCurrentSession() async {
    final client = await _clientForConfiguredProject();
    try {
      await client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {
      throw const LearnerAuthenticationException('Bu cihazdaki oturum kapatılamadı.');
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
).hasMatch(normalizedToken)) {
      throw const LearnerAuthenticationException('Doğrulama kodu 6 haneli olmalı.');
    }
    final client = await _clientForConfiguredProject();
    final before = client.auth.currentUser;
    if (before == null || !before.isAnonymous) {
      throw const LearnerAuthenticationException('Misafir oturumu artık aktif değil.');
    }
    try {
      await client.auth.verifyOTP(
        email: normalized,
        token: normalizedToken,
        type: OtpType.emailChange,
      );
      final after = client.auth.currentUser;
      if (after == null || after.id != before.id || after.isAnonymous) {
        throw const LearnerAuthenticationException(
          'Kimlik korunarak hesap bağlama doğrulanamadı. Mevcut verileri silme veya çıkış yapma.',
        );
      }
      return AuthenticatedLearner(id: LearnerId(after.id));
    } on LearnerAuthenticationException {
      rethrow;
    } catch (_) {
      throw const LearnerAuthenticationException('E-posta doğrulanamadı. Yeni kod veya bağlantı iste.');
    }
  }

  static Future<void> requestEmailOtp(String email) async {
    final normalized = _normalizedEmail(email);
    final client = await _clientForConfiguredProject();
    // Signing in with OTP creates/switches identity; it is NOT an upgrade of an
    // anonymous learner. Never silently strand that learner's source/evidence.
    if (client.auth.currentUser?.isAnonymous == true) {
      throw const LearnerAuthenticationException(
        'Misafir ilerlemeni korumak için hesap bağlama henüz hazır değil. Bu oturumda öğrenmeye devam edebilirsin.',
      );
    }
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

  static Future<void> signOutCurrentSession() async {
    final client = await _clientForConfiguredProject();
    try {
      await client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {
      throw const LearnerAuthenticationException('Bu cihazdaki oturum kapatılamadı.');
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
