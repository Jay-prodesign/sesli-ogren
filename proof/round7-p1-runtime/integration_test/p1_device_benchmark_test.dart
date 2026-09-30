// Physical-device benchmark (R7-06). Run in profile mode on a real device:
//   flutter drive --profile --driver=test_driver/perf_driver.dart \
//     --target=integration_test/p1_device_benchmark_test.dart \
//     --dart-define=GIT_SHA=<commit> -d <device-id>
// Writes build/p1_timeline.timeline_summary.json (Flutter frame/raster summary) and
// build/p1_report.json (T1–T11 functional checks, per-scenario frame timings, RSS samples).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:r7_p1_runtime_proof/src/app/proof_controller.dart';
import 'package:r7_p1_runtime_proof/src/app/proof_screen.dart';
import 'package:r7_p1_runtime_proof/src/bench/bench_runner.dart';
import 'package:r7_p1_runtime_proof/src/bench/frame_stats.dart';
import 'package:r7_p1_runtime_proof/src/scene/fixture.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('P1 T1–T11 on device', (tester) async {
    var assetBytes = 0;
    for (final path in kFixtureAssets) {
      assetBytes += (await rootBundle.load(path)).lengthInBytes;
    }
    final fixtures = await ProofFixture.loadAll(rootBundle);
    final controller = ProofController(fixtures);
    await tester.pumpWidget(MaterialApp(home: ProofScreen(controller: controller)));
    await tester.pump(const Duration(seconds: 1));

    late Map<String, Object?> report;
    await binding.traceAction(() async {
      report = await ScenarioRunner(
        controller,
        wait: (d) => Future<void>.delayed(d),
        collector: FrameCollector(),
        soakCycles: const int.fromEnvironment('SOAK_CYCLES', defaultValue: 30),
      ).runAll(assetBytes: assetBytes);
    }, reportKey: 'timeline');
    (binding.reportData ??= <String, dynamic>{})['p1_report'] = report;
    expect(report['functional_result'], 'PASS');
  });
}
