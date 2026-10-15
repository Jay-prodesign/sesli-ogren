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
  final Map<SourceVersionId, Uint8List> mediaBytes = {};
  final List<SourceVersionId?> expectedPrevious = [];
  bool failMediaDownloadIntegrity = false;
  int cleanupCalls = 0;

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
        throw const CloudContinuityException('source_conflict', kind: CloudContinuityFailureKind.conflict);
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

  @override
  Future<CloudMaterialSnapshot> ensureMediaSource({
    required AuthenticatedLearner learner,
    required SourceIngestResult source,
    required Uint8List rawSourceBytes,
    SourceVersionId? expectedPreviousSourceVersionId,
  }) async {
    expectedPrevious.add(expectedPreviousSourceVersionId);
    final current = remote[source.material.id];
    if (current != null && current.sourceVersionId != source.sourceVersion.identity.sourceVersionId) {
      if (expectedPreviousSourceVersionId == null || expectedPreviousSourceVersionId != current.sourceVersionId) {
        throw const CloudContinuityException('source_conflict', kind: CloudContinuityFailureKind.conflict);
      }
    }
    expect(rawSourceBytes.length, source.sourceVersion.byteSize);
    expect(sha256.convert(rawSourceBytes).toString(), source.sourceVersion.identity.contentDigest);
    mediaBytes[source.sourceVersion.identity.sourceVersionId] = Uint8List.fromList(rawSourceBytes);
    final snapshot = _mediaSnapshotFromSource(source: source, sourceOrdinal: (current?.serverSourceVersion ?? 0) + 1);
    remote[source.material.id] = snapshot;
    return snapshot;
  }

  @override
  Future<Uint8List> downloadMediaSource({
    required AuthenticatedLearner learner,
    required CloudMaterialSnapshot source,
  }) async {
    if (failMediaDownloadIntegrity) {
      throw const CloudContinuityException('media_integrity_failed', kind: CloudContinuityFailureKind.conflict);
    }
    final bytes = mediaBytes[source.sourceVersionId];
    if (bytes == null) {
      throw const CloudContinuityException('media_missing', kind: CloudContinuityFailureKind.unavailable);
    }
    return Uint8List.fromList(bytes);
  }

  @override
  Future<void> cleanupSupersededMedia({required AuthenticatedLearner learner, required MaterialId materialId}) async {
    cleanupCalls += 1;
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
    sourceName: title,
    mimeType: 'text/plain; charset=utf-8',
    byteSize: utf8.encode(text).length,
    storageBucket: null,
    storagePath: null,
    inlineText: text,
    serverExtractedContentId: 'server-extracted-$sourceOrdinal',
    normalizedText: text.trim(),
    extractionMethod: 'inline_text',
    extractionMethodVersion: 'v1',
    anchors: [SourceAnchor(startOffset: 0, endOffset: text.trim().length)],
    warnings: const [],
    materialUpdatedAt: now,
    sourceCreatedAt: now,
  );
}

CloudMaterialSnapshot _mediaSnapshotFromSource({required SourceIngestResult source, required int sourceOrdinal}) {
  final now = DateTime.utc(2026, 10, 14, 1, sourceOrdinal);
  return CloudMaterialSnapshot(
    serverMaterialId: 'server-${source.material.id.value}',
    materialId: source.material.id,
    title: source.material.title,
    serverSourceAssetId: 'server-media-$sourceOrdinal',
    sourceVersionId: source.sourceVersion.identity.sourceVersionId,
    serverSourceVersion: sourceOrdinal,
    sourceContentHash: source.sourceVersion.identity.contentDigest,
    mediaType: source.sourceVersion.mediaType,
    sourceName: source.sourceVersion.sourceName,
    mimeType: source.sourceVersion.mimeType,
    byteSize: source.sourceVersion.byteSize,
    storageBucket: 'study-materials',
    storagePath: 'learner/server-${source.material.id.value}/${source.sourceVersion.identity.sourceVersionId.value}',
    inlineText: null,
    serverExtractedContentId: 'server-media-extracted-$sourceOrdinal',
    normalizedText: source.extractedContent.normalizedText,
    extractionMethod: source.extractedContent.method,
    extractionMethodVersion: source.extractedContent.methodVersion,
    anchors: source.extractedContent.anchors,
    warnings: source.extractedContent.warnings,
    materialUpdatedAt: now,
    sourceCreatedAt: now,
  );
}

CloudMaterialSnapshot _remoteMediaSnapshot({
  required AuthenticatedLearner learner,
  required MaterialId materialId,
  required Uint8List bytes,
  required String title,
  required String normalizedText,
}) {
  final digest = sha256.convert(bytes).toString();
  final sourceVersionId = SourceIngestService.deriveSourceVersionId(
    learner: learner,
    materialId: materialId,
    mediaType: SourceMediaType.document,
    contentDigest: digest,
  );
  final now = DateTime.utc(2026, 10, 14, 2);
  return CloudMaterialSnapshot(
    serverMaterialId: 'server-${materialId.value}',
    materialId: materialId,
    title: title,
    serverSourceAssetId: 'server-media-remote',
    sourceVersionId: sourceVersionId,
    serverSourceVersion: 1,
    sourceContentHash: digest,
    mediaType: SourceMediaType.document,
    sourceName: title,
    mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    byteSize: bytes.length,
    storageBucket: 'study-materials',
    storagePath: 'learner/server-${materialId.value}/${sourceVersionId.value}',
    inlineText: null,
    serverExtractedContentId: 'server-media-extracted-remote',
    normalizedText: normalizedText,
    extractionMethod: 'office_openxml_text',
    extractionMethodVersion: 'openxml-v1',
    anchors: [SourceAnchor(startOffset: 0, endOffset: normalizedText.length)],
    warnings: const ['Layout sadeleştirildi'],
    materialUpdatedAt: now,
    sourceCreatedAt: now,
  );
}

