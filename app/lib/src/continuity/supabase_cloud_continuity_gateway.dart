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
      final rows = await client.rpc<List<dynamic>>('list_material_continuity');
      return rows
          .whereType<Map>()
          .map((row) => _snapshot(Map<String, dynamic>.from(row)))
          .toList(growable: false);
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
        'read_material_continuity',
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
        mimeType: row['mime_type'] as String? ?? 'application/octet-stream',
        byteSize: (row['byte_size'] as num?)?.toInt() ?? 0,
        inlineText: row['inline_text'] as String?,
        serverExtractedContentId: row['extracted_content_id'] as String,
        normalizedText: row['normalized_text'] as String,
        anchors: anchors,
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
