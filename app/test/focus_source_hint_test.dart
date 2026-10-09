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

class _UnavailableServerFocusGateway implements FocusHelpGateway {
  const _UnavailableServerFocusGateway();

  @override
  Future<FocusHelpResult> help(FocusHelpRequest request) async => const FocusHelpUnavailable('simulated server outage');
}

class _SourceGateway extends SupabaseSourceSummaryGateway {
  const _SourceGateway();

  @override
  Future<String> ensureServerMaterial({required SourceIngestResult source}) async =>
      '11111111-1111-4111-8111-111111111111';

  @override
  Future<bool> deleteServerMaterial(String serverMaterialId) async => true;
}

Future<AppRuntime> _runtime(
  SqliteSourceStore store, {
  FocusHelpGateway focusHelp = const UnavailableFocusHelpGateway(),
}) async {
  final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
  return AppRuntime(
    learner: AppRuntime.localM5LearnerFixture,
    store: store,
    ingest: ingest,
    recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
    telemetry: store.operationalTelemetry(),
    focusHelp: focusHelp,
  );
}

void main() {
  sqfliteFfiInit();

  testWidgets('Focus hint points only to a source passage with term overlap', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final runtime = await _runtime(store);
    const materialId = MaterialId('focus-source-hint');
    await runtime.ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: materialId,
      text:
          'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür. '
          'Bitki bu süreçte karbondioksit ve su kullanır.',
      sourceName: 'Biyoloji notu',
    );
    final source = await store.currentSourceVersion(learner: runtime.learner, materialId: materialId);
    expect(source, isNotNull);

    await tester.pumpWidget(
      MaterialApp(
        home: FocusScreen(
          runtime: runtime,
          source: source!,
          sourceText:
              'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür. '
              'Bitki bu süreçte karbondioksit ve su kullanır.',
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Karbondioksit bu süreçte nasıl kullanılır?');
    await tester.tap(find.text('İpucu ver'));
    await tester.pump();

    expect(find.textContaining('Kaynak ipucu:'), findsOneWidget);
    expect(find.textContaining('karbondioksit ve su kullanır'), findsWidgets);
    expect(find.textContaining('kendi cümlelerinle yeniden kurmayı dene'), findsOneWidget);
  });

  testWidgets('Focus hint falls back to current local source when server help is unavailable', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final runtime = await _runtime(store, focusHelp: const _UnavailableServerFocusGateway());
    const materialId = MaterialId('focus-server-fallback');
    const sourceText =
        'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür. '
        'Bitki bu süreçte karbondioksit ve su kullanır.';
    await runtime.ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: materialId,
      text: sourceText,
      sourceName: 'Biyoloji notu',
    );
    final source = await store.currentSourceVersion(learner: runtime.learner, materialId: materialId);
    expect(source, isNotNull);

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

    await tester.enterText(find.byType(TextField), 'Karbondioksit bu süreçte nasıl kullanılır?');
    await tester.tap(find.text('İpucu ver'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Kaynak ipucu:'), findsOneWidget);
    expect(find.textContaining('karbondioksit ve su kullanır'), findsWidgets);
    expect(find.textContaining('simulated server outage'), findsNothing);
  });

  testWidgets('Focus hint refuses to invent a passage when terms do not match', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final runtime = await _runtime(store);
    const materialId = MaterialId('focus-source-no-match');
    await runtime.ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: materialId,
      text: 'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür.',
      sourceName: 'Biyoloji notu',
    );
    final source = await store.currentSourceVersion(learner: runtime.learner, materialId: materialId);
    expect(source, isNotNull);

    await tester.pumpWidget(
      MaterialApp(
        home: FocusScreen(
          runtime: runtime,
          source: source!,
          sourceText: 'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür.',
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Mitokondriyal ribozomların alt birimi nedir?');
    await tester.tap(find.text('İpucu ver'));
    await tester.pump();

    expect(find.textContaining('kaynakta güvenle bağlayabildiğimiz bir bölüm bulamadık'), findsOneWidget);
    expect(find.textContaining('Kaynak ipucu:'), findsNothing);
  });
}