void main() {
  sqfliteFfiInit();

  Future<(SqliteSourceStore, SourceIngestService, _FakeCloudContinuityGateway, CloudContinuityService)>
  harness() async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    final ingest = SourceIngestService(
      store: store,
      pdfTextExtractor: const _UnusedPdfExtractor(),
      now: () => DateTime.utc(2026, 10, 14),
    );
    final gateway = _FakeCloudContinuityGateway();
    return (store, ingest, gateway, CloudContinuityService(store: store, ingest: ingest, gateway: gateway));
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

  test('local original media pushes exact raw bytes and canonical extraction without conversion', () async {
    final (store, ingest, gateway, service) = await harness();
    addTearDown(store.close);
    const learner = AuthenticatedLearner(id: LearnerId('continuity-media-local'));
    const materialId = MaterialId('material_continuity_media_local');
    final bytes = Uint8List.fromList(List<int>.generate(64, (index) => index));
    final digest = sha256.convert(bytes).toString();
    final sourceVersionId = SourceIngestService.deriveSourceVersionId(
      learner: learner,
      materialId: materialId,
      mediaType: SourceMediaType.document,
      contentDigest: digest,
    );

    await ingest.hydrateVerifiedMediaSource(
      learner: learner,
      materialId: materialId,
      expectedSourceVersionId: sourceVersionId,
      contentDigest: digest,
      mediaType: SourceMediaType.document,
      sourceName: 'Ders notu.docx',
      mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      rawSourceBytes: bytes,
      normalizedText: 'Belgeden doğrulanmış kaynak metni.',
      extractionMethod: 'office_openxml_text',
      extractionMethodVersion: 'openxml-v1',
      anchors: const [SourceAnchor(startOffset: 0, endOffset: 34)],
      warnings: const ['Layout sadeleştirildi'],
    );

    final result = await service.reconcileMaterial(learner: learner, materialId: materialId);

    expect(result.disposition, CloudContinuityDisposition.pushedLocal);
    expect(gateway.mediaBytes[sourceVersionId], orderedEquals(bytes));
    expect(gateway.remote[materialId]!.extractionMethod, 'office_openxml_text');
    expect(gateway.remote[materialId]!.warnings, const ['Layout sadeleştirildi']);
    expect(gateway.cleanupCalls, 1);
  });

  test('new device hydrates original media from verified bytes and server extraction provenance', () async {
    final (store, _, gateway, service) = await harness();
    addTearDown(store.close);
    const learner = AuthenticatedLearner(id: LearnerId('continuity-media-remote'));
    const materialId = MaterialId('material_continuity_media_remote');
    final bytes = Uint8List.fromList(List<int>.generate(80, (index) => 255 - index));
    const normalizedText = 'Sunucudan gelen doğrulanmış DOCX kaynak metni.';
    final snapshot = _remoteMediaSnapshot(
      learner: learner,
      materialId: materialId,
      bytes: bytes,
      title: 'Ders notu.docx',
      normalizedText: normalizedText,
    );
    gateway.remote[materialId] = snapshot;
    gateway.mediaBytes[snapshot.sourceVersionId] = Uint8List.fromList(bytes);

    final result = await service.reconcileAll(learner: learner);

    expect(result.single.disposition, CloudContinuityDisposition.pulledRemote);
    final local = await store.currentSourceVersion(learner: learner, materialId: materialId);
    expect(local?.identity.sourceVersionId, snapshot.sourceVersionId);
    expect(local?.identity.contentDigest, snapshot.sourceContentHash);
    expect(
      await store.rawSourceBytesForSource(learner: learner, sourceVersionId: snapshot.sourceVersionId),
      orderedEquals(bytes),
    );
    final extracted = await store.extractedContentForSource(
      learner: learner,
      sourceVersionId: snapshot.sourceVersionId,
    );
    expect(extracted?.normalizedText, normalizedText);
    expect(extracted?.method, 'office_openxml_text');
    expect(extracted?.warnings, const ['Layout sadeleştirildi']);
  });

  test('original media download integrity failure is fail-closed and does not hydrate a local source', () async {
    final (store, _, gateway, service) = await harness();
    addTearDown(store.close);
    const learner = AuthenticatedLearner(id: LearnerId('continuity-media-corrupt'));
    const materialId = MaterialId('material_continuity_media_corrupt');
    final bytes = Uint8List.fromList(List<int>.generate(48, (index) => index + 3));
    final snapshot = _remoteMediaSnapshot(
      learner: learner,
      materialId: materialId,
      bytes: bytes,
      title: 'Bozuk indirme.docx',
      normalizedText: 'Bu kaynak yalnız bütünlük doğrulaması geçerse hydrate olur.',
    );
    gateway.remote[materialId] = snapshot;
    gateway.mediaBytes[snapshot.sourceVersionId] = Uint8List.fromList(bytes);
    gateway.failMediaDownloadIntegrity = true;

    final result = await service.reconcileAll(learner: learner);

    expect(result.single.disposition, CloudContinuityDisposition.conflict);
    expect(await store.material(learner: learner, materialId: materialId), isNull);
  });

  test('two devices changing after the shared ancestor fail closed without overwriting either source', () async {
    final (store, ingest, gateway, service) = await harness();
    addTearDown(store.close);
    const learner = AuthenticatedLearner(id: LearnerId('continuity-learner'));
    const materialId = MaterialId('material_continuity_diverged');

    await ingest.ingestPastedText(learner: learner, materialId: materialId, text: 'Ortak sürüm.', sourceName: 'Not');
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
