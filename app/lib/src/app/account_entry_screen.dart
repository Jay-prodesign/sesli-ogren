import 'package:flutter/material.dart';

import '../auth/supabase_learner_auth.dart';
import '../domain/authenticated_learner.dart';
import 'companion_view.dart';

class AccountEntryScreen extends StatefulWidget {
  const AccountEntryScreen({
    required this.onAuthenticated,
    this.requestOtp = SupabaseLearnerAuth.requestEmailOtp,
    this.verifyOtp = SupabaseLearnerAuth.verifyEmailOtp,
    super.key,
  });

  final Future<void> Function(AuthenticatedLearner learner) onAuthenticated;
  final Future<void> Function(String email) requestOtp;
  final Future<AuthenticatedLearner> Function({required String email, required String token}) verifyOtp;

  @override
  State<AccountEntryScreen> createState() => _AccountEntryScreenState();
}

class _AccountEntryScreenState extends State<AccountEntryScreen> {
  final _emailController = TextEditingController();
  final _tokenController = TextEditingController();

  bool _codeRequested = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (_busy) return;
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'E-posta adresini gir.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.requestOtp(email);
      if (!mounted) return;
      setState(() {
        _codeRequested = true;
        _tokenController.clear();
      });
    } on LearnerAuthenticationException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Giriş kodu gönderilemedi. Tekrar deneyebilirsin.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyCode() async {
    if (_busy) return;
    final email = _emailController.text.trim();
    final token = _tokenController.text.trim();
    if (token.length != 6) {
      setState(() => _error = 'E-postandaki 6 haneli kodu gir.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final learner = await widget.verifyOtp(email: email, token: token);
      await widget.onAuthenticated(learner);
    } on LearnerAuthenticationException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Kod doğrulanamadı. Yeni bir kod isteyebilirsin.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _changeEmail() {
    if (_busy) return;
    setState(() {
      _codeRequested = false;
      _tokenController.clear();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: CompanionView(state: CompanionVisualState.idle, size: 116)),
                  const SizedBox(height: 24),
                  Text(
                    _codeRequested ? 'Kodunu gir' : 'Öğrenme alanına gir',
                    style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _codeRequested
                        ? '${_emailController.text.trim()} adresine gönderilen 6 haneli kodu gir.'
                        : 'E-posta adresinle giriş yap veya yeni hesabını oluştur. Şifre gerekmiyor.',
                    style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  if (!_codeRequested)
                    TextField(
                      controller: _emailController,
                      enabled: !_busy,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _requestCode(),
                      decoration: const InputDecoration(labelText: 'E-posta', hintText: 'ornek@eposta.com'),
                    )
                  else
                    TextField(
                      controller: _tokenController,
                      enabled: !_busy,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      textInputAction: TextInputAction.done,
                      maxLength: 6,
                      onSubmitted: (_) => _verifyCode(),
                      decoration: const InputDecoration(labelText: '6 haneli kod', counterText: ''),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _busy ? null : (_codeRequested ? _verifyCode : _requestCode),
                    child: Text(
                      _busy
                          ? 'Kontrol ediliyor…'
                          : _codeRequested
                          ? 'Giriş yap'
                          : 'Kod gönder',
                    ),
                  ),
                  if (_codeRequested) ...[
                    const SizedBox(height: 8),
                    TextButton(onPressed: _busy ? null : _requestCode, child: const Text('Yeni kod gönder')),
                    TextButton(onPressed: _busy ? null : _changeEmail, child: const Text('E-postayı değiştir')),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    'Hesabın, materyal ve öğrenme geçmişini aynı kimlikle geri açabilmek için kullanılır.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
