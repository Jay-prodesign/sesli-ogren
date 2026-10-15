import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../data/sqlite_source_store.dart';
import '../domain/authenticated_learner.dart';
import '../domain/learning_contracts.dart';
import '../domain/passive_resume.dart';
import 'passive_resume_gateway.dart';

enum PassiveResumeSyncDisposition { inSync, pushedLocal, pulledRemote, conflict, unavailable }

class PassiveResumeSyncResult {
  const PassiveResumeSyncResult({required this.surface, required this.disposition, this.message});

  final PassiveResumeSurface surface;
  final PassiveResumeSyncDisposition disposition;
  final String? message;
}

class PassiveResumeSyncSummary {
  const PassiveResumeSyncSummary({required this.results});

  final List<PassiveResumeSyncResult> results;

  int get conflicts => results.where((item) => item.disposition == PassiveResumeSyncDisposition.conflict).length;
  int get unavailable => results.where((item) => item.disposition == PassiveResumeSyncDisposition.unavailable).length;
}

class PassiveResumeContinuityService {
  const PassiveResumeContinuityService({required this.store, required this.gateway});

  final SqliteSourceStore store;
  final PassiveResumeGateway gateway;

  Future<PassiveResumeSyncSummary> syncAll({required AuthenticatedLearner learner}) async {
    if (!learner.isAuthenticated) return const PassiveResumeSyncSummary(results: []);
    final materials = await store.activeMaterials(learner: learner);
    final results = <PassiveResumeSyncResult>[];
    for (final material in materials) {
      results.addAll(await syncMaterial(learner: learner, materialId: material.id));
    }
    return PassiveResumeSyncSummary(results: results);
  }

  Future<List<PassiveResumeSyncResult>> syncMaterial({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  }) async {
    if (!learner.isAuthenticated) return const [];
    final source = await store.currentSourceVersion(learner: learner, materialId: materialId);
    if (source == null) return const [];

    List<PassiveResumeRemoteState> remote;
    try {
      remote = await gateway.read(learner: learner, materialId: materialId);
    } on PassiveResumeException catch (error) {
      final disposition = _failureDisposition(error);
      return PassiveResumeSurface.values
          .map((surface) => PassiveResumeSyncResult(surface: surface, disposition: disposition, message: error.message))
          .toList(growable: false);
    }

    final remoteBySurface = {for (final item in remote) item.surface: item};
    final results = <PassiveResumeSyncResult>[];
    for (final surface in PassiveResumeSurface.values) {
      final local = await store.passiveResumeLocalState(
        learner: learner,
        materialId: materialId,
        sourceVersionId: source.identity.sourceVersionId,
        surface: surface,
      );
      results.add(
        await _syncSurface(
          learner: learner,
          materialId: materialId,
          sourceVersionId: source.identity.sourceVersionId,
          surface: surface,
          local: local,
          remote: remoteBySurface[surface],
        ),
      );
    }
    return results;
  }

  Future<PassiveResumeSyncResult> _syncSurface({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    required SourceVersionId sourceVersionId,
    required PassiveResumeSurface surface,
    required PassiveResumeLocalState? local,
    required PassiveResumeRemoteState? remote,
  }) async {
    if (remote != null && (remote.materialId != materialId || remote.sourceVersionId != sourceVersionId)) {
      return PassiveResumeSyncResult(
        surface: surface,
        disposition: PassiveResumeSyncDisposition.conflict,
        message: 'Cloud resume belongs to a different source version.',
      );
    }
    if (local == null && remote == null) {
      return PassiveResumeSyncResult(surface: surface, disposition: PassiveResumeSyncDisposition.inSync);
    }
    if (local == null) {
      await store.applyCloudPassiveResume(learner: learner, remote: remote!);
      return PassiveResumeSyncResult(surface: surface, disposition: PassiveResumeSyncDisposition.pulledRemote);
    }
    if (remote == null) {
      if (local.serverRevision != null) {
        return PassiveResumeSyncResult(
          surface: surface,
          disposition: PassiveResumeSyncDisposition.conflict,
          message: 'Previously synced cloud resume disappeared; local position was preserved.',
        );
      }
      return _push(learner: learner, local: local, expectedRevision: null);
    }
    if (local.serverRevision == null) {
      return PassiveResumeSyncResult(
        surface: surface,
        disposition: PassiveResumeSyncDisposition.conflict,
        message: 'Local and cloud resume positions have no shared revision.',
      );
    }

    final localAhead = local.hasLocalChangeSinceSync;
    final remoteAhead = local.serverRevision != remote.revision;
    if (!localAhead && !remoteAhead) {
      return PassiveResumeSyncResult(surface: surface, disposition: PassiveResumeSyncDisposition.inSync);
    }
    if (localAhead && remoteAhead) {
      return PassiveResumeSyncResult(
        surface: surface,
        disposition: PassiveResumeSyncDisposition.conflict,
        message: 'Reader or Listen position changed on both devices after the last sync.',
      );
    }
    if (localAhead) {
      return _push(learner: learner, local: local, expectedRevision: remote.revision);
    }

    await store.applyCloudPassiveResume(learner: learner, remote: remote);
    return PassiveResumeSyncResult(surface: surface, disposition: PassiveResumeSyncDisposition.pulledRemote);
  }

  Future<PassiveResumeSyncResult> _push({
    required AuthenticatedLearner learner,
    required PassiveResumeLocalState local,
    required int? expectedRevision,
  }) async {
    try {
      final remote = await gateway.write(
        learner: learner,
        local: local,
        expectedRevision: expectedRevision,
        clientUpdateId: _updateId(learner, local),
      );
      if (remote.materialId != local.materialId ||
          remote.sourceVersionId != local.sourceVersionId ||
          remote.surface != local.surface) {
        throw const PassiveResumeException(
          'Cloud resume confirmation changed lineage.',
          kind: PassiveResumeFailureKind.invalidPayload,
        );
      }
      await store.markPassiveResumePushed(learner: learner, local: local, serverRevision: remote.revision);
      return PassiveResumeSyncResult(surface: local.surface, disposition: PassiveResumeSyncDisposition.pushedLocal);
    } on PassiveResumeException catch (error) {
      return PassiveResumeSyncResult(
        surface: local.surface,
        disposition: _failureDisposition(error),
        message: error.message,
      );
    }
  }

  static PassiveResumeSyncDisposition _failureDisposition(PassiveResumeException error) {
    return error.kind == PassiveResumeFailureKind.conflict || error.kind == PassiveResumeFailureKind.staleSource
        ? PassiveResumeSyncDisposition.conflict
        : PassiveResumeSyncDisposition.unavailable;
  }

  static String _updateId(AuthenticatedLearner learner, PassiveResumeLocalState local) {
    final value = local.surface == PassiveResumeSurface.reader
        ? local.readerProgress!.toStringAsFixed(8)
        : local.listenChunkIndex!.toString();
    final digest = sha256
        .convert(
          utf8.encode(
            '${learner.id.value}\u0000${local.materialId.value}\u0000'
            '${local.sourceVersionId.value}\u0000${local.surface.name}\u0000'
            '${local.updatedAt.toUtc().toIso8601String()}\u0000$value',
          ),
        )
        .toString();
    return 'resume_${digest.substring(0, 32)}';
  }
}
