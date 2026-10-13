import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/app_runtime.dart';
import 'package:sesli_ogren/src/app/app_theme.dart';
import 'package:sesli_ogren/src/app/living_study_desk_home.dart';
import 'package:sesli_ogren/src/app/study_plan_screen.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/domain/authenticated_learner.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sesli_ogren/src/domain/study_plan.dart';
import 'package:sesli_ogren/src/learning/recall_learning_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _UnusedPdfExtractor implements PdfTextExtractor {
  const _UnusedPdfExtractor();

  @override
  Future<ExtractedPdf> extract(Uint8List bytes, {required String sourceName}) {
    throw UnimplementedError();
  }
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

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder, {int maxPumps = 120}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Expected Study Plan surface was not reached within bounded pumps.');
}

Future<void> _pumpPlan(WidgetTester tester, AppRuntime runtime) async {
  tester.view.physicalSize = const Size(320, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: SesliOgrenTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(disableAnimations: true, accessibleNavigation: true, textScaler: const TextScaler.linear(1.5)),
        child: child!,
      ),
      home: LivingDeskReviewScope(child: StudyPlanScreen(runtime: runtime)),
    ),
  );
  await _pumpUntilFound(tester, find.byKey(const ValueKey('study-plan-screen')));
}

void main() {
  sqfliteFfiInit();

  testWidgets('Study Plan reconciles a replaced source explicitly at narrow large text', (tester) async {
    final runtime = await _runtime();
    addTearDown(runtime.close);
    const materialId = MaterialId('study-plan-screen-material');
    final first = await runtime.ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: materialId,
      sourceName: 'Fizik ilk sürüm',
      text:
          'Momentum bir cismin kütlesi ile hızının çarpımıdır. '
          'İtme, momentumdaki değişimle ilişkilidir ve vektörel bir büyüklüktür.',
    );
    final now = DateTime.utc(2026, 10, 13, 9);
    await runtime.store.saveStudyTarget(
      learner: runtime.learner,
      target: StudyTargetRecord(
        id: const StudyTargetId('screen-exam-target'),
        title: 'Fizik ara sınavı',
        targetDate: DateTime.utc(2027, 1, 20),
        materials: [
          StudyTargetMaterialBinding(
            materialId: materialId,
            sourceVersionId: first.sourceVersion.identity.sourceVersionId,
            ordinal: 0,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      ),
    );

    await _pumpPlan(tester, runtime);
    await _pumpUntilFound(tester, find.text('Fizik ara sınavı'));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('hazır olma puanı değildir'), findsOneWidget);
    expect(find.text('Güncel kaynak'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);

    await runtime.ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: materialId,
      sourceName: 'Fizik güncel sürüm',
      text:
          'Enerjinin korunumu kapalı bir sistemde toplam enerjinin değişmediğini söyler. '
          'Kinetik ve potansiyel enerji farklı biçimler arasında dönüşebilir.',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpPlan(tester, runtime);
    await _pumpUntilFound(tester, find.text('Kaynak değişti'));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Eski sürümden yeni görev üretmiyoruz'), findsOneWidget);
    expect(find.text('Planı güncel kaynaklara bağla'), findsOneWidget);

    final reconcile = find.byKey(const ValueKey('study-plan-primary'));
    await tester.ensureVisible(reconcile);
    await tester.tap(reconcile.hitTestable());
    await tester.pump();
    await _pumpUntilFound(tester, find.byKey(const ValueKey('study-plan-editor')));
    expect(find.byKey(const ValueKey('study-plan-material-study-plan-screen-material')), findsOneWidget);

    final save = find.byKey(const ValueKey('study-plan-save'));
    await tester.ensureVisible(save);
    await tester.tap(save.hitTestable());
    await _pumpUntilFound(tester, find.text('Güncel kaynak'));
    expect(find.text('Kaynak değişti'), findsNothing);

    final stored = await runtime.store.activeStudyTarget(learner: runtime.learner);
    final current = await runtime.store.currentSourceVersion(learner: runtime.learner, materialId: materialId);
    expect(stored!.materials.single.sourceVersionId, current!.identity.sourceVersionId);
  });
}
