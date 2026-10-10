import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/app_runtime.dart';
import 'package:sesli_ogren/src/app/focus_screen.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sesli_ogren/src/generation/supabase_source_summary_gateway.dart';
import 'package:sesli_ogren/src/learning/focus_help_gateway.dart';
import 'package:sesli_ogren/src/learning/recall_learning_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _UnusedPdfExtractor implements PdfTextExtractor {
  const _UnusedPdfExtractor();

  @override
  Future<ExtractedPdf> extract(Uint8List bytes, {required String sourceName}) {
    throw UnimplementedError();
  }
}

class _SourceGateway extends SupabaseSourceSummaryGateway {
  const _SourceGateway();

  @override
  Future<String> ensureServerMaterial({required SourceIngestResult source}) async =>
      '11111111-1111-4111-8111-111111111111';

  @override
  Future<bool> deleteServerMaterial(String serverMaterialId) async => true;
}

class _FocusGateway implements FocusHelpGateway {
  FocusHelpRequest? lastRequest;

  @override
  Future<FocusHelpResult> help(FocusHelpRequest request) async {
    lastRequest = request;
    return FocusHelpReady(
      sourceVersionId: request.sourceVersionId,
      sourceContentDigest: request.sourceContentDigest,
      text: 'Karbondioksit, kaynakta fotosentezin girdilerinden biri olarak yer alır.',
      sourceCues: const ['Bitki bu süreçte karbondioksit ve su kullanır.'],
      executionRef: 'test:focus',
    );
  }
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 240, scrollable: find.byType(Scrollable).last);
  await tester.pump();
  await tester.tap(finder);
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder, {int maxPumps = 80}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Expected Focus result was not reached within bounded pumps.');
}

void main() {
  sqfliteFfiInit();

  testWidgets('Focus sends the exact server source binding and renders grounded help', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);

    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    const materialId = MaterialId('focus-server-route');
    const sourceText =
        'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür. '
        'Bitki bu süreçte karbondioksit ve su kullanır.';
    await ingest.ingestPastedText(
      learner: AppRuntime.localM5LearnerFixture,
      materialId: materialId,
      text: sourceText,
      sourceName: 'Biyoloji notu',
    );
    final source = await store.currentSourceVersion(learner: AppRuntime.localM5LearnerFixture, materialId: materialId);
    expect(source, isNotNull);

    final focus = _FocusGateway();
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
      focusHelp: focus,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: FocusScreen(
          runtime: runtime,
          source: source!,
          sourceText: sourceText,
          sourceGateway: const _SourceGateway(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Karbondioksit burada ne işe yarıyor?');
    await _tapVisible(tester, find.text('Sorumu açıkla'));
    await _pumpUntilFound(tester, find.textContaining('Karbondioksit, kaynakta'));

    expect(focus.lastRequest, isNotNull);
    expect(focus.lastRequest!.serverMaterialId, '11111111-1111-4111-8111-111111111111');
    expect(focus.lastRequest!.groundingContentHash, hasLength(64));
    expect(focus.lastRequest!.kind, FocusHelpKind.directExplanation);
    expect(find.text('Kaynak dayanakları'), findsOneWidget);
    expect(find.textContaining('Bitki bu süreçte karbondioksit ve su kullanır'), findsWidgets);
    expect(find.text('Hatırla'), findsOneWidget);
    expect(find.text('Kendi cümlelerinle anlat'), findsOneWidget);
  });
}
