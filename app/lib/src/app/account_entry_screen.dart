import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/supabase_learner_auth.dart';
import '../domain/authenticated_learner.dart';
import 'atelier_learning_surfaces.dart';
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

  static const _resendCooldown = Duration(seconds: 30);

  bool _codeRequested = false;
  bool _busy = false;
  String? _error;
  String? _status;
  DateTime? _lastCodeRequestedAt;

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  bool _validEmail(String value) {
    if (value.isEmpty || value.length > 254 || RegExp(r'\s').hasMatch(value)) return false;
    final at = value.indexOf('@');
    if (at <= 0 || at != value.lastIndexOf('@')) return false;
    final domain = value.substring(at + 1);
    final dot = domain.lastIndexOf('.');
    return dot > 0 && dot < domain.length - 1;
  }

  Future<void> _requestCode() async {
    if (_busy) return;
    final email = _emailController.text.trim();
    if (_codeRequested && _lastCodeRequestedAt != null) {
      final elapsed = DateTime.now().difference(_lastCodeRequestedAt!);
      if (elapsed < _resendCooldown) {
        final remaining = (_resendCooldown - elapsed).inSeconds + 1;
        setState(() {
          _error = null;
          _status = 'Yeni kod istemek için $remaining saniye bekle.';
        });
        return;
      }
    }
    if (!_validEmail(email)) {
      setState(() => _error = 'Geçerli bir e-posta adresi gir.');
      return;
    }

    final resending = _codeRequested;
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });
    try {
      await widget.requestOtp(email);
      if (!mounted) return;
      setState(() {
        _codeRequested = true;
        _lastCodeRequestedAt = DateTime.now();
        _tokenController.clear();
        _status = resending ? 'Yeni kod gönderildi. En son gelen kodu kullan.' : 'Kod gönderildi. E-postanı kontrol et.';
      });
    } on LearnerAuthenticationException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _status = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Giriş kodu gönderilemedi. Tekrar deneyebilirsin.';
        _status = null;
      });
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
      _lastCodeRequestedAt = null;
      _tokenController.clear();
      _error = null;
      _status = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AtelierStyle.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      SizedBox(
                        width: 8,
                        height: 28,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AtelierStyle.teal,
                            borderRadius: BorderRadius.all(Radius.circular(3)),
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'sesli öğren',
                        style: TextStyle(
                          color: AtelierStyle.ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.fromLTRB(22, 22, 18, 22),
                    decoration: BoxDecoration(color: AtelierStyle.ink, borderRadius: BorderRadius.circular(24)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'KENDİ KAYNAĞIN · GERÇEK HATIRLAMA',
                          style: TextStyle(
                            color: AtelierStyle.mark,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 9),
                        const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                'Çalışma alanın burada başlar.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 29,
                                  height: 1.08,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.8,
                                ),
                              ),
                            ),
                            SizedBox(width: 6),
                            CompanionView(state: CompanionVisualState.idle, size: 92),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'PDF veya metnini ekle. Kaynağı aç, kapatıp hatırla; sonra yanıtını kaynak kanıtıyla karşılaştır.',
                          style: TextStyle(color: Color(0xFFDCE8E5), fontSize: 14, height: 1.45),
                        ),
                        const SizedBox(height: 18),
                        const Row(
                          children: [
                            Expanded(
                              child: _EntryJourneyStep(icon: Icons.auto_stories_outlined, label: 'KAYNAK'),
                            ),
                            _EntryJourneyArrow(),
                            Expanded(
                              child: _EntryJourneyStep(icon: Icons.visibility_off_outlined, label: 'KAPAT'),
                            ),
                            _EntryJourneyArrow(),
                            Expanded(
                              child: _EntryJourneyStep(icon: Icons.psychology_alt_outlined, label: 'HATIRLA'),
                            ),
                            _EntryJourneyArrow(),
                            Expanded(
                              child: _EntryJourneyStep(icon: Icons.find_in_page_outlined, label: 'KANIT'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                    decoration: BoxDecoration(
                      color: AtelierStyle.paper,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AtelierStyle.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _codeRequested ? 'Kodunu gir' : 'Öğrenme alanına gir',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: AtelierStyle.ink,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _codeRequested
                              ? '${_emailController.text.trim()} adresine gönderilen 6 haneli kodu gir.'
                              : 'E-posta adresinle giriş yap veya yeni hesabını oluştur. Şifre gerekmiyor.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: AtelierStyle.muted, height: 1.45),
                        ),
                        const SizedBox(height: 20),
                        if (!_codeRequested)
                          TextField(
                            controller: _emailController,
                            enabled: !_busy,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            autocorrect: false,
                            enableSuggestions: false,
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
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            textInputAction: TextInputAction.done,
                            maxLength: 6,
                            onSubmitted: (_) => _verifyCode(),
                            decoration: const InputDecoration(labelText: '6 haneli kod', counterText: ''),
                          ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              _error!,
                              style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ] else if (_status != null) ...[
                          const SizedBox(height: 12),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              _status!,
                              style: const TextStyle(color: AtelierStyle.teal, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AtelierStyle.teal,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(54),
                            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.05),
                          ),
                          onPressed: _busy ? null : (_codeRequested ? _verifyCode : _requestCode),
                          child: Text(
                            _busy
                                ? 'Kontrol ediliyor…'
                                : _codeRequested
                                ? 'Giriş yap'
                                : 'Kod gönder',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        if (_codeRequested) ...[
                          const SizedBox(height: 8),
                          TextButton(onPressed: _busy ? null : _requestCode, child: const Text('Yeni kod gönder')),
                          TextButton(onPressed: _busy ? null : _changeEmail, child: const Text('E-postayı değiştir')),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 17, color: AtelierStyle.teal),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Hesabın, bu cihazdaki materyal ve öğrenme geçmişini doğru kullanıcıyla ayrı tutmak için kullanılır.',
                          style: TextStyle(color: AtelierStyle.muted, fontSize: 12, height: 1.4),
                        ),
                      ),
                    ],
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

class _EntryJourneyStep extends StatelessWidget {
  const _EntryJourneyStep({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, color: AtelierStyle.mark, size: 19),
      const SizedBox(height: 6),
      Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.fade,
        softWrap: false,
        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.4),
      ),
    ],
  );
}

class _EntryJourneyArrow extends StatelessWidget {
  const _EntryJourneyArrow();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 4),
    child: Icon(Icons.arrow_forward_rounded, color: Color(0xFF8DA7A1), size: 16),
  );
}
