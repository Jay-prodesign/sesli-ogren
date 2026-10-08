import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/companion_view.dart';
import 'package:sesli_ogren/src/app/living_study_desk_home.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('LA-0040 empty Home at 390x844', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: LivingStudyDeskHome(
            material: null,
            continuation: null,
            sourceText: null,
            otherMaterials: const [],
            onOpenWorkspace: () {},
            onOpenLearning: () {},
            onOpenListen: () {},
            onOpenMaterial: (_) {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/la0040_home_empty_390x844.png'));
  });

  for (final state in CompanionVisualState.values) {
    testWidgets('LA-0040 D/Knot $state at 390x844', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: const Color(0xFFF5F7F4),
            body: Center(child: CompanionView(state: state, size: 128)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/la0040_companion_${state.name}_390x844.png'),
      );
    });
  }
}
