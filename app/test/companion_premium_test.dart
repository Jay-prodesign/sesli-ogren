import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/companion_view.dart';

void main() {
  testWidgets('companion exposes one accessible state label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: CompanionView(state: CompanionVisualState.listen),
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Düğüm dinleme modunda'), findsOneWidget);
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  testWidgets('companion supports compact presentation with reduced motion', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: CompanionView(state: CompanionVisualState.success, size: 76),
          ),
        ),
      ),
    );
    expect(find.byType(CompanionView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
