import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/atelier_learning_surfaces.dart';
import 'package:sesli_ogren/src/app/living_study_desk_home.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sesli_ogren/src/domain/learning_truth.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Future<void> loadFont(String family, String path) async {
      final bytes = await File(path).readAsBytes();
      final loader = FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }

    await loadFont('Roboto', '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf');
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot == null || flutterRoot.isEmpty) {
      throw StateError('FLUTTER_ROOT is required for material icon capture.');
    }
    await loadFont('MaterialIcons', '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  });

  final now = DateTime.utc(2026, 10, 8);
  const materialId = MaterialId('visual-fixture');
  const versionId = SourceVersionId('visual-version');
  const evidenceId = LearnerEvidenceId('visual-evidence');
  const source =
      'Fotosentez sırasında bitkiler ışık enerjisini kimyasal enerjiye dönüştürür. Klorofil ışığın soğurulmasında görev alır. Bu süreçte karbondioksit ve su kullanılır.';
  final material = MaterialRecord(
    id: materialId,
    title: 'Fotosentez: ışık ve enerji',
    mediaType: SourceMediaType.pastedText,
    lifecycleStatus: MaterialLifecycleStatus.active,
    processingState: MaterialProcessingState.ready,
    createdAt: now,
    updatedAt: now,
  );
  final evidence = LearnerEvidence(
    id: evidenceId,
    attemptId: const RecallAttemptId('visual-attempt'),
    actionId: const RecallActionId('visual-action'),
    materialId: materialId,
    sourceVersionId: versionId,
    extractedContentId: const ExtractedContentId('visual-extract'),
    outcome: RecallOutcome.correct,
    assistance: RecallAssistance.none,
    responseDigest: 'visual-only',
    responseLength: 8,
    ruleVersion: RecallTruthPolicy.evidenceRuleVersion,
    createdAt: now,
  );
  final state = LearnerState(
    materialId: materialId,
    sourceVersionId: versionId,
    kind: RecallStateKind.retrievedOnce,
    evidenceCount: 1,
    latestEvidenceId: evidenceId,
    ruleVersion: RecallTruthPolicy.stateRuleVersion,
    updatedAt: now,
  );
  final next = RecallTruthPolicy.nextActionFor(
    materialId: materialId,
    sourceVersionId: versionId,
    evidenceId: evidenceId,
    outcome: RecallOutcome.correct,
    createdAt: now,
  );
  final continuation = LearningContinuation(state: state, nextAction: next);
  final result = RecallAttemptResult(
    evidence: evidence,
    state: state,
    nextAction: next,
    correctAnswer: 'Klorofil',
    sourceExcerpt: 'Klorofil ışığın soğurulmasında görev alır.',
  );

  Future<void> capture(WidgetTester tester, String name, Widget child) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, home: Scaffold(body: child)));
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/$name.png'));
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  testWidgets('LA-0040 populated Home', (tester) async {
    await capture(
      tester,
      'la0040_home_populated_390x844',
      LivingStudyDeskHome(
        material: material,
        continuation: continuation,
        sourceText: source,
        otherMaterials: const [],
        onOpenWorkspace: () {},
        onOpenLearning: () {},
        onOpenListen: () {},
        onOpenMaterial: (_) {},
      ),
    );
  });

  testWidgets('LA-0040 source Reader', (tester) async {
    await capture(
      tester,
      'la0040_reader_390x844',
      AtelierWorkspace(
        material: material,
        sourceText: source,
        onRecall: () {},
        onListen: () {},
        onExplain: () {},
        onFocus: () {},
      ),
    );
  });

  testWidgets('LA-0040 source-hidden Recall', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await capture(
      tester,
      'la0040_recall_390x844',
      SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: AtelierRecall(
          prompt: const RecallPrompt(
            id: RecallActionId('visual-action'),
            materialId: materialId,
            sourceVersionId: versionId,
            promptText: 'Işığın soğurulmasında hangi pigment görev alır?',
            anchor: SourceAnchor(startOffset: 75, endOffset: 84),
            ruleVersion: 'visual-fixture',
          ),
          controller: controller,
          busy: false,
          onSubmit: () {},
          onHint: () {},
          onReveal: () {},
          onUnknown: () {},
        ),
      ),
    );
  });

  testWidgets('LA-0040 source-evidence Result', (tester) async {
    await capture(
      tester,
      'la0040_result_390x844',
      SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: AtelierResult(result: result, answerInMemory: 'Klorofil', onContinue: () {}),
      ),
    );
  });
}
