import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/app/proof_app.dart';
import 'src/bench/bench_runner.dart';
import 'src/native_tts_capture.dart';
import 'src/scene/fixture.dart';

const _nativeTtsCaptureMode = bool.fromEnvironment(
  'R7_NATIVE_TTS_CAPTURE',
  defaultValue: false,
);

Future<void> main() async {
  StartupTiming.sinceMain.start();
  WidgetsFlutterBinding.ensureInitialized();

  if (_nativeTtsCaptureMode) {
    runApp(const NativeTtsCaptureApp());
    return;
  }

  var assetBytes = 0;
  for (final path in kFixtureAssets) {
    assetBytes += (await rootBundle.load(path)).lengthInBytes;
  }
  final fixtures = await ProofFixture.loadAll(rootBundle);
  runApp(ProofApp(fixtures: fixtures, assetBytes: assetBytes));
  WidgetsBinding.instance.waitUntilFirstFrameRasterized.then((_) {
    StartupTiming.firstFrameMs = StartupTiming.sinceMain.elapsedMilliseconds;
  });
}
