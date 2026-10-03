import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:r7_p1_runtime_proof/src/app/proof_controller.dart';
import 'package:r7_p1_runtime_proof/src/qa/native_speech_qa_screen.dart';
import 'package:r7_p1_runtime_proof/src/speech/device_speech_output.dart';

import 'helpers.dart';

class _LifecycleSpeechOutput implements SpeechOutput {
  Timer? _completion;
  int _generation = 0;
  int speakCalls = 0;

  @override
  Future<void> speak(
    String text, {
    required String locale,
    required VoidCallback onStart,
    required VoidCallback onDone,
    required ValueChanged<Object> onError,
  }) async {
    final generation = ++_generation;
    speakCalls++;
    onStart();
    _completion?.cancel();
    _completion = Timer(
      speakCalls == 1 ? const Duration(milliseconds: 10) : const Duration(seconds: 1),
      () {
        if (generation == _generation) onDone();
      },
    );
  }

  @override
  Future<void> stop() async {
    _generation++;
    _completion?.cancel();
  }

  @override
  Future<void> dispose() => stop();
}

void main() {
  testWidgets('native speech QA verifies completion and explicit-stop callback lifecycles', (tester) async {
    usePhoneSurface(tester);
    final fixtures = await loadFixtures();
    final speech = _LifecycleSpeechOutput();
    final controller = ProofController(fixtures, speechOutput: speech)..setReducedMotion(true);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: NativeSpeechQaScreen(
          controller: controller,
          startTimeout: const Duration(seconds: 1),
          completionTimeout: const Duration(seconds: 1),
          interruptAfter: const Duration(milliseconds: 10),
          staleCallbackGuard: const Duration(milliseconds: 20),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('run-native-speech-qa')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('CALLBACK_LIFECYCLE_PASS'), findsOneWidget);
    expect(find.textContaining('onStart observed'), findsWidgets);
    expect(find.textContaining('completion observed'), findsOneWidget);
    expect(find.textContaining('stop() settled SPEAK'), findsOneWidget);
    expect(find.textContaining('stale-callback guard PASS'), findsOneWidget);
    expect(speech.speakCalls, 2);
    expect(controller.speaking, isFalse);
  });

  testWidgets('native speech QA is fail-closed without a real SpeechOutput', (tester) async {
    usePhoneSurface(tester);
    final fixtures = await loadFixtures();
    final controller = ProofController(fixtures)..setReducedMotion(true);
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(home: NativeSpeechQaScreen(controller: controller)));

    expect(find.text('Native Speech QA'), findsOneWidget);
    expect(find.byKey(const Key('run-native-speech-qa')), findsOneWidget);

    await tester.tap(find.byKey(const Key('run-native-speech-qa')));
    await tester.pump();

    expect(find.text('BLOCKED_NO_REAL_DEVICE_SPEECH'), findsOneWidget);
    expect(find.textContaining('cannot grant a native callback PASS'), findsOneWidget);
  });
}
