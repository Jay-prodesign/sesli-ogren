import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/app_runtime.dart';
import 'package:sesli_ogren/src/app/app_theme.dart';
import 'package:sesli_ogren/src/app/learning_slice_screen.dart';
import 'package:sesli_ogren/src/app/material_workspace_screen.dart';
import 'package:sesli_ogren/src/app/product_shell_screen.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/learning/recall_learning_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _captureEnabled = bool.fromEnvironment('LA0039_VISUAL_CAPTURE');

class _UnusedPdfExtractor implements PdfTextExtractor {
  const _UnusedPdfExtractor();

  @override
  Future<ExtractedPdf> extract(Uint8List bytes, {required String sourceName}) {
    throw UnimplementedError();
  }
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder, {int maxPumps = 120}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Expected visual-review widget was not reached within bounded pumps.');
}

Widget _phoneFrame(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: SesliOgrenTheme.light(),
    home: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: child,
    ),
  );
}

void main() {
  sqfliteFfiInit();

  testWidgets(
    'capture LA-0039 representative Golden Product Slice',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
      addTearDown(store.close);

      final ingest = SourceIngestService(
        store: store,
        pdfTextExtractor: const _UnusedPdfExtractor(),
        now: () => DateTime.utc(2026, 10, 7, 12),
      );
      final recall = RecallLearningService(
        sourceStore: store,
        learningStore: store.learningTruthStore(),
        now: () => DateTime.utc(2026, 10, 7, 12, 1),
      );
      final runtime = AppRuntime(
        learner: AppRuntime.localM5LearnerFixture,
        store: store,
        ingest: ingest,
        recall: recall,
        telemetry: store.operationalTelemetry(),
      );

      await ingest.ingestPastedText(
        learner: runtime.learner,
        materialId: AppRuntime.primaryMaterialId,
        text:
            'Fotosentez sırasında klorofil ışık enerjisini kimyasal enerjiye dönüştürmeye yardımcı olur. '
            'Bitkiler karbondioksit ve suyu kullanır; süreç sonunda kimyasal enerji depolanır.',
        sourceName: 'Biyoloji — Fotosentez Notları',
      );

      await tester.pumpWidget(_phoneFrame(ProductShellScreen(runtime: runtime)));
      await _pumpUntilFound(tester, find.text('Şimdi ne yapmalı?'));
      await tester.pump(const Duration(milliseconds: 200));
      await expectLater(find.byType(Scaffold).first, matchesGoldenFile('goldens/la0039_home.png'));

      await tester.pumpWidget(_phoneFrame(
        MaterialWorkspaceScreen(runtime: runtime, materialId: AppRuntime.primaryMaterialId),
      ));
      await _pumpUntilFound(tester, find.text('Sıradaki aktif adım'));
      await tester.pump(const Duration(milliseconds: 200));
      await expectLater(find.byType(Scaffold).first, matchesGoldenFile('goldens/la0039_workspace.png'));

      final prompt = await recall.createCurrentPrompt(
        learner: runtime.learner,
        materialId: AppRuntime.primaryMaterialId,
      );
      final action = await store.learningTruthStore().recallAction(
        learner: runtime.learner,
        actionId: prompt.id,
      );
      expect(action, isNotNull);

      await tester.pumpWidget(_phoneFrame(
        LearningSliceScreen(runtime: runtime, materialId: AppRuntime.primaryMaterialId),
      ));
      await _pumpUntilFound(tester, find.text('Hatırla'));
      await tester.enterText(find.byType(TextField), action!.expectedAnswer);
      await tester.tap(find.text('Yanıtla'));
      await _pumpUntilFound(tester, find.text('İpucusuz hatırladın'));
      await tester.pump(const Duration(milliseconds: 200));
      await expectLater(find.byType(Scaffold).first, matchesGoldenFile('goldens/la0039_recall_payoff.png'));
    },
    skip: !_captureEnabled,
  );
}
