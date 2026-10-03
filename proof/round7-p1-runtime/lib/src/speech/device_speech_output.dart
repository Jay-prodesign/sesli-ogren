import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

abstract interface class SpeechOutput {
  Future<void> speak(
    String text, {
    required VoidCallback onStart,
    required VoidCallback onDone,
    required ValueChanged<Object> onError,
  });

  Future<void> stop();

  Future<void> dispose();
}

/// Concrete, product-local device speech for the Round 7 proof.
///
/// This is intentionally not a shared/provider-neutral speech service. It uses
/// the platform TTS available on the device so the real-phone learning loop can
/// drive Companion SPEAK from actual playback lifecycle callbacks.
final class DeviceSpeechOutput implements SpeechOutput {
  DeviceSpeechOutput({this.locale = 'en-US', FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final String locale;
  final FlutterTts _tts;

  bool _configured = false;
  int _generation = 0;

  Future<void> _configure() async {
    if (_configured) return;
    await _tts.setLanguage(locale);
    await _tts.setSpeechRate(0.46);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    await _tts.awaitSpeakCompletion(true);
    _configured = true;
  }

  @override
  Future<void> speak(
    String text, {
    required VoidCallback onStart,
    required VoidCallback onDone,
    required ValueChanged<Object> onError,
  }) async {
    final generation = ++_generation;

    _tts.setStartHandler(() {
      if (generation == _generation) onStart();
    });
    _tts.setCompletionHandler(() {
      if (generation == _generation) onDone();
    });
    _tts.setErrorHandler((message) {
      if (generation == _generation) onError(StateError('device_tts:$message'));
    });

    try {
      await _tts.stop();
      await _configure();
      final result = await _tts.speak(text);
      if (result != 1 && generation == _generation) {
        onError(StateError('device_tts_speak_failed:$result'));
      }
    } catch (error) {
      if (generation == _generation) onError(error);
    }
  }

  @override
  Future<void> stop() async {
    _generation++;
    try {
      await _tts.stop();
    } catch (_) {
      // Stopping speech is best-effort; the learning loop must remain usable.
    }
  }

  @override
  Future<void> dispose() => stop();
}
