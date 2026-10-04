import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:r7_p1_runtime_proof/src/app/proof_controller.dart';
import 'package:r7_p1_runtime_proof/src/qa/native_speech_qa_screen.dart';

import 'helpers.dart';

void main() {
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
