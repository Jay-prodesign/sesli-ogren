import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/app_runtime.dart';
import 'package:sesli_ogren/src/app/learning_slice_screen.dart';
import 'package:sesli_ogren/src/app/living_study_desk_home.dart';
import 'package:sesli_ogren/src/app/material_workspace_screen.dart';
import 'package:sesli_ogren/src/app/product_shell_screen.dart';
import 'package:sesli_ogren/src/app/source_reader_screen.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sesli_ogren/src/domain/learning_truth.dart';
import 'package:sesli_ogren/src/learning/recall_learning_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _UnusedPdfExtractor implements PdfTextExtractor {
  const _UnusedPdfExtractor();

  @override
  Future<ExtractedPdf> extract(Uint8List bytes, {required String sourceName}) {
    throw UnimplementedError();
  }
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder, {int maxPumps = 160}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Golden Journey did not reach the expected surface within bounded pumps.');
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _pumpUntilGone(WidgetTester tester, Finder finder, {int maxPumps = 40}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isEmpty) return;
  }
  fail('Golden Journey kept the previous route mounted past the transition window.');
}

void main() {
  sqfliteFfiInit();

  testWidgets('Golden Journey keeps real source, learner evidence, next action and resume coherent', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
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

    await tester.pumpWidget(
      MaterialApp(
        home: LivingDeskReviewScope(child: ProductShellScreen(runtime: runtime)),
      ),
    );
    await _pumpUntilFound(tester, find.text('İlk kaynağımı ekle'));

    await _tapVisible(tester, find.text('İlk kaynağımı ekle'));
    await _pumpUntilFound(tester, find.byType(LearningSliceScreen));
    await _pumpUntilFound(tester, find.text('İLK KAYNAĞIN'));

    await _tapVisible(tester, find.text('Metin yapıştır'));
    await tester.enterText(
      find.byKey(const ValueKey('pasted-material-text')),
      'Fotosentez sırasında klorofil ışık enerjisini kimyasal enerjiye dönüştürür. '
      'Klorofil ışığın soğurulmasına yardım eder.',
    );
    await _tapVisible(tester, find.text('Başlık ekle · isteğe bağlı'));
    await tester.enterText(find.byKey(const ValueKey('pasted-material-title')), 'Biyoloji · Fotosentez');
    await _tapVisible(tester, find.text('Metni ekle · çalışma alanını aç'));

    await _pumpUntilFound(tester, find.byKey(const ValueKey('first-value-intent')));
    expect(find.byType(MaterialWorkspaceScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('first-value-recommendation-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('first-intent-recommend')), findsOneWidget);

    await _tapVisible(tester, find.byKey(const ValueKey('first-intent-recommend')));
    await _pumpUntilFound(tester, find.byType(SourceReaderScreen));
    expect(find.textContaining('Fotosentez sırasında klorofil'), findsWidgets);

    await _tapVisible(tester, find.text('Kaynağı kapat ve hatırla'));
    await _pumpUntilFound(tester, find.byKey(const ValueKey('la0040-atelier-recall')));
    await _pumpUntilGone(tester, find.byType(SourceReaderScreen));

    expect(find.byType(SourceReaderScreen), findsNothing);
    expect(find.text('KAYNAK KAPALI · ŞİMDİ SEN'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('la0040-atelier-answer')), 'Fotosentez');
    await _tapVisible(tester, find.byKey(const ValueKey('la0040-atelier-submit')));

    await _pumpUntilFound(tester, find.byKey(const ValueKey('la0040-atelier-result')));
    expect(find.text('Kendi başına hatırladın'), findsOneWidget);
    expect(find.text('KAYNAKTAKİ DOĞRU İFADE'), findsOneWidget);
    expect(find.text('Fotosentez'), findsWidgets);
    expect(find.text('İyi başlangıç. Kalıcılığı sonraki bağımsız deneme gösterecek.'), findsOneWidget);
    expect(find.text('Bu denemeyi tamamla'), findsOneWidget);

    await _tapVisible(tester, find.text('Bu denemeyi tamamla'));
    await _pumpUntilFound(tester, find.byType(MaterialWorkspaceScreen));
    expect(find.byKey(const ValueKey('la0040-atelier-workspace')), findsOneWidget);

    Navigator.of(tester.element(find.byType(MaterialWorkspaceScreen))).pop();
    await _pumpUntilGone(tester, find.byType(MaterialWorkspaceScreen));
    await _pumpUntilFound(tester, find.text('Şu an planlı bir tekrar yok'));

    expect(find.byType(ProductShellScreen), findsOneWidget);
    expect(find.text('Kendi başına hatırladın'), findsOneWidget);
    expect(find.text('Bugün için bekleyen bir tekrar yok.'), findsOneWidget);
    final quietReturn = find.text('Materyali aç');
    await tester.scrollUntilVisible(quietReturn, 180, scrollable: find.byType(Scrollable).last);
    await tester.pump();
    expect(quietReturn, findsOneWidget);
    final durableEvidence = find.text('İlk bağımsız hatırlaman kaydedildi. Kalıcılığı sonraki deneme gösterecek.');
    await tester.scrollUntilVisible(durableEvidence, 180, scrollable: find.byType(Scrollable).last);
    await tester.pump();
    expect(durableEvidence, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('scheduled Recall bypasses repeat-later continuation for the still-current source', (tester) async {
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
    const materialId = MaterialId('scheduled-recall-material');
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: materialId,
      sourceName: 'Planlı Recall kaynağı',
      text:
          'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür. '
          'Klorofil ışığın soğurulmasına yardım eder.',
    );
    final source = await store.currentSourceVersion(learner: runtime.learner, materialId: materialId);
    final prompt = await runtime.recall.createCurrentPrompt(learner: runtime.learner, materialId: materialId);
    final action = await store.learningTruthStore().recallAction(learner: runtime.learner, actionId: prompt.id);
    final attempt = await runtime.recall.openAttempt(learner: runtime.learner, actionId: prompt.id);
    final result = await runtime.recall.submit(
      learner: runtime.learner,
      actionId: prompt.id,
      attemptId: attempt.attempt.attemptId,
      disposition: RecallResponseDisposition.answer,
      answer: action!.expectedAnswer,
    );
    expect(result.nextAction.kind, NextLearningActionKind.repeatRecallLater);

    await tester.pumpWidget(
      MaterialApp(
        home: LivingDeskReviewScope(
          child: LearningSliceScreen(
            runtime: runtime,
            materialId: materialId,
            scheduledReviewSourceVersionId: source!.identity.sourceVersionId,
            scheduledReviewSourceAnchor: prompt.anchor,
          ),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const ValueKey('la0040-atelier-recall')));
    expect(find.byKey(const ValueKey('continuation')), findsNothing);
    expect(find.text('KAYNAK KAPALI · ŞİMDİ SEN'), findsOneWidget);
    expect(find.text(prompt.promptText), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
