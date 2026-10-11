import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android release manifest keeps network and Android 11+ TTS visibility requirements', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(
      manifest,
      contains('<uses-permission android:name="android.permission.INTERNET"/>'),
      reason: 'Release builds require network access for authenticated Supabase and AI calls.',
    );
    expect(
      manifest,
      contains('<action android:name="android.intent.action.TTS_SERVICE"/>'),
      reason: 'flutter_tts requires the Android 11+ TTS service package-visibility query.',
    );
  });
}
