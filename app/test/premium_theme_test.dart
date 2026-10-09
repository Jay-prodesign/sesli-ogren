import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/app_theme.dart';

void main() {
  test('premium palette keeps readable primary actions and surfaces', () {
    final theme = SesliOgrenTheme.light();
    expect(theme.colorScheme.primary, AppPalette.primary);
    expect(theme.colorScheme.onPrimary, Colors.white);
    expect(theme.scaffoldBackgroundColor, AppPalette.canvas);
    expect(theme.colorScheme.onSurface, AppPalette.ink);
    expect(theme.colorScheme.primaryContainer, AppPalette.primarySoft);
    expect(theme.navigationBarTheme.height, 72);
  });

  testWidgets('premium theme retains legible scalable action labels', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: SesliOgrenTheme.light(),
        home: const Scaffold(
          body: Center(child: FilledButton(onPressed: null, child: Text('Öğrenmeye devam et'))),
        ),
      ),
    );
    expect(find.text('Öğrenmeye devam et'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
