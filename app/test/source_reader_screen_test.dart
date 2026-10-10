import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/source_reader_screen.dart';
import 'package:sesli_ogren/src/app/living_study_desk_home.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';

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
    expect(find.bySemanticsLabel('Okuma ilerlemesi'), findsOneWidget);

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

    await tester.tap(find.text('Kaynağı kapat ve hatırla'));
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

  testWidgets('source reader restores and reports a durable reading position', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final reported = <double>[];
    final longSource = List<String>.generate(
      90,
      (index) => 'Bölüm ${index + 1}: Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür.',
    ).join(' ');

    await tester.pumpWidget(
      MaterialApp(
        home: SourceReaderScreen(
          title: 'Uzun biyoloji notu',
          sourceText: longSource,
          initialProgress: 0.5,
          onProgressChanged: (progress) async {
            reported.add(progress);
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).last);
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    final restored = scrollable.position.pixels / scrollable.position.maxScrollExtent;
    expect(restored, closeTo(0.5, 0.08));
    expect(find.byKey(const ValueKey('reader-resume-restored')), findsOneWidget);
    expect(find.text('Kaldığın yer geri açıldı · %50'), findsOneWidget);

    await tester.drag(find.byType(Scrollable).last, const Offset(0, -240));
    await tester.pump();
    expect(reported, isNotEmpty);
    expect(reported.last, greaterThan(0.5));

    reported.clear();
    var recalled = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SourceReaderScreen(
          title: 'Uzun biyoloji notu',
          sourceText: longSource,
          initialProgress: restored,
          onProgressChanged: (progress) async {
            reported.add(progress);
          },
          onRecall: () => recalled++,
        ),
      ),
    );
    await tester.pump();
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -180));
    await tester.pump();
    reported.clear();
    await tester.tap(find.text('Kaynağı kapat ve hatırla'));
    await tester.pump();

    expect(recalled, 1);
    expect(reported, isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('source trust UI never labels platform reference as learner-owned', (tester) async {
    final sourceVersion = SourceVersionRecord(
      identity: const SourceVersionIdentity(
        materialId: MaterialId('reference-material'),
        sourceVersionId: SourceVersionId('reference-version'),
        contentDigest: 'reference-digest',
        trustClass: SourceTrustClass.authoritativeReference,
        knowledgeClass: SourceKnowledgeClass.trustedPlatform,
      ),
      mediaType: SourceMediaType.pdf,
      sourceName: 'Biyoloji referansı.pdf',
      mimeType: 'application/pdf',
      byteSize: 1024,
      createdAt: DateTime.utc(2026, 10, 10),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LivingDeskReviewScope(
          child: SourceReaderScreen(
            title: 'Biyoloji referansı',
            sourceText: 'Klorofil ışık enerjisinin soğurulmasında görev alır.',
            sourceVersion: sourceVersion,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('GÜVENİLİR KAYNAK · PDF · GÜNCEL SÜRÜM'), findsOneWidget);
    expect(find.textContaining('KENDİ KAYNAĞIN'), findsNothing);
    expect(find.text('Biyoloji referansı.pdf'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
