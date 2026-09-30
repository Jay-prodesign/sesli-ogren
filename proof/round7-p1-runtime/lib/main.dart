import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/app/proof_app.dart';
import 'src/bench/bench_runner.dart';
import 'src/scene/fixture.dart';

Future<void> main() async {
  StartupTiming.sinceMain.start();
  WidgetsFlutterBinding.ensureInitialized();
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
