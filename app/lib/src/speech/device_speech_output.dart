import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

abstract interface class SpeechOutput {
  Future<void> speak(
    String text, {
    required String locale,
    required VoidCallback onStart,
    required VoidCallback onDone,
    required ValueChanged<Object> onError,
    double rateMultiplier = 1.0,
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
  DeviceSpeechOutput({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  String? _configuredLocale;
  int _generation = 0;

  Future<void> _configure(String locale) async {
    if (_configuredLocale == locale) return;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await _tts.setSharedInstance(true);
      await _tts.autoStopSharedSession(false);
      await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, const [
        IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
        IosTextToSpeechAudioCategoryOptions.allowAirPlay,
      ], IosTextToSpeechAudioMode.spokenAudio);
    }

    await _tts.setLanguage(locale);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    await _tts.awaitSpeakCompletion(true);
    _configuredLocale = locale;
  }

  static double _platformSpeechRate(double multiplier) {
    final normalized = multiplier.clamp(0.75, 1.5).toDouble();
    return (0.46 * normalized).clamp(0.34, 0.70).toDouble();
  }

  @override
  Future<void> speak(
    String text, {
    required String locale,
    required VoidCallback onStart,
    required VoidCallback onDone,
    required ValueChanged<Object> onError,
    double rateMultiplier = 1.0,
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
      await _configure(locale);
      await _tts.setSpeechRate(_platformSpeechRate(rateMultiplier));
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
