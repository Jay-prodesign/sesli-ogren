import 'dart:convert';

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
        onCreate: (db, version) async {
          await db.execute('''
CREATE TABLE source_versions (
  learner_id TEXT NOT NULL,
  material_id TEXT NOT NULL,
  source_version_id TEXT NOT NULL,
  content_digest TEXT NOT NULL,
  trust_class TEXT NOT NULL,
  media_type TEXT NOT NULL,
  source_name TEXT NOT NULL,
  extracted_text TEXT NOT NULL,
  provenance_json TEXT NOT NULL,
  created_at_utc TEXT NOT NULL,
  superseded_by TEXT,
  deleted_at_utc TEXT,
  PRIMARY KEY (learner_id, source_version_id),
  UNIQUE (learner_id, material_id, content_digest)
)
''');
          await db.execute('''
CREATE INDEX idx_source_versions_current
ON source_versions (learner_id, material_id, superseded_by, deleted_at_utc)
''');
        },
      ),
    );
    return SqliteSourceStore._(database);
  }

  @override
  Future<SourceVersionRecord?> currentSourceVersion({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  }) async {
    final rows = await _database.query(
      'source_versions',
      where:
          'learner_id = ? AND material_id = ? AND superseded_by IS NULL '
          'AND deleted_at_utc IS NULL',
      whereArgs: [learner.id.value, materialId.value],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  @override
  Future<SourceVersionRecord?> sourceVersion({
    required AuthenticatedLearner learner,
    required SourceVersionId sourceVersionId,
  }) async {
    final rows = await _database.query(
      'source_versions',
      where:
          'learner_id = ? AND source_version_id = ? AND deleted_at_utc IS NULL',
      whereArgs: [learner.id.value, sourceVersionId.value],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.single);
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
    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<SourceVersionRecord> persistSourceVersion({
    required AuthenticatedLearner learner,
    required SourceVersionRecord sourceVersion,
  }) {
    return _database.transaction((transaction) async {
      final existing = await transaction.query(
        'source_versions',
        where: 'learner_id = ? AND source_version_id = ?',
        whereArgs: [
          learner.id.value,
          sourceVersion.identity.sourceVersionId.value,
        ],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        final record = _fromRow(existing.single);
        if (record.deletedAt != null) {
          throw const SourceStoreConflict(
            'A deleted source version cannot be silently resurrected.',
          );
        }
        return record;
      }

      await transaction.update(
        'source_versions',
        {'superseded_by': sourceVersion.identity.sourceVersionId.value},
        where:
            'learner_id = ? AND material_id = ? AND superseded_by IS NULL '
            'AND deleted_at_utc IS NULL',
        whereArgs: [learner.id.value, sourceVersion.identity.materialId.value],
      );

      await transaction.insert(
        'source_versions',
        _toRow(learner: learner, record: sourceVersion),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      return sourceVersion;
    });
  }

  @override
  Future<void> deleteMaterial({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    required DateTime deletedAt,
  }) async {
    await _database.update(
      'source_versions',
      {'deleted_at_utc': deletedAt.toUtc().toIso8601String()},
      where: 'learner_id = ? AND material_id = ? AND deleted_at_utc IS NULL',
      whereArgs: [learner.id.value, materialId.value],
    );
  }

  @override
  Future<void> close() => _database.close();

  static Map<String, Object?> _toRow({
    required AuthenticatedLearner learner,
    required SourceVersionRecord record,
  }) {
    return {
      'learner_id': learner.id.value,
      'material_id': record.identity.materialId.value,
      'source_version_id': record.identity.sourceVersionId.value,
      'content_digest': record.identity.contentDigest,
      'trust_class': record.identity.trustClass.name,
      'media_type': record.mediaType.name,
      'source_name': record.sourceName,
      'extracted_text': record.extractedText,
      'provenance_json': jsonEncode(
        record.anchors.map((anchor) => anchor.toJson()).toList(growable: false),
      ),
      'created_at_utc': record.createdAt.toUtc().toIso8601String(),
      'superseded_by': record.supersededBy?.value,
      'deleted_at_utc': record.deletedAt?.toUtc().toIso8601String(),
    };
  }

  static SourceVersionRecord _fromRow(Map<String, Object?> row) {
    final anchorsJson = jsonDecode(row['provenance_json']! as String) as List;
    return SourceVersionRecord(
      identity: SourceVersionIdentity(
        materialId: MaterialId(row['material_id']! as String),
        sourceVersionId: SourceVersionId(row['source_version_id']! as String),
        contentDigest: row['content_digest']! as String,
        trustClass: SourceTrustClass.values.byName(
          row['trust_class']! as String,
        ),
      ),
      mediaType: SourceMediaType.values.byName(row['media_type']! as String),
      sourceName: row['source_name']! as String,
      extractedText: row['extracted_text']! as String,
      anchors: anchorsJson
          .map(
            (value) => SourceAnchor.fromJson(
              Map<String, Object?>.from(value! as Map),
            ),
          )
          .toList(growable: false),
      createdAt: DateTime.parse(row['created_at_utc']! as String).toUtc(),
      supersededBy: row['superseded_by'] == null
          ? null
          : SourceVersionId(row['superseded_by']! as String),
      deletedAt: row['deleted_at_utc'] == null
          ? null
          : DateTime.parse(row['deleted_at_utc']! as String).toUtc(),
    );
  }
}
