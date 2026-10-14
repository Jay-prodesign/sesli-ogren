import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../data/source_ingest_service.dart';
import '../data/sqlite_source_store.dart';
import '../domain/authenticated_learner.dart';
import '../domain/learning_contracts.dart';
import 'cloud_continuity_gateway.dart';

enum CloudContinuityDisposition {
  inSync,
  pushedLocal,
  pulledRemote,
  unsupportedSource,
  conflict,
  noMaterial,
  accountRequired,
  unavailable,
}

class CloudContinuityItemResult {
  const CloudContinuityItemResult({required this.materialId, required this.disposition, this.message});

  final MaterialId materialId;
  final CloudContinuityDisposition disposition;
  final String? message;
}

class CloudContinuityService {
  const CloudContinuityService({required this.store, required this.ingest, required this.gateway});

  final SqliteSourceStore store;
  final SourceIngestService ingest;
  final CloudContinuityGateway gateway;

  Future<List<CloudContinuityItemResult>> reconcileAll({required AuthenticatedLearner learner}) async {
    if (!learner.isAuthenticated) return const [];

    final remoteMaterials = await gateway.listMaterials(learner: learner);
    final remoteByMaterial = {for (final item in remoteMaterials) item.materialId: item};
    final localMaterials = await store.activeMaterials(learner: learner);
    final materialIds = <MaterialId>{
      ...remoteByMaterial.keys,
      ...localMaterials.map((item) => item.id),
    }.toList(growable: false);

    final results = <CloudContinuityItemResult>[];
    for (final materialId in materialIds) {
      results.add(await _reconcile(learner: learner, materialId: materialId, remote: remoteByMaterial[materialId]));
    }
    return results;
  }

  Future<CloudContinuityItemResult> reconcileMaterial({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  }) async {
    if (!learner.isAuthenticated) {
      return CloudContinuityItemResult(
        materialId: materialId,
        disposition: CloudContinuityDisposition.accountRequired,
        message: 'Cross-device continuity requires an optional account connection.',
      );
    }

    try {
      final remote = await gateway.readMaterial(learner: learner, materialId: materialId);
      return await _reconcile(learner: learner, materialId: materialId, remote: remote);
    } on CloudContinuityException catch (error) {
      return _failure(materialId, error);
    }
  }

  Future<CloudContinuityItemResult> _reconcile({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    required CloudMaterialSnapshot? remote,
  }) async {
    try {
      final localMaterial = await store.material(learner: learner, materialId: materialId);
      final localSource = localMaterial == null
          ? null
          : await store.currentSourceVersion(learner: learner, materialId: materialId);
      final binding = await store.serverMaterialBinding(learner: learner, materialId: materialId);

      if (localSource == null && remote == null) {
        return CloudContinuityItemResult(materialId: materialId, disposition: CloudContinuityDisposition.noMaterial);
      }

      if (remote == null) {
        if (binding != null) {
          return CloudContinuityItemResult(
            materialId: materialId,
            disposition: CloudContinuityDisposition.conflict,
            message: 'Cloud copy disappeared after an earlier sync; local data was preserved.',
          );
        }
        return await _pushLocal(
          learner: learner,
          materialId: materialId,
          localMaterial: localMaterial!,
          localSource: localSource!,
          expectedPreviousSourceVersionId: null,
        );
      }

      if (localSource == null) {
        return await _pullRemote(learner: learner, remote: remote);
      }

      if (localSource.identity.sourceVersionId == remote.sourceVersionId) {
        await gateway.cleanupSupersededMedia(learner: learner, materialId: materialId);
        await store.saveServerMaterialBinding(
          learner: learner,
          materialId: materialId,
          sourceVersionId: localSource.identity.sourceVersionId,
          serverMaterialId: remote.serverMaterialId,
        );
        return CloudContinuityItemResult(materialId: materialId, disposition: CloudContinuityDisposition.inSync);
      }

      if (binding == null || binding.serverMaterialId != remote.serverMaterialId) {
        return CloudContinuityItemResult(
          materialId: materialId,
          disposition: CloudContinuityDisposition.conflict,
          message: 'Local and cloud source histories have no shared sync checkpoint.',
        );
      }

      if (binding.sourceVersionId == localSource.identity.sourceVersionId) {
        return _pullRemote(learner: learner, remote: remote);
      }

      if (binding.sourceVersionId == remote.sourceVersionId) {
        return _pushLocal(
          learner: learner,
          materialId: materialId,
          localMaterial: localMaterial!,
          localSource: localSource,
          expectedPreviousSourceVersionId: remote.sourceVersionId,
        );
      }

      return CloudContinuityItemResult(
        materialId: materialId,
        disposition: CloudContinuityDisposition.conflict,
        message: 'Both this device and another device changed the source after the last sync.',
      );
    } on CloudContinuityException catch (error) {
      return _failure(materialId, error);
    }
  }

