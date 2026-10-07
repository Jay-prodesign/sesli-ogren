import 'package:flutter/material.dart';

import 'app_runtime.dart';

class FirstRunOnboardingGate extends StatefulWidget {
  const FirstRunOnboardingGate({required this.runtime, required this.child, super.key});

  final AppRuntime runtime;
  final Widget child;

  @override
  State<FirstRunOnboardingGate> createState() => _FirstRunOnboardingGateState();
}

class _FirstRunOnboardingGateState extends State<FirstRunOnboardingGate> {
  late Future<bool> _completed;

  @override
  void initState() {
    super.initState();
    _completed = _load();
  }

  Future<bool> _load() => widget.runtime.store.onboardingCompleted(learner: widget.runtime.learner);

  Future<void> _complete() async {
    await widget.runtime.store.markOnboardingCompleted(
      learner: widget.runtime.learner,
      updatedAt: DateTime.now().toUtc(),
    );
    if (!mounted) return;
    setState(() {
      _completed = Future.value(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _completed,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.data!) return widget.child;
        return _FirstRunOnboarding(onComplete: _complete);
      },
    );
  }
}

class _FirstRunOnboarding extends StatefulWidget {
  const _FirstRunOnboarding({required this.onComplete});

  final Future<void> Function() onComplete;

  @override
  State<_FirstRunOnboarding> createState() => _FirstRunOnboardingState();
}

class _FirstRunOnboardingState extends State<_FirstRunOnboarding> {
  int _step = 0;
  bool _saving = false;

  static const _steps = [
    _OnboardingStep(
      icon: Icons.auto_stories_outlined,
      title: 'Materyalinle başla',
      body: 'PDF veya metnini ekle. Sesli Öğren aynı kaynağı dinleme ve aktif öğrenme adımlarında birlikte tutar.',
    ),
    _OnboardingStep(
      icon: Icons.psychology_alt_outlined,
      title: 'Öğrenmeyi kanıtla',
      body: 'Dinlemek faydalı olabilir ama tek başına öğrendiğin anlamına gelmez. Hatırlama ve açıklama gibi aktif adımlar ilerleme kanıtını oluşturur.',
    ),
    _OnboardingStep(
      icon: Icons.shield_outlined,
      title: 'Kontrol sende',
      body: 'Neden bir sonraki adımı önerdiğimizi görebilir, materyallerini ayrı ayrı veya hesabını ve verilerini tamamen silebilirsin.',
    ),
  ];

  Future<void> _next() async {
    if (_step < _steps.length - 1) {
      setState(() => _step += 1);
      return;
    }
    setState(() => _saving = true);
    await widget.onComplete();
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final step = _steps[_step];
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Sesli Öğren',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const Spacer(),
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(step.icon, size: 42, color: theme.colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: 28),
                  AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    child: Column(
                      key: ValueKey(_step),
                      children: [
                        Text(
                          step.title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          step.body,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _steps.length,
                      (index) => Container(
                        width: index == _step ? 24 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: index == _step ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_step > 0)
                    TextButton(onPressed: _saving ? null : () => setState(() => _step -= 1), child: const Text('Geri')),
                  const SizedBox(height: 4),
                  FilledButton(
                    onPressed: _saving ? null : _next,
                    child: Text(
                      _saving
                          ? 'Hazırlanıyor…'
                          : _step == _steps.length - 1
                          ? 'Öğrenmeye başla'
                          : 'Devam et',
                    ),
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

class _OnboardingStep {
  const _OnboardingStep({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;
}
