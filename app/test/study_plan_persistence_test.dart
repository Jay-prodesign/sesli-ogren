import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/domain/authenticated_learner.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sesli_ogren/src/domain/study_plan.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _UnusedPdfExtractor implements PdfTextExtractor {
  const _UnusedPdfExtractor();

  @override
  Future<ExtractedPdf> extract(Uint8List bytes, {required String sourceName}) {
    throw UnimplementedError();
  }
}

void main() {
  sqfliteFfiInit();

  test('study target persists per learner and survives reopen', () async {
    final directory = await Directory.systemTemp.createTemp('sesli-ogren-study-plan-');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/study-plan.db';
    var store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: path);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    const learner = LearnerIdentity.local();
    const materialId = MaterialId('exam-target-material');
    final ingested = await ingest.ingestPastedText(
      learner: learner,
      materialId: materialId,
      sourceName: 'Fizik notu',
      text: 'Momentum bir cismin kütlesi ile hızının çarpımıdır. İtme momentum değişimine eşittir.',
    );
    final now = DateTime.utc(2026, 10, 13, 9);
    final target = StudyTargetRecord(
      id: const StudyTargetId('exam-midterm'),
      title: 'Fizik ara sınavı',
      targetDate: DateTime.utc(2026, 10, 27),
      materials: [
        StudyTargetMaterialBinding(
          materialId: materialId,
          sourceVersionId: ingested.sourceVersion.identity.sourceVersionId,
          ordinal: 0,
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );
    await store.saveStudyTarget(learner: learner, target: target);
    await store.close();
    store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: path);
    addTearDown(store.close);

    final restored = await store.activeStudyTarget(learner: learner);
    expect(restored, isNotNull);
    expect(restored!.title, 'Fizik ara sınavı');
    expect(restored.targetDate, DateTime.utc(2026, 10, 27));
    expect(restored.materials.single.materialId, materialId);
    expect(restored.materials.single.sourceVersionId, ingested.sourceVersion.identity.sourceVersionId);

    const other = LearnerIdentity.authenticated(id: LearnerId('other-study-target-learner'));
    expect(await store.activeStudyTarget(learner: other), isNull);
  });

  test('study target refuses stale source binding and exposes reconciliation after replacement', () async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    const learner = LearnerIdentity.local();
    const materialId = MaterialId('exam-stale-material');
    final first = await ingest.ingestPastedText(
      learner: learner,
      materialId: materialId,
      sourceName: 'İlk sürüm',
      text: 'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür. Klorofil ışığı soğurur.',
    );
    final now = DateTime.utc(2026, 10, 13, 10);
    final target = StudyTargetRecord(
      id: const StudyTargetId('exam-biology'),
      title: 'Biyoloji sınavı',
      targetDate: DateTime.utc(2026, 11, 2),
      materials: [
        StudyTargetMaterialBinding(
          materialId: materialId,
          sourceVersionId: first.sourceVersion.identity.sourceVersionId,
          ordinal: 0,
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );
    await store.saveStudyTarget(learner: learner, target: target);

    final second = await ingest.ingestPastedText(
      learner: learner,
      materialId: materialId,
      sourceName: 'Yeni sürüm',
      text: 'Hücresel solunum kimyasal enerjiyi ATP biçiminde kullanılabilir hale getirir. Mitokondri görev alır.',
    );
    final restored = (await store.activeStudyTarget(learner: learner))!;
    final projection = StudyTargetProjection.evaluate(
      target: restored,
      activeMaterials: await store.activeMaterials(learner: learner),
      currentSourceVersions: {materialId: second.sourceVersion.identity.sourceVersionId},
      evaluatedAt: now,
    );
    expect(projection.hasReconciliationIssues, isTrue);
    expect(projection.materials.single.state, StudyTargetBindingState.sourceChanged);
    expect(projection.currentMaterialIds, isEmpty);

    await expectLater(
      store.saveStudyTarget(
        learner: learner,
        target: StudyTargetRecord(
          id: restored.id,
          title: restored.title,
          targetDate: restored.targetDate,
          materials: restored.materials,
          createdAt: restored.createdAt,
          updatedAt: now.add(const Duration(minutes: 1)),
        ),
      ),
      throwsA(isA<SourceStoreConflict>()),
    );
  });

  test('target date is calendar context and never produces readiness math', () {
    final target = StudyTargetRecord(
      id: const StudyTargetId('exam-date-only'),
      title: 'Kimya finali',
      targetDate: DateTime(2026, 10, 20, 18, 45),
      materials: const [
        StudyTargetMaterialBinding(
          materialId: MaterialId('chemistry'),
          sourceVersionId: SourceVersionId('chemistry-source'),
          ordinal: 0,
        ),
      ],
      createdAt: DateTime.utc(2026, 10, 13),
      updatedAt: DateTime.utc(2026, 10, 13),
    );
    final projection = StudyTargetProjection(
      target: target,
      materials: const [],
      evaluatedAt: DateTime.utc(2026, 10, 13, 23, 59),
    );
    expect(target.targetDate, DateTime.utc(2026, 10, 20));
    expect(projection.daysUntilTarget, 7);
    expect(projection.isPastTarget, isFalse);
  });
}
