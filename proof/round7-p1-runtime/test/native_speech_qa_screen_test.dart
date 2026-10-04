import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:r7_p1_runtime_proof/src/app/proof_controller.dart';
import 'package:r7_p1_runtime_proof/src/qa/native_speech_qa_screen.dart';
import 'package:r7_p1_runtime_proof/src/speech/device_speech_output.dart';

import 'helpers.dart';

class _AttachedSpeechOutput implements SpeechOutput {
  @override
  Future<void> speak(
    String text, {
    required String locale,
    required VoidCallback onStart,
    required VoidCallback onDone,
    required ValueChanged<Object> onError,
  }) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets('native speech QA is runnable only when a real SpeechOutput is attached', (tester) async {
    usePhoneSurface(tester);
    final fixtures = await loadFixtures();
    final controller = ProofController(fixtures, speechOutput: _AttachedSpeechOutput())..setReducedMotion(true);
    await tester.pumpWidget(MaterialApp(home: NativeSpeechQaScreen(controller: controller)));

    expect(find.text('Native Speech QA'), findsOneWidget);
    expect(find.text('NOT_RUN'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byKey(const Key('run-native-speech-qa')));
    expect(button.onPressed, isNotNull);
    expect(controller.usingRealSpeech, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('native speech QA is fail-closed without a real SpeechOutput', (tester) async {
    usePhoneSurface(tester);
    final fixtures = await loadFixtures();
    final controller = ProofController(fixtures)..setReducedMotion(true);
    await tester.pumpWidget(MaterialApp(home: NativeSpeechQaScreen(controller: controller)));

    expect(find.text('Native Speech QA'), findsOneWidget);
    expect(find.text('BLOCKED_NO_REAL_DEVICE_SPEECH'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byKey(const Key('run-native-speech-qa')));
    expect(button.onPressed, isNull);
    expect(controller.usingRealSpeech, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
