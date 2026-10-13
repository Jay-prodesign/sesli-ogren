import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/continuity/cloud_continuity_gateway.dart';
import 'package:sesli_ogren/src/continuity/cloud_continuity_service.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/domain/authenticated_learner.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _UnusedPdfExtractor implements PdfTextExtractor {
  const _UnusedPdfExtractor();

  @override
  Future<ExtractedPdf> extract(Uint8List bytes, {required String sourceName}) {
    throw UnimplementedError();
  }
}

class _FakeCloudContinuityGateway implements CloudContinuityGateway {
  final Map<MaterialId, CloudMaterialSnapshot> remote = {};
  final List<SourceVersionId?> expectedPrevious = [];

  @override
  Future<List<CloudMaterialSnapshot>> listMaterials({required AuthenticatedLearner learner}) async =>
      remote.values.toList(growable: false);

  @override
  Future<CloudMaterialSnapshot?> readMaterial({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  }) async => remote[materialId];

  @override
  Future<CloudMaterialSnapshot> ensureTextSource({
    required AuthenticatedLearner learner,
    required SourceIngestResult source,
    SourceVersionId? expectedPreviousSourceVersionId,
  }) async {
    expectedPrevious.add(expectedPreviousSourceVersionId);
    final current = remote[source.material.id];
    if (current != null && current.sourceVersionId != source.sourceVersion.identity.sourceVersionId) {
      if (expectedPreviousSourceVersionId == null || expectedPreviousSourceVersionId != current.sourceVersionId) {
        throw const CloudContinuityException(
          'source_conflict',
          kind: CloudContinuityFailureKind.conflict,
        );
      }
    }

    final snapshot = _snapshotFor(
      learner: learner,
      materialId: source.material.id,
      title: source.material.title,
      text: source.sourceVersion.inlineText!,
      sourceOrdinal: (current?.serverSourceVersion ?? 0) + 1,
    );
    remote[source.material.id] = snapshot;
    return snapshot;
  }
}

CloudMaterialSnapshot _snapshotFor({
  required AuthenticatedLearner learner,
  required MaterialId materialId,
  required String title,
  required String text,
  required int sourceOrdinal,
}) {
  final digest = sha256.convert(utf8.encode(text)).toString();
  final sourceVersionId = SourceIngestService.deriveSourceVersionId(
    learner: learner,
    materialId: materialId,
    mediaType: SourceMediaType.pastedText,
    contentDigest: digest,
  );
  final now = DateTime.utc(2026, 10, 14, 0, sourceOrdinal);
  return CloudMaterialSnapshot(
    serverMaterialId: 'server-${materialId.value}',
    materialId: materialId,
    title: title,
    serverSourceAssetId: 'server-source-$sourceOrdinal',
    sourceVersionId: sourceVersionId,
    serverSourceVersion: sourceOrdinal,
    sourceContentHash: digest,
    mediaType: SourceMediaType.pastedText,
    mimeType: 'text/plain; charset=utf-8',
    byteSize: utf8.encode(text).length,
    inlineText: text,
    serverExtractedContentId: 'server-extracted-$sourceOrdinal',
    normalizedText: text.trim(),
    anchors: [SourceAnchor(startOffset: 0, endOffset: text.trim().length)],
    materialUpdatedAt: now,
    sourceCreatedAt: now,
  );
}

