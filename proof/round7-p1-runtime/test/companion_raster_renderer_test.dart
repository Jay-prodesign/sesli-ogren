import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:r7_p1_runtime_proof/src/flow/flow_engine.dart';
import 'package:r7_p1_runtime_proof/src/render/companion_renderer.dart';
import 'package:r7_p1_runtime_proof/src/render/world_painter.dart';

void main() {
  Future<void> pumpRenderer(
    WidgetTester tester, {
    required CompanionRenderer renderer,
    required CompanionState state,
    required double motion,
    bool animate = true,
  }) async {
    final stats = PaintStats();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 72,
            height: 72,
            child: renderer.build(
              state: state,
              tone: CompanionTone.neutral,
              motion: AlwaysStoppedAnimation<double>(motion),
              animate: animate,
              stats: stats,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('SPEAK uses local mouth warp on D without changing the raster identity', (tester) async {
    await pumpRenderer(
      tester,
      renderer: const RasterCompanionRenderer.knot(),
      state: CompanionState.speak,
      motion: 0.25,
    );

    expect(find.byKey(const Key('companion-raster')), findsOneWidget);
    expect(find.byKey(const Key('companion-mouth-warp')), findsOneWidget);
  });

  testWidgets('SPEAK uses the same local mouth-warp architecture on E', (tester) async {
    await pumpRenderer(
      tester,
      renderer: const RasterCompanionRenderer.tilt(),
      state: CompanionState.speak,
      motion: 0.25,
    );

    expect(find.byKey(const Key('companion-raster')), findsOneWidget);
    expect(find.byKey(const Key('companion-mouth-warp')), findsOneWidget);
  });

  testWidgets('blink is a small overlay and does not replace the canonical raster', (tester) async {
    await pumpRenderer(
      tester,
      renderer: const RasterCompanionRenderer.knot(),
      state: CompanionState.idle,
      motion: 0.16,
    );

    expect(find.byKey(const Key('companion-raster')), findsOneWidget);
    expect(find.byKey(const Key('companion-blink-overlay')), findsOneWidget);
  });

  testWidgets('reduced/static rendering disables mouth animation and blink overlays', (tester) async {
    await pumpRenderer(
      tester,
      renderer: const RasterCompanionRenderer.tilt(),
      state: CompanionState.speak,
      motion: 0.16,
      animate: false,
    );

    expect(find.byKey(const Key('companion-raster')), findsOneWidget);
    expect(find.byKey(const Key('companion-mouth-warp')), findsNothing);
    expect(find.byKey(const Key('companion-blink-overlay')), findsNothing);
  });
}
