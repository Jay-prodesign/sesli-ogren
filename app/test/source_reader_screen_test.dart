import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/source_reader_screen.dart';

void main() {
  testWidgets('source reader keeps local search and learning exits usable', (tester) async {
    var listened = 0;
    var recalled = 0;
    var recap = 0;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: SourceReaderScreen(
          title: 'Biyoloji notu',
          sourceText: 'İlk bölüm. Fotosentez ışık enerjisini kullanır. Fotosentez bitkilerde gerçekleşir.',
          onListen: () => listened++,
          onRecap: () => recap++,
          onRecall: () => recalled++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.descendant(of: find.byType(AppBar), matching: find.text('Biyoloji notu')), findsOneWidget);
    expect(find.byType(RichText), findsWidgets);

    await tester.tap(find.byTooltip('Metinde ara'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ışık');
    await tester.pumpAndSettle();
    expect(find.text('1 eşleşme'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Aramayı temizle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'IŞIK');
    await tester.pumpAndSettle();
    expect(find.text('1 eşleşme'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Hatırla'));
    await tester.pump();
    expect(recalled, 1);

    await tester.tap(find.byTooltip('Okuma ve öğrenme seçenekleri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaynağı dinle').last);
    await tester.pump();
    expect(listened, 1);

    await tester.tap(find.byTooltip('Okuma ve öğrenme seçenekleri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hızlı özet').last);
    await tester.pump();
    expect(recap, 1);
  });

  testWidgets('empty source returns to the material instead of trapping the learner', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const SourceReaderScreen(title: 'Kaynak', sourceText: '   '),
                  ),
                ),
                child: const Text('Reader aç'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Reader aç'));
    await tester.pumpAndSettle();

    expect(find.text('Bu kaynak için okunabilir metin bulunamadı.'), findsOneWidget);
    expect(find.text('Materyale dön'), findsOneWidget);
    await tester.tap(find.text('Materyale dön'));
    await tester.pumpAndSettle();

    expect(find.text('Reader aç'), findsOneWidget);
    expect(find.text('Bu kaynak için okunabilir metin bulunamadı.'), findsNothing);
  });

  testWidgets('source reader gives a clear empty-source recovery state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SourceReaderScreen(title: 'Kaynak', sourceText: '   '),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bu kaynak için okunabilir metin bulunamadı.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