void main() {
  sqfliteFfiInit();

  Future<(SqliteSourceStore, SourceIngestService, _FakeCloudContinuityGateway, CloudContinuityService)> harness() async {
    final store = await SqliteSourceStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    final ingest = SourceIngestService(
      store: store,
      pdfTextExtractor: const _UnusedPdfExtractor(),
      now: () => DateTime.utc(2026, 10, 14),
    );
    final gateway = _FakeCloudContinuityGateway();
    return (
      store,
      ingest,
      gateway,
      CloudContinuityService(store: store, ingest: ingest, gateway: gateway),
    );
  }

  test('new device hydrates the exact remote text source and records the sync ancestor', () async {
    final (store, ingest, gateway, service) = await harness();
    addTearDown(store.close);
    const learner = AuthenticatedLearner(id: LearnerId('continuity-learner'));
    const materialId = MaterialId('material_continuity_remote_1');
    gateway.remote[materialId] = _snapshotFor(
      learner: learner,
      materialId: materialId,
      title: 'Biyoloji',
      text: 'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür.',
      sourceOrdinal: 1,
    );

    final results = await service.reconcileAll(learner: learner);

    expect(results.single.disposition, CloudContinuityDisposition.pulledRemote);
    final source = await store.currentSourceVersion(learner: learner, materialId: materialId);
    expect(source?.identity.sourceVersionId, gateway.remote[materialId]!.sourceVersionId);
    final binding = await store.serverMaterialBinding(learner: learner, materialId: materialId);
    expect(binding?.sourceVersionId, gateway.remote[materialId]!.sourceVersionId);
  });

  test('local replacement pushes only when the last synced cloud source is the shared ancestor', () async {
    final (store, ingest, gateway, service) = await harness();
    addTearDown(store.close);
    const learner = AuthenticatedLearner(id: LearnerId('continuity-learner'));
    const materialId = MaterialId('material_continuity_local_1');

    await ingest.ingestPastedText(
      learner: learner,
      materialId: materialId,
      text: 'İlk kaynak sürümü.',
      sourceName: 'Not',
    );
    expect(
      (await service.reconcileMaterial(learner: learner, materialId: materialId)).disposition,
      CloudContinuityDisposition.pushedLocal,
    );
    final firstSource = gateway.remote[materialId]!.sourceVersionId;

    await ingest.ingestPastedText(
      learner: learner,
      materialId: materialId,
      text: 'İkinci kaynak sürümü farklı içerik taşır.',
      sourceName: 'Not',
    );
    final result = await service.reconcileMaterial(learner: learner, materialId: materialId);

    expect(result.disposition, CloudContinuityDisposition.pushedLocal);
    expect(gateway.expectedPrevious.last, firstSource);
    expect(gateway.remote[materialId]!.sourceVersionId, isNot(firstSource));
  });

  test('remote replacement is pulled when this device has not diverged since the shared ancestor', () async {
    final (store, ingest, gateway, service) = await harness();
    addTearDown(store.close);
    const learner = AuthenticatedLearner(id: LearnerId('continuity-learner'));
    const materialId = MaterialId('material_continuity_remote_ahead');

    await ingest.ingestPastedText(
      learner: learner,
      materialId: materialId,
      text: 'Ortak kaynak sürümü.',
      sourceName: 'Not',
    );
    await service.reconcileMaterial(learner: learner, materialId: materialId);
    final firstSource = gateway.remote[materialId]!.sourceVersionId;

    gateway.remote[materialId] = _snapshotFor(
      learner: learner,
      materialId: materialId,
      title: 'Not',
      text: 'Diğer cihazdaki daha yeni kaynak sürümü.',
      sourceOrdinal: 2,
    );

    final result = await service.reconcileMaterial(learner: learner, materialId: materialId);
    final current = await store.currentSourceVersion(learner: learner, materialId: materialId);

    expect(result.disposition, CloudContinuityDisposition.pulledRemote);
    expect(current?.identity.sourceVersionId, gateway.remote[materialId]!.sourceVersionId);
    expect(current?.identity.sourceVersionId, isNot(firstSource));
  });

  test('two devices changing after the shared ancestor fail closed without overwriting either source', () async {
    final (store, ingest, gateway, service) = await harness();
    addTearDown(store.close);
    const learner = AuthenticatedLearner(id: LearnerId('continuity-learner'));
    const materialId = MaterialId('material_continuity_diverged');

    await ingest.ingestPastedText(
      learner: learner,
      materialId: materialId,
      text: 'Ortak sürüm.',
      sourceName: 'Not',
    );
    await service.reconcileMaterial(learner: learner, materialId: materialId);

    await ingest.ingestPastedText(
      learner: learner,
      materialId: materialId,
      text: 'Bu cihazın yeni sürümü.',
      sourceName: 'Not',
    );
    final localBefore = await store.currentSourceVersion(learner: learner, materialId: materialId);
    gateway.remote[materialId] = _snapshotFor(
      learner: learner,
      materialId: materialId,
      title: 'Not',
      text: 'Diğer cihazın farklı yeni sürümü.',
      sourceOrdinal: 2,
    );

    final result = await service.reconcileMaterial(learner: learner, materialId: materialId);
    final localAfter = await store.currentSourceVersion(learner: learner, materialId: materialId);

    expect(result.disposition, CloudContinuityDisposition.conflict);
    expect(localAfter?.identity.sourceVersionId, localBefore?.identity.sourceVersionId);
  });
}
