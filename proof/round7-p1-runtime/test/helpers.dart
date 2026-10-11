import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:r7_p1_runtime_proof/src/scene/fixture.dart';

Future<List<ProofFixture>> loadFixtures() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  return ProofFixture.loadAll(rootBundle);
}

Future<Map<String, dynamic>> rawFixture(String path) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  return jsonDecode(await rootBundle.loadString(path)) as Map<String, dynamic>;
}

/// Phone-sized logical surface (360×780 at 3x).
void usePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}
