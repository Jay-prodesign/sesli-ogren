import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/supabase_learner_auth.dart';
import '../domain/authenticated_learner.dart';
import 'account_entry_screen.dart';
import 'app_runtime.dart';
import 'app_theme.dart';
import 'atelier_learning_surfaces.dart';
import 'companion_view.dart';
import 'first_run_onboarding.dart';
import 'product_shell_screen.dart';
import 'living_study_desk_home.dart';

class SesliOgrenApp extends StatefulWidget {
  const SesliOgrenApp({this.restoreSession, this.openRuntime, this.openLocalRuntime, this.signOutSession, super.key});

  /// Test/review seams only. Production restores Supabase when available and
  /// otherwise opens the truthful device-local learning runtime.
  final Future<AuthenticatedLearner?> Function()? restoreSession;
  final Future<AppRuntime> Function(AuthenticatedLearner learner)? openRuntime;
  final Future<AppRuntime> Function()? openLocalRuntime;
  final Future<void> Function()? signOutSession;

  @override
  State<SesliOgrenApp> createState() => _SesliOgrenAppState();
}

class _SesliOgrenAppState extends State<SesliOgrenApp> {
  late Future<AppRuntime?> _runtimeFuture;
  AppRuntime? _runtime;
  bool _accountDeleted = false;
  bool _showAccountEntry = false;
  bool _openingAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _openRuntime();
  }

  void _openRuntime() {
    _showAccountEntry = false;
    _openingAuthenticated = false;
    _runtimeFuture = _restoreOrOpenLocal();
  }

  Future<AppRuntime> _restoreOrOpenLocal() async {
    final restoreSession = widget.restoreSession ?? SupabaseLearnerAuth.restoreSession;
    AuthenticatedLearner? learner;
    try {
      learner = await restoreSession();
    } catch (_) {
      // Optional account restore must never gate device-local learning.
      return _openLocalRuntime();
    }
    if (learner == null) return _openLocalRuntime();
    _openingAuthenticated = true;
    return _openRuntimeForLearner(learner);
  }

  Future<AppRuntime> _openLocalRuntime() async {
    _openingAuthenticated = false;
    final current = _runtime;
    final runtime = widget.openLocalRuntime != null
        ? await widget.openLocalRuntime!.call()
        : current != null
        ? current.asLocal()
        : await AppRuntime.openLocal();
    _runtime = runtime;
    return runtime;
  }

  Future<AppRuntime> _openRuntimeForLearner(AuthenticatedLearner learner) async {
    final current = _runtime;
    final runtime = widget.openRuntime != null
        ? await widget.openRuntime!.call(learner)
        : current != null
        ? current.asAuthenticated(learner)
        : await AppRuntime.open(learner: learner);
    _runtime = runtime;
    return runtime;
  }

  Future<void> _handleAuthenticated(AuthenticatedLearner learner) async {
    if (!mounted) return;
    setState(() {
      // Authentication is optional. Production rebinds the already-open local
      // data plane to the authenticated learner namespace, so local work stays
      // intact and the SQLite handle is never closed out from under the next
      // runtime.
      _showAccountEntry = false;
      _openingAuthenticated = true;
      _runtimeFuture = _openRuntimeForLearner(learner);
    });
  }

  @override
  void dispose() {
    final runtime = _runtime;
    if (runtime != null) {
      unawaited(runtime.close());
    }
    super.dispose();
  }

  void _retryRuntime() {
    final runtime = _runtime;
    if (runtime != null) {
      unawaited(runtime.close());
    }
    _runtime = null;
    _accountDeleted = false;
    _showAccountEntry = false;
    setState(_openRuntime);
  }

  void _handleAccountDeleted() {
    // Remote/account-scoped data has been removed, but the device-local
    // namespace is a separate learner_id and must remain intact.
    setState(() {
      _showAccountEntry = false;
      _openingAuthenticated = false;
      _accountDeleted = true;
    });
  }

  Future<void> _signOutSession() => (widget.signOutSession ?? SupabaseLearnerAuth.signOutCurrentSession)();

  Future<void> _handleSignOut() async {
    await _signOutSession();

    // Session sign-out is the authority boundary. The existing local data
    // plane is rebound to the device-local namespace; no account gate and no
    // database close/reopen race sits between the learner and local study.
    if (mounted) {
      setState(() {
        _accountDeleted = false;
        _showAccountEntry = false;
        _openingAuthenticated = false;
        _runtimeFuture = _openLocalRuntime();
      });
    }
  }

  Future<void> _returnToAccountEntryAfterRuntimeFailure() async {
    await _signOutSession();

    // If an optional account runtime cannot open, preserve any already-open
    // device-local runtime so "Hesapsız devam et" remains a truthful recovery.
    if (mounted) {
      setState(() {
        _accountDeleted = false;
        _showAccountEntry = true;
        _openingAuthenticated = false;
      });
    }
  }

  void _startFresh() {
    setState(() {
      _accountDeleted = false;
      _showAccountEntry = false;
      _openingAuthenticated = false;
      _runtimeFuture = _openLocalRuntime();
    });
  }

  void _openAccountEntry() {
    setState(() => _showAccountEntry = true);
  }

  void _continueWithoutAccount() {
    setState(() {
      _showAccountEntry = false;
      if (_runtime == null) {
        _runtimeFuture = _openLocalRuntime();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sesli Öğren',
      debugShowCheckedModeBanner: false,
      theme: SesliOgrenTheme.light(),
      home: _accountDeleted
          ? _AccountDeletedScreen(onStartFresh: _startFresh)
          : _showAccountEntry
          ? AccountEntryScreen(onAuthenticated: _handleAuthenticated, onContinueWithoutAccount: _continueWithoutAccount)
          : FutureBuilder<AppRuntime?>(
              future: _runtimeFuture,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final runtime = snapshot.data!;
                  return FirstRunOnboardingGate(
                    child: LivingDeskReviewScope(
                      child: ProductShellScreen(
                        runtime: runtime,
                        onAccountDeleted: runtime.learner.isAuthenticated ? _handleAccountDeleted : null,
                        onSignOut: runtime.learner.isAuthenticated ? _handleSignOut : null,
                        onConnectAccount: runtime.learner.isLocal ? _openAccountEntry : null,
                      ),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return _RuntimeErrorScreen(
                    error: snapshot.error!,
                    onRetry: _retryRuntime,
                    onUseAnotherAccount: _openingAuthenticated ? _returnToAccountEntryAfterRuntimeFailure : null,
                  );
                }
                return const _RuntimeLoadingScreen();
              },
            ),
    );
  }
}

class _AccountDeletedScreen extends StatelessWidget {
  const _AccountDeletedScreen({required this.onStartFresh});

  final VoidCallback onStartFresh;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AtelierStyle.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            key: const ValueKey('account-deleted-scroll'),
            child: ConstrainedBox(
              constraints: const BoxConstraints(),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AtelierStyle.focus,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [BoxShadow(color: Color(0x1A14224A), blurRadius: 30, offset: Offset(0, 16))],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CompanionView(state: CompanionVisualState.success, size: 96),
                            const SizedBox(height: 18),
                            const Text(
                              'HESAP SİLİNDİ',
                              style: TextStyle(
                                color: AtelierStyle.mark,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.9,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Hesabın ve hesaba bağlı verilerin silindi.',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Bu cihazdaki hesapsız öğrenme alanın ayrı tutulduğu için korunur. İstersen doğrudan yerel çalışmalarına dönebilirsin.',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.76), height: 1.45),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 22),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AtelierStyle.pulse,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(52),
                                ),
                                onPressed: onStartFresh,
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Cihazdaki öğrenmeye dön'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RuntimeLoadingScreen extends StatelessWidget {
  const _RuntimeLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AtelierStyle.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 390),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AtelierStyle.focus,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [BoxShadow(color: Color(0x1A14224A), blurRadius: 30, offset: Offset(0, 16))],
                      ),
                      child: const Padding(
                        padding: EdgeInsets.fromLTRB(22, 22, 22, 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CompanionView(state: CompanionVisualState.think, size: 96),
                            SizedBox(height: 18),
                            Text(
                              'ÇALIŞMA MASAN HAZIRLANIYOR',
                              style: TextStyle(
                                color: AtelierStyle.mark,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.9,
                              ),
                            ),
                            SizedBox(height: 9),
                            Text(
                              'Öğrenme alanın hazırlanıyor…',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                height: 1.15,
                                fontWeight: FontWeight.w900,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 16),
                            LinearProgressIndicator(
                              color: AtelierStyle.aqua,
                              backgroundColor: Color(0x26FFFFFF),
                              borderRadius: BorderRadius.all(Radius.circular(99)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RuntimeErrorScreen extends StatefulWidget {
  const _RuntimeErrorScreen({required this.error, required this.onRetry, required this.onUseAnotherAccount});

  final Object error;
  final VoidCallback onRetry;
  final Future<void> Function()? onUseAnotherAccount;

  @override
  State<_RuntimeErrorScreen> createState() => _RuntimeErrorScreenState();
}

class _RuntimeErrorScreenState extends State<_RuntimeErrorScreen> {
  bool _switchingAccount = false;
  String? _switchError;

  Future<void> _useAnotherAccount() async {
    final callback = widget.onUseAnotherAccount;
    if (callback == null || _switchingAccount) return;
    setState(() {
      _switchingAccount = true;
      _switchError = null;
    });
    try {
      await callback();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _switchError = 'Oturum güvenle kapatılamadı. Mevcut hesap açık kalıyor; tekrar deneyebilirsin.';
      });
    } finally {
      if (mounted) setState(() => _switchingAccount = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configurationError = widget.error is LearnerAuthConfigurationException;
    return Scaffold(
      backgroundColor: AtelierStyle.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            key: const ValueKey('runtime-error-scroll'),
            child: ConstrainedBox(
              constraints: const BoxConstraints(),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AtelierStyle.focus,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [BoxShadow(color: Color(0x1A14224A), blurRadius: 30, offset: Offset(0, 16))],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CompanionView(state: CompanionVisualState.think, size: 96),
                            const SizedBox(height: 16),
                            const Text(
                              'GÜVENLİ DURAK',
                              style: TextStyle(
                                color: AtelierStyle.mark,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.9,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              configurationError
                                  ? 'Uygulama bağlantısı henüz yapılandırılmadı.'
                                  : 'Güvenli öğrenme oturumu açılamadı.',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              configurationError
                                  ? 'Öğrenme verisi açılmadı. Güvenli bağlantı yapılandırması gerekiyor.'
                                  : 'Öğrenme verisi açılmadan yeniden deneyebilir veya başka bir hesapla giriş yapabilirsin.',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.76), height: 1.45),
                              textAlign: TextAlign.center,
                            ),
                            if (_switchError != null) ...[
                              const SizedBox(height: 12),
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  _switchError!,
                                  style: const TextStyle(color: Color(0xFFFFB9BE), height: 1.4),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AtelierStyle.pulse,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _switchingAccount ? null : widget.onRetry,
                              child: const Text('Yeniden dene'),
                            ),
                            if (widget.onUseAnotherAccount != null) ...[
                              const SizedBox(height: 8),
                              TextButton.icon(
                                style: TextButton.styleFrom(foregroundColor: AtelierStyle.aqua),
                                onPressed: _switchingAccount ? null : _useAnotherAccount,
                                icon: _switchingAccount
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.switch_account_outlined),
                                label: Text(_switchingAccount ? 'Oturum kapatılıyor…' : 'Başka hesapla giriş yap'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
