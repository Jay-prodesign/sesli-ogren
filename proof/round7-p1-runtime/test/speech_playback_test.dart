import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:r7_p1_runtime_proof/src/app/proof_controller.dart';
import 'package:r7_p1_runtime_proof/src/flow/flow_engine.dart';
import 'package:r7_p1_runtime_proof/src/scene/fixture.dart';
import 'package:r7_p1_runtime_proof/src/speech/device_speech_output.dart';

import 'helpers.dart';

class _FakeSpeechOutput implements SpeechOutput {
  VoidCallback? _onStart;
  VoidCallback? _onDone;
  ValueChanged<Object>? _onError;

  String? lastText;
  String? lastLocale;
  int speakCalls = 0;
  int stopCalls = 0;

  @override
  Future<void> speak(
    String text, {
    required String locale,
    required VoidCallback onStart,
    required VoidCallback onDone,
    required ValueChanged<Object> onError,
  }) async {
    speakCalls++;
    lastText = text;
    lastLocale = locale;
    _onStart = onStart;
    _onDone = onDone;
    _onError = onError;
  }

  void start() => _onStart?.call();
  void complete() => _onDone?.call();
  void fail(Object error) => _onError?.call(error);

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> dispose() => stop();
}

void main() {
  late List<ProofFixture> fixtures;
  setUpAll(() async => fixtures = await loadFixtures());

  test('fixtures own the voice locale instead of inheriting device/UI locale', () {
    expect(fixtures.map((f) => f.voiceLocale).toSet(), {'en-US'});
  });

  test('real speech drives SPEAK only from playback lifecycle callbacks', () async {
    final speech = _FakeSpeechOutput();
    final controller = ProofController(fixtures, speechOutput: speech);
    addTearDown(controller.dispose);

    controller.orient();
    await Future<void>.delayed(Duration.zero);

    expect(controller.engine.step, FlowStep.orient);
    expect(speech.speakCalls, 1);
    expect(speech.lastLocale, fixtures.first.voiceLocale);
    expect(speech.lastText, controller.engine.spokenText);
    expect(controller.companionState, CompanionState.idle);

    speech.start();
    expect(controller.companionState, CompanionState.speak);

    speech.complete();
    expect(controller.companionState, CompanionState.idle);
  });

  test('restart resets the speech transition cursor and can speak the same step again', () async {
    final speech = _FakeSpeechOutput();
    final controller = ProofController(fixtures, speechOutput: speech);
    addTearDown(controller.dispose);

    controller.orient();
    await Future<void>.delayed(Duration.zero);
    expect(speech.speakCalls, 1);

    controller.restart();
    controller.orient();
    await Future<void>.delayed(Duration.zero);

    expect(controller.engine.step, FlowStep.orient);
    expect(speech.speakCalls, 2);
  });

  test('speech error falls back to text without breaking the learning flow', () async {
    final speech = _FakeSpeechOutput();
    final controller = ProofController(fixtures, speechOutput: speech);
    addTearDown(controller.dispose);

    controller.orient();
    await Future<void>.delayed(Duration.zero);
    speech.start();
    speech.fail(StateError('synthetic-device-error'));

    expect(controller.companionState, CompanionState.idle);
    expect(controller.engine.step, FlowStep.orient);
    expect(controller.audioAvailable, isFalse);
    expect(controller.engine.events.where((e) => e.name == 'audio_unavailable'), hasLength(1));
    expect(controller.engine.spokenText, isNotEmpty);

    controller.advance();
    await Future<void>.delayed(Duration.zero);

    expect(controller.engine.step, FlowStep.teach);
    expect(speech.speakCalls, 1, reason: 'failed TTS must stay text-only until explicitly re-enabled');
    expect(controller.companionState, CompanionState.idle);
  });

  test('stop immediately clears SPEAK and forwards stop to the device output', () async {
    final speech = _FakeSpeechOutput();
    final controller = ProofController(fixtures, speechOutput: speech);
    addTearDown(controller.dispose);

    controller.orient();
    await Future<void>.delayed(Duration.zero);
    speech.start();
    expect(controller.companionState, CompanionState.speak);

    controller.stopSpeaking();

    expect(controller.companionState, CompanionState.idle);
    expect(speech.stopCalls, greaterThanOrEqualTo(1));
  });
}
