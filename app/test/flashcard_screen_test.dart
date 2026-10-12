import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/app_runtime.dart';
import 'package:sesli_ogren/src/app/app_theme.dart';
import 'package:sesli_ogren/src/app/flashcard_screen.dart';
import 'package:sesli_ogren/src/app/living_study_desk_home.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/domain/authenticated_learner.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sesli_ogren/src/learning/recall_learning_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _UnusedPdfExtractor implements PdfTextExtractor {
  const _UnusedPdfExtractor();

  @override
  Future<ExtractedPdf> extract(Uint8List bytes, {required String sourceName}) {
    throw UnimplementedError();
  }
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder, {int maxPumps = 100}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Expected flashcard surface was not reached within bounded pumps.');
}

Future<AppRuntime> _runtime() async {
  final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
  final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
  return AppRuntime(
    learner: const LearnerIdentity.local(),
    store: store,
    ingest: ingest,
    recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
    telemetry: store.operationalTelemetry(),
  );
}

void main() {
  sqfliteFfiInit();

  testWidgets('flashcard response stays hidden until reveal and resumes durable cursor', (tester) async {
    final runtime = await _runtime();
    addTearDown(runtime.close);
    const materialId = MaterialId('flashcard-screen-material');
    await runtime.ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: materialId,
      sourceName: 'Fotosentez kart notu',
      text:
          'Fotosentez sırasında bitkiler ışık enerjisini kimyasal enerjiye dönüştürür. '
          'Klorofil ışığın soğurulmasında önemli görev alır. '
          'Karbondioksit ve su kullanılarak glikoz üretimine katkı sağlanır.',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: SesliOgrenTheme.light(),
        home: LivingDeskReviewScope(
          child: FlashcardScreen(runtime: runtime, materialId: materialId),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const ValueKey('flashcards-reveal')));

    expect(find.byKey(const ValueKey('flashcards-answer')), findsNothing);
    expect(find.byKey(const ValueKey('flashcards-remembered')), findsNothing);
    expect(find.byKey(const ValueKey('flashcards-again')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('flashcards-reveal')));
    await tester.pump();
    expect(find.byKey(const ValueKey('flashcards-answer')), findsOneWidget);
    expect(find.byKey(const ValueKey('flashcards-source-evidence')), findsOneWidget);
    expect(find.byKey(const ValueKey('flashcards-remembered')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('flashcards-remembered')));
    await _pumpUntilFound(tester, find.text('KART 2 / 3'));
    expect(find.byKey(const ValueKey('flashcards-answer')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        theme: SesliOgrenTheme.light(),
        home: LivingDeskReviewScope(
          child: FlashcardScreen(runtime: runtime, materialId: materialId),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('KART 2 / 3'));
    expect(find.text('KART 2 / 3'), findsOneWidget);

    for (final expectedNext in ['KART 3 / 3', 'complete']) {
      await tester.tap(find.byKey(const ValueKey('flashcards-reveal')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('flashcards-remembered')));
      if (expectedNext == 'complete') {
        await _pumpUntilFound(tester, find.byKey(const ValueKey('flashcards-complete')));
      } else {
        await _pumpUntilFound(tester, find.text(expectedNext));
      }
    }
    expect(find.text('3 hatırlandı · 0 tekrar'), findsOneWidget);
    expect(find.textContaining('ustalık veya kalıcı öğrenme iddiası değildir'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('flashcards-restart')));
    await _pumpUntilFound(tester, find.text('KART 1 / 3'));
    expect(find.text('KART 1 / 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unusable source fails closed with a recoverable Flashcards state', (tester) async {
    final runtime = await _runtime();
    addTearDown(runtime.close);
    const materialId = MaterialId('flashcard-unusable-source');
    await runtime.ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: materialId,
      sourceName: 'Çok kısa not',
      text: 'Kısa.',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: SesliOgrenTheme.light(),
        home: LivingDeskReviewScope(
          child: FlashcardScreen(runtime: runtime, materialId: materialId),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const ValueKey('flashcards-retry')));
    expect(find.text('Kartlar açılamadı.'), findsOneWidget);
    expect(find.byKey(const ValueKey('flashcards-reveal')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('flashcards remain usable at 320px and 150% text scale', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final runtime = await _runtime();
    addTearDown(runtime.close);
    const materialId = MaterialId('flashcard-large-text');
    await runtime.ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: materialId,
      sourceName: 'Uzun başlıklı fotosentez çalışma kartı notu',
      text:
          'Fotosentez sırasında bitkiler ışık enerjisini kimyasal enerjiye dönüştürür. '
          'Klorofil ışığın soğurulmasında önemli görev alır. '
          'Karbondioksit ve su kullanılarak glikoz üretimine katkı sağlanır.',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: SesliOgrenTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5), disableAnimations: true),
          child: LivingDeskReviewScope(
            child: FlashcardScreen(runtime: runtime, materialId: materialId),
          ),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const ValueKey('flashcards-reveal')));
    expect(find.byKey(const ValueKey('flashcards-companion')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('flashcards-reveal')));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('flashcards-source-evidence')),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('flashcards-source-evidence')), findsOneWidget);
    expect(find.byKey(const ValueKey('flashcards-remembered')), findsOneWidget);
    expect(find.byKey(const ValueKey('flashcards-again')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
