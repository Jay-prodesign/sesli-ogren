import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/atelier_learning_surfaces.dart';
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
    final progress = tester.widget<LinearProgressIndicator>(find.byKey(const ValueKey('reader-progress')));
    expect(progress.semanticsLabel, isIn(const ['Kaynak görünümü, tamamı ekranda', 'Okuma konumu']));

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

  testWidgets('OCR provenance warning stays visible and is not presented as learner evidence', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 650));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: LivingDeskReviewScope(
            child: SourceReaderScreen(
              title: 'Tahta fotoğrafı',
              sourceText: 'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür.',
              sourceWarnings: const ['OCR_TEXT_REQUIRES_SOURCE_CHECK'],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('reader-source-warning')), findsOneWidget);
    expect(find.textContaining('OCR ile okundu'), findsOneWidget);
    expect(find.textContaining('görsel kaynakla karşılaştır'), findsOneWidget);
    expect(find.textContaining('ustalık'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('source reader stacks learning actions on narrow large-text layouts', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 650));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var listened = 0;
    var recalled = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: LivingDeskReviewScope(
            child: SourceReaderScreen(
              title: 'Dar ekran biyoloji notu',
              sourceText:
                  'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürmeye yardım eder. '
                  'Kaynak açıkken kanıt görülebilir.',
              onListen: () => listened++,
              onRecall: () => recalled++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('reader-learning-actions-stacked')), findsOneWidget);
    expect(find.byType(AtelierLearningRail), findsNothing);
    expect(find.text('Kaynağı kapat ve hatırla'), findsOneWidget);
    expect(find.text('Dinleyerek hazırlan'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Kaynağı kapat ve hatırla'));
    await tester.pump();
    expect(recalled, 1);

    await tester.tap(find.text('Dinleyerek hazırlan'));
    await tester.pump();
    expect(listened, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text never gives Reader action buttons infinite width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 544));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: SourceReaderScreen(
            title: 'Geniş ekran büyük yazı notu',
            sourceText:
                'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürmeye yardım eder. '
                'Kaynak açıkken güvenli öğrenme eylemleri görünür kalır.',
            onListen: () {},
            onRecall: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('reader-learning-actions-stacked')), findsOneWidget);
    final listenSize = tester.getSize(find.widgetWithText(OutlinedButton, 'Dinleyerek hazırlan'));
    final recallSize = tester.getSize(find.widgetWithText(FilledButton, 'Kaynağı kapat ve hatırla'));
    expect(listenSize.width.isFinite, isTrue);
    expect(recallSize.width.isFinite, isTrue);
    expect(listenSize.width, lessThanOrEqualTo(800));
    expect(recallSize.width, lessThanOrEqualTo(800));
    expect(tester.takeException(), isNull);
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

    final sourceScroll = find.byKey(const ValueKey('reader-source-scroll'));
    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: sourceScroll, matching: find.byType(Scrollable)).first,
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    final restored = scrollable.position.pixels / scrollable.position.maxScrollExtent;
    expect(restored, closeTo(0.5, 0.08));
    expect(find.byKey(const ValueKey('reader-resume-restored')), findsOneWidget);
    expect(find.text('Kaldığın yer geri açıldı · %50'), findsOneWidget);

    await tester.drag(sourceScroll, const Offset(0, -900));
    await tester.pump(const Duration(milliseconds: 20));
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
    await tester.drag(find.byKey(const ValueKey('reader-source-scroll')), const Offset(0, -180));
    await tester.pump();
    reported.clear();
    await tester.tap(find.text('Kaynağı kapat ve hatırla'));
    await tester.pump(const Duration(milliseconds: 20));

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
