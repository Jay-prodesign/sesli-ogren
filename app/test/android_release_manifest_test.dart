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

  test('native platform configuration preserves system text scaling, keyboard resize and background audio', () {
    final androidManifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final iosInfo = File('ios/Runner/Info.plist').readAsStringSync();

    expect(
      androidManifest,
      contains(
        'android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"',
      ),
      reason: 'Flutter must receive Android font-scale configuration changes without recreating a stale text layout.',
    );
    expect(
      androidManifest,
      contains('android:windowSoftInputMode="adjustResize"'),
      reason: 'The native window must resize around the keyboard so source and Recall inputs stay reachable.',
    );
    expect(
      iosInfo,
      contains('<key>UIBackgroundModes</key>'),
      reason: 'The iOS release configuration must declare the background capability used by the Listen experience.',
    );
    expect(
      iosInfo,
      contains('<string>audio</string>'),
      reason: 'Background Listen playback is an admitted V0 audio-player behavior and must not silently disappear.',
    );
  });

  test('Android internal dogfood signing stays explicit and opt-in', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(
      gradle,
      contains(
        'val internalDogfoodSigning = providers.environmentVariable("INTERNAL_DOGFOOD_SIGNING").orNull == "true"',
      ),
      reason: 'Internal dogfood signing must require an explicit CI environment flag.',
    );
    expect(
      gradle,
      contains(
        'if (internalDogfoodSigning) {\n                signingConfig = signingConfigs.getByName("debug")\n            }',
      ),
      reason: 'Only the explicit internal dogfood path may reuse the debug key for installability.',
    );
  });
}
