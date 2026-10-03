import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:r7_p1_runtime_proof/src/speech/device_speech_output.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native flutter_tts start completion and stop lifecycle', (tester) async {
    final output = DeviceSpeechOutput();
    addTearDown(output.dispose);

    final errors = <Object>[];
    final started = Completer<void>();
    final completed = Completer<void>();

    unawaited(
      output.speak(
        'Merhaba. Bu, Sesli Öğren için yerel konuşma yaşam döngüsü testidir.',
      locale: 'tr-TR',
      onStart: () {
        if (!started.isCompleted) started.complete();
      },
      onDone: () {
        if (!completed.isCompleted) completed.complete();
      },
        onError: errors.add,
      ),
    );

    await started.future.timeout(const Duration(seconds: 5));
    await completed.future.timeout(const Duration(seconds: 20));
    expect(errors, isEmpty);

    final interruptedStarted = Completer<void>();
    var interruptedDone = false;

    unawaited(
      output.speak(
        'Bu ikinci konuşma, durdurma davranışını doğrulamak için biraz daha uzun tutulmaktadır.',
      locale: 'tr-TR',
      onStart: () {
        if (!interruptedStarted.isCompleted) interruptedStarted.complete();
      },
      onDone: () => interruptedDone = true,
        onError: errors.add,
      ),
    );

    await interruptedStarted.future.timeout(const Duration(seconds: 5));
    await output.stop();
    await Future<void>.delayed(const Duration(milliseconds: 900));

    expect(interruptedDone, isFalse);
    expect(errors, isEmpty);
  });
}
