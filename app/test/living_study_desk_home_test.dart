import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/living_study_desk_home.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sesli_ogren/src/domain/learning_truth.dart';

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
    required VoidCallback onOpenLearning,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: LivingStudyDeskHome(
            material: material,
            continuation: continuation,
            sourceText: 'Fotosentez sırasında klorofil ışık enerjisinin yakalanmasına yardım eder.',
            otherMaterials: const [],
            onOpenWorkspace: onOpenWorkspace,
            onOpenLearning: onOpenLearning,
            onOpenListen: () {},
              onOpenMaterial: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('completed Recall returns Home CTA to the source instead of reopening the completed step', (
    tester,
  ) async {
    var workspaceOpens = 0;
    var learningOpens = 0;
    await pumpHome(
      tester,
      continuation: continuationFor(RecallOutcome.correct, RecallStateKind.retrievedOnce),
      onOpenWorkspace: () => workspaceOpens++,
      onOpenLearning: () => learningOpens++,
    );

    expect(find.text('Bugünlük tamam. Kaynağın burada.'), findsOneWidget);
    expect(find.text('Kaynağa dön'), findsOneWidget);
    final cta = find.byKey(const ValueKey('la0040-living-continue'));
    await tester.ensureVisible(cta);
    await tester.tap(cta);
    await tester.pump();

    expect(workspaceOpens, 1);
    expect(learningOpens, 0);
  });

  testWidgets('review-required Home CTA keeps the learner in the repair and Recall journey', (tester) async {
    var workspaceOpens = 0;
    var learningOpens = 0;
    await pumpHome(
      tester,
      continuation: continuationFor(RecallOutcome.unknown, RecallStateKind.needsReview),
      onOpenWorkspace: () => workspaceOpens++,
      onOpenLearning: () => learningOpens++,
    );

    expect(find.text('Kaynağa dön, sonra yeniden dene'), findsOneWidget);
    expect(find.text('Kaynağı gözden geçir'), findsOneWidget);
    final cta = find.byKey(const ValueKey('la0040-living-continue'));
    await tester.ensureVisible(cta);
    await tester.tap(cta);
    await tester.pump();

    expect(workspaceOpens, 0);
    expect(learningOpens, 1);
  });
}
