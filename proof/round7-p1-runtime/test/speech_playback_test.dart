import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:r7_p1_runtime_proof/src/app/proof_controller.dart';
import 'package:r7_p1_runtime_proof/src/flow/flow_engine.dart';
import 'package:r7_p1_runtime_proof/src/speech_playback.dart';

import 'helpers.dart';

final class _FakeSpeechPlayback implements SpeechPlayback {
  ValueChanged<bool>? listener;
  String? lastText;
  var stopCount = 0;
  var disposed = false;

  @override
  set onSpeakingChanged(ValueChanged<bool>? value) => listener = value;

  @override
  Future<void> speak(String text) async {
    lastText = text;
    listener?.call(true);
  }

  void finish() => listener?.call(false);

  @override
  Future<void> stop() async {
    stopCount++;
    listener?.call(false);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    listener = null;
  }
}

void main() {
  test('native playback callbacks own SPEAK state lifetime', () async {
    final fixtures = await loadFixtures();
    final speech = _FakeSpeechPlayback();
    final controller = ProofController(fixtures, speechPlayback: speech);
    addTearDown(controller.dispose);

    expect(controller.usesNativeSpeech, isTrue);
    expect(controller.companionState, CompanionState.idle);

    controller.orient();
    await Future<void>.delayed(Duration.zero);

    expect(speech.lastText, controller.engine.spokenText);
    expect(controller.speaking, isTrue);
    expect(controller.companionState, CompanionState.speak);

    speech.finish();

    expect(controller.speaking, isFalse);
    expect(controller.companionState, CompanionState.idle);
  });

  test('manual stop delegates to native playback and clears speaking state', () async {
    final fixtures = await loadFixtures();
    final speech = _FakeSpeechPlayback();
    final controller = ProofController(fixtures, speechPlayback: speech);
    addTearDown(controller.dispose);

    controller.orient();
    await Future<void>.delayed(Duration.zero);
    expect(controller.speaking, isTrue);

    controller.stopSpeaking();
    await Future<void>.delayed(Duration.zero);

    expect(speech.stopCount, greaterThan(0));
    expect(controller.speaking, isFalse);
  });
}
