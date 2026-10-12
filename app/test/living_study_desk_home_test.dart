import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/living_study_desk_home.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sesli_ogren/src/domain/learning_truth.dart';

void usePhoneViewport(WidgetTester tester, {Size size = const Size(390, 844)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> tapHomeCta(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 260, scrollable: find.byType(Scrollable).first);
  await tester.pump();
  await tester.tap(finder);
}

void main() {
  final now = DateTime.utc(2026, 10, 10);
  const materialId = MaterialId('home-routing-material');
  const versionId = SourceVersionId('home-routing-version');
  const evidenceId = LearnerEvidenceId('home-routing-evidence');

  final material = MaterialRecord(
    id: materialId,
    title: 'Fotosentez çalışma notu',
    mediaType: SourceMediaType.pastedText,
    lifecycleStatus: MaterialLifecycleStatus.active,
    processingState: MaterialProcessingState.ready,
    createdAt: now,
    updatedAt: now,
  );

  LearningContinuation continuationFor(RecallOutcome outcome, RecallStateKind stateKind) {
    final nextAction = RecallTruthPolicy.nextActionFor(
      materialId: materialId,
      sourceVersionId: versionId,
      evidenceId: evidenceId,
      outcome: outcome,
      createdAt: now,
    );
    return LearningContinuation(
      state: LearnerState(
        materialId: materialId,
        sourceVersionId: versionId,
        kind: stateKind,
        evidenceCount: 1,
        latestEvidenceId: evidenceId,
        ruleVersion: RecallTruthPolicy.stateRuleVersion,
        updatedAt: now,
      ),
      nextAction: nextAction,
    );
  }

  Future<void> pumpHome(
    WidgetTester tester, {
    required LearningContinuation continuation,
    required VoidCallback onOpenWorkspace,
    required VoidCallback onOpenReader,
    required VoidCallback onOpenLearning,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: true, textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: LivingStudyDeskHome(
            material: material,
            continuation: continuation,
            sourceText: 'Fotosentez sırasında klorofil ışık enerjisinin yakalanmasına yardım eder.',
            otherMaterials: const [],
            onOpenWorkspace: onOpenWorkspace,
            onOpenReader: onOpenReader,
            onOpenLearning: onOpenLearning,
            onOpenListen: () {},
            onOpenMaterial: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('completed Recall returns Home CTA to the source instead of reopening the completed step', (
    tester,
  ) async {
    usePhoneViewport(tester);
    var workspaceOpens = 0;
    var readerOpens = 0;
    var learningOpens = 0;
    await pumpHome(
      tester,
      continuation: continuationFor(RecallOutcome.correct, RecallStateKind.retrievedOnce),
      onOpenWorkspace: () => workspaceOpens++,
      onOpenReader: () => readerOpens++,
      onOpenLearning: () => learningOpens++,
    );

    expect(find.text('Kendi başına hatırladın'), findsOneWidget);
    expect(find.textContaining('Kalıcılığı sonraki deneme gösterecek'), findsOneWidget);
    expect(find.byKey(const ValueKey('la0040-home-evidence-payoff')), findsOneWidget);
    expect(find.text('Bu tur tamam. Sonra yeniden hatırla.'), findsOneWidget);
    expect(find.text('Çalışma alanına dön'), findsOneWidget);
    final cta = find.byKey(const ValueKey('la0040-living-continue'));
    await tapHomeCta(tester, cta);
    await tester.pump();

    expect(workspaceOpens, 1);
    expect(readerOpens, 0);
    expect(learningOpens, 0);
  });

  testWidgets('review-required Home CTA keeps the learner in the repair and Recall journey', (tester) async {
    usePhoneViewport(tester);
    var workspaceOpens = 0;
    var readerOpens = 0;
    var learningOpens = 0;
    await pumpHome(
      tester,
      continuation: continuationFor(RecallOutcome.unknown, RecallStateKind.notAssessed),
      onOpenWorkspace: () => workspaceOpens++,
      onOpenReader: () => readerOpens++,
      onOpenLearning: () => learningOpens++,
    );

    expect(find.text('Henüz bağımsız deneme yok'), findsOneWidget);
    expect(find.textContaining('Henüz bağımsız bir hatırlama denemen yok'), findsOneWidget);
    expect(find.text('DENEMEN KAYITLI · SIRADAKİ ADIM'), findsOneWidget);
    expect(find.text('Kaynağa dön, sonra yeniden dene'), findsOneWidget);
    expect(find.text('Kaynağı gözden geçir'), findsOneWidget);
    final cta = find.byKey(const ValueKey('la0040-living-continue'));
    await tapHomeCta(tester, cta);
    await tester.pump();

    expect(workspaceOpens, 0);
    expect(readerOpens, 1);
    expect(learningOpens, 0);
  });

  testWidgets('prominent D/Knot hierarchy remains usable at 320px with large text', (tester) async {
    usePhoneViewport(tester, size: const Size(320, 844));
    await pumpHome(
      tester,
      continuation: continuationFor(RecallOutcome.unknown, RecallStateKind.notAssessed),
      onOpenWorkspace: () {},
      onOpenReader: () {},
      onOpenLearning: () {},
      textScale: 1.5,
    );

    expect(find.text('Kaynağın ve sıradaki adımın hazır.'), findsOneWidget);
    expect(find.text('Kaynağı gözden geçir'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty Home keeps first-source action usable at 320px with large text', (tester) async {
    usePhoneViewport(tester, size: const Size(320, 844));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: true, textScaler: TextScaler.linear(1.5)),
          child: child!,
        ),
        home: Scaffold(
          body: LivingStudyDeskHome(
            material: null,
            continuation: null,
            sourceText: null,
            otherMaterials: const [],
            onOpenWorkspace: () {},
            onOpenReader: () {},
            onOpenLearning: () {},
            onOpenListen: () {},
            onOpenMaterial: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Birlikte\nöğrenelim.'), findsOneWidget);
    expect(find.byKey(const ValueKey('la0040-living-add')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
