import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../domain/authenticated_learner.dart';
import '../domain/learning_contracts.dart';
import 'source_store.dart';

class SourceStoreConflict implements Exception {
  const SourceStoreConflict(this.message);

  final String message;

  @override
  String toString() => 'SourceStoreConflict: $message';
}

class SqliteSourceStore implements SourceStore {
  SqliteSourceStore._(this._database);

  final Database _database;

  static Future<SqliteSourceStore> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final selectedFactory = factory ?? databaseFactory;
    final databasePath =
        path ?? '${await getDatabasesPath()}/sesli_ogren_sources.db';
    final database = await selectedFactory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await db.execute('''
CREATE TABLE materials (
  learner_id TEXT NOT NULL,
  material_id TEXT NOT NULL,
  title TEXT NOT NULL,
  media_type TEXT NOT NULL,
  lifecycle_status TEXT NOT NULL,
  processing_state TEXT NOT NULL,
  current_source_version_id TEXT,
  created_at_utc TEXT NOT NULL,
  updated_at_utc TEXT NOT NULL,
  deleted_at_utc TEXT,
  PRIMARY KEY (learner_id, material_id)
)
''');
          await db.execute('''
CREATE TABLE source_versions (
  learner_id TEXT NOT NULL,
  material_id TEXT NOT NULL,
  source_version_id TEXT NOT NULL,
  content_digest TEXT NOT NULL,
  trust_class TEXT NOT NULL,
  knowledge_class TEXT NOT NULL,
  media_type TEXT NOT NULL,
  source_name TEXT NOT NULL,
  mime_type TEXT NOT NULL,
  byte_size INTEGER NOT NULL,
  inline_text TEXT,
  source_blob BLOB,
  created_at_utc TEXT NOT NULL,
  superseded_by TEXT,
  revoked_at_utc TEXT,
  PRIMARY KEY (learner_id, source_version_id),
  UNIQUE (learner_id, material_id, content_digest),
  FOREIGN KEY (learner_id, material_id)
    REFERENCES materials (learner_id, material_id) ON DELETE CASCADE,
  CHECK (
    (
      revoked_at_utc IS NULL
      AND (
        (media_type = 'pastedText' AND inline_text IS NOT NULL AND source_blob IS NULL)
        OR
        (media_type = 'pdf' AND inline_text IS NULL AND source_blob IS NOT NULL)
      )
    )
    OR
    (
      revoked_at_utc IS NOT NULL
      AND inline_text IS NULL
      AND source_blob IS NULL
    )
  )
)
''');
          await db.execute('''
CREATE TABLE extracted_contents (
  learner_id TEXT NOT NULL,
  extracted_content_id TEXT NOT NULL,
  source_version_id TEXT NOT NULL,
  normalized_text TEXT NOT NULL,
  method TEXT NOT NULL,
  method_version TEXT NOT NULL,
  anchors_json TEXT NOT NULL,
  warnings_json TEXT NOT NULL,
  source_content_digest TEXT NOT NULL,
  created_at_utc TEXT NOT NULL,
  invalidated_at_utc TEXT,
  PRIMARY KEY (learner_id, extracted_content_id),
  UNIQUE (learner_id, source_version_id, method, method_version),
  FOREIGN KEY (learner_id, source_version_id)
    REFERENCES source_versions (learner_id, source_version_id) ON DELETE CASCADE
)
''');
          await db.execute('''
CREATE INDEX idx_materials_active
ON materials (learner_id, lifecycle_status, updated_at_utc)
''');
          await db.execute('''
CREATE INDEX idx_source_versions_material
ON source_versions (learner_id, material_id, created_at_utc)
''');
          await db.execute('''
CREATE INDEX idx_extracted_contents_source
ON extracted_contents (learner_id, source_version_id, invalidated_at_utc)
''');
        },
      ),
    );
    return SqliteSourceStore._(database);
  }

  @override
  Future<MaterialRecord?> material({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  }) async {
    final rows = await _database.query(
      'materials',
      where:
          'learner_id = ? AND material_id = ? AND lifecycle_status = ? '
          'AND deleted_at_utc IS NULL',
      whereArgs: [
        learner.id.value,
        materialId.value,
        MaterialLifecycleStatus.active.name,
      ],
      limit: 1,
    );
    return rows.isEmpty ? null : _materialFromRow(rows.single);
  }

  @override
  Future<SourceVersionRecord?> currentSourceVersion({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  }) async {
    final rows = await _database.rawQuery(
      '''
SELECT s.*
FROM materials m
JOIN source_versions s
  ON s.learner_id = m.learner_id
 AND s.source_version_id = m.current_source_version_id
WHERE m.learner_id = ?
  AND m.material_id = ?
  AND m.lifecycle_status = ?
  AND m.deleted_at_utc IS NULL
  AND s.revoked_at_utc IS NULL
LIMIT 1
''',
      [
        learner.id.value,
        materialId.value,
        MaterialLifecycleStatus.active.name,
      ],
    );
    return rows.isEmpty ? null : _sourceFromRow(rows.single);
  }

  @override
  Future<SourceVersionRecord?> sourceVersion({
    required AuthenticatedLearner learner,
    required SourceVersionId sourceVersionId,
  }) async {
    final rows = await _database.query(
      'source_versions',
      where:
          'learner_id = ? AND source_version_id = ? AND revoked_at_utc IS NULL',
      whereArgs: [learner.id.value, sourceVersionId.value],
      limit: 1,
    );
    return rows.isEmpty ? null : _sourceFromRow(rows.single);
  }

  @override
  Future<List<SourceVersionRecord>> sourceVersions({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  }) async {
    final rows = await _database.query(
      'source_versions',
      where: 'learner_id = ? AND material_id = ?',
      whereArgs: [learner.id.value, materialId.value],
      orderBy: 'created_at_utc ASC',
    );
    return rows.map(_sourceFromRow).toList(growable: false);
  }

  @override
  Future<ExtractedContentRecord?> extractedContentForSource({
    required AuthenticatedLearner learner,
    required SourceVersionId sourceVersionId,
  }) async {
    final rows = await _database.query(
      'extracted_contents',
      where:
          'learner_id = ? AND source_version_id = ? '
          'AND invalidated_at_utc IS NULL',
      whereArgs: [learner.id.value, sourceVersionId.value],
      limit: 1,
    );
    return rows.isEmpty ? null : _extractedFromRow(rows.single);
  }

  @override
  Future<SourceIngestResult> persistIngestResult({
    required AuthenticatedLearner learner,
    required MaterialRecord material,
    required SourceVersionRecord sourceVersion,
    required ExtractedContentRecord extractedContent,
    Uint8List? rawSourceBytes,
  }) {
    _assertRelationships(
      material: material,
      sourceVersion: sourceVersion,
      extractedContent: extractedContent,
      rawSourceBytes: rawSourceBytes,
    );

    return _database.transaction((transaction) async {
      final materialRows = await transaction.query(
        'materials',
        where: 'learner_id = ? AND material_id = ?',
        whereArgs: [learner.id.value, material.id.value],
        limit: 1,
      );

      MaterialRecord? existingMaterial;
      if (materialRows.isNotEmpty) {
        existingMaterial = _materialFromRow(materialRows.single);
        if (!existingMaterial.isActive) {
          throw const SourceStoreConflict(
            'A deleted material cannot be silently resurrected.',
          );
        }
        if (existingMaterial.mediaType != material.mediaType) {
          throw const SourceStoreConflict(
            'A material cannot silently change its source media type.',
          );
        }
      } else {
        await transaction.insert(
          'materials',
          _materialToRow(
            learner: learner,
            material: MaterialRecord(
              id: material.id,
              title: material.title,
              mediaType: material.mediaType,
              lifecycleStatus: MaterialLifecycleStatus.active,
              processingState: MaterialProcessingState.none,
              createdAt: material.createdAt,
              updatedAt: material.createdAt,
            ),
          ),
        );
      }

      final existingSourceRows = await transaction.query(
        'source_versions',
        where: 'learner_id = ? AND source_version_id = ?',
        whereArgs: [
          learner.id.value,
          sourceVersion.identity.sourceVersionId.value,
        ],
        limit: 1,
      );

      if (existingSourceRows.isNotEmpty) {
        final existingSource = _sourceFromRow(existingSourceRows.single);
        if (existingSource.revokedAt != null) {
          throw const SourceStoreConflict(
            'A revoked source version cannot be silently resurrected.',
          );
        }

        final refreshedMaterialRows = await transaction.query(
          'materials',
          where: 'learner_id = ? AND material_id = ?',
          whereArgs: [learner.id.value, material.id.value],
          limit: 1,
        );
        final refreshedMaterial = _materialFromRow(refreshedMaterialRows.single);
        if (refreshedMaterial.currentSourceVersionId !=
            existingSource.identity.sourceVersionId) {
          throw const SourceStoreConflict(
            'A retry of a superseded source version is stale and fails closed.',
          );
        }

        final extractionRows = await transaction.query(
          'extracted_contents',
          where:
              'learner_id = ? AND source_version_id = ? '
              'AND invalidated_at_utc IS NULL',
          whereArgs: [
            learner.id.value,
            existingSource.identity.sourceVersionId.value,
          ],
          limit: 1,
        );
        if (extractionRows.isEmpty) {
          throw const SourceStoreConflict(
            'Current source version is missing valid extracted content.',
          );
        }
        return SourceIngestResult(
          material: refreshedMaterial,
          sourceVersion: existingSource,
          extractedContent: _extractedFromRow(extractionRows.single),
        );
      }

      await transaction.insert(
        'source_versions',
        _sourceToRow(
          learner: learner,
          record: sourceVersion,
          rawSourceBytes: rawSourceBytes,
        ),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      await transaction.insert(
        'extracted_contents',
        _extractedToRow(learner: learner, record: extractedContent),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      final supersededAt = sourceVersion.createdAt.toUtc().toIso8601String();
      final previousSourceId = existingMaterial?.currentSourceVersionId;
      if (previousSourceId != null) {
        await transaction.update(
          'source_versions',
          {'superseded_by': sourceVersion.identity.sourceVersionId.value},
          where: 'learner_id = ? AND source_version_id = ?',
          whereArgs: [learner.id.value, previousSourceId.value],
        );
        await transaction.update(
          'extracted_contents',
          {'invalidated_at_utc': supersededAt},
          where:
              'learner_id = ? AND source_version_id = ? '
              'AND invalidated_at_utc IS NULL',
          whereArgs: [learner.id.value, previousSourceId.value],
        );
      }

      await transaction.update(
        'materials',
        {
          'processing_state': MaterialProcessingState.ready.name,
          'current_source_version_id':
              sourceVersion.identity.sourceVersionId.value,
          'updated_at_utc': supersededAt,
        },
        where: 'learner_id = ? AND material_id = ?',
        whereArgs: [learner.id.value, material.id.value],
      );

      final finalMaterialRows = await transaction.query(
        'materials',
        where: 'learner_id = ? AND material_id = ?',
        whereArgs: [learner.id.value, material.id.value],
        limit: 1,
      );

      return SourceIngestResult(
        material: _materialFromRow(finalMaterialRows.single),
        sourceVersion: sourceVersion,
        extractedContent: extractedContent,
      );
    });
  }

  @override
  Future<void> deleteMaterial({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    required DateTime deletedAt,
  }) {
    final deletedAtUtc = deletedAt.toUtc().toIso8601String();
    return _database.transaction((transaction) async {
      final changed = await transaction.update(
        'materials',
        {
          'title': 'Deleted material',
          'lifecycle_status': MaterialLifecycleStatus.deleted.name,
          'processing_state': MaterialProcessingState.none.name,
          'current_source_version_id': null,
          'updated_at_utc': deletedAtUtc,
          'deleted_at_utc': deletedAtUtc,
        },
        where:
            'learner_id = ? AND material_id = ? AND lifecycle_status = ? '
            'AND deleted_at_utc IS NULL',
        whereArgs: [
          learner.id.value,
          materialId.value,
          MaterialLifecycleStatus.active.name,
        ],
      );
      if (changed == 0) {
        return;
      }

      await transaction.delete(
        'extracted_contents',
        where:
            'learner_id = ? AND source_version_id IN ('
            'SELECT source_version_id FROM source_versions '
            'WHERE learner_id = ? AND material_id = ?'
            ')',
        whereArgs: [
          learner.id.value,
          learner.id.value,
          materialId.value,
        ],
      );

      await transaction.update(
        'source_versions',
        {
          'source_name': 'Deleted source',
          'byte_size': 0,
          'inline_text': null,
          'source_blob': null,
          'revoked_at_utc': deletedAtUtc,
        },
        where:
            'learner_id = ? AND material_id = ? AND revoked_at_utc IS NULL',
        whereArgs: [learner.id.value, materialId.value],
      );
    });
  }

  @override
  Future<void> close() => _database.close();

  static void _assertRelationships({
    required MaterialRecord material,
    required SourceVersionRecord sourceVersion,
    required ExtractedContentRecord extractedContent,
    required Uint8List? rawSourceBytes,
  }) {
    if (sourceVersion.identity.materialId != material.id) {
      throw const SourceStoreConflict(
        'Source version does not belong to the material being persisted.',
      );
    }
    if (extractedContent.sourceVersionId !=
        sourceVersion.identity.sourceVersionId) {
      throw const SourceStoreConflict(
        'Extracted content does not belong to the source version.',
      );
    }
    if (extractedContent.sourceContentDigest !=
        sourceVersion.identity.contentDigest) {
      throw const SourceStoreConflict(
        'Extracted content digest does not match the source version.',
      );
    }
    if (sourceVersion.mediaType == SourceMediaType.pdf &&
        (rawSourceBytes == null || rawSourceBytes.isEmpty)) {
      throw const SourceStoreConflict(
        'PDF source bytes are required for durable source authority.',
      );
    }
    if (sourceVersion.mediaType == SourceMediaType.pastedText &&
        rawSourceBytes != null) {
      throw const SourceStoreConflict(
        'Pasted text must not carry a parallel raw binary source.',
      );
    }
  }

  static Map<String, Object?> _materialToRow({
    required AuthenticatedLearner learner,
    required MaterialRecord material,
  }) {
    return {
      'learner_id': learner.id.value,
      'material_id': material.id.value,
      'title': material.title,
      'media_type': material.mediaType.name,
      'lifecycle_status': material.lifecycleStatus.name,
      'processing_state': material.processingState.name,
      'current_source_version_id': material.currentSourceVersionId?.value,
      'created_at_utc': material.createdAt.toUtc().toIso8601String(),
      'updated_at_utc': material.updatedAt.toUtc().toIso8601String(),
      'deleted_at_utc': material.deletedAt?.toUtc().toIso8601String(),
    };
  }

  static Map<String, Object?> _sourceToRow({
    required AuthenticatedLearner learner,
    required SourceVersionRecord record,
    required Uint8List? rawSourceBytes,
  }) {
    return {
      'learner_id': learner.id.value,
      'material_id': record.identity.materialId.value,
      'source_version_id': record.identity.sourceVersionId.value,
      'content_digest': record.identity.contentDigest,
      'trust_class': record.identity.trustClass.name,
      'knowledge_class': record.identity.knowledgeClass.name,
      'media_type': record.mediaType.name,
      'source_name': record.sourceName,
      'mime_type': record.mimeType,
      'byte_size': record.byteSize,
      'inline_text': record.inlineText,
      'source_blob': rawSourceBytes,
      'created_at_utc': record.createdAt.toUtc().toIso8601String(),
      'superseded_by': record.supersededBy?.value,
      'revoked_at_utc': record.revokedAt?.toUtc().toIso8601String(),
    };
  }

  static Map<String, Object?> _extractedToRow({
    required AuthenticatedLearner learner,
    required ExtractedContentRecord record,
  }) {
    return {
      'learner_id': learner.id.value,
      'extracted_content_id': record.id.value,
      'source_version_id': record.sourceVersionId.value,
      'normalized_text': record.normalizedText,
      'method': record.method,
      'method_version': record.methodVersion,
      'anchors_json': jsonEncode(
        record.anchors.map((anchor) => anchor.toJson()).toList(growable: false),
      ),
      'warnings_json': jsonEncode(record.warnings),
      'source_content_digest': record.sourceContentDigest,
      'created_at_utc': record.createdAt.toUtc().toIso8601String(),
      'invalidated_at_utc': record.invalidatedAt?.toUtc().toIso8601String(),
    };
  }

  static MaterialRecord _materialFromRow(Map<String, Object?> row) {
    return MaterialRecord(
      id: MaterialId(row['material_id']! as String),
      title: row['title']! as String,
      mediaType: SourceMediaType.values.byName(row['media_type']! as String),
      lifecycleStatus: MaterialLifecycleStatus.values.byName(
        row['lifecycle_status']! as String,
      ),
      processingState: MaterialProcessingState.values.byName(
        row['processing_state']! as String,
      ),
      currentSourceVersionId: row['current_source_version_id'] == null
          ? null
          : SourceVersionId(row['current_source_version_id']! as String),
      createdAt: DateTime.parse(row['created_at_utc']! as String).toUtc(),
      updatedAt: DateTime.parse(row['updated_at_utc']! as String).toUtc(),
      deletedAt: row['deleted_at_utc'] == null
          ? null
          : DateTime.parse(row['deleted_at_utc']! as String).toUtc(),
    );
  }

  static SourceVersionRecord _sourceFromRow(Map<String, Object?> row) {
    return SourceVersionRecord(
      identity: SourceVersionIdentity(
        materialId: MaterialId(row['material_id']! as String),
        sourceVersionId: SourceVersionId(row['source_version_id']! as String),
        contentDigest: row['content_digest']! as String,
        trustClass: SourceTrustClass.values.byName(
          row['trust_class']! as String,
        ),
        knowledgeClass: SourceKnowledgeClass.values.byName(
          row['knowledge_class']! as String,
        ),
      ),
      mediaType: SourceMediaType.values.byName(row['media_type']! as String),
      sourceName: row['source_name']! as String,
      mimeType: row['mime_type']! as String,
      byteSize: row['byte_size']! as int,
      inlineText: row['inline_text'] as String?,
      createdAt: DateTime.parse(row['created_at_utc']! as String).toUtc(),
      supersededBy: row['superseded_by'] == null
          ? null
          : SourceVersionId(row['superseded_by']! as String),
      revokedAt: row['revoked_at_utc'] == null
          ? null
          : DateTime.parse(row['revoked_at_utc']! as String).toUtc(),
    );
  }

  static ExtractedContentRecord _extractedFromRow(
    Map<String, Object?> row,
  ) {
    final anchorsJson = jsonDecode(row['anchors_json']! as String) as List;
    final warningsJson = jsonDecode(row['warnings_json']! as String) as List;
    return ExtractedContentRecord(
      id: ExtractedContentId(row['extracted_content_id']! as String),
      sourceVersionId: SourceVersionId(row['source_version_id']! as String),
      normalizedText: row['normalized_text']! as String,
      method: row['method']! as String,
      methodVersion: row['method_version']! as String,
      anchors: anchorsJson
          .map(
            (value) => SourceAnchor.fromJson(
              Map<String, Object?>.from(value as Map),
            ),
          )
          .toList(growable: false),
      warnings: warningsJson.cast<String>().toList(growable: false),
      sourceContentDigest: row['source_content_digest']! as String,
      createdAt: DateTime.parse(row['created_at_utc']! as String).toUtc(),
      invalidatedAt: row['invalidated_at_utc'] == null
          ? null
          : DateTime.parse(row['invalidated_at_utc']! as String).toUtc(),
    );
  }
}
