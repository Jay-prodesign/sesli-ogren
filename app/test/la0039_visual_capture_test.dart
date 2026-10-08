import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/app_runtime.dart';
import 'package:sesli_ogren/src/app/app_theme.dart';
import 'package:sesli_ogren/src/app/explain_back_screen.dart';
import 'package:sesli_ogren/src/app/explain_screen.dart';
import 'package:sesli_ogren/src/app/focus_screen.dart';
import 'package:sesli_ogren/src/app/learning_slice_screen.dart';
import 'package:sesli_ogren/src/app/listen_screen.dart';
import 'package:sesli_ogren/src/app/material_workspace_screen.dart';
import 'package:sesli_ogren/src/app/product_shell_screen.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/generation/grounded_explain_gateway.dart';
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

class _ReadyExplainGateway implements GroundedExplainGateway {
  const _ReadyExplainGateway();

  @override
  Future<GroundedExplainResult> explain(GroundedExplainRequest request) async => GroundedExplainReady(
    sourceVersionId: request.sourceVersionId,
    sourceContentDigest: request.sourceContentDigest,
    explanation: 'Fotosentezde bitki, ışık enerjisini kullanarak su ve karbondioksitten kimyasal enerji depolayan moleküller üretir.',
    keyPoints: const [
      'Işık enerjisi süreci başlatır.',
      'Karbondioksit ve su kaynak olarak kullanılır.',
      'Enerji kimyasal biçimde depolanır.',
    ],
    language: 'tr-TR',
    executionRef: 'visual-review:grounded-explain',
  );
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder, {int maxPumps = 120}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Expected visual-review widget was not reached within bounded pumps.');
}

Future<void> _loadReviewFonts() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null || flutterRoot.isEmpty) {
    fail('FLUTTER_ROOT is required for deterministic LA-0039 visual review fonts.');
  }

  Future<ByteData> readFont(String fileName) async {
    final bytes = await File('$flutterRoot/bin/cache/artifacts/material_fonts/$fileName').readAsBytes();
    return ByteData.sublistView(bytes);
  }

  final roboto = FontLoader('Roboto')..addFont(readFont('Roboto-Regular.ttf'));
  final materialIcons = FontLoader('MaterialIcons')..addFont(readFont('MaterialIcons-Regular.otf'));
  await Future.wait([roboto.load(), materialIcons.load()]);
}

Widget _phoneFrame(Widget child) {
  final baseTheme = SesliOgrenTheme.light();
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: 'Roboto'),
      primaryTextTheme: baseTheme.primaryTextTheme.apply(fontFamily: 'Roboto'),
      filledButtonTheme: FilledButtonThemeData(
        style: (baseTheme.filledButtonTheme.style ?? const ButtonStyle()).copyWith(
          textStyle: const WidgetStatePropertyAll(TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: (baseTheme.outlinedButtonTheme.style ?? const ButtonStyle()).copyWith(
          textStyle: const WidgetStatePropertyAll(TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: (baseTheme.textButtonTheme.style ?? const ButtonStyle()).copyWith(
          textStyle: const WidgetStatePropertyAll(TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700)),
        ),
      ),
    ),
    home: MediaQuery(data: const MediaQueryData(disableAnimations: true), child: child),
  );
}

Future<void> _precacheCompanion(WidgetTester tester) async {
  final context = tester.element(find.byType(MaterialApp));
  await tester.runAsync(() => precacheImage(const AssetImage('assets/companions/D_KNOT_128.webp'), context));
  await tester.pump(const Duration(milliseconds: 120));
}

