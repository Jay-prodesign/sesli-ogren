import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/continuity/passive_resume_continuity_service.dart';
import 'package:sesli_ogren/src/continuity/passive_resume_gateway.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/domain/authenticated_learner.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sesli_ogren/src/domain/passive_resume.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _UnusedPdfExtractor implements PdfTextExtractor {
  const _UnusedPdfExtractor();

  @override
  Future<ExtractedPdf> extract(Uint8List bytes, {required String sourceName}) {
    throw UnimplementedError();
  }
}

class _FakePassiveResumeGateway implements PassiveResumeGateway {
  final Map<PassiveResumeSurface, PassiveResumeRemoteState> remote = {};
  int reads = 0;
  int writes = 0;

  @override
  Future<List<PassiveResumeRemoteState>> read({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  }) async {
    reads += 1;
    return remote.values.where((item) => item.materialId == materialId).toList(growable: false);
  }

  @override
  Future<PassiveResumeRemoteState> write({
    required AuthenticatedLearner learner,
    required PassiveResumeLocalState local,
    required int? expectedRevision,
    required String clientUpdateId,
  }) async {
    writes += 1;
    final current = remote[local.surface];
    if (current == null) {
      if (expectedRevision != null) {
        throw const PassiveResumeException('resume_revision_conflict', kind: PassiveResumeFailureKind.conflict);
      }
    } else if (current.revision != expectedRevision) {
      throw const PassiveResumeException('resume_revision_conflict', kind: PassiveResumeFailureKind.conflict);
    }
    final next = PassiveResumeRemoteState(
      materialId: local.materialId,
      sourceVersionId: local.sourceVersionId,
      surface: local.surface,
      readerProgress: local.readerProgress,
      listenChunkIndex: local.listenChunkIndex,
      revision: (current?.revision ?? 0) + 1,
      updatedAt: local.updatedAt,
    );
    remote[local.surface] = next;
    return next;
  }
}

Future<(SqliteSourceStore, SourceIngestService, SourceIngestResult)> _source({
  required AuthenticatedLearner learner,
  required MaterialId materialId,
  String? path,
}) async {
  final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: path ?? inMemoryDatabasePath);
  final ingest = SourceIngestService(
    store: store,
    pdfTextExtractor: const _UnusedPdfExtractor(),
    now: () => DateTime.utc(2026, 10, 14),
  );
  final source = await ingest.ingestPastedText(
    learner: learner,
    materialId: materialId,
    text: 'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür.',
    sourceName: 'Biyoloji',
  );
  return (store, ingest, source);
}

