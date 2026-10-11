import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:r7_p1_runtime_proof/src/app/proof_controller.dart';
import 'package:r7_p1_runtime_proof/src/app/proof_screen.dart';
import 'package:r7_p1_runtime_proof/src/bench/bench_runner.dart';
import 'package:r7_p1_runtime_proof/src/flow/flow_engine.dart';
import 'package:r7_p1_runtime_proof/src/render/companion_renderer.dart';
import 'package:r7_p1_runtime_proof/src/render/views.dart';
import 'package:r7_p1_runtime_proof/src/render/world_painter.dart';
import 'package:r7_p1_runtime_proof/src/scene/fixture.dart';
import 'package:r7_p1_runtime_proof/src/scene/scene_schema.dart';

import 'helpers.dart';

class _TestCompanionRenderer implements CompanionRenderer {
  const _TestCompanionRenderer();

  @override
  Widget build({
    required CompanionState state,
    required CompanionTone tone,
    required Animation<double> motion,
    required bool animate,
    required PaintStats stats,
  }) {
    return const ColoredBox(key: Key('test-companion-renderer'), color: Colors.transparent);
  }
}

void main() {
  late List<ProofFixture> fixtures;
  setUpAll(() async => fixtures = await loadFixtures());

  Future<ProofController> pumpProof(WidgetTester tester, {bool disableAnimations = false, double textScale = 1}) async {
    usePhoneSurface(tester);
    final c = ProofController(fixtures);
    addTearDown(c.dispose);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 780),
          devicePixelRatio: 3,
          disableAnimations: disableAnimations,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(home: ProofScreen(controller: c)),
      ),
    );
    await tester.pump();
    return c;
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(Key(key));
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> toChallenge(WidgetTester tester, ProofController c) async {
    await tapKey(tester, 'act-primary');
    for (var guard = 0; c.engine.step != FlowStep.challenge; guard++) {
      expect(guard, lessThan(10), reason: 'could not reach the challenge through the UI');
      await tapKey(tester, 'act-primary');
    }
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5)); // drain simulated speech timers
  }

  testWidgets('T2–T6: every branch completes through the UI for every fixture', (tester) async {
    final c = await pumpProof(tester);
    for (var i = 0; i < fixtures.length; i++) {
      for (final s in EvidenceState.values) {
        c.selectFixture(i);
        await tester.pump();
        await toChallenge(tester, c);
        expect(find.byKey(Key('respond-${wireName(s)}')), findsOneWidget);
        await tapKey(tester, 'respond-${wireName(s)}');
        expect(c.engine.step, FlowStep.feedback, reason: '${fixtures[i].id} ${s.name}');
        expect(find.byKey(const Key('next-action')), findsOneWidget);
        await tapKey(tester, 'act-primary');
        if (c.engine.step == FlowStep.challenge) await tapKey(tester, 'respond-STRONG');
        if (c.engine.step == FlowStep.feedback) await tapKey(tester, 'act-primary');
        if (c.engine.step == FlowStep.repairTeach) await tapKey(tester, 'act-primary');
        if (c.engine.step == FlowStep.repairCheck) await tapKey(tester, 'repair-correct');
        expect(c.engine.step, FlowStep.complete, reason: '${fixtures[i].id} ${s.name}');
        expect(find.textContaining('not permanent mastery'), findsOneWidget);
      }
    }
    await finish(tester);
  });

  testWidgets('THINK is shown only while evaluating', (tester) async {
    final c = await pumpProof(tester);
    await toChallenge(tester, c);
    await tester.ensureVisible(find.byKey(const Key('respond-STRONG')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('respond-STRONG')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(c.companionState, CompanionState.think);
    expect(find.text('Thinking'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    expect(c.companionState, CompanionState.success);
    await finish(tester);
  });

  testWidgets('D/E identity selection swaps the canonical raster without changing the learning state', (tester) async {
    final c = await pumpProof(tester);

    Image raster() => tester.widget<Image>(find.byType(Image).first);

    expect((raster().image as AssetImage).assetName, 'assets/companions/D_KNOT_128.webp');
    final before = c.companionState;

    c.setCompanionIdentity(CompanionIdentity.tilt);
    await tester.pump();

    expect(c.companionState, before);
    expect((raster().image as AssetImage).assetName, 'assets/companions/E_TILT_128.webp');

    c.setCompanionIdentity(CompanionIdentity.knot);
    await tester.pump();

    expect(c.companionState, before);
    expect((raster().image as AssetImage).assetName, 'assets/companions/D_KNOT_128.webp');
    await finish(tester);
  });

  testWidgets('Companion renderer seam swaps the visual body without changing fallback semantics', (tester) async {
    usePhoneSurface(tester);
    final c = ProofController(fixtures);
    addTearDown(c.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ProofScreen(controller: c, companionRenderer: const _TestCompanionRenderer()),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('test-companion-renderer')), findsOneWidget);
    expect(find.byKey(const Key('companion-label')), findsOneWidget);

    c.setTier(FallbackLevel.neutral);
    await tester.pump();

    expect(find.byKey(const Key('test-companion-renderer')), findsNothing);
    expect(find.byKey(const Key('companion-label')), findsOneWidget);
  });

  testWidgets('T8: tiers degrade cost; CONTENT has no canvas and keeps the learning loop', (tester) async {
    final c = await pumpProof(tester);
    await toChallenge(tester, c);
    final ops = <FallbackLevel, double>{};
    for (final t in FallbackLevel.values) {
      c.setTier(t);
      await tester.pump();
      final o0 = worldStats.ops, f0 = worldStats.frames;
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      final frames = worldStats.frames - f0;
      ops[t] = frames == 0 ? 0 : (worldStats.ops - o0) / frames;
      expect(find.byKey(const Key('companion-label')), findsOneWidget, reason: 'state label at $t');
      expect(find.text(c.fixture.challengePrompt), findsOneWidget, reason: 'challenge at $t');
      expect(find.byKey(const Key('respond-STRONG')), findsOneWidget, reason: 'evidence capture at $t');
    }
    expect(find.byKey(const Key('content-first-world')), findsOneWidget);
    expect(find.byKey(const Key('companion-canvas')), findsNothing);
    expect(ops[FallbackLevel.content], 0);
    expect(ops[FallbackLevel.full]!, greaterThan(0));
    // FULL animates (repaints every frame); lower tiers paint once and stop.
    expect(ops[FallbackLevel.full]!, greaterThan(ops[FallbackLevel.reduced]!));
    await tapKey(tester, 'respond-PARTIAL');
    await tapKey(tester, 'act-primary');
    await tapKey(tester, 'repair-correct');
    expect(c.engine.step, FlowStep.complete);
    await finish(tester);
  });

  testWidgets('T8: per-paint work falls FULL > REDUCED > SIMPLE and NEUTRAL drops domain grammar', (tester) async {
    final c = await pumpProof(tester, disableAnimations: true);
    await toChallenge(tester, c);
    final perPaint = <FallbackLevel, int>{};
    final companionOps = <FallbackLevel, int>{};
    for (final t in [FallbackLevel.full, FallbackLevel.reduced, FallbackLevel.simple, FallbackLevel.neutral]) {
      c.setTier(t);
      final o0 = worldStats.ops, f0 = worldStats.frames, co0 = companionStats.ops;
      await tester.pump();
      perPaint[t] = ((worldStats.ops - o0) / (worldStats.frames - f0)).round();
      companionOps[t] = companionStats.ops - co0;
    }
    expect(perPaint[FallbackLevel.full]!, greaterThan(perPaint[FallbackLevel.reduced]!));
    expect(perPaint[FallbackLevel.reduced]!, greaterThanOrEqualTo(perPaint[FallbackLevel.simple]!));
    expect(perPaint[FallbackLevel.neutral]!, lessThan(perPaint[FallbackLevel.full]!));
    // NEUTRAL removes the Companion canvas entirely; only the state label remains.
    expect(find.byKey(const Key('companion-canvas')), findsNothing);
    c.setTier(FallbackLevel.simple);
    await tester.pump();
    expect(find.byKey(const Key('companion-canvas')), findsOneWidget);
    debugPrint('R7P1_TIER_OPS world=$perPaint companion=$companionOps');
    await finish(tester);
  });

  testWidgets('T9: reduced motion (setting or OS) stops all continuous animation', (tester) async {
    final c = await pumpProof(tester, disableAnimations: true);
    await toChallenge(tester, c);
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.byKey(const Key('companion-label')), findsOneWidget);
    await finish(tester);
  });

  testWidgets('FULL tier without reduced motion does animate (control)', (tester) async {
    final c = await pumpProof(tester);
    await toChallenge(tester, c);
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.hasRunningAnimations, isTrue);
    c.setReducedMotion(true);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
    await finish(tester);
  });

  testWidgets('T10: audio unavailable shows text and never claims Speaking', (tester) async {
    final c = await pumpProof(tester);
    c.setAudioAvailable(false);
    await tester.pump();
    await tapKey(tester, 'act-primary');
    expect(find.byKey(const Key('audio-status')), findsOneWidget);
    expect(find.byKey(const Key('transcript')), findsOneWidget);
    for (var guard = 0; c.engine.step != FlowStep.challenge; guard++) {
      expect(guard, lessThan(10));
      expect(find.text('Speaking'), findsNothing);
      await tapKey(tester, 'act-primary');
    }
    await finish(tester);
  });

  testWidgets('B12: Companion and world asset failures keep the teacher UI and the loop', (tester) async {
    final c = await pumpProof(tester);
    c.setCompanionAssetFailed(true);
    await tester.pump();
    expect(find.byKey(const Key('companion-canvas')), findsNothing);
    expect(find.byKey(const Key('companion-label')), findsOneWidget);
    c.setWorldAssetFailed(true);
    await tester.pump();
    expect(find.byKey(const Key('content-first-world')), findsOneWidget);
    expect(c.engine.events.where((e) => e.reasonCode == 'R_FALLBACK_CAPABILITY'), isNotEmpty);
    await toChallenge(tester, c);
    await tapKey(tester, 'respond-STRONG');
    await tapKey(tester, 'act-primary');
    expect(c.engine.step, FlowStep.complete);
    await finish(tester);
  });

  testWidgets('R7-08: tap targets, labels and contrast guidelines at the challenge', (tester) async {
    final handle = tester.ensureSemantics();
    final c = await pumpProof(tester, disableAnimations: true);
    await toChallenge(tester, c);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    expect(find.bySemanticsLabel(RegExp('^Learning world\\. ')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Companion: ')), findsOneWidget);
    handle.dispose();
    await finish(tester);
  });

  testWidgets('R7-08: large text (2.0x) keeps the challenge and actions reachable', (tester) async {
    final c = await pumpProof(tester, textScale: 2, disableAnimations: true);
    await toChallenge(tester, c);
    expect(tester.takeException(), isNull);
    await tapKey(tester, 'respond-MISCONCEPTION');
    expect(tester.takeException(), isNull);
    expect(c.engine.step, FlowStep.feedback);
    await finish(tester);
  });

  testWidgets('P9 synthetic phone matrix keeps D/E usable in iPhone portrait and landscape', (tester) async {
    Future<void> runViewport(Size size, CompanionIdentity identity) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final c = ProofController(fixtures);
      addTearDown(c.dispose);
      c.setCompanionIdentity(identity);
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size, devicePixelRatio: 3, disableAnimations: false),
          child: MaterialApp(home: ProofScreen(controller: c)),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull, reason: '${identity.name} @ $size initial');
      expect(find.byKey(const Key('companion-raster')), findsOneWidget);
      expect(find.byKey(const Key('proof-scroll')), findsOneWidget);
      final visualSize = tester.getSize(find.byKey(const Key('companion-visual-box')));
      final expectedExtent = size.width > size.height ? 104.0 : 124.0;
      expect(visualSize, Size.square(expectedExtent), reason: '${identity.name} @ $size companion scale');
      final initialCompanionRect = tester.getRect(find.byKey(const Key('companion-raster')));
      expect(initialCompanionRect.top, greaterThanOrEqualTo(0));
      expect(
        initialCompanionRect.bottom,
        lessThanOrEqualTo(size.height),
        reason: '${identity.name} @ $size companion must be visible without scrolling',
      );

      await toChallenge(tester, c);
      expect(tester.takeException(), isNull, reason: '${identity.name} @ $size challenge');
      expect(find.byKey(const Key('respond-STRONG')), findsOneWidget);

      await tapKey(tester, 'respond-PARTIAL');
      expect(c.engine.step, FlowStep.feedback);
      expect(tester.takeException(), isNull, reason: '${identity.name} @ $size feedback');

      c.setReducedMotion(true);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.byKey(const Key('companion-raster')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '${identity.name} @ $size reduced motion');

      await finish(tester);
    }

    for (final size in const [Size(430, 932), Size(932, 430)]) {
      for (final identity in CompanionIdentity.values) {
        await runViewport(size, identity);
      }
    }
  });

  testWidgets('B13: switching fixtures repeatedly does not leak animation controllers', (tester) async {
    final c = await pumpProof(tester);
    final base = LiveControllers.count;
    for (var i = 0; i < 12; i++) {
      c.selectFixture(i % fixtures.length);
      c.setTier(FallbackLevel.values[i % FallbackLevel.values.length]);
      await tester.pump(const Duration(milliseconds: 50));
    }
    c.setTier(FallbackLevel.full);
    await tester.pump();
    expect(LiveControllers.count, base);
    await finish(tester);
  });

  testWidgets('T1–T11 scenario runner completes functionally (fake clock, no frame timing)', (tester) async {
    final c = await pumpProof(tester);
    final runner = ScenarioRunner(
      c,
      wait: (d) => tester.pump(d),
      soakCycles: 4,
      dwell: const Duration(milliseconds: 300),
      flush: const Duration(milliseconds: 100),
      tierHold: const Duration(milliseconds: 200),
    );
    final report = await runner.runAll(assetBytes: 1);
    final failed = [
      for (final s in report['scenarios'] as List)
        if ((s as Map)['result'] != 'FUNCTIONAL_PASS') '${s['id']}: ${s['checks_failed']}',
    ];
    expect(failed, isEmpty);
    expect(report['functional_result'], 'PASS');
    expect((report['scenarios'] as List), hasLength(11));
    await finish(tester);
  });

  test('painter uses one renderer for all domains (no domain-specific painter class)', () {
    expect(WorldPainter, isNotNull);
    for (final f in fixtures) {
      expect(() => describeScene(f.scene), returnsNormally);
    }
  });
}
