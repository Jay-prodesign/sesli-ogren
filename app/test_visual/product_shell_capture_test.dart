import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/app_runtime.dart';
import 'package:sesli_ogren/src/app/app_theme.dart';
import 'package:sesli_ogren/src/app/product_shell_screen.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/learning/recall_learning_service.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:typed_data';

class _NoPdf implements PdfTextExtractor {
  const _NoPdf();
  @override
  Future<ExtractedPdf> extract(Uint8List bytes, {required String sourceName}) => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  setUpAll(() async {
    Future<void> load(String name, String path) async {
      final bytes = await File(path).readAsBytes();
      await (FontLoader(name)..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
    await load('Roboto', '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf');
    final root = Platform.environment['FLUTTER_ROOT']!;
    await load('MaterialIcons', '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  });

  for (final populated in [false, true]) {
    testWidgets('Actual product shell home and library: populated=$populated', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
      addTearDown(store.close);
      final ingest = SourceIngestService(store: store, pdfTextExtractor: const _NoPdf());
      final runtime = AppRuntime(
        learner: AppRuntime.localM5LearnerFixture,
        store: store,
        ingest: ingest,
        recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
        telemetry: store.operationalTelemetry(),
      );
      if (populated) {
        await ingest.ingestPastedText(
          learner: runtime.learner,
          materialId: AppRuntime.primaryMaterialId,
          text: 'Fotosentez sırasında bitkiler ışık enerjisini kullanır. Klorofil ışığı soğurur. Karbondioksit ve su kullanılır.',
          sourceName: 'Biyoloji notu',
        );
      }
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: SesliOgrenTheme.light(),
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: SizedBox.shrink(),
        ),
      ));
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: SesliOgrenTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: ProductShellScreen(runtime: runtime),
        ),
      ));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byKey(const ValueKey('home-surface')).evaluate().isNotEmpty) break;
      }
      expect(find.byKey(const ValueKey('home-surface')), findsOneWidget);
      await expectLater(find.byType(Scaffold).first, matchesGoldenFile('goldens/product_shell_home_${populated ? 'populated' : 'empty'}_390x844.png'));
      await tester.tap(find.text('Kütüphane').last);
      await tester.pump(const Duration(milliseconds: 400));
      await expectLater(find.byType(Scaffold).first, matchesGoldenFile('goldens/product_shell_library_${populated ? 'populated' : 'empty'}_390x844.png'));
    });
  }
}
