import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/supabase_learner_auth.dart';
import 'app_runtime.dart';
import 'companion_view.dart';
import 'learning_slice_screen.dart';

class SesliOgrenApp extends StatefulWidget {
  const SesliOgrenApp({super.key});

  @override
  State<SesliOgrenApp> createState() => _SesliOgrenAppState();
}

class _SesliOgrenAppState extends State<SesliOgrenApp> {
  late Future<AppRuntime> _runtimeFuture;
  AppRuntime? _runtime;

  @override
  void initState() {
    super.initState();
    _openRuntime();
  }

  void _openRuntime() {
    _runtimeFuture = SupabaseLearnerAuth.authenticate().then((learner) => AppRuntime.open(learner: learner)).then((
      runtime,
    ) {
      _runtime = runtime;
      return runtime;
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
    setState(_openRuntime);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF65558F), brightness: Brightness.light);
    return MaterialApp(
      title: 'Sesli Öğren',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(filled: true),
        filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48))),
      ),
      home: FutureBuilder<AppRuntime>(
        future: _runtimeFuture,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return LearningSliceScreen(runtime: snapshot.data!);
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
