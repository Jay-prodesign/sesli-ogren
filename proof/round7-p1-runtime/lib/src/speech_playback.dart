import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract interface class SpeechPlayback {
  set onSpeakingChanged(ValueChanged<bool>? listener);

  Future<void> speak(String text);
  Future<void> stop();
  Future<void> dispose();
}

/// Thin product-local bridge to the operating system's Turkish speech engine.
///
/// This is a functional V1 playback seam, not a final voice-quality selection.
/// The platform side emits real playback start/stop events so Companion SPEAK
/// state follows actual audio activity instead of an estimated timer.
final class NativeSpeechPlayback implements SpeechPlayback {
  NativeSpeechPlayback() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static const _channel = MethodChannel('sesliogren/native_speech');

  ValueChanged<bool>? _listener;

  @override
  set onSpeakingChanged(ValueChanged<bool>? listener) => _listener = listener;

  @override
  Future<void> speak(String text) async {
    final value = text.trim();
    if (value.isEmpty) return;
    await _channel.invokeMethod<void>('speak', {'text': value, 'locale': 'tr-TR'});
  }

  @override
  Future<void> stop() => _channel.invokeMethod<void>('stop');

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != 'speechState') return;
    final arguments = Map<String, dynamic>.from(call.arguments as Map? ?? const {});
    _listener?.call(arguments['speaking'] == true);
  }

  @override
  Future<void> dispose() async {
    _listener = null;
    await stop();
    await _channel.setMethodCallHandler(null);
  }
}
