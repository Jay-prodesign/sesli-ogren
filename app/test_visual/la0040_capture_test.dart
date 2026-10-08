import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/companion_view.dart';
import 'package:sesli_ogren/src/app/living_study_desk_home.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Widget tests default to Ahem, which draws unreadable blocks.
    // Load real glyphs so screenshots can be assessed for visual quality.
    Future<void> loadFont(String family, String path) async {
      final bytes = await File(path).readAsBytes();
      final loader = FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }

    await loadFont('Roboto', '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf');
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot == null || flutterRoot.isEmpty) {
      throw StateError('FLUTTER_ROOT is required for material icon capture.');
    }
    await loadFont('MaterialIcons', '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  });

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
      await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/la0040_companion_${state.name}_390x844.png'));
    });
  }
}
