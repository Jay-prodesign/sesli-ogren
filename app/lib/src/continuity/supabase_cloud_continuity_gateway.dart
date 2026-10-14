import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/supabase_learner_auth.dart';
import '../domain/authenticated_learner.dart';
import '../domain/learning_contracts.dart';
import 'cloud_continuity_gateway.dart';

class SupabaseCloudContinuityGateway implements CloudContinuityGateway {
  const SupabaseCloudContinuityGateway();

  @override
  Future<List<CloudMaterialSnapshot>> listMaterials({required AuthenticatedLearner learner}) async {
    try {
      final client = await _clientFor(learner);
      final rows = await client.rpc<List<dynamic>>('list_material_continuity_v2');
      return rows.whereType<Map>().map((row) => _snapshot(Map<String, dynamic>.from(row))).toList(growable: false);
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<CloudMaterialSnapshot?> readMaterial({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  }) async {
    try {
      final client = await _clientFor(learner);
      final rows = await client.rpc<List<dynamic>>(
        'read_material_continuity_v2',
        params: {'p_client_material_id': materialId.value},
      );
      if (rows.isEmpty) return null;
      if (rows.length != 1 || rows.first is! Map) {
        throw const CloudContinuityException(
          'Cloud material continuity returned an invalid payload.',
          kind: CloudContinuityFailureKind.invalidPayload,
        );
      }
      return _snapshot(Map<String, dynamic>.from(rows.first as Map));
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<CloudMaterialSnapshot> ensureTextSource({
    required AuthenticatedLearner learner,
    required SourceIngestResult source,
    SourceVersionId? expectedPreviousSourceVersionId,
  }) async {
    final sourceVersion = source.sourceVersion;
    final inlineText = sourceVersion.inlineText;
    if (sourceVersion.mediaType != SourceMediaType.pastedText || inlineText == null) {
      throw const CloudContinuityException(
        'This source needs original-media cloud storage before it can sync across devices.',
        kind: CloudContinuityFailureKind.unsupportedSource,
      );
    }

    try {
      final client = await _clientFor(learner);
      final rows = await client.rpc<List<dynamic>>(
        'ensure_text_material_continuity',
        params: {
          'p_title': source.material.title,
          'p_text': inlineText,
          'p_client_material_id': source.material.id.value,
          'p_client_source_id': sourceVersion.identity.sourceVersionId.value,
          'p_expected_previous_source_id': expectedPreviousSourceVersionId?.value,
        },
      );
      if (rows.length != 1 || rows.first is! Map) {
        throw const CloudContinuityException(
          'Cloud material continuity did not confirm the source.',
          kind: CloudContinuityFailureKind.invalidPayload,
        );
      }

      final row = Map<String, dynamic>.from(rows.first as Map);
      if (row['source_content_hash'] != sourceVersion.identity.contentDigest) {
        throw const CloudContinuityException(
          'Cloud source digest does not match the current source version.',
          kind: CloudContinuityFailureKind.conflict,
        );
      }

      final snapshot = await readMaterial(learner: learner, materialId: source.material.id);
      if (snapshot == null ||
          snapshot.sourceVersionId != sourceVersion.identity.sourceVersionId ||
          snapshot.sourceContentHash != sourceVersion.identity.contentDigest) {
        throw const CloudContinuityException(
          'Cloud source lineage does not match the current source version.',
          kind: CloudContinuityFailureKind.conflict,
        );
      }
      return snapshot;
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<CloudMaterialSnapshot> ensureMediaSource({
    required AuthenticatedLearner learner,
    required SourceIngestResult source,
    required Uint8List rawSourceBytes,
    SourceVersionId? expectedPreviousSourceVersionId,
  }) async {
    final sourceVersion = source.sourceVersion;
    if (sourceVersion.mediaType == SourceMediaType.pastedText ||
        sourceVersion.inlineText != null ||
        rawSourceBytes.isEmpty ||
        rawSourceBytes.length != sourceVersion.byteSize ||
        sha256.convert(rawSourceBytes).toString() != sourceVersion.identity.contentDigest) {
      throw const CloudContinuityException(
        'Original-media bytes do not match the current local SourceVersion.',
        kind: CloudContinuityFailureKind.conflict,
      );
    }

    final client = await _clientFor(learner);
    String? storagePath;
    try {
      final prepared = await client.rpc<List<dynamic>>(
        'prepare_media_material_continuity',
        params: {
          'p_title': source.material.title,
          'p_client_material_id': source.material.id.value,
          'p_client_source_id': sourceVersion.identity.sourceVersionId.value,
          'p_expected_previous_source_id': expectedPreviousSourceVersionId?.value,
          'p_source_type': _sourceTypeForServer(sourceVersion.mediaType),
          'p_mime_type': sourceVersion.mimeType,
          'p_byte_size': sourceVersion.byteSize,
          'p_content_hash': sourceVersion.identity.contentDigest,
        },
      );
      if (prepared.length != 1 || prepared.first is! Map) {
        throw const CloudContinuityException(
          'Cloud media continuity did not prepare a storage path.',
          kind: CloudContinuityFailureKind.invalidPayload,
        );
      }
      final preparedRow = Map<String, dynamic>.from(prepared.first as Map);
      final bucket = preparedRow['storage_bucket'] as String?;
      storagePath = preparedRow['storage_path'] as String?;
      final alreadyCurrent = preparedRow['already_current'] as bool? ?? false;
      if (bucket != 'study-materials' || storagePath == null || storagePath.isEmpty) {
        throw const CloudContinuityException(
          'Cloud media continuity returned an invalid private storage path.',
          kind: CloudContinuityFailureKind.invalidPayload,
        );
      }

      if (!alreadyCurrent) {
        final storage = client.storage.from(bucket);
        try {
          await storage.uploadBinary(
            storagePath,
            rawSourceBytes,
            fileOptions: FileOptions(contentType: sourceVersion.mimeType, upsert: false),
          );
        } on StorageException {
          try {
            final existing = await storage.download(storagePath);
            if (existing.length != rawSourceBytes.length ||
                sha256.convert(existing).toString() != sourceVersion.identity.contentDigest) {
              throw const CloudContinuityException(
                'A different media object already occupies the canonical source path.',
                kind: CloudContinuityFailureKind.conflict,
              );
            }
          } on CloudContinuityException {
            rethrow;
          } catch (_) {
            throw const CloudContinuityException(
              'Original media could not be confirmed in private cloud storage.',
              kind: CloudContinuityFailureKind.unavailable,
            );
          }
        }

        final finalized = await client.rpc<List<dynamic>>(
          'finalize_media_material_continuity',
          params: {
            'p_title': source.material.title,
            'p_client_material_id': source.material.id.value,
            'p_client_source_id': sourceVersion.identity.sourceVersionId.value,
            'p_expected_previous_source_id': expectedPreviousSourceVersionId?.value,
            'p_source_type': _sourceTypeForServer(sourceVersion.mediaType),
            'p_source_name': sourceVersion.sourceName,
            'p_mime_type': sourceVersion.mimeType,
            'p_byte_size': sourceVersion.byteSize,
            'p_content_hash': sourceVersion.identity.contentDigest,
            'p_storage_bucket': bucket,
            'p_storage_path': storagePath,
            'p_normalized_text': source.extractedContent.normalizedText,
            'p_extraction_method': source.extractedContent.method,
            'p_extraction_method_version': source.extractedContent.methodVersion,
            'p_anchors': source.extractedContent.anchors.map((anchor) => anchor.toJson()).toList(growable: false),
            'p_warnings': source.extractedContent.warnings,
          },
        );
        if (finalized.length != 1 || finalized.first is! Map) {
          throw const CloudContinuityException(
            'Cloud media continuity did not finalize the source.',
            kind: CloudContinuityFailureKind.invalidPayload,
          );
        }
        final finalizedRow = Map<String, dynamic>.from(finalized.first as Map);
        if (finalizedRow['source_content_hash'] != sourceVersion.identity.contentDigest) {
          throw const CloudContinuityException(
            'Cloud media source digest changed while finalizing.',
            kind: CloudContinuityFailureKind.conflict,
          );
        }
      }

      final snapshot = await readMaterial(learner: learner, materialId: source.material.id);
      if (snapshot == null ||
          snapshot.sourceVersionId != sourceVersion.identity.sourceVersionId ||
          snapshot.sourceContentHash != sourceVersion.identity.contentDigest ||
          snapshot.storageBucket != 'study-materials' ||
          snapshot.storagePath != storagePath) {
        throw const CloudContinuityException(
          'Cloud media lineage does not match the local SourceVersion.',
          kind: CloudContinuityFailureKind.conflict,
        );
      }
      return snapshot;
    } on CloudContinuityException {
      rethrow;
    } on PostgrestException catch (error) {
      if (storagePath != null) {
        try {
          await client.storage.from('study-materials').remove([storagePath]);
        } catch (_) {
          // The database rejected finalization; orphan cleanup is best-effort
          // here and will be retried by continuity cleanup on the next run.
        }
      }
      throw _mapError(error);
    } on StorageException {
      throw const CloudContinuityException(
        'Original media storage is temporarily unavailable.',
        kind: CloudContinuityFailureKind.unavailable,
      );
    }
  }

  @override
  Future<Uint8List> downloadMediaSource({
    required AuthenticatedLearner learner,
    required CloudMaterialSnapshot source,
  }) async {
    final bucket = source.storageBucket;
    final path = source.storagePath;
    if (source.mediaType == SourceMediaType.pastedText || bucket != 'study-materials' || path == null || path.isEmpty) {
      throw const CloudContinuityException(
        'Cloud source does not have an admitted original-media object.',
        kind: CloudContinuityFailureKind.invalidPayload,
      );
    }
    try {
      final client = await _clientFor(learner);
      final bytes = await client.storage.from(bucket).download(path);
      if (bytes.length != source.byteSize || sha256.convert(bytes).toString() != source.sourceContentHash) {
        throw const CloudContinuityException(
          'Downloaded media failed canonical source integrity validation.',
          kind: CloudContinuityFailureKind.conflict,
        );
      }
      return bytes;
    } on CloudContinuityException {
      rethrow;
    } on StorageException {
      throw const CloudContinuityException(
        'Original media could not be downloaded from private cloud storage.',
        kind: CloudContinuityFailureKind.unavailable,
      );
    }
  }

  @override
  Future<void> cleanupSupersededMedia({required AuthenticatedLearner learner, required MaterialId materialId}) async {
    try {
      final client = await _clientFor(learner);
      final rows = await client.rpc<List<dynamic>>(
        'list_superseded_media_storage_paths',
        params: {'p_client_material_id': materialId.value},
      );
      final paths = rows
          .whereType<Map>()
          .map((row) => row['storage_path'])
          .whereType<String>()
          .where((path) => path.isNotEmpty)
          .toSet()
          .toList(growable: false);
      if (paths.isEmpty) return;
      await client.storage.from('study-materials').remove(paths);
    } on PostgrestException catch (error) {
      throw _mapError(error);
    } on StorageException {
      throw const CloudContinuityException(
        'Superseded media cleanup is temporarily unavailable.',
        kind: CloudContinuityFailureKind.unavailable,
      );
    }
  }

  static Future<SupabaseClient> _clientFor(AuthenticatedLearner learner) async {
    if (!learner.isAuthenticated) {
      throw const CloudContinuityException(
        'An account is required for cross-device continuity.',
        kind: CloudContinuityFailureKind.authenticationRequired,
      );
    }
    final client = await SupabaseLearnerAuth.clientForAuthenticatedRuntime();
    final user = client.auth.currentSession?.user;
    if (user == null || user.id != learner.id.value) {
      throw const CloudContinuityException(
        'The authenticated cloud session does not match the learner.',
        kind: CloudContinuityFailureKind.authenticationRequired,
      );
    }
    return client;
  }

  static CloudMaterialSnapshot _snapshot(Map<String, dynamic> row) {
    try {
      final rawAnchors = row['anchors'];
      final anchors = rawAnchors is List
          ? rawAnchors
                .whereType<Map>()
                .map((item) => SourceAnchor.fromJson(Map<String, Object?>.from(item)))
                .toList(growable: false)
          : const <SourceAnchor>[];

      return CloudMaterialSnapshot(
        serverMaterialId: row['material_id'] as String,
        materialId: MaterialId(row['client_material_id'] as String),
        title: row['title'] as String,
        serverSourceAssetId: row['source_asset_id'] as String,
        sourceVersionId: SourceVersionId(row['client_source_id'] as String),
        serverSourceVersion: row['source_version'] as int,
        sourceContentHash: row['source_content_hash'] as String,
        mediaType: _mediaType(row['source_type'] as String),
        sourceName: row['source_name'] as String? ?? row['title'] as String,
        mimeType: row['mime_type'] as String? ?? 'application/octet-stream',
        byteSize: (row['byte_size'] as num?)?.toInt() ?? 0,
        storageBucket: row['storage_bucket'] as String?,
        storagePath: row['storage_path'] as String?,
        inlineText: row['inline_text'] as String?,
        serverExtractedContentId: row['extracted_content_id'] as String,
        normalizedText: row['normalized_text'] as String,
        extractionMethod: row['extraction_method'] as String,
        extractionMethodVersion: row['extraction_method_version'] as String,
        anchors: anchors,
        warnings: (row['warnings'] as List? ?? const []).whereType<String>().toList(growable: false),
        materialUpdatedAt: DateTime.parse(row['material_updated_at'] as String).toUtc(),
        sourceCreatedAt: DateTime.parse(row['source_created_at'] as String).toUtc(),
      );
    } catch (_) {
      throw const CloudContinuityException(
        'Cloud material continuity returned malformed source metadata.',
        kind: CloudContinuityFailureKind.invalidPayload,
      );
    }
  }

  static SourceMediaType _mediaType(String value) => switch (value) {
    'pasted_text' => SourceMediaType.pastedText,
    'pdf' => SourceMediaType.pdf,
    'image' => SourceMediaType.image,
    'document' => SourceMediaType.document,
    'presentation' => SourceMediaType.presentation,
    _ => throw const CloudContinuityException(
      'Cloud material continuity returned an unsupported source type.',
      kind: CloudContinuityFailureKind.invalidPayload,
    ),
  };

  static CloudContinuityException _mapError(PostgrestException error) {
    final message = error.message;
    if (message.contains('stale_client_source_version')) {
      return const CloudContinuityException(
        'A newer source version already exists on another device.',
        kind: CloudContinuityFailureKind.staleSource,
      );
    }
    if (message.contains('source_conflict') ||
        message.contains('source_lineage') ||
        message.contains('idempotency_key_reused')) {
      return const CloudContinuityException(
        'The local and cloud source lineages conflict.',
        kind: CloudContinuityFailureKind.conflict,
      );
    }
    return const CloudContinuityException(
      'Cloud continuity is temporarily unavailable.',
      kind: CloudContinuityFailureKind.unavailable,
    );
  }
}