void main() {
  sqfliteFfiInit();

  testWidgets('capture LA-0039 representative Golden Product Slice', (tester) async {
    await tester.runAsync(_loadReviewFonts);

    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
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
      explain: const _ReadyExplainGateway(),
    );

    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: AppRuntime.primaryMaterialId,
      text:
          'Fotosentez sırasında klorofil ışık enerjisini kimyasal enerjiye dönüştürmeye yardımcı olur. '
          'Bitkiler karbondioksit ve suyu kullanır; süreç sonunda kimyasal enerji depolanır.',
      sourceName: 'Biyoloji — Fotosentez Notları',
    );

    final source = await store.currentSourceVersion(learner: runtime.learner, materialId: AppRuntime.primaryMaterialId);
    final extracted = source == null
        ? null
        : await store.extractedContentForSource(
            learner: runtime.learner,
            sourceVersionId: source.identity.sourceVersionId,
          );
    expect(source, isNotNull);
    expect(extracted, isNotNull);

    await tester.pumpWidget(_phoneFrame(ProductShellScreen(runtime: runtime)));
    await _pumpUntilFound(tester, find.text('KALDIĞIN MATERYAL'));
    await _precacheCompanion(tester);
    await tester.pump(const Duration(milliseconds: 200));
    await expectLater(find.byType(Scaffold).first, matchesGoldenFile('goldens/la0039_home.png'));

    await tester.tap(find.byIcon(Icons.library_books_outlined));
    await tester.pump(const Duration(milliseconds: 200));
    await expectLater(find.byType(Scaffold).first, matchesGoldenFile('goldens/la0040_library.png'));

    await tester.tap(find.byIcon(Icons.insights_outlined));
    await tester.pump(const Duration(milliseconds: 200));
    await expectLater(find.byType(Scaffold).first, matchesGoldenFile('goldens/la0040_progress.png'));

    await tester.pumpWidget(
      _phoneFrame(MaterialWorkspaceScreen(runtime: runtime, materialId: AppRuntime.primaryMaterialId)),
    );
    await _pumpUntilFound(tester, find.text('SIRADAKİ ADIM'));
    await tester.pump(const Duration(milliseconds: 200));
    await expectLater(find.byType(Scaffold).first, matchesGoldenFile('goldens/la0039_workspace.png'));

    await tester.pumpWidget(_phoneFrame(ListenScreen(runtime: runtime, materialId: AppRuntime.primaryMaterialId)));
    await _pumpUntilFound(tester, find.text('DİNLEME'));
    await tester.pump(const Duration(milliseconds: 200));
    await expectLater(find.byType(Scaffold).first, matchesGoldenFile('goldens/la0040_listen.png'));

    await tester.pumpWidget(
      _phoneFrame(FocusScreen(runtime: runtime, source: source!, sourceText: extracted!.normalizedText)),
    );
    await _pumpUntilFound(tester, find.text('Kısa odak oturumu'));
    await tester.pump(const Duration(milliseconds: 200));
    await expectLater(find.byType(Scaffold).first, matchesGoldenFile('goldens/la0040_focus.png'));

    await tester.pumpWidget(_phoneFrame(ExplainScreen(runtime: runtime, source: source)));
    await _pumpUntilFound(tester, find.text('Kaynağına dayalı açıklama'));
    await tester.pump(const Duration(milliseconds: 200));
    await expectLater(find.byType(Scaffold).first, matchesGoldenFile('goldens/la0040_explain.png'));

    await tester.pumpWidget(_phoneFrame(ExplainBackScreen(runtime: runtime, source: source)));
    await _pumpUntilFound(tester, find.text('Anlatımımı değerlendir'));
    await tester.pump(const Duration(milliseconds: 200));
    await expectLater(find.byType(Scaffold).first, matchesGoldenFile('goldens/la0040_explain_back.png'));

    final prompt = await recall.createCurrentPrompt(learner: runtime.learner, materialId: AppRuntime.primaryMaterialId);
    final action = await store.learningTruthStore().recallAction(learner: runtime.learner, actionId: prompt.id);
    expect(action, isNotNull);

    await tester.pumpWidget(
      _phoneFrame(LearningSliceScreen(runtime: runtime, materialId: AppRuntime.primaryMaterialId)),
    );
    await _pumpUntilFound(tester, find.text('Hatırla'));
    await tester.pump(const Duration(milliseconds: 200));
    await expectLater(find.byType(Scaffold).first, matchesGoldenFile('goldens/la0040_recall_prompt.png'));

    await tester.enterText(find.byType(TextField), action!.expectedAnswer);
    await tester.tap(find.text('Yanıtla'));
    await _pumpUntilFound(tester, find.text('İpucusuz hatırladın'));
    await tester.pump(const Duration(milliseconds: 200));
    await expectLater(find.byType(Scaffold).first, matchesGoldenFile('goldens/la0039_recall_payoff.png'));
  }, skip: !_captureEnabled);
}
