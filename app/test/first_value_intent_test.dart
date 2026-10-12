import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/app_runtime.dart';
import 'package:sesli_ogren/src/app/focus_screen.dart';
import 'package:sesli_ogren/src/app/living_study_desk_home.dart';
import 'package:sesli_ogren/src/app/material_workspace_screen.dart';
import 'package:sesli_ogren/src/app/source_reader_screen.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
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

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder, {int maxPumps = 80}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Expected first-value route was not reached within bounded pumps.');
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  final target = finder.hitTestable();
  await _pumpUntilFound(tester, target);
  await tester.tap(target);
  await tester.pump();
}

void main() {
  sqfliteFfiInit();

  testWidgets('first value keeps learning truth and alternate paths usable at narrow large text', (tester) async {
    tester.view.physicalSize = const Size(320, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
    );
    const materialId = MaterialId('first-value-large-text');
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: materialId,
      text: 'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür. Bu kısa kaynak büyük yazıda da öğrenme gerçeğini eksiksiz göstermelidir.',
      sourceName: 'Büyük yazı ilk değer notu',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: LivingDeskReviewScope(
            child: MaterialWorkspaceScreen(runtime: runtime, materialId: materialId, showFirstValueIntent: true),
          ),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const ValueKey('first-value-intent')));

    final firstValueScroll = find.descendant(
      of: find.byKey(const ValueKey('first-value-intent')),
      matching: find.byType(Scrollable),
    );
    expect(firstValueScroll, findsOneWidget);

    final reasonFinder = find.text('Önce bütünü gör; sonra kaynağı kapatıp ne kaldığını sınarsın.');
    await tester.scrollUntilVisible(reasonFinder, 180, scrollable: firstValueScroll);
    await tester.pump();
    final reason = tester.widget<Text>(reasonFinder);
    expect(reason.maxLines, isNull);
    expect(reason.overflow, isNull);

    final evidenceFinder = find.text('Hatırla denemesi öğrenme kanıtını oluşturur.');
    await tester.scrollUntilVisible(evidenceFinder, 180, scrollable: firstValueScroll);
    await tester.pump();
    final evidenceTruth = tester.widget<Text>(evidenceFinder);
    expect(evidenceTruth.maxLines, isNull);
    expect(evidenceTruth.overflow, isNull);

    await _tapVisible(tester, find.text('Diğer çalışma yolları'));
    await _pumpUntilFound(tester, find.byKey(const ValueKey('first-intent-other-paths-scroll')));

    expect(find.byKey(const ValueKey('first-intent-other-paths-scroll')), findsOneWidget);
    expect(find.text('Dinle'), findsOneWidget);
    expect(find.text('Hızlı özet'), findsOneWidget);
    expect(find.text('Bildiğimi kontrol et'), findsOneWidget);
    final focusPath = find.text('Birlikte odaklanalım');
    await tester.scrollUntilVisible(
      focusPath,
      140,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('first-intent-other-paths-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pump();
    expect(focusPath.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new source asks one intent question before evidence and keeps paths reversible', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
    );
    const materialId = MaterialId('first-value-intent-material');
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: materialId,
      text: 'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür. Bu kısa kaynak ilk değer yolunu seçmek için yeterlidir.',
      sourceName: 'İlk değer notu',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LivingDeskReviewScope(
          child: MaterialWorkspaceScreen(runtime: runtime, materialId: materialId, showFirstValueIntent: true),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const ValueKey('first-value-intent')));

    expect(find.text('İLK 60 SANİYE'), findsOneWidget);
    expect(find.text('Önce kaynağı bir kez gör.'), findsOneWidget);
    expect(find.text('Kaynağı aç'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('first-intent-listen-direct')),
      220,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump();
    expect(find.text('Kaynağı dinle'), findsOneWidget);
    expect(find.text('Hızlı özetle genel resmi gör'), findsNothing);
    expect(find.text('Diğer çalışma yolları'), findsOneWidget);
    expect(find.text('Hatırla denemesi öğrenme kanıtını oluşturur.'), findsOneWidget);

    await _tapVisible(tester, find.text('Kaynağı aç'));
    await _pumpUntilFound(tester, find.byType(SourceReaderScreen));
    expect(find.text('İlk değer notu'), findsWidgets);
    Navigator.of(tester.element(find.byType(SourceReaderScreen))).pop();
    await _pumpUntilFound(tester, find.text('İlk aktif denemeni yap'));

    expect(find.byKey(const ValueKey('first-value-intent')), findsNothing);
    expect(find.text('İlk aktif denemeni yap'), findsOneWidget);
    expect(find.text('Diğer çalışma yolları'), findsOneWidget);

    await _tapVisible(tester, find.byKey(const ValueKey('workspace-other-study-paths')));
    await _pumpUntilFound(tester, find.byKey(const ValueKey('workspace-other-study-paths-scroll')));
    expect(find.byKey(const ValueKey('workspace-other-quick-recap')), findsOneWidget);
    final focusAction = find.byKey(const ValueKey('workspace-other-focus'));
    await tester.scrollUntilVisible(
      focusAction,
      140,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('workspace-other-study-paths-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    final visibleFocusAction = focusAction.hitTestable();
    await _pumpUntilFound(tester, visibleFocusAction);
    await tester.tap(visibleFocusAction);
    await _pumpUntilFound(tester, find.text('KISA ODAK · 3 ADIM'));
    expect(find.byType(FocusScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
