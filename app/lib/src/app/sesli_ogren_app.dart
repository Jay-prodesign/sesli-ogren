import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/supabase_learner_auth.dart';
import '../domain/authenticated_learner.dart';
import 'account_entry_screen.dart';
import 'app_runtime.dart';
import 'app_theme.dart';
import 'companion_view.dart';
import 'first_run_onboarding.dart';
import 'product_shell_screen.dart';
import 'living_study_desk_home.dart';

class SesliOgrenApp extends StatefulWidget {
  const SesliOgrenApp({super.key});

  @override
  State<SesliOgrenApp> createState() => _SesliOgrenAppState();
}

class _SesliOgrenAppState extends State<SesliOgrenApp> {
  late Future<AppRuntime?> _runtimeFuture;
  AppRuntime? _runtime;
  bool _accountDeleted = false;

  @override
  void initState() {
    super.initState();
    _openRuntime();
  }

  void _openRuntime() {
    _runtimeFuture = SupabaseLearnerAuth.restoreSession().then((learner) async {
      if (learner == null) return null;
      return _openRuntimeForLearner(learner);
    });
  }

  Future<AppRuntime> _openRuntimeForLearner(AuthenticatedLearner learner) async {
    final runtime = await AppRuntime.open(learner: learner);
    _runtime = runtime;
    return runtime;
  }

  Future<void> _handleAuthenticated(AuthenticatedLearner learner) async {
    final runtime = await _openRuntimeForLearner(learner);
    if (!mounted) {
      await runtime.close();
      return;
    }
    setState(() => _runtimeFuture = Future.value(runtime));
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
    setState(_openRuntime);
  }

  void _handleAccountDeleted() {
    final runtime = _runtime;
    _runtime = null;
    if (runtime != null) {
      unawaited(runtime.close());
    }
    setState(() => _accountDeleted = true);
  }

  Future<void> _handleSignOut() async {
    await SupabaseLearnerAuth.signOutCurrentSession();
    final runtime = _runtime;
    if (runtime != null) {
      await runtime.close();
    }
    if (!mounted) return;
    _runtime = null;
    _accountDeleted = false;
    setState(() => _runtimeFuture = Future.value(null));
  }

  void _startFresh() {
    _accountDeleted = false;
    setState(_openRuntime);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sesli Öğren',
      debugShowCheckedModeBanner: false,
      theme: SesliOgrenTheme.light(),
      home: _accountDeleted
          ? _AccountDeletedScreen(onStartFresh: _startFresh)
          : FutureBuilder<AppRuntime?>(
              future: _runtimeFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done && !snapshot.hasError && snapshot.data == null) {
                  return AccountEntryScreen(onAuthenticated: _handleAuthenticated);
                }
                if (snapshot.hasData) {
                  final runtime = snapshot.data!;
                  return FirstRunOnboardingGate(
                    runtime: runtime,
                    child: const bool.fromEnvironment('LA0040_ATELIER_PREVIEW', defaultValue: false)
                        ? LivingDeskReviewScope(
                            child: ProductShellScreen(
                              runtime: runtime,
                              onAccountDeleted: _handleAccountDeleted,
                              onSignOut: _handleSignOut,
                            ),
                          )
                        : ProductShellScreen(
                            runtime: runtime,
                            onAccountDeleted: _handleAccountDeleted,
                            onSignOut: _handleSignOut,
                          ),
                  );
                }
                if (snapshot.hasError) {
                  return _RuntimeErrorScreen(error: snapshot.error!, onRetry: _retryRuntime);
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
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 72),
                  const SizedBox(height: 18),
                  Text(
                    'Hesabın ve verilerin silindi.',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Yeni bir öğrenme alanı oluşturmak istersen sıfırdan başlayabilirsin.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(onPressed: onStartFresh, child: const Text('Yeni öğrenme alanı oluştur')),
                ],
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
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CompanionView(state: CompanionVisualState.think, size: 112),
              SizedBox(height: 20),
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Öğrenme alanın hazırlanıyor…'),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuntimeErrorScreen extends StatelessWidget {
  const _RuntimeErrorScreen({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CompanionView(state: CompanionVisualState.correct, size: 112),
                  const SizedBox(height: 20),
                  Text(
                    error is LearnerAuthConfigurationException
                        ? 'Uygulama bağlantısı henüz yapılandırılmadı.'
                        : 'Güvenli öğrenme oturumu açılamadı.',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    error is LearnerAuthConfigurationException
                        ? 'Öğrenme verisi açılmadı. Güvenli bağlantı yapılandırması gerekiyor.'
                        : 'Öğrenme verisi açılmadan yeniden deneyebilirsin.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(onPressed: onRetry, child: const Text('Yeniden dene')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
