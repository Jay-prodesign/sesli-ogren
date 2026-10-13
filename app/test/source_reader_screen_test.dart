import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/atelier_learning_surfaces.dart';
import 'package:sesli_ogren/src/app/source_reader_screen.dart';
import 'package:sesli_ogren/src/app/living_study_desk_home.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sesli_ogren/src/domain/reader_annotation.dart';

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

  testWidgets('Reader selection creates source-bound non-evidence context actions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const source = 'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür.';
    ReaderAnnotationRecord? saved;
    SourceAnchor? tutorAnchor;
    SourceAnchor? recalledAnchor;

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: SourceReaderScreen(
          title: 'Biyoloji',
          sourceText: source,
          sourceAnchors: const [SourceAnchor(startOffset: 0, endOffset: source.length, pageNumber: 1)],
          onSaveAnnotation: (anchor, text, kind, noteText) async {
            saved = ReaderAnnotationRecord(
              id: ReaderAnnotationId('reader-test-${kind.name}'),
              materialId: const MaterialId('reader-test-material'),
              sourceVersionId: const SourceVersionId('reader-test-source'),
              sourceAnchor: anchor,
              selectedText: text,
              selectedTextDigest: 'digest',
              kind: kind,
              noteText: noteText,
              createdAt: DateTime.utc(2026, 10, 13),
              updatedAt: DateTime.utc(2026, 10, 13),
            );
            return saved!;
          },
          onTutorSelection: (anchor) => tutorAnchor = anchor,
          onRecallSelection: (anchor) => recalledAnchor = anchor,
        ),
      ),
    );
    await tester.pump();

    final selectable = tester.widget<SelectableText>(find.byKey(const ValueKey('reader-selectable-source')));
    final selectedStart = source.indexOf('ışık enerjisini');
    final selectedEnd = selectedStart + 'ışık enerjisini'.length;
    selectable.onSelectionChanged!(
      TextSelection(baseOffset: selectedStart, extentOffset: selectedEnd),
      SelectionChangedCause.longPress,
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('reader-selection-context')), findsOneWidget);
    expect(find.text('Seçili bölüm · öğrenme kanıtı değil'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reader-selection-highlight')));
    await tester.pump();

    expect(saved, isNotNull);
    expect(saved!.selectedText, 'ışık enerjisini');
    expect(saved!.sourceAnchor.startOffset, selectedStart);
    expect(saved!.sourceAnchor.endOffset, selectedEnd);
    expect(saved!.sourceAnchor.pageNumber, 1);
    expect(find.byKey(const ValueKey('reader-annotation-reader-test-highlight')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('reader-selection-note')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('reader-note-input')), 'Enerji dönüşümünü tekrar sor.');
    await tester.tap(find.byKey(const ValueKey('reader-note-save')));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.kind, ReaderAnnotationKind.note);
    expect(saved!.noteText, 'Enerji dönüşümünü tekrar sor.');
    expect(find.byKey(const ValueKey('reader-annotation-reader-test-note')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('reader-selection-tutor')));
    await tester.pump();
    expect(tutorAnchor, isNotNull);
    expect(tutorAnchor!.startOffset, selectedStart);
    expect(tutorAnchor!.endOffset, selectedEnd);

    await tester.tap(find.byKey(const ValueKey('reader-selection-recall')));
    await tester.pump();
    expect(recalledAnchor, isNotNull);
    expect(recalledAnchor!.startOffset, selectedStart);
    expect(recalledAnchor!.endOffset, selectedEnd);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reader note edit and delete remain explicit and local', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final original = ReaderAnnotationRecord(
      id: const ReaderAnnotationId('reader-note-crud'),
      materialId: const MaterialId('reader-note-material'),
      sourceVersionId: const SourceVersionId('reader-note-source'),
      sourceAnchor: const SourceAnchor(startOffset: 0, endOffset: 10),
      selectedText: 'Fotosentez',
      selectedTextDigest: 'digest',
      kind: ReaderAnnotationKind.note,
      noteText: 'İlk not',
      createdAt: DateTime.utc(2026, 10, 13),
      updatedAt: DateTime.utc(2026, 10, 13),
    );
    ReaderAnnotationRecord? edited;
    ReaderAnnotationId? deleted;

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: SourceReaderScreen(
          title: 'Biyoloji',
          sourceText: 'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür.',
          initialAnnotations: [original],
          onSaveAnnotation: (anchor, text, kind, noteText) async {
            edited = ReaderAnnotationRecord(
              id: original.id,
              materialId: original.materialId,
              sourceVersionId: original.sourceVersionId,
              sourceAnchor: anchor,
              selectedText: text,
              selectedTextDigest: original.selectedTextDigest,
              kind: kind,
              noteText: noteText,
              createdAt: original.createdAt,
              updatedAt: DateTime.utc(2026, 10, 13, 1),
            );
            return edited!;
          },
          onDeleteAnnotation: (annotationId) async {
            deleted = annotationId;
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.text('İlk not'), findsOneWidget);
    await tester.tap(find.byTooltip('Notu düzenle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('reader-note-edit-input')), 'Güncellenmiş not');
    await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
    await tester.pumpAndSettle();

    expect(edited?.noteText, 'Güncellenmiş not');
    expect(find.text('Güncellenmiş not'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final deleteAction = find.byTooltip('İşareti sil');
    await tester.ensureVisible(deleteAction);
    await tester.pump();
    expect(deleteAction.hitTestable(), findsOneWidget);
    await tester.tap(deleteAction.hitTestable());
    await tester.pump();
    expect(deleted, original.id);
    expect(find.byKey(const ValueKey('reader-annotation-reader-note-crud')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reader shows stale annotations without rebinding them to current source', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 650));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: SourceReaderScreen(
          title: 'Güncel kaynak',
          sourceText: 'Yeni kaynak metni burada.',
          staleAnnotationCount: 2,
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('reader-stale-annotations')), findsOneWidget);
    expect(find.textContaining('2 eski işaret'), findsOneWidget);
    expect(find.textContaining('yeniden bağlanmış sayılmıyor'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
