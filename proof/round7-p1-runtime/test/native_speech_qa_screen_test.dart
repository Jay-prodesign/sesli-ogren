import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:r7_p1_runtime_proof/src/app/proof_controller.dart';
import 'package:r7_p1_runtime_proof/src/qa/native_speech_qa_screen.dart';
import 'package:r7_p1_runtime_proof/src/speech/device_speech_output.dart';

import 'helpers.dart';

class _LifecycleSpeechOutput implements SpeechOutput {
  VoidCallback? _activeOnDone;
  int speakCalls = 0;
  int staleCallbacksFired = 0;

  @override
  Future<void> speak(
    String text, {
    required String locale,
    required VoidCallback onStart,
    required VoidCallback onDone,
    required ValueChanged<Object> onError,
  }) async {
    speakCalls++;
    _activeOnDone = onDone;
    onStart();
  }

  void completeCurrent() {
    final onDone = _activeOnDone;
    _activeOnDone = null;
    onDone?.call();
  }

  @override
  Future<void> stop() async {
    final staleOnDone = _activeOnDone;
    _activeOnDone = null;
    if (staleOnDone != null) {
      staleCallbacksFired++;
      staleOnDone();
    }
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
          interruptAfter: Duration.zero,
          staleCallbackGuard: Duration.zero,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('run-native-speech-qa')));
    await tester.pump();

    expect(speech.speakCalls, 1);
    expect(controller.speaking, isTrue);

    speech.completeCurrent();
    await tester.pump();
    await tester.pump();

    expect(speech.speakCalls, 2);
    expect(controller.speaking, isTrue);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(find.text('CALLBACK_LIFECYCLE_PASS'), findsOneWidget);
    expect(speech.staleCallbacksFired, 1);
    expect(controller.speaking, isFalse);
  });

  testWidgets('native speech QA is fail-closed without a real SpeechOutput', (tester) async {
    usePhoneSurface(tester);
    final fixtures = await loadFixtures();
    final controller = ProofController(fixtures)..setReducedMotion(true);
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(home: NativeSpeechQaScreen(controller: controller)));

    expect(find.text('Native Speech QA'), findsOneWidget);
    expect(find.text('BLOCKED_NO_REAL_DEVICE_SPEECH'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byKey(const Key('run-native-speech-qa')));
    expect(button.onPressed, isNull);
    expect(controller.usingRealSpeech, isFalse);
  });
}
