import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/app_runtime.dart';
import 'package:sesli_ogren/src/app/app_theme.dart';
import 'package:sesli_ogren/src/app/living_study_desk_home.dart';
import 'package:sesli_ogren/src/app/quiz_screen.dart';
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

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder, {int maxPumps = 120}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Expected quiz surface was not reached within bounded pumps.');
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

  testWidgets('quiz hides source evidence until committed answer and resumes durable cursor', (tester) async {
    final runtime = await _runtime();
    addTearDown(runtime.close);
    const materialId = MaterialId('quiz-screen-material');
    await runtime.ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: materialId,
      sourceName: 'Fotosentez quiz notu',
      text:
          'Fotosentez sırasında bitkiler ışık enerjisini kimyasal enerjiye dönüştürür. '
          'Klorofil ışığın soğurulmasında önemli görev alır. '
          'Karbondioksit ve su kullanılarak glikoz üretimine katkı sağlanır.',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: SesliOgrenTheme.light(),
        home: LivingDeskReviewScope(
          child: QuizScreen(runtime: runtime, materialId: materialId),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const ValueKey('quiz-submit')));
    expect(find.byKey(const ValueKey('quiz-source-evidence')), findsNothing);
    expect(find.byKey(const ValueKey('quiz-answer-feedback')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('quiz-option-0')).hitTestable());
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('quiz-submit')));
    await _pumpUntilFound(tester, find.byKey(const ValueKey('quiz-source-evidence')));
    expect(find.text('Doğru.'), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz-source-evidence')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('quiz-next')));
    await _pumpUntilFound(tester, find.text('SORU 2 / 3'));
    expect(find.text('SORU 2 / 3'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        theme: SesliOgrenTheme.light(),
        home: LivingDeskReviewScope(
          child: QuizScreen(runtime: runtime, materialId: materialId),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('SORU 2 / 3'));
    expect(find.byKey(const ValueKey('quiz-source-evidence')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('quiz-unknown')));
    await _pumpUntilFound(tester, find.text('Bilmiyorum olarak kaydedildi.'));
    expect(find.byKey(const ValueKey('quiz-source-evidence')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('quiz-next')));
    await _pumpUntilFound(tester, find.text('SORU 3 / 3'));
    await tester.tap(find.byKey(const ValueKey('quiz-unknown')));
    await _pumpUntilFound(tester, find.text('Bilmiyorum olarak kaydedildi.'));
    await tester.tap(find.byKey(const ValueKey('quiz-next')));
    await _pumpUntilFound(tester, find.byKey(const ValueKey('quiz-complete')));
    expect(find.byKey(const ValueKey('quiz-return-workspace')), findsOneWidget);
    expect(find.text('Eksikleri kaynakta onar'), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz-restart')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scheduled quiz review opens the exact due question and completes after truthful feedback', (
    tester,
  ) async {
    final runtime = await _runtime();
    addTearDown(runtime.close);
    const materialId = MaterialId('quiz-scheduled-screen');
    await runtime.ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: materialId,
      sourceName: 'Planlı quiz ekranı',
      text:
          'Fotosentez sırasında bitkiler ışık enerjisini kimyasal enerjiye dönüştürür. '
          'Klorofil ışığın soğurulmasında önemli görev alır. '
          'Karbondioksit ve su kullanılarak glikoz üretimine katkı sağlanır.',
    );
    final state = await runtime.quiz.openCurrentSet(learner: runtime.learner, materialId: materialId);
    final target = state.set.questions[1];

    await tester.pumpWidget(
      MaterialApp(
        theme: SesliOgrenTheme.light(),
        home: LivingDeskReviewScope(
          child: QuizScreen(
            runtime: runtime,
            materialId: materialId,
            scheduledReviewSourceVersionId: state.set.sourceVersionId,
            scheduledReviewSourceAnchor: target.sourceAnchor,
          ),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const ValueKey('quiz-submit')));
    final persisted = await runtime.quiz.openCurrentSet(learner: runtime.learner, materialId: materialId);
    expect(persisted.session.cursorIndex, target.ordinal);
    expect(persisted.currentQuestion?.id, target.id);
    expect(find.text('SORU 2 / 3'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('quiz-option-${target.correctOptionIndex}')).hitTestable());
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('quiz-submit')));
    await _pumpUntilFound(tester, find.byKey(const ValueKey('quiz-source-evidence')));
    expect(find.text('Tekrarı tamamla'), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz-source-evidence')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('incorrect quiz answer is committed before exact source correction appears', (tester) async {
    final runtime = await _runtime();
    addTearDown(runtime.close);
    const materialId = MaterialId('quiz-incorrect-answer');
    await runtime.ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: materialId,
      sourceName: 'Fotosentez yanlış cevap testi',
      text:
          'Fotosentez sırasında bitkiler ışık enerjisini kimyasal enerjiye dönüştürür. '
          'Klorofil ışığın soğurulmasında önemli görev alır. '
          'Karbondioksit ve su kullanılarak glikoz üretimine katkı sağlanır.',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: SesliOgrenTheme.light(),
        home: LivingDeskReviewScope(
          child: QuizScreen(runtime: runtime, materialId: materialId),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const ValueKey('quiz-submit')));
    expect(find.byKey(const ValueKey('quiz-source-evidence')), findsNothing);

    final wrongOption = find.byKey(const ValueKey('quiz-option-1'));
    await tester.ensureVisible(wrongOption);
    await tester.pump();
    await tester.tap(wrongOption.hitTestable());
    await tester.pump();
    final submit = find.byKey(const ValueKey('quiz-submit'));
    await tester.ensureVisible(submit);
    await tester.pump();
    await tester.tap(submit.hitTestable());
    await _pumpUntilFound(tester, find.byKey(const ValueKey('quiz-source-evidence')));
    expect(find.text('Kaynakla eşleşmedi.'), findsOneWidget);
    expect(find.text('Doğru yanıt: Fotosentez'), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz-source-evidence')), findsOneWidget);

    final state = await runtime.quiz.openCurrentSet(learner: runtime.learner, materialId: materialId);
    expect(state.session.incorrectCount, 1);
    expect(state.session.cursorIndex, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('source change while answering fails closed and reloads current quiz', (tester) async {
    final runtime = await _runtime();
    addTearDown(runtime.close);
    const materialId = MaterialId('quiz-source-change-recovery');
    await runtime.ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: materialId,
      sourceName: 'İlk quiz kaynağı',
      text:
          'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür. '
          'Klorofil ışığın soğurulmasına yardım eder. '
          'Karbondioksit süreçte önemli bir girdidir.',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: SesliOgrenTheme.light(),
        home: LivingDeskReviewScope(
          child: QuizScreen(runtime: runtime, materialId: materialId),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const ValueKey('quiz-submit')));
    await tester.tap(find.byKey(const ValueKey('quiz-option-0')).hitTestable());
    await tester.pump();

    await runtime.ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: materialId,
      sourceName: 'Güncel quiz kaynağı',
      text:
          'Hücresel solunum glikozdaki enerjiyi kullanılabilir enerjiye dönüştürür. '
          'Mitokondri hücresel enerji dönüşümünde önemli görev alır. '
          'Oksijenli solunumda oksijen temel girdilerden biridir.',
    );

    await tester.tap(find.byKey(const ValueKey('quiz-submit')));
    await _pumpUntilFound(tester, find.byKey(const ValueKey('quiz-recovery-notice')));
    expect(find.text('Güncel quiz kaynağı'), findsWidgets);
    expect(find.text('Önceki quiz yanıtı kaydedilmedi. Güncel kaynaktan devam ediyorsun.'), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz-source-evidence')), findsNothing);
    expect(find.byKey(const ValueKey('quiz-submit')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unusable source fails closed with recoverable quiz state', (tester) async {
    final runtime = await _runtime();
    addTearDown(runtime.close);
    const materialId = MaterialId('quiz-unusable-source');
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
          child: QuizScreen(runtime: runtime, materialId: materialId),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const ValueKey('quiz-retry')));
    expect(find.text('Quiz açılamadı.'), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz-submit')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quiz remains usable at 320px and 150% text scale', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final runtime = await _runtime();
    addTearDown(runtime.close);
    const materialId = MaterialId('quiz-large-text');
    await runtime.ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: materialId,
      sourceName: 'Uzun başlıklı fotosentez quiz çalışma notu',
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
            child: QuizScreen(runtime: runtime, materialId: materialId),
          ),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const ValueKey('quiz-submit')));
    expect(find.byKey(const ValueKey('quiz-companion')), findsOneWidget);
    final option = find.byKey(const ValueKey('quiz-option-0'));
    for (var i = 0; i < 8 && option.hitTestable().evaluate().isEmpty; i++) {
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -120), warnIfMissed: false);
      await tester.pump();
    }
    expect(option.hitTestable(), findsOneWidget);
    await tester.tap(option.hitTestable());
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('quiz-submit')));
    await _pumpUntilFound(tester, find.byKey(const ValueKey('quiz-source-evidence')));
    final evidence = find.byKey(const ValueKey('quiz-source-evidence'));
    for (var i = 0; i < 8 && evidence.hitTestable().evaluate().isEmpty; i++) {
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -120), warnIfMissed: false);
      await tester.pump();
    }
    expect(evidence.hitTestable(), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz-next')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
