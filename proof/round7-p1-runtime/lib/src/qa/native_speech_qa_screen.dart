import 'dart:async';

import 'package:flutter/material.dart';

import '../app/proof_controller.dart';
import '../bench/bench_runner.dart';
import '../flow/flow_engine.dart';
import '../render/companion_renderer.dart';
import '../render/views.dart';
import '../render/world_painter.dart';
import '../scene/scene_schema.dart';

class NativeSpeechQaScreen extends StatefulWidget {
  const NativeSpeechQaScreen({
    super.key,
    required this.controller,
    this.startTimeout = const Duration(seconds: 3),
    this.completionTimeout = const Duration(seconds: 20),
    this.interruptAfter = const Duration(milliseconds: 650),
    this.staleCallbackGuard = const Duration(milliseconds: 900),
  });

  final ProofController controller;
  final Duration startTimeout;
  final Duration completionTimeout;
  final Duration interruptAfter;
  final Duration staleCallbackGuard;

  @override
  State<NativeSpeechQaScreen> createState() => _NativeSpeechQaScreenState();
}

class _NativeSpeechQaScreenState extends State<NativeSpeechQaScreen> {
  final _stats = PaintStats();
  final _timeline = <String>[];
  bool _running = false;
  String _result = 'NOT_RUN';

  ProofController get controller => widget.controller;

  void _note(String value) {
    if (!mounted) return;
    setState(() => _timeline.add(value));
  }

  int get _audioErrorCount => controller.engine.events.where((event) => event.name == 'audio_unavailable').length;

  Future<void> _run() async {
    if (_running) return;
    if (!controller.usingRealSpeech) {
      setState(() {
        _result = 'BLOCKED_NO_REAL_DEVICE_SPEECH';
        _timeline
          ..clear()
          ..add('Real SpeechOutput is not attached. This surface cannot grant a native callback PASS.');
      });
      return;
    }

    setState(() {
      _running = true;
      _result = 'RUNNING';
      _timeline.clear();
    });

    try {
      controller.setAudioAvailable(true);
      await _runCompletionLifecycle();
      await _runStopLifecycle();
      if (!mounted) return;
      setState(() => _result = 'CALLBACK_LIFECYCLE_PASS');
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _result = 'CALLBACK_LIFECYCLE_FAIL';
        _timeline.add('FAIL: $error');
      });
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _runCompletionLifecycle() async {
    controller.restart();
    final baselineErrors = _audioErrorCount;
    final started = Completer<void>();
    final completed = Completer<void>();
    var sawStart = false;

    void listener() {
      if (!sawStart && controller.speaking) {
        sawStart = true;
        if (!started.isCompleted) started.complete();
      } else if (sawStart && !controller.speaking && !completed.isCompleted) {
        completed.complete();
      }
    }

    controller.addListener(listener);
    try {
      _note('Playback test requested · locale ${controller.fixture.voiceLocale}');
      controller.orient();
      await started.future.timeout(widget.startTimeout);
      _note('onStart observed · Companion=${controller.companionState.name}');
      if (controller.companionState != CompanionState.speak) {
        throw StateError('Companion did not enter SPEAK on real playback start.');
      }

      await completed.future.timeout(widget.completionTimeout);
      _note('completion observed · Companion=${controller.companionState.name}');
      if (controller.speaking || controller.companionState == CompanionState.speak) {
        throw StateError('Companion remained SPEAK after playback completion.');
      }
      if (_audioErrorCount != baselineErrors) {
        throw StateError('audio_unavailable was emitted during the completion test.');
      }
    } finally {
      controller.removeListener(listener);
      controller.stopSpeaking();
    }
  }

  Future<void> _runStopLifecycle() async {
    controller.restart();
    final baselineErrors = _audioErrorCount;
    final started = Completer<void>();

    void listener() {
      if (controller.speaking && !started.isCompleted) started.complete();
    }

    controller.addListener(listener);
    try {
      _note('Interruption test requested');
      controller.orient();
      await started.future.timeout(widget.startTimeout);
      _note('onStart observed before interruption');
      await Future<void>.delayed(widget.interruptAfter);
      controller.stopSpeaking();
      await Future<void>.delayed(const Duration(milliseconds: 80));

      if (controller.speaking || controller.companionState == CompanionState.speak) {
        throw StateError('SPEAK did not settle after stop().');
      }
      _note('stop() settled SPEAK');

      await Future<void>.delayed(widget.staleCallbackGuard);
      if (controller.speaking || controller.companionState == CompanionState.speak) {
        throw StateError('A stale playback callback re-entered SPEAK after stop().');
      }
      if (_audioErrorCount != baselineErrors) {
        throw StateError('audio_unavailable was emitted during the interruption test.');
      }
      _note('stale-callback guard PASS');
    } finally {
      controller.removeListener(listener);
      controller.stopSpeaking();
    }
  }

  CompanionRenderer get _renderer => switch (controller.companionIdentity) {
    CompanionIdentity.knot => const RasterCompanionRenderer.knot(),
    CompanionIdentity.tilt => const RasterCompanionRenderer.tilt(),
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Native Speech QA')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Build ${BuildIdentity.gitSha} · ${BuildIdentity.buildMode}\n'
                'Locale ${controller.fixture.voiceLocale} · '
                '${controller.usingRealSpeech ? 'real device speech attached' : 'simulated/no device speech'}',
              ),
              const SizedBox(height: 12),
              Center(
                child: CompanionView(
                  state: controller.companionState,
                  tone: controller.engine.companionTone,
                  tier: FallbackLevel.full,
                  reducedMotion: controller.reducedMotion,
                  assetFailed: false,
                  stats: _stats,
                  visualExtent: 144,
                  renderer: _renderer,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('run-native-speech-qa'),
                onPressed: _running ? null : _run,
                icon: const Icon(Icons.record_voice_over),
                label: Text(_running ? 'Running…' : 'Run Native Speech QA'),
              ),
              const SizedBox(height: 12),
              SelectableText(
                _result,
                key: const Key('native-speech-qa-result'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'PASS here proves callback/state lifecycle only. '
                'Actual speaker audibility, Turkish voice quality and physical-device smoothness remain observations.',
              ),
              const Divider(height: 24),
              for (final item in _timeline) Text('• $item'),
            ],
          ),
        ),
      ),
    );
  }
}
