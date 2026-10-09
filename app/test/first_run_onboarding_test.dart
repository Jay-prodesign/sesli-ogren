import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/first_run_onboarding.dart';

void main() {
  testWidgets('first run no longer blocks real product behind a feature tour', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FirstRunOnboardingGate(
          child: Scaffold(body: Text('APP_READY')),
        ),
      ),
    );

    expect(find.text('APP_READY'), findsOneWidget);
    expect(find.text('Materyalinle başla'), findsNothing);
    expect(find.text('Öğrenmeyi kanıtla'), findsNothing);
    expect(find.text('Kontrol sende'), findsNothing);
    expect(find.text('Devam et'), findsNothing);
  });
}