void main() {
  sqfliteFfiInit();

  test('Reader resume moves through initial push, remote-ahead pull, then local-ahead CAS push', () async {
    const learner = AuthenticatedLearner(id: LearnerId('resume-learner'));
    const materialId = MaterialId('material_resume_reader_0001');
    final (store, _, source) = await _source(learner: learner, materialId: materialId);
    addTearDown(store.close);
    final gateway = _FakePassiveResumeGateway();
    final service = PassiveResumeContinuityService(store: store, gateway: gateway);
    final sourceId = source.sourceVersion.identity.sourceVersionId;
    final firstAt = DateTime.utc(2026, 10, 14, 8);

    await store.saveReaderResumeProgress(
      learner: learner,
      materialId: materialId,
      sourceVersionId: sourceId,
      progress: 0.25,
      updatedAt: firstAt,
    );
    var result = await service.syncMaterial(learner: learner, materialId: materialId);

    expect(
      result.singleWhere((item) => item.surface == PassiveResumeSurface.reader).disposition,
      PassiveResumeSyncDisposition.pushedLocal,
    );
    var local = await store.passiveResumeLocalState(
      learner: learner,
      materialId: materialId,
      sourceVersionId: sourceId,
      surface: PassiveResumeSurface.reader,
    );
    expect(local?.serverRevision, 1);
    expect(local?.hasLocalChangeSinceSync, isFalse);

    gateway.remote[PassiveResumeSurface.reader] = PassiveResumeRemoteState(
      materialId: materialId,
      sourceVersionId: sourceId,
      surface: PassiveResumeSurface.reader,
      readerProgress: 0.70,
      listenChunkIndex: null,
      revision: 2,
      updatedAt: DateTime.utc(2026, 10, 14, 9),
    );
    result = await service.syncMaterial(learner: learner, materialId: materialId);

    expect(
      result.singleWhere((item) => item.surface == PassiveResumeSurface.reader).disposition,
      PassiveResumeSyncDisposition.pulledRemote,
    );
    expect(await store.readerResumeProgress(learner: learner, materialId: materialId, sourceVersionId: sourceId), 0.70);

    await store.saveReaderResumeProgress(
      learner: learner,
      materialId: materialId,
      sourceVersionId: sourceId,
      progress: 0.82,
      updatedAt: DateTime.utc(2026, 10, 14, 10),
    );
    local = await store.passiveResumeLocalState(
      learner: learner,
      materialId: materialId,
      sourceVersionId: sourceId,
      surface: PassiveResumeSurface.reader,
    );
    expect(local?.serverRevision, 2);
    expect(local?.hasLocalChangeSinceSync, isTrue);

    result = await service.syncMaterial(learner: learner, materialId: materialId);
    expect(
      result.singleWhere((item) => item.surface == PassiveResumeSurface.reader).disposition,
      PassiveResumeSyncDisposition.pushedLocal,
    );
    expect(gateway.remote[PassiveResumeSurface.reader]?.revision, 3);
    expect(gateway.remote[PassiveResumeSurface.reader]?.readerProgress, 0.82);
  });

  test('Reader divergence on both devices fails closed and preserves local position', () async {
    const learner = AuthenticatedLearner(id: LearnerId('resume-diverged-learner'));
    const materialId = MaterialId('material_resume_diverged_1');
    final (store, _, source) = await _source(learner: learner, materialId: materialId);
    addTearDown(store.close);
    final gateway = _FakePassiveResumeGateway();
    final service = PassiveResumeContinuityService(store: store, gateway: gateway);
    final sourceId = source.sourceVersion.identity.sourceVersionId;

    await store.saveReaderResumeProgress(
      learner: learner,
      materialId: materialId,
      sourceVersionId: sourceId,
      progress: 0.20,
      updatedAt: DateTime.utc(2026, 10, 14, 8),
    );
    await service.syncMaterial(learner: learner, materialId: materialId);

    await store.saveReaderResumeProgress(
      learner: learner,
      materialId: materialId,
      sourceVersionId: sourceId,
      progress: 0.60,
      updatedAt: DateTime.utc(2026, 10, 14, 9),
    );
    gateway.remote[PassiveResumeSurface.reader] = PassiveResumeRemoteState(
      materialId: materialId,
      sourceVersionId: sourceId,
      surface: PassiveResumeSurface.reader,
      readerProgress: 0.90,
      listenChunkIndex: null,
      revision: 2,
      updatedAt: DateTime.utc(2026, 10, 14, 9, 5),
    );

    final result = await service.syncMaterial(learner: learner, materialId: materialId);

    expect(
      result.singleWhere((item) => item.surface == PassiveResumeSurface.reader).disposition,
      PassiveResumeSyncDisposition.conflict,
    );
    expect(await store.readerResumeProgress(learner: learner, materialId: materialId, sourceVersionId: sourceId), 0.60);
    expect(gateway.remote[PassiveResumeSurface.reader]?.readerProgress, 0.90);
  });

  test('Listen resume uses an independent revision stream', () async {
    const learner = AuthenticatedLearner(id: LearnerId('resume-listen-learner'));
    const materialId = MaterialId('material_resume_listen_01');
    final (store, _, source) = await _source(learner: learner, materialId: materialId);
    addTearDown(store.close);
    final gateway = _FakePassiveResumeGateway();
    final service = PassiveResumeContinuityService(store: store, gateway: gateway);
    final sourceId = source.sourceVersion.identity.sourceVersionId;

    await store.saveListenResumeChunk(
      learner: learner,
      materialId: materialId,
      sourceVersionId: sourceId,
      chunkIndex: 4,
      updatedAt: DateTime.utc(2026, 10, 14, 8),
    );
    final result = await service.syncMaterial(learner: learner, materialId: materialId);

    expect(
      result.singleWhere((item) => item.surface == PassiveResumeSurface.listen).disposition,
      PassiveResumeSyncDisposition.pushedLocal,
    );
    expect(gateway.remote[PassiveResumeSurface.listen]?.listenChunkIndex, 4);
    expect(gateway.remote[PassiveResumeSurface.listen]?.revision, 1);
    expect(gateway.remote[PassiveResumeSurface.reader], isNull);
  });

  test('two device Reader resume round-trip converges without wall-clock arbitration', () async {
    const learner = AuthenticatedLearner(id: LearnerId('resume-two-device-learner'));
    const materialId = MaterialId('material_resume_two_device');
    final temp = await Directory.systemTemp.createTemp('sesli-ogren-passive-two-device-');
    addTearDown(() => temp.delete(recursive: true));
    final (storeA, _, sourceA) = await _source(
      learner: learner,
      materialId: materialId,
      path: '${temp.path}/device-a.db',
    );
    final (storeB, _, sourceB) = await _source(
      learner: learner,
      materialId: materialId,
      path: '${temp.path}/device-b.db',
    );
    addTearDown(storeA.close);
    addTearDown(storeB.close);
    expect(sourceA.sourceVersion.identity.sourceVersionId, sourceB.sourceVersion.identity.sourceVersionId);

    final gateway = _FakePassiveResumeGateway();
    final deviceA = PassiveResumeContinuityService(store: storeA, gateway: gateway);
    final deviceB = PassiveResumeContinuityService(store: storeB, gateway: gateway);
    final sourceId = sourceA.sourceVersion.identity.sourceVersionId;

    await storeA.saveReaderResumeProgress(
      learner: learner,
      materialId: materialId,
      sourceVersionId: sourceId,
      progress: 0.31,
      updatedAt: DateTime.utc(2026, 10, 14, 8),
    );
    await deviceA.syncMaterial(learner: learner, materialId: materialId);

    await deviceB.syncMaterial(learner: learner, materialId: materialId);
    expect(
      await storeB.readerResumeProgress(learner: learner, materialId: materialId, sourceVersionId: sourceId),
      0.31,
    );

    await storeB.saveReaderResumeProgress(
      learner: learner,
      materialId: materialId,
      sourceVersionId: sourceId,
      progress: 0.74,
      updatedAt: DateTime.utc(2026, 10, 14, 9),
    );
    await deviceB.syncMaterial(learner: learner, materialId: materialId);
    expect(gateway.remote[PassiveResumeSurface.reader]?.revision, 2);

    final result = await deviceA.syncMaterial(learner: learner, materialId: materialId);
    expect(
      result.singleWhere((item) => item.surface == PassiveResumeSurface.reader).disposition,
      PassiveResumeSyncDisposition.pulledRemote,
    );
    expect(
      await storeA.readerResumeProgress(learner: learner, materialId: materialId, sourceVersionId: sourceId),
      0.74,
    );
  });

  test('guest sync does not call the remote resume gateway', () async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final gateway = _FakePassiveResumeGateway();
    final service = PassiveResumeContinuityService(store: store, gateway: gateway);

    final summary = await service.syncAll(learner: const AuthenticatedLearner.local());

    expect(summary.results, isEmpty);
    expect(gateway.reads, 0);
    expect(gateway.writes, 0);
  });
}
