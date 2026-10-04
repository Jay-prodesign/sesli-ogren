import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/sesli_ogren_app.dart';

void main() {
  testWidgets('production app shell boots with D/Knot and no feature-grid shell', (tester) async {
    await tester.pumpWidget(const SesliOgrenApp());

    expect(find.text('Sesli Öğren'), findsOneWidget);
    expect(
      find.text('Materyalinden anlayarak ilerleyen bir öğrenme yolculuğu.'),
      findsOneWidget,
    );
    expect(find.byType(FoundationScreen), findsOneWidget);
  });
}
