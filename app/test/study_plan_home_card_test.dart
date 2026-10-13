import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/app_theme.dart';
import 'package:sesli_ogren/src/app/study_plan_home_card.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sesli_ogren/src/domain/study_plan.dart';

void main() {
  testWidgets('Study Plan Home card stays truthful and usable at 320px large text', (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var opens = 0;
    final target = StudyTargetRecord(
      id: const StudyTargetId('home-plan'),
      title: 'Biyoloji finali',
      targetDate: DateTime.utc(2026, 10, 20),
      materials: const [
        StudyTargetMaterialBinding(
          materialId: MaterialId('biology'),
          sourceVersionId: SourceVersionId('biology-old-source'),
          ordinal: 0,
        ),
      ],
      createdAt: DateTime.utc(2026, 10, 13),
      updatedAt: DateTime.utc(2026, 10, 13),
    );
    final projection = StudyTargetProjection.evaluate(
      target: target,
      activeMaterials: [
        MaterialRecord(
          id: const MaterialId('biology'),
          title: 'Biyoloji notu',
          mediaType: SourceMediaType.pastedText,
          lifecycleStatus: MaterialLifecycleStatus.active,
          processingState: MaterialProcessingState.ready,
          currentSourceVersionId: const SourceVersionId('biology-new-source'),
          createdAt: DateTime.utc(2026, 10, 1),
          updatedAt: DateTime.utc(2026, 10, 13),
        ),
      ],
      currentSourceVersions: const {MaterialId('biology'): SourceVersionId('biology-new-source')},
      evaluatedAt: DateTime.utc(2026, 10, 13),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: SesliOgrenTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(size: Size(320, 844), textScaler: TextScaler.linear(1.5)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: StudyPlanHomeCard(projection: projection, hasMaterials: true, onOpen: () => opens++),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('HEDEF · KAYNAK GÜNCELLE'), findsOneWidget);
    expect(find.text('Biyoloji finali'), findsOneWidget);
    expect(find.textContaining('Kaynak bağlarını doğrula'), findsOneWidget);
    expect(find.textContaining('hazır olma'), findsNothing);

    final card = find.byKey(const ValueKey('home-study-plan'));
    await tester.tap(card.hitTestable());
    await tester.pump();
    expect(opens, 1);
  });
}
