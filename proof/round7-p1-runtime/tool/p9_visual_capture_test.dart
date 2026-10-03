import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:r7_p1_runtime_proof/src/app/proof_controller.dart';
import 'package:r7_p1_runtime_proof/src/app/proof_screen.dart';
import 'package:r7_p1_runtime_proof/src/flow/flow_engine.dart';
import 'package:r7_p1_runtime_proof/src/render/companion_renderer.dart';
import 'package:r7_p1_runtime_proof/src/render/world_painter.dart';
import 'package:r7_p1_runtime_proof/src/scene/fixture.dart';
import 'package:r7_p1_runtime_proof/src/scene/scene_schema.dart';

Future<List<ProofFixture>> _loadFixtures() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  return ProofFixture.loadAll(rootBundle);
}

CompanionRenderer _renderer(CompanionIdentity identity) => switch (identity) {
  CompanionIdentity.knot => const RasterCompanionRenderer.knot(),
  CompanionIdentity.tilt => const RasterCompanionRenderer.tilt(),
};

String _identityName(CompanionIdentity identity) => switch (identity) {
  CompanionIdentity.knot => 'D_KNOT',
  CompanionIdentity.tilt => 'E_TILT',
};

Future<void> _toChallenge(WidgetTester tester, ProofController controller) async {
  controller.orient();
  await tester.pump();
  for (var guard = 0; controller.engine.step != FlowStep.challenge; guard++) {
    expect(guard, lessThan(10));
    controller.advance();
    await tester.pump();
  }
}

Future<void> _driveState(WidgetTester tester, ProofController controller, CompanionState state) async {
  switch (state) {
    case CompanionState.idle:
      break;
    case CompanionState.speak:
      controller.orient();
      await tester.pump(const Duration(milliseconds: 20));
    case CompanionState.listen:
      await _toChallenge(tester, controller);
    case CompanionState.think:
      await _toChallenge(tester, controller);
      controller.submit(EvidenceState.strong);
      await tester.pump(const Duration(milliseconds: 20));
    case CompanionState.correct:
      await _toChallenge(tester, controller);
      controller.submit(EvidenceState.partial);
      await tester.pump();
      controller.engine.completeEvaluation();
      await tester.pump();
    case CompanionState.success:
      await _toChallenge(tester, controller);
      controller.submit(EvidenceState.strong);
      await tester.pump();
      controller.engine.completeEvaluation();
      await tester.pump();
  }
  expect(controller.companionState, state);
}

Future<void> _captureFullScreen(
  WidgetTester tester, {
  required List<ProofFixture> fixtures,
  required Size logicalSize,
  required String orientation,
  required CompanionIdentity identity,
  required CompanionState state,
}) async {
  const dpr = 3.0;
  tester.view.physicalSize = Size(logicalSize.width * dpr, logicalSize.height * dpr);
  tester.view.devicePixelRatio = dpr;

  final controller = ProofController(fixtures, evaluationDelay: const Duration(minutes: 10))
    ..setCompanionIdentity(identity);

  await tester.pumpWidget(
    RepaintBoundary(
      key: const Key('capture-root'),
      child: MediaQuery(
        data: MediaQueryData(size: logicalSize, devicePixelRatio: dpr, disableAnimations: false),
        child: MaterialApp(home: ProofScreen(controller: controller)),
      ),
    ),
  );
  await tester.pump();
  await _driveState(tester, controller, state);

  controller.setReducedMotion(true);
  await tester.pump();
  expect(tester.takeException(), isNull);

  final name = 'p9_captures/full_${orientation}_${_identityName(identity)}_${state.name.toUpperCase()}.png';
  await expectLater(find.byKey(const Key('capture-root')), matchesGoldenFile(name));

  controller.dispose();
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Future<void> _captureCloseup(
  WidgetTester tester, {
  required CompanionIdentity identity,
  required CompanionState state,
  required double motion,
  required String suffix,
}) async {
  tester.view.physicalSize = const Size(900, 900);
  tester.view.devicePixelRatio = 3;

  final stats = PaintStats();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFFF7F5F2),
        body: Center(
          child: RepaintBoundary(
            key: const Key('closeup-root'),
            child: SizedBox(
              width: 240,
              height: 240,
              child: _renderer(identity).build(
                state: state,
                tone: state == CompanionState.correct ? CompanionTone.attention : CompanionTone.neutral,
                motion: AlwaysStoppedAnimation<double>(motion),
                animate: true,
                stats: stats,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  final name = 'p9_captures/closeup_${_identityName(identity)}_${state.name.toUpperCase()}_$suffix.png';
  await expectLater(find.byKey(const Key('closeup-root')), matchesGoldenFile(name));
}

void main() {
  late List<ProofFixture> fixtures;

  setUpAll(() async {
    fixtures = await _loadFixtures();
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('capture full P9 portrait and landscape state matrix', (tester) async {
    final surfaces = <(Size, String)>[(const Size(430, 932), 'portrait'), (const Size(932, 430), 'landscape')];

    for (final (size, orientation) in surfaces) {
      for (final identity in CompanionIdentity.values) {
        for (final state in CompanionState.values) {
          await _captureFullScreen(
            tester,
            fixtures: fixtures,
            logicalSize: size,
            orientation: orientation,
            identity: identity,
            state: state,
          );
        }
      }
    }

    tester.view.reset();
  });

  testWidgets('capture deterministic D/E companion closeups for visual QA', (tester) async {
    for (final identity in CompanionIdentity.values) {
      for (final state in CompanionState.values) {
        await _captureCloseup(
          tester,
          identity: identity,
          state: state,
          motion: state == CompanionState.speak ? 0.25 : 0.0,
          suffix: state == CompanionState.speak ? 'MOUTH_MAX' : 'BASE',
        );
      }
    }

    tester.view.reset();
  });
}