  Future<CloudContinuityItemResult> _pushLocal({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    required MaterialRecord localMaterial,
    required SourceVersionRecord localSource,
    required SourceVersionId? expectedPreviousSourceVersionId,
  }) async {
    final extracted = await store.extractedContentForSource(
      learner: learner,
      sourceVersionId: localSource.identity.sourceVersionId,
    );
    if (extracted == null || !extracted.isValid) {
      return CloudContinuityItemResult(
        materialId: materialId,
        disposition: CloudContinuityDisposition.conflict,
        message: 'The current source extraction is unavailable, so sync was not attempted.',
      );
    }

    final ingestResult = SourceIngestResult(
      material: localMaterial,
      sourceVersion: localSource,
      extractedContent: extracted,
    );
    final CloudMaterialSnapshot snapshot;
    if (localSource.mediaType == SourceMediaType.pastedText) {
      if (localSource.inlineText == null) {
        throw const CloudContinuityException(
          'Pasted text source lost its canonical inline source.',
          kind: CloudContinuityFailureKind.conflict,
        );
      }
      snapshot = await gateway.ensureTextSource(
        learner: learner,
        source: ingestResult,
        expectedPreviousSourceVersionId: expectedPreviousSourceVersionId,
      );
    } else {
      final bytes = await store.rawSourceBytesForSource(
        learner: learner,
        sourceVersionId: localSource.identity.sourceVersionId,
      );
      if (bytes == null || bytes.isEmpty) {
        throw const CloudContinuityException(
          'Original-media source bytes are unavailable on this device.',
          kind: CloudContinuityFailureKind.conflict,
        );
      }
      snapshot = await gateway.ensureMediaSource(
        learner: learner,
        source: ingestResult,
        rawSourceBytes: bytes,
        expectedPreviousSourceVersionId: expectedPreviousSourceVersionId,
      );
    }
    if (snapshot.materialId != materialId ||
        snapshot.sourceVersionId != localSource.identity.sourceVersionId ||
        snapshot.sourceContentHash != localSource.identity.contentDigest) {
      throw const CloudContinuityException(
        'Cloud confirmation does not match the exact local source.',
        kind: CloudContinuityFailureKind.conflict,
      );
    }

    await gateway.cleanupSupersededMedia(learner: learner, materialId: materialId);
    await store.saveServerMaterialBinding(
      learner: learner,
      materialId: materialId,
      sourceVersionId: localSource.identity.sourceVersionId,
      serverMaterialId: snapshot.serverMaterialId,
    );
    return CloudContinuityItemResult(materialId: materialId, disposition: CloudContinuityDisposition.pushedLocal);
  }

  Future<CloudContinuityItemResult> _pullRemote({
    required AuthenticatedLearner learner,
    required CloudMaterialSnapshot remote,
  }) async {
    final SourceIngestResult result;
    if (remote.mediaType == SourceMediaType.pastedText) {
      final inlineText = remote.inlineText;
      if (inlineText == null) {
        throw const CloudContinuityException(
          'Cloud pasted text lost its canonical inline source.',
          kind: CloudContinuityFailureKind.invalidPayload,
        );
      }
      final digest = sha256.convert(utf8.encode(inlineText)).toString();
      final derivedSourceId = SourceIngestService.deriveSourceVersionId(
        learner: learner,
        materialId: remote.materialId,
        mediaType: SourceMediaType.pastedText,
        contentDigest: digest,
      );
      if (digest != remote.sourceContentHash || derivedSourceId != remote.sourceVersionId) {
        return CloudContinuityItemResult(
          materialId: remote.materialId,
          disposition: CloudContinuityDisposition.conflict,
          message: 'Cloud source identity cannot be reproduced exactly on this device.',
        );
      }
      result = await ingest.ingestPastedText(
        learner: learner,
        materialId: remote.materialId,
        text: inlineText,
        sourceName: remote.sourceName,
      );
    } else {
      final bytes = await gateway.downloadMediaSource(learner: learner, source: remote);
      result = await ingest.hydrateVerifiedMediaSource(
        learner: learner,
        materialId: remote.materialId,
        expectedSourceVersionId: remote.sourceVersionId,
        contentDigest: remote.sourceContentHash,
        mediaType: remote.mediaType,
        sourceName: remote.sourceName,
        mimeType: remote.mimeType,
        rawSourceBytes: bytes,
        normalizedText: remote.normalizedText,
        extractionMethod: remote.extractionMethod,
        extractionMethodVersion: remote.extractionMethodVersion,
        anchors: remote.anchors,
        warnings: remote.warnings,
      );
    }
    if (result.sourceVersion.identity.sourceVersionId != remote.sourceVersionId ||
        result.sourceVersion.identity.contentDigest != remote.sourceContentHash) {
      return CloudContinuityItemResult(
        materialId: remote.materialId,
        disposition: CloudContinuityDisposition.conflict,
        message: 'Hydrated source identity does not match the cloud source.',
      );
    }

    await gateway.cleanupSupersededMedia(learner: learner, materialId: remote.materialId);
    await store.saveServerMaterialBinding(
      learner: learner,
      materialId: remote.materialId,
      sourceVersionId: remote.sourceVersionId,
      serverMaterialId: remote.serverMaterialId,
    );
    return CloudContinuityItemResult(
      materialId: remote.materialId,
      disposition: CloudContinuityDisposition.pulledRemote,
    );
  }

  static CloudContinuityItemResult _failure(MaterialId materialId, CloudContinuityException error) {
    final disposition = switch (error.kind) {
      CloudContinuityFailureKind.authenticationRequired => CloudContinuityDisposition.accountRequired,
      CloudContinuityFailureKind.unsupportedSource => CloudContinuityDisposition.unsupportedSource,
      CloudContinuityFailureKind.conflict ||
      CloudContinuityFailureKind.staleSource => CloudContinuityDisposition.conflict,
      CloudContinuityFailureKind.unavailable ||
      CloudContinuityFailureKind.invalidPayload => CloudContinuityDisposition.unavailable,
    };
    return CloudContinuityItemResult(materialId: materialId, disposition: disposition, message: error.message);
  }
}
