import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/app_theme.dart';
import 'package:sesli_ogren/src/app/atelier_learning_surfaces.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sesli_ogren/src/domain/learning_truth.dart';

void main() {
  final now = DateTime.utc(2026, 10, 12, 8);
  const materialId = MaterialId('workspace-action-material');
  const sourceVersionId = SourceVersionId('workspace-action-source');
  const evidenceId = LearnerEvidenceId('workspace-action-evidence');

  MaterialRecord material() => MaterialRecord(
    id: materialId,
    title: 'Fotosentez çalışma notları',
    mediaType: SourceMediaType.pastedText,
    lifecycleStatus: MaterialLifecycleStatus.active,
    processingState: MaterialProcessingState.ready,
    currentSourceVersionId: sourceVersionId,
    createdAt: now,
    updatedAt: now,
  );

  SourceVersionRecord source() => SourceVersionRecord(
    identity: const SourceVersionIdentity(
      materialId: materialId,
      sourceVersionId: sourceVersionId,
      contentDigest: 'digest',
      trustClass: SourceTrustClass.userProvided,
      knowledgeClass: SourceKnowledgeClass.learnerOwned,
    ),
    mediaType: SourceMediaType.pastedText,
    sourceName: 'Biyoloji notları',
    mimeType: 'text/plain',
    byteSize: 128,
    inlineText: 'Klorofil ışık enerjisinin kimyasal enerjiye dönüşümünde rol alır.',
    createdAt: now,
  );

  Widget frame({
    required bool disableAnimations,
    LearningContinuation? continuation,
    required VoidCallback onReadSource,
    required VoidCallback onRecall,
    required VoidCallback onListen,
    VoidCallback? onFlashcards,
  }) {
    return MaterialApp(
      theme: SesliOgrenTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(size: const Size(390, 844), disableAnimations: disableAnimations),
        child: Scaffold(
          body: AtelierWorkspace(
            material: material(),
            sourceText:
                'Klorofil ışık enerjisinin kimyasal enerjiye dönüşümünde rol alır. '
                'Bitkiler karbondioksit ve suyu kullanır.',
            sourceVersion: source(),
            continuation: continuation,
            onReadSource: onReadSource,
            onQuickRecap: () {},
            onUpdateSource: () {},
            onRecall: onRecall,
            onListen: onListen,
            onGroundedExplain: () {},
            onExplain: () {},
            onFlashcards: onFlashcards,
            onFocus: () {},
          ),
        ),
      ),
    );
  }

  testWidgets('Workspace exposes one dominant next action and outcome-led secondary actions', (tester) async {
    var readSource = 0;
    var recall = 0;
    var listen = 0;
    var flashcards = 0;

    await tester.pumpWidget(
      frame(
        disableAnimations: false,
        onReadSource: () => readSource += 1,
        onRecall: () => recall += 1,
        onListen: () => listen += 1,
        onFlashcards: () => flashcards += 1,
      ),
    );

    expect(find.byKey(const ValueKey('la0040-atelier-workspace-recall')), findsOneWidget);
    expect(find.text('Kaynağı kapat · Hatırla'), findsOneWidget);
    expect(find.text('Tam kaynağı aç'), findsOneWidget);
    expect(find.text('Dinleyerek hazırlan'), findsOneWidget);
    expect(find.text('Diğer çalışma yolları'), findsOneWidget);
    expect(find.byKey(const ValueKey('workspace-evidence-state')), findsNothing);

    final filledButtons = tester.widgetList<FilledButton>(find.byType(FilledButton));
    expect(filledButtons.length, 1);

    await tester.tap(find.byKey(const ValueKey('la0040-atelier-workspace-recall')));
    await tester.pump();
    expect(recall, 1);
    expect(readSource, 0);
    expect(listen, 0);

    final switcher = tester.widget<AnimatedSwitcher>(find.byKey(const ValueKey('workspace-active-step-motion')));
    expect(switcher.duration, const Duration(milliseconds: 220));

    await tester.tap(find.byKey(const ValueKey('workspace-other-study-paths')));
    await tester.pumpAndSettle();
    expect(find.text('Bu kaynakla başka bir yol seç'), findsOneWidget);
    expect(find.text('HAZIRLIK'), findsOneWidget);
    expect(find.text('AKTİF ÇALIŞMA'), findsOneWidget);
    expect(find.text('Kaynağı hızlıca toparla'), findsOneWidget);
    final flashcardAction = find.byKey(const ValueKey('workspace-other-flashcards'));
    expect(flashcardAction, findsOneWidget);
    await tester.scrollUntilVisible(
      flashcardAction,
      120,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('workspace-other-study-paths-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pump();
    await tester.tap(flashcardAction.hitTestable());
    await tester.pump();
    expect(flashcards, 1);
  });

  testWidgets('Workspace review recommendation makes source repair the primary action and honors Reduced Motion', (
    tester,
  ) async {
    var readSource = 0;
    var recall = 0;

    final continuation = LearningContinuation(
      state: LearnerState(
        materialId: materialId,
        sourceVersionId: sourceVersionId,
        kind: RecallStateKind.needsReview,
        evidenceCount: 1,
        latestEvidenceId: evidenceId,
        ruleVersion: 'recall-state-v2',
        updatedAt: now,
      ),
      nextAction: NextLearningAction(
        materialId: materialId,
        sourceVersionId: sourceVersionId,
        latestEvidenceId: evidenceId,
        kind: NextLearningActionKind.reviewSourceThenRecall,
        reasonCode: 'review_source',
        reasonText: 'Eksik kısmı kaynaktan yeniden gör.',
        policyVersion: 'recall-next-v1',
        createdAt: now,
      ),
    );

    await tester.pumpWidget(
      frame(
        disableAnimations: true,
        continuation: continuation,
        onReadSource: () => readSource += 1,
        onRecall: () => recall += 1,
        onListen: () {},
      ),
    );

    expect(find.text('Kaynağı gözden geçir'), findsOneWidget);
    expect(find.text('Eksik kısmı kaynaktan yeniden gör.'), findsOneWidget);
    expect(find.byKey(const ValueKey('workspace-evidence-state')), findsOneWidget);
    expect(find.text('Kaynak onarımı gerekiyor'), findsOneWidget);
    expect(
      find.text(
        '1 Hatırla denemesi kaydedildi. Son deneme eksik ya da yanlış geri çağırma gösterdi; sıradaki adım kaynaktan onarım.',
      ),
      findsOneWidget,
    );

    final switcher = tester.widget<AnimatedSwitcher>(find.byKey(const ValueKey('workspace-active-step-motion')));
    expect(switcher.duration, Duration.zero);

    await tester.tap(find.byKey(const ValueKey('la0040-atelier-workspace-recall')));
    await tester.pump();
    expect(readSource, 1);
    expect(recall, 0);
  });
}
