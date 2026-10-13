import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/authenticated_learner.dart';
import '../domain/flashcard_learning.dart';
import '../domain/quiz_learning.dart';
import '../domain/learning_contracts.dart';
import '../domain/learning_truth.dart';
import '../domain/operational_event.dart';
import '../domain/retention_schedule.dart';
import 'learning_truth_store.dart';
import 'operational_telemetry.dart';
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

  LearningTruthStore learningTruthStore() => SqliteLearningTruthStore._(_database);

  OperationalTelemetry operationalTelemetry() => SqliteOperationalTelemetry._(_database);

  static Future<SqliteSourceStore> open({DatabaseFactory? factory, String? path}) async {
    final selectedFactory = factory ?? databaseFactory;
    final databasePath = path ?? '${await getDatabasesPath()}/sesli_ogren_sources.db';
    final database = await selectedFactory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 16,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await _upgradeLearningTruthSchema(db);
          }
          if (oldVersion < 3) {
            await _upgradeRecallSupportSchema(db);
          }
          if (oldVersion < 4) {
            await _upgradeOperationalTelemetrySchema(db);
          }
          if (oldVersion < 5) {
            await _upgradeOperationalTelemetryV5(db);
          }
          if (oldVersion < 6) {
            await _upgradeActiveRecallAttemptSchema(db);
          }
          if (oldVersion < 7) {
            await _upgradeListenProgressSchema(db);
          }
          if (oldVersion < 8) {
            await _upgradeLearnerPreferencesSchema(db);
          }
          if (oldVersion < 9) {
            await _upgradeSummaryJobsSchema(db);
          }
          if (oldVersion < 10) {
            await _upgradeSummaryCacheSchema(db);
          }
          if (oldVersion < 11) {
            await _upgradeServerMaterialBindingSchema(db);
          }
          if (oldVersion < 12) {
            await _upgradeListenRatePreferenceSchema(db);
          }
          if (oldVersion < 13) {
            await _upgradeReaderProgressSchema(db);
          }
          if (oldVersion < 14) {
            await _upgradeFlashcardSchema(db);
          }
          if (oldVersion < 15) {
            await _upgradeQuizSchema(db);
          }
          if (oldVersion < 16) {
            await _upgradeRetentionSchema(db);
          }
        },
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
CREATE TABLE recall_actions (
  learner_id TEXT NOT NULL,
  action_id TEXT NOT NULL,
  material_id TEXT NOT NULL,
  source_version_id TEXT NOT NULL,
  extracted_content_id TEXT NOT NULL,
  prompt_text TEXT NOT NULL,
  expected_answer TEXT NOT NULL,
  anchor_start INTEGER NOT NULL,
  anchor_end INTEGER NOT NULL,
  page_number INTEGER,
  rule_version TEXT NOT NULL,
  created_at_utc TEXT NOT NULL,
  PRIMARY KEY (learner_id, action_id),
  FOREIGN KEY (learner_id, source_version_id)
    REFERENCES source_versions (learner_id, source_version_id),
  FOREIGN KEY (learner_id, extracted_content_id)
    REFERENCES extracted_contents (learner_id, extracted_content_id)
    ON DELETE CASCADE
)
''');
          await db.execute('''
CREATE TABLE learner_evidence (
  learner_id TEXT NOT NULL,
  evidence_id TEXT NOT NULL,
  attempt_id TEXT NOT NULL,
  action_id TEXT NOT NULL,
  material_id TEXT NOT NULL,
  source_version_id TEXT NOT NULL,
  extracted_content_id TEXT NOT NULL,
  outcome TEXT NOT NULL,
  assistance TEXT NOT NULL,
  help_used INTEGER NOT NULL,
  response_digest TEXT NOT NULL,
  response_length INTEGER NOT NULL,
  rule_version TEXT NOT NULL,
  created_at_utc TEXT NOT NULL,
  PRIMARY KEY (learner_id, evidence_id),
  UNIQUE (learner_id, attempt_id),
  FOREIGN KEY (learner_id, action_id)
    REFERENCES recall_actions (learner_id, action_id)
    ON DELETE CASCADE
)
''');
          await db.execute('''
CREATE TABLE learner_states (
  learner_id TEXT NOT NULL,
  material_id TEXT NOT NULL,
  source_version_id TEXT NOT NULL,
  state_kind TEXT NOT NULL,
  evidence_count INTEGER NOT NULL,
  latest_evidence_id TEXT NOT NULL,
  rule_version TEXT NOT NULL,
  updated_at_utc TEXT NOT NULL,
  PRIMARY KEY (learner_id, material_id)
)
''');
          await db.execute('''
CREATE TABLE next_learning_actions (
  learner_id TEXT NOT NULL,
  material_id TEXT NOT NULL,
  source_version_id TEXT NOT NULL,
  latest_evidence_id TEXT NOT NULL,
  action_kind TEXT NOT NULL,
  reason_code TEXT NOT NULL,
  reason_text TEXT NOT NULL,
  policy_version TEXT NOT NULL,
  created_at_utc TEXT NOT NULL,
  PRIMARY KEY (learner_id, material_id),
  FOREIGN KEY (learner_id, latest_evidence_id)
    REFERENCES learner_evidence (learner_id, evidence_id)
    ON DELETE CASCADE
)
''');
          await db.execute('''
CREATE TABLE recall_attempt_support (
  learner_id TEXT NOT NULL,
  attempt_id TEXT NOT NULL,
  action_id TEXT NOT NULL,
  assistance TEXT NOT NULL,
  updated_at_utc TEXT NOT NULL,
  PRIMARY KEY (learner_id, attempt_id),
  FOREIGN KEY (learner_id, action_id)
    REFERENCES recall_actions (learner_id, action_id)
    ON DELETE CASCADE
)
''');
          await db.execute('''
CREATE TABLE active_recall_attempts (
  learner_id TEXT NOT NULL,
  material_id TEXT NOT NULL,
  source_version_id TEXT NOT NULL,
  action_id TEXT NOT NULL,
  attempt_id TEXT NOT NULL,
  opened_at_utc TEXT NOT NULL,
  PRIMARY KEY (learner_id, material_id),
  UNIQUE (learner_id, attempt_id),
  FOREIGN KEY (learner_id, action_id)
    REFERENCES recall_actions (learner_id, action_id)
    ON DELETE CASCADE
)
''');
          await db.execute('''
CREATE TABLE listen_progress (
  learner_id TEXT NOT NULL,
  material_id TEXT NOT NULL,
  source_version_id TEXT NOT NULL,
  chunk_index INTEGER NOT NULL,
  updated_at_utc TEXT NOT NULL,
  PRIMARY KEY (learner_id, material_id),
  FOREIGN KEY (learner_id, source_version_id)
    REFERENCES source_versions (learner_id, source_version_id)
    ON DELETE CASCADE,
  CHECK (chunk_index >= 0)
)
''');
          await db.execute('''
CREATE TABLE reader_progress (
  learner_id TEXT NOT NULL,
  material_id TEXT NOT NULL,
  source_version_id TEXT NOT NULL,
  progress REAL NOT NULL,
  updated_at_utc TEXT NOT NULL,
  PRIMARY KEY (learner_id, material_id),
  FOREIGN KEY (learner_id, source_version_id)
    REFERENCES source_versions (learner_id, source_version_id)
    ON DELETE CASCADE,
  CHECK (progress >= 0.0 AND progress <= 1.0)
)
''');
          await db.execute('''
CREATE TABLE learner_preferences (
  learner_id TEXT PRIMARY KEY,
  onboarding_completed INTEGER NOT NULL DEFAULT 0,
  listen_rate REAL NOT NULL DEFAULT 1.0,
  updated_at_utc TEXT NOT NULL,
  CHECK (onboarding_completed IN (0, 1)),
  CHECK (listen_rate >= 0.75 AND listen_rate <= 1.5)
)
''');
          await _upgradeSummaryJobsSchema(db);
          await _upgradeSummaryCacheSchema(db);
          await _upgradeServerMaterialBindingSchema(db);
          await _upgradeFlashcardSchema(db);
          await _upgradeQuizSchema(db);
          await _upgradeRetentionSchema(db);
          await db.execute('''
CREATE TABLE operational_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  learner_id TEXT NOT NULL,
  schema_version INTEGER NOT NULL DEFAULT 1,
  event_type TEXT NOT NULL,
  phase TEXT NOT NULL,
  material_id TEXT,
  source_version_id TEXT,
  action_id TEXT,
  attempt_id TEXT,
  evidence_id TEXT,
  outcome TEXT,
  state_kind TEXT,
  reason_code TEXT,
  rule_version TEXT,
  policy_version TEXT,
  duration_ms INTEGER,
  error_class TEXT,
  created_at_utc TEXT NOT NULL
)
''');
          await db.execute('''
CREATE INDEX idx_operational_events_learner_time
ON operational_events (learner_id, created_at_utc)
''');
          await db.execute('''
CREATE INDEX idx_recall_actions_source
ON recall_actions (learner_id, material_id, source_version_id)
''');
          await db.execute('''
CREATE INDEX idx_learner_evidence_material
ON learner_evidence (learner_id, material_id, source_version_id, created_at_utc)
''');
          await db.execute('''
CREATE INDEX idx_learner_states_source
ON learner_states (learner_id, source_version_id)
''');
          await db.execute('''
CREATE INDEX idx_next_learning_actions_source
ON next_learning_actions (learner_id, source_version_id)
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

  static Future<void> _upgradeFlashcardSchema(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS flashcard_sets (
  learner_id TEXT NOT NULL,
  flashcard_set_id TEXT NOT NULL,
  material_id TEXT NOT NULL,
  source_version_id TEXT NOT NULL,
  generation_version TEXT NOT NULL,
  created_at_utc TEXT NOT NULL,
  PRIMARY KEY (learner_id, flashcard_set_id),
  UNIQUE (learner_id, material_id, source_version_id, generation_version),
  FOREIGN KEY (learner_id, material_id)
    REFERENCES materials (learner_id, material_id) ON DELETE CASCADE,
  FOREIGN KEY (learner_id, source_version_id)
    REFERENCES source_versions (learner_id, source_version_id) ON DELETE CASCADE
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS flashcards (
  learner_id TEXT NOT NULL,
  card_id TEXT NOT NULL,
  flashcard_set_id TEXT NOT NULL,
  ordinal INTEGER NOT NULL,
  front_text TEXT NOT NULL,
  back_text TEXT NOT NULL,
  source_start INTEGER NOT NULL,
  source_end INTEGER NOT NULL,
  page_number INTEGER,
  source_excerpt TEXT NOT NULL,
  PRIMARY KEY (learner_id, card_id),
  UNIQUE (learner_id, flashcard_set_id, ordinal),
  FOREIGN KEY (learner_id, flashcard_set_id)
    REFERENCES flashcard_sets (learner_id, flashcard_set_id) ON DELETE CASCADE,
  CHECK (ordinal >= 0),
  CHECK (source_start >= 0 AND source_end > source_start)
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS flashcard_reviews (
  learner_id TEXT NOT NULL,
  card_id TEXT NOT NULL,
  review_count INTEGER NOT NULL,
  remembered_count INTEGER NOT NULL,
  again_count INTEGER NOT NULL,
  last_response TEXT NOT NULL,
  last_reviewed_at_utc TEXT NOT NULL,
  PRIMARY KEY (learner_id, card_id),
  FOREIGN KEY (learner_id, card_id)
    REFERENCES flashcards (learner_id, card_id) ON DELETE CASCADE,
  CHECK (review_count >= 1),
  CHECK (remembered_count >= 0 AND again_count >= 0),
  CHECK (last_response IN ('again', 'remembered'))
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS flashcard_sessions (
  learner_id TEXT NOT NULL,
  flashcard_set_id TEXT NOT NULL,
  cursor_index INTEGER NOT NULL,
  remembered_count INTEGER NOT NULL,
  again_count INTEGER NOT NULL,
  is_completed INTEGER NOT NULL,
  updated_at_utc TEXT NOT NULL,
  PRIMARY KEY (learner_id, flashcard_set_id),
  FOREIGN KEY (learner_id, flashcard_set_id)
    REFERENCES flashcard_sets (learner_id, flashcard_set_id) ON DELETE CASCADE,
  CHECK (cursor_index >= 0),
  CHECK (remembered_count >= 0 AND again_count >= 0),
  CHECK (is_completed IN (0, 1))
)
''');
    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_flashcard_sets_material
ON flashcard_sets (learner_id, material_id, source_version_id)
''');
  }

  static Future<void> _upgradeQuizSchema(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS quiz_sets (
  learner_id TEXT NOT NULL,
  quiz_set_id TEXT NOT NULL,
  material_id TEXT NOT NULL,
  source_version_id TEXT NOT NULL,
  generation_version TEXT NOT NULL,
  created_at_utc TEXT NOT NULL,
  PRIMARY KEY (learner_id, quiz_set_id),
  UNIQUE (learner_id, material_id, source_version_id, generation_version),
  FOREIGN KEY (learner_id, material_id)
    REFERENCES materials (learner_id, material_id) ON DELETE CASCADE,
  FOREIGN KEY (learner_id, source_version_id)
    REFERENCES source_versions (learner_id, source_version_id) ON DELETE CASCADE
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS quiz_questions (
  learner_id TEXT NOT NULL,
  question_id TEXT NOT NULL,
  quiz_set_id TEXT NOT NULL,
  ordinal INTEGER NOT NULL,
  prompt_text TEXT NOT NULL,
  options_json TEXT NOT NULL,
  correct_option_index INTEGER NOT NULL,
  source_start INTEGER NOT NULL,
  source_end INTEGER NOT NULL,
  page_number INTEGER,
  source_excerpt TEXT NOT NULL,
  PRIMARY KEY (learner_id, question_id),
  UNIQUE (learner_id, quiz_set_id, ordinal),
  FOREIGN KEY (learner_id, quiz_set_id)
    REFERENCES quiz_sets (learner_id, quiz_set_id) ON DELETE CASCADE,
  CHECK (ordinal >= 0),
  CHECK (correct_option_index >= 0),
  CHECK (source_start >= 0 AND source_end > source_start)
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS quiz_answers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  learner_id TEXT NOT NULL,
  question_id TEXT NOT NULL,
  quiz_set_id TEXT NOT NULL,
  answer_kind TEXT NOT NULL,
  selected_option_index INTEGER,
  is_correct INTEGER,
  answered_at_utc TEXT NOT NULL,
  FOREIGN KEY (learner_id, question_id)
    REFERENCES quiz_questions (learner_id, question_id) ON DELETE CASCADE,
  FOREIGN KEY (learner_id, quiz_set_id)
    REFERENCES quiz_sets (learner_id, quiz_set_id) ON DELETE CASCADE,
  CHECK (answer_kind IN ('selected', 'unknown')),
  CHECK (is_correct IS NULL OR is_correct IN (0, 1))
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS quiz_reviews (
  learner_id TEXT NOT NULL,
  question_id TEXT NOT NULL,
  answer_count INTEGER NOT NULL,
  correct_count INTEGER NOT NULL,
  incorrect_count INTEGER NOT NULL,
  unknown_count INTEGER NOT NULL,
  last_answer_kind TEXT NOT NULL,
  last_selected_option_index INTEGER,
  last_is_correct INTEGER,
  last_answered_at_utc TEXT NOT NULL,
  PRIMARY KEY (learner_id, question_id),
  FOREIGN KEY (learner_id, question_id)
    REFERENCES quiz_questions (learner_id, question_id) ON DELETE CASCADE,
  CHECK (answer_count >= 1),
  CHECK (correct_count >= 0 AND incorrect_count >= 0 AND unknown_count >= 0),
  CHECK (last_answer_kind IN ('selected', 'unknown')),
  CHECK (last_is_correct IS NULL OR last_is_correct IN (0, 1))
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS quiz_sessions (
  learner_id TEXT NOT NULL,
  quiz_set_id TEXT NOT NULL,
  cursor_index INTEGER NOT NULL,
  correct_count INTEGER NOT NULL,
  incorrect_count INTEGER NOT NULL,
  unknown_count INTEGER NOT NULL,
  is_completed INTEGER NOT NULL,
  updated_at_utc TEXT NOT NULL,
  PRIMARY KEY (learner_id, quiz_set_id),
  FOREIGN KEY (learner_id, quiz_set_id)
    REFERENCES quiz_sets (learner_id, quiz_set_id) ON DELETE CASCADE,
  CHECK (cursor_index >= 0),
  CHECK (correct_count >= 0 AND incorrect_count >= 0 AND unknown_count >= 0),
  CHECK (is_completed IN (0, 1))
)
''');
    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_quiz_sets_material
ON quiz_sets (learner_id, material_id, source_version_id)
''');
    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_quiz_answers_set
ON quiz_answers (learner_id, quiz_set_id, id)
''');
  }

  static Future<void> _upgradeSummaryJobsSchema(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS summary_jobs (
  learner_id TEXT NOT NULL,
  material_id TEXT NOT NULL,
  source_version_id TEXT NOT NULL,
  server_material_id TEXT NOT NULL,
  job_id TEXT NOT NULL,
  summary_text TEXT,
  key_points_json TEXT,
  summary_cached_at_utc TEXT,
  PRIMARY KEY (learner_id, material_id),
  FOREIGN KEY (learner_id, material_id)
    REFERENCES materials (learner_id, material_id) ON DELETE CASCADE
)
''');
  }

  static Future<void> _upgradeSummaryCacheSchema(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(summary_jobs)');
    final names = columns.map((row) => row['name'] as String).toSet();

    Future<void> add(String name, String sql) async {
      if (!names.contains(name)) {
        await db.execute(sql);
      }
    }

    await add('summary_text', 'ALTER TABLE summary_jobs ADD COLUMN summary_text TEXT');
    await add('key_points_json', 'ALTER TABLE summary_jobs ADD COLUMN key_points_json TEXT');
    await add('summary_cached_at_utc', 'ALTER TABLE summary_jobs ADD COLUMN summary_cached_at_utc TEXT');
  }

  static Future<void> _upgradeServerMaterialBindingSchema(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS server_material_bindings (
  learner_id TEXT NOT NULL,
  material_id TEXT NOT NULL,
  source_version_id TEXT NOT NULL,
  server_material_id TEXT NOT NULL,
  PRIMARY KEY (learner_id, material_id),
  FOREIGN KEY (learner_id, material_id)
    REFERENCES materials (learner_id, material_id) ON DELETE CASCADE,
  FOREIGN KEY (learner_id, source_version_id)
    REFERENCES source_versions (learner_id, source_version_id) ON DELETE CASCADE
)
''');

    final prerequisiteTables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name IN ('materials', 'source_versions', 'summary_jobs')",
    );
    final prerequisiteNames = prerequisiteTables.map((row) => row['name'] as String).toSet();
    if (!prerequisiteNames.containsAll({'materials', 'source_versions', 'summary_jobs'})) {
      return;
    }

    await db.execute('''
INSERT OR REPLACE INTO server_material_bindings (
  learner_id,
  material_id,
  source_version_id,
  server_material_id
)
SELECT learner_id, material_id, source_version_id, server_material_id
FROM summary_jobs
''');
  }

  Future<String?> summaryJobId({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    required SourceVersionId sourceVersionId,
  }) async {
    final rows = await _database.query(
      'summary_jobs',
      columns: ['job_id'],
      where: 'learner_id = ? AND material_id = ? AND source_version_id = ?',
      whereArgs: [learner.id.value, materialId.value, sourceVersionId.value],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['job_id']! as String;
  }

  Future<String?> summaryServerMaterialId({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    SourceVersionId? sourceVersionId,
  }) async {
    final where = sourceVersionId == null
        ? 'learner_id = ? AND material_id = ?'
        : 'learner_id = ? AND material_id = ? AND source_version_id = ?';
    final whereArgs = sourceVersionId == null
        ? <Object?>[learner.id.value, materialId.value]
        : <Object?>[learner.id.value, materialId.value, sourceVersionId.value];

    final bindings = await _database.query(
      'server_material_bindings',
      columns: ['server_material_id'],
      where: where,
      whereArgs: whereArgs,
      limit: 1,
    );
    if (bindings.isNotEmpty) return bindings.first['server_material_id']! as String;

    final legacyRows = await _database.query(
      'summary_jobs',
      columns: ['server_material_id'],
      where: where,
      whereArgs: whereArgs,
      limit: 1,
    );
    return legacyRows.isEmpty ? null : legacyRows.first['server_material_id']! as String;
  }

  Future<void> saveServerMaterialBinding({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    required SourceVersionId sourceVersionId,
    required String serverMaterialId,
  }) async {
    await _database.insert('server_material_bindings', {
      'learner_id': learner.id.value,
      'material_id': materialId.value,
      'source_version_id': sourceVersionId.value,
      'server_material_id': serverMaterialId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<CachedSummaryResult?> cachedSummaryResult({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    required SourceVersionId sourceVersionId,
  }) async {
    final rows = await _database.query(
      'summary_jobs',
      columns: ['summary_text', 'key_points_json', 'summary_cached_at_utc'],
      where: 'learner_id = ? AND material_id = ? AND source_version_id = ?',
      whereArgs: [learner.id.value, materialId.value, sourceVersionId.value],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final row = rows.first;
    final summary = row['summary_text'] as String?;
    final keyPointsJson = row['key_points_json'] as String?;
    final cachedAtRaw = row['summary_cached_at_utc'] as String?;
    if (summary == null || summary.trim().isEmpty || keyPointsJson == null || cachedAtRaw == null) {
      return null;
    }

    try {
      final decoded = jsonDecode(keyPointsJson);
      final cachedAt = DateTime.tryParse(cachedAtRaw);
      if (decoded is! List || decoded.any((value) => value is! String) || cachedAt == null) {
        return null;
      }
      return CachedSummaryResult(summary: summary, keyPoints: decoded.cast<String>(), cachedAt: cachedAt.toUtc());
    } catch (_) {
      return null;
    }
  }

  Future<bool> saveCachedSummaryResult({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    required SourceVersionId sourceVersionId,
    required String jobId,
    required String summary,
    required List<String> keyPoints,
    required DateTime cachedAt,
  }) async {
    final normalizedSummary = summary.trim();
    if (normalizedSummary.isEmpty) return false;
    final normalizedPoints = keyPoints.map((point) => point.trim()).where((point) => point.isNotEmpty).toList();

    final changed = await _database.update(
      'summary_jobs',
      {
        'summary_text': normalizedSummary,
        'key_points_json': jsonEncode(normalizedPoints),
        'summary_cached_at_utc': cachedAt.toUtc().toIso8601String(),
      },
      where: 'learner_id = ? AND material_id = ? AND source_version_id = ? AND job_id = ?',
      whereArgs: [learner.id.value, materialId.value, sourceVersionId.value, jobId],
    );
    return changed == 1;
  }

  Future<void> clearSummaryJob({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    SourceVersionId? sourceVersionId,
  }) async {
    final scoped = sourceVersionId != null;
    await _database.delete(
      'summary_jobs',
      where: scoped
          ? 'learner_id = ? AND material_id = ? AND source_version_id = ?'
          : 'learner_id = ? AND material_id = ?',
      whereArgs: scoped
          ? [learner.id.value, materialId.value, sourceVersionId.value]
          : [learner.id.value, materialId.value],
    );
  }

  Future<void> clearServerMaterialBinding({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    SourceVersionId? sourceVersionId,
  }) async {
    final scoped = sourceVersionId != null;
    await _database.delete(
      'server_material_bindings',
      where: scoped
          ? 'learner_id = ? AND material_id = ? AND source_version_id = ?'
          : 'learner_id = ? AND material_id = ?',
      whereArgs: scoped
          ? [learner.id.value, materialId.value, sourceVersionId.value]
          : [learner.id.value, materialId.value],
    );
  }

  Future<void> saveSummaryJob({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    required SourceVersionId sourceVersionId,
    required String serverMaterialId,
    required String jobId,
  }) async {
    await _database.transaction((transaction) async {
      await transaction.insert('server_material_bindings', {
        'learner_id': learner.id.value,
        'material_id': materialId.value,
        'source_version_id': sourceVersionId.value,
        'server_material_id': serverMaterialId,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await transaction.insert('summary_jobs', {
        'learner_id': learner.id.value,
        'material_id': materialId.value,
        'source_version_id': sourceVersionId.value,
        'server_material_id': serverMaterialId,
        'job_id': jobId,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  static Future<void> _upgradeActiveRecallAttemptSchema(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS active_recall_attempts (
  learner_id TEXT NOT NULL,
  material_id TEXT NOT NULL,
  source_version_id TEXT NOT NULL,
  action_id TEXT NOT NULL,
  attempt_id TEXT NOT NULL,
  opened_at_utc TEXT NOT NULL,
  PRIMARY KEY (learner_id, material_id),
  UNIQUE (learner_id, attempt_id),
  FOREIGN KEY (learner_id, action_id)
    REFERENCES recall_actions (learner_id, action_id)
    ON DELETE CASCADE
)
''');
  }

  static Future<void> _upgradeListenProgressSchema(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS listen_progress (
  learner_id TEXT NOT NULL,
  material_id TEXT NOT NULL,
  source_version_id TEXT NOT NULL,
  chunk_index INTEGER NOT NULL,
  updated_at_utc TEXT NOT NULL,
  PRIMARY KEY (learner_id, material_id),
  FOREIGN KEY (learner_id, source_version_id)
    REFERENCES source_versions (learner_id, source_version_id)
    ON DELETE CASCADE,
  CHECK (chunk_index >= 0)
)
''');
  }

  static Future<void> _upgradeReaderProgressSchema(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS reader_progress (
  learner_id TEXT NOT NULL,
  material_id TEXT NOT NULL,
  source_version_id TEXT NOT NULL,
  progress REAL NOT NULL,
  updated_at_utc TEXT NOT NULL,
  PRIMARY KEY (learner_id, material_id),
  FOREIGN KEY (learner_id, source_version_id)
    REFERENCES source_versions (learner_id, source_version_id)
    ON DELETE CASCADE,
  CHECK (progress >= 0.0 AND progress <= 1.0)
)
''');
  }

  static Future<void> _upgradeLearnerPreferencesSchema(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS learner_preferences (
  learner_id TEXT PRIMARY KEY,
  onboarding_completed INTEGER NOT NULL DEFAULT 0,
  listen_rate REAL NOT NULL DEFAULT 1.0,
  updated_at_utc TEXT NOT NULL,
  CHECK (onboarding_completed IN (0, 1)),
  CHECK (listen_rate >= 0.75 AND listen_rate <= 1.5)
)
''');
  }

  static Future<void> _upgradeListenRatePreferenceSchema(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(learner_preferences)');
    if (columns.isEmpty) {
      // Recover safely from legacy/partial databases whose earlier migration
      // did not create the preferences table; preserve all other user data.
      await _upgradeLearnerPreferencesSchema(db);
      return;
    }
    final hasListenRate = columns.any((column) => column['name'] == 'listen_rate');
    if (!hasListenRate) {
      await db.execute(
        'ALTER TABLE learner_preferences '
        'ADD COLUMN listen_rate REAL NOT NULL DEFAULT 1.0 '
        'CHECK (listen_rate >= 0.75 AND listen_rate <= 1.5)',
      );
    }
  }

  static Future<void> _upgradeOperationalTelemetrySchema(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS operational_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  learner_id TEXT NOT NULL,
  event_type TEXT NOT NULL,
  phase TEXT NOT NULL,
  material_id TEXT,
  source_version_id TEXT,
  action_id TEXT,
  evidence_id TEXT,
  rule_version TEXT,
  policy_version TEXT,
  duration_ms INTEGER,
  error_class TEXT,
  created_at_utc TEXT NOT NULL
)
''');
    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_operational_events_learner_time
ON operational_events (learner_id, created_at_utc)
''');
  }

  static Future<void> _upgradeOperationalTelemetryV5(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(operational_events)');
    final names = columns.map((row) => row['name'] as String).toSet();

    Future<void> add(String name, String sql) async {
      if (!names.contains(name)) {
        await db.execute(sql);
      }
    }

    await add(
      'schema_version',
      'ALTER TABLE operational_events '
          'ADD COLUMN schema_version INTEGER NOT NULL DEFAULT 1',
    );
    await add('attempt_id', 'ALTER TABLE operational_events ADD COLUMN attempt_id TEXT');
    await add('outcome', 'ALTER TABLE operational_events ADD COLUMN outcome TEXT');
    await add('state_kind', 'ALTER TABLE operational_events ADD COLUMN state_kind TEXT');
    await add('reason_code', 'ALTER TABLE operational_events ADD COLUMN reason_code TEXT');
  }

  static Future<void> _upgradeRecallSupportSchema(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS recall_attempt_support (
  learner_id TEXT NOT NULL,
  attempt_id TEXT NOT NULL,
  action_id TEXT NOT NULL,
  assistance TEXT NOT NULL,
  updated_at_utc TEXT NOT NULL,
  PRIMARY KEY (learner_id, attempt_id),
  FOREIGN KEY (learner_id, action_id)
    REFERENCES recall_actions (learner_id, action_id)
    ON DELETE CASCADE
)
''');
  }

  static Future<void> _upgradeLearningTruthSchema(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS recall_actions (
  learner_id TEXT NOT NULL,
  action_id TEXT NOT NULL,
  material_id TEXT NOT NULL,
  source_version_id TEXT NOT NULL,
  extracted_content_id TEXT NOT NULL,
  prompt_text TEXT NOT NULL,
  expected_answer TEXT NOT NULL,
  anchor_start INTEGER NOT NULL,
  anchor_end INTEGER NOT NULL,
  page_number INTEGER,
  rule_version TEXT NOT NULL,
  created_at_utc TEXT NOT NULL,
  PRIMARY KEY (learner_id, action_id),
  FOREIGN KEY (learner_id, source_version_id)
    REFERENCES source_versions (learner_id, source_version_id),
  FOREIGN KEY (learner_id, extracted_content_id)
    REFERENCES extracted_contents (learner_id, extracted_content_id)
    ON DELETE CASCADE
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS learner_evidence (
  learner_id TEXT NOT NULL,
  evidence_id TEXT NOT NULL,
  attempt_id TEXT NOT NULL,
  action_id TEXT NOT NULL,
  material_id TEXT NOT NULL,
  source_version_id TEXT NOT NULL,
  extracted_content_id TEXT NOT NULL,
  outcome TEXT NOT NULL,
  assistance TEXT NOT NULL DEFAULT 'none',
  help_used INTEGER NOT NULL DEFAULT 0,
  response_digest TEXT NOT NULL,
  response_length INTEGER NOT NULL,
  rule_version TEXT NOT NULL,
  created_at_utc TEXT NOT NULL,
  PRIMARY KEY (learner_id, evidence_id),
  UNIQUE (learner_id, attempt_id),
  FOREIGN KEY (learner_id, action_id)
    REFERENCES recall_actions (learner_id, action_id)
    ON DELETE CASCADE
)
''');
    final evidenceColumns = await db.rawQuery('PRAGMA table_info(learner_evidence)');
    final evidenceColumnNames = evidenceColumns.map((row) => row['name'] as String).toSet();
    if (!evidenceColumnNames.contains('assistance')) {
      await db.execute(
        "ALTER TABLE learner_evidence "
        "ADD COLUMN assistance TEXT NOT NULL DEFAULT 'none'",
      );
      await db.execute(
        "UPDATE learner_evidence "
        "SET assistance = CASE WHEN help_used = 1 THEN 'hint' ELSE 'none' END",
      );
    }
    await db.execute('''
CREATE TABLE IF NOT EXISTS learner_states (
  learner_id TEXT NOT NULL,
  material_id TEXT NOT NULL,
  source_version_id TEXT NOT NULL,
  state_kind TEXT NOT NULL,
  evidence_count INTEGER NOT NULL,
  latest_evidence_id TEXT NOT NULL,
  rule_version TEXT NOT NULL,
  updated_at_utc TEXT NOT NULL,
  PRIMARY KEY (learner_id, material_id)
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS next_learning_actions (
  learner_id TEXT NOT NULL,
  material_id TEXT NOT NULL,
  source_version_id TEXT NOT NULL,
  latest_evidence_id TEXT NOT NULL,
  action_kind TEXT NOT NULL,
  reason_code TEXT NOT NULL,
  reason_text TEXT NOT NULL,
  policy_version TEXT NOT NULL,
  created_at_utc TEXT NOT NULL,
  PRIMARY KEY (learner_id, material_id),
  FOREIGN KEY (learner_id, latest_evidence_id)
    REFERENCES learner_evidence (learner_id, evidence_id)
    ON DELETE CASCADE
)
''');
    await db.execute('''
UPDATE learner_states
SET state_kind = CASE (
      SELECT e.outcome
      FROM learner_evidence e
      WHERE e.learner_id = learner_states.learner_id
        AND e.evidence_id = learner_states.latest_evidence_id
    )
      WHEN 'correct' THEN 'retrievedOnce'
      WHEN 'helpedCorrect' THEN 'developing'
      WHEN 'partial' THEN 'developing'
      WHEN 'incorrect' THEN 'needsReview'
      WHEN 'unknown' THEN 'notAssessed'
      ELSE 'notAssessed'
    END,
    rule_version = 'recall-state-v2'
WHERE EXISTS (
  SELECT 1
  FROM learner_evidence e
  WHERE e.learner_id = learner_states.learner_id
    AND e.evidence_id = learner_states.latest_evidence_id
)
''');
    await db.execute('''
INSERT OR REPLACE INTO next_learning_actions (
  learner_id,
  material_id,
  source_version_id,
  latest_evidence_id,
  action_kind,
  reason_code,
  reason_text,
  policy_version,
  created_at_utc
)
SELECT
  s.learner_id,
  s.material_id,
  s.source_version_id,
  s.latest_evidence_id,
  CASE e.outcome
    WHEN 'correct' THEN 'repeatRecallLater'
    WHEN 'helpedCorrect' THEN 'retryRecallWithoutHint'
    WHEN 'partial' THEN 'retryRecallWithoutHint'
    WHEN 'incorrect' THEN 'reviewSourceThenRecall'
    WHEN 'unknown' THEN 'reviewSourceThenRecall'
    ELSE 'reviewSourceThenRecall'
  END,
  CASE e.outcome
    WHEN 'correct' THEN 'ONE_UNASSISTED_RETRIEVAL_OBSERVED'
    WHEN 'helpedCorrect' THEN 'HINTED_SUCCESS_NEEDS_UNASSISTED_RETRIEVAL'
    WHEN 'partial' THEN 'PARTIAL_RETRIEVAL_NEEDS_RETRY'
    WHEN 'incorrect' THEN 'INCORRECT_RETRIEVAL_NEEDS_REPAIR'
    WHEN 'unknown' THEN 'NO_EVALUABLE_RETRIEVAL'
    ELSE 'NO_EVALUABLE_RETRIEVAL'
  END,
  CASE e.outcome
    WHEN 'correct' THEN 'One unassisted retrieval was observed; repeat later.'
    WHEN 'helpedCorrect' THEN 'Hinted success needs a later unassisted retry.'
    WHEN 'partial' THEN 'Partial retrieval needs feedback and retry.'
    WHEN 'incorrect' THEN 'Review the source and retry Recall.'
    WHEN 'unknown' THEN 'No evaluable retrieval response; review or retry later.'
    ELSE 'Review the source before the next Recall.'
  END,
  'recall-next-v1',
  s.updated_at_utc
FROM learner_states s
JOIN learner_evidence e
  ON e.learner_id = s.learner_id
 AND e.evidence_id = s.latest_evidence_id
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_recall_actions_source '
      'ON recall_actions (learner_id, material_id, source_version_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_learner_evidence_material '
      'ON learner_evidence '
      '(learner_id, material_id, source_version_id, created_at_utc)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_learner_states_source '
      'ON learner_states (learner_id, source_version_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_next_learning_actions_source '
      'ON next_learning_actions (learner_id, source_version_id)',
    );
  }

  static Future<void> _upgradeRetentionSchema(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS retention_schedules (
  learner_id TEXT NOT NULL,
  retention_schedule_id TEXT NOT NULL,
  material_id TEXT NOT NULL,
  source_version_id TEXT NOT NULL,
  source_start INTEGER NOT NULL,
  source_end INTEGER NOT NULL,
  page_number INTEGER,
  latest_evidence_kind TEXT NOT NULL,
  latest_outcome_band TEXT NOT NULL,
  latest_event_id TEXT NOT NULL,
  reason_code TEXT NOT NULL,
  review_count INTEGER NOT NULL,
  success_streak INTEGER NOT NULL,
  interval_seconds INTEGER NOT NULL,
  due_at_utc TEXT NOT NULL,
  last_reviewed_at_utc TEXT NOT NULL,
  policy_version TEXT NOT NULL,
  invalidated_at_utc TEXT,
  PRIMARY KEY (learner_id, retention_schedule_id),
  FOREIGN KEY (learner_id, material_id)
    REFERENCES materials (learner_id, material_id) ON DELETE CASCADE,
  FOREIGN KEY (learner_id, source_version_id)
    REFERENCES source_versions (learner_id, source_version_id) ON DELETE CASCADE,
  CHECK (source_start >= 0 AND source_end > source_start),
  CHECK (review_count >= 1),
  CHECK (success_streak >= 0),
  CHECK (interval_seconds >= 0)
)
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_retention_due '
      'ON retention_schedules (learner_id, due_at_utc, invalidated_at_utc)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_retention_material '
      'ON retention_schedules (learner_id, material_id, source_version_id, invalidated_at_utc)',
    );

    // Recall has canonical event history, so it can be replayed exactly into
    // the new scheduling projection. This migration never invents mastery.
    final recallRows = await db.rawQuery('''
SELECT e.learner_id, e.evidence_id, e.material_id, e.source_version_id,
       e.outcome, e.created_at_utc,
       a.anchor_start, a.anchor_end, a.page_number
FROM learner_evidence e
JOIN recall_actions a
  ON a.learner_id = e.learner_id AND a.action_id = e.action_id
ORDER BY e.created_at_utc ASC
''');
    for (final row in recallRows) {
      final outcome = RecallOutcome.values.byName(row['outcome']! as String);
      await _upsertRetentionSchedule(
        db,
        learnerId: row['learner_id']! as String,
        materialId: MaterialId(row['material_id']! as String),
        sourceVersionId: SourceVersionId(row['source_version_id']! as String),
        sourceAnchor: SourceAnchor(
          startOffset: row['anchor_start']! as int,
          endOffset: row['anchor_end']! as int,
          pageNumber: row['page_number'] as int?,
        ),
        evidenceKind: RetentionEvidenceKind.recall,
        outcomeBand: switch (outcome) {
          RecallOutcome.correct => RetentionOutcomeBand.independentRetrieval,
          RecallOutcome.helpedCorrect || RecallOutcome.partial => RetentionOutcomeBand.supportedRetrieval,
          RecallOutcome.incorrect => RetentionOutcomeBand.repairNeeded,
          RecallOutcome.answerExposed || RecallOutcome.unknown => RetentionOutcomeBand.unassessed,
        },
        eventId: 'recall:${row['evidence_id']! as String}',
        occurredAt: DateTime.parse(row['created_at_utc']! as String).toUtc(),
      );
    }

    // Flashcards historically store a cumulative review projection rather than
    // one row per response. Backfill only the latest durable signal and keep
    // the streak conservative instead of fabricating prior intervals.
    final flashcardRows = await db.rawQuery('''
SELECT r.learner_id, r.card_id, r.review_count, r.last_response,
       r.last_reviewed_at_utc, s.material_id, s.source_version_id,
       c.source_start, c.source_end, c.page_number
FROM flashcard_reviews r
JOIN flashcards c
  ON c.learner_id = r.learner_id AND c.card_id = r.card_id
JOIN flashcard_sets s
  ON s.learner_id = c.learner_id AND s.flashcard_set_id = c.flashcard_set_id
ORDER BY r.last_reviewed_at_utc ASC
''');
    for (final row in flashcardRows) {
      final response = FlashcardResponse.values.byName(row['last_response']! as String);
      await _upsertRetentionSchedule(
        db,
        learnerId: row['learner_id']! as String,
        materialId: MaterialId(row['material_id']! as String),
        sourceVersionId: SourceVersionId(row['source_version_id']! as String),
        sourceAnchor: SourceAnchor(
          startOffset: row['source_start']! as int,
          endOffset: row['source_end']! as int,
          pageNumber: row['page_number'] as int?,
        ),
        evidenceKind: RetentionEvidenceKind.flashcard,
        outcomeBand: response == FlashcardResponse.remembered
            ? RetentionOutcomeBand.independentRetrieval
            : RetentionOutcomeBand.repairNeeded,
        eventId: 'flashcard:${row['card_id']! as String}:${row['review_count']! as int}',
        occurredAt: DateTime.parse(row['last_reviewed_at_utc']! as String).toUtc(),
      );
    }

    // Quiz keeps every durable answer, allowing chronological replay.
    final quizRows = await db.rawQuery('''
SELECT a.id, a.learner_id, a.answer_kind, a.is_correct, a.answered_at_utc,
       s.material_id, s.source_version_id,
       q.source_start, q.source_end, q.page_number
FROM quiz_answers a
JOIN quiz_questions q
  ON q.learner_id = a.learner_id AND q.question_id = a.question_id
JOIN quiz_sets s
  ON s.learner_id = q.learner_id AND s.quiz_set_id = q.quiz_set_id
ORDER BY a.id ASC
''');
    for (final row in quizRows) {
      final kind = QuizAnswerKind.values.byName(row['answer_kind']! as String);
      final isCorrect = row['is_correct'] == null ? null : row['is_correct'] == 1;
      await _upsertRetentionSchedule(
        db,
        learnerId: row['learner_id']! as String,
        materialId: MaterialId(row['material_id']! as String),
        sourceVersionId: SourceVersionId(row['source_version_id']! as String),
        sourceAnchor: SourceAnchor(
          startOffset: row['source_start']! as int,
          endOffset: row['source_end']! as int,
          pageNumber: row['page_number'] as int?,
        ),
        evidenceKind: RetentionEvidenceKind.quiz,
        outcomeBand: kind == QuizAnswerKind.unknown
            ? RetentionOutcomeBand.unassessed
            : isCorrect == true
            ? RetentionOutcomeBand.independentRetrieval
            : RetentionOutcomeBand.repairNeeded,
        eventId: 'quiz:${row['id']! as int}',
        occurredAt: DateTime.parse(row['answered_at_utc']! as String).toUtc(),
      );
    }
  }

  @override
  Future<MaterialRecord?> material({required AuthenticatedLearner learner, required MaterialId materialId}) async {
    final rows = await _database.query(
      'materials',
      where:
          'learner_id = ? AND material_id = ? AND lifecycle_status = ? '
          'AND deleted_at_utc IS NULL',
      whereArgs: [learner.id.value, materialId.value, MaterialLifecycleStatus.active.name],
      limit: 1,
    );
    return rows.isEmpty ? null : _materialFromRow(rows.single);
  }

  @override
  Future<List<MaterialRecord>> activeMaterials({required AuthenticatedLearner learner}) async {
    final rows = await _database.query(
      'materials',
      where: 'learner_id = ? AND lifecycle_status = ? AND deleted_at_utc IS NULL',
      whereArgs: [learner.id.value, MaterialLifecycleStatus.active.name],
      orderBy: 'updated_at_utc DESC, material_id ASC',
    );
    return rows.map(_materialFromRow).toList(growable: false);
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
      [learner.id.value, materialId.value, MaterialLifecycleStatus.active.name],
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
      where: 'learner_id = ? AND source_version_id = ? AND revoked_at_utc IS NULL',
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
  Future<int> listenResumeChunk({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    required SourceVersionId sourceVersionId,
  }) async {
    final rows = await _database.query(
      'listen_progress',
      columns: ['chunk_index'],
      where: 'learner_id = ? AND material_id = ? AND source_version_id = ?',
      whereArgs: [learner.id.value, materialId.value, sourceVersionId.value],
      limit: 1,
    );
    return rows.isEmpty ? 0 : rows.single['chunk_index']! as int;
  }

  @override
  Future<DateTime?> listenResumeUpdatedAt({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    required SourceVersionId sourceVersionId,
  }) async {
    final rows = await _database.query(
      'listen_progress',
      columns: ['updated_at_utc'],
      where: 'learner_id = ? AND material_id = ? AND source_version_id = ?',
      whereArgs: [learner.id.value, materialId.value, sourceVersionId.value],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final raw = rows.single['updated_at_utc'];
    return raw is String ? DateTime.parse(raw).toUtc() : null;
  }

  @override
  Future<void> saveListenResumeChunk({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    required SourceVersionId sourceVersionId,
    required int chunkIndex,
    required DateTime updatedAt,
  }) async {
    if (chunkIndex < 0) {
      throw ArgumentError.value(chunkIndex, 'chunkIndex', 'must be non-negative');
    }
    await _database.insert('listen_progress', {
      'learner_id': learner.id.value,
      'material_id': materialId.value,
      'source_version_id': sourceVersionId.value,
      'chunk_index': chunkIndex,
      'updated_at_utc': updatedAt.toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<double> readerResumeProgress({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    required SourceVersionId sourceVersionId,
  }) async {
    final rows = await _database.query(
      'reader_progress',
      columns: ['progress'],
      where: 'learner_id = ? AND material_id = ? AND source_version_id = ?',
      whereArgs: [learner.id.value, materialId.value, sourceVersionId.value],
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    return (rows.single['progress']! as num).toDouble().clamp(0.0, 1.0);
  }

  @override
  Future<DateTime?> readerResumeUpdatedAt({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    required SourceVersionId sourceVersionId,
  }) async {
    final rows = await _database.query(
      'reader_progress',
      columns: ['updated_at_utc'],
      where: 'learner_id = ? AND material_id = ? AND source_version_id = ?',
      whereArgs: [learner.id.value, materialId.value, sourceVersionId.value],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final raw = rows.single['updated_at_utc'];
    return raw is String ? DateTime.parse(raw).toUtc() : null;
  }

  @override
  Future<void> saveReaderResumeProgress({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    required SourceVersionId sourceVersionId,
    required double progress,
    required DateTime updatedAt,
  }) async {
    if (!progress.isFinite || progress < 0 || progress > 1) {
      throw ArgumentError.value(progress, 'progress', 'must be finite and between 0 and 1');
    }
    await _database.insert('reader_progress', {
      'learner_id': learner.id.value,
      'material_id': materialId.value,
      'source_version_id': sourceVersionId.value,
      'progress': progress,
      'updated_at_utc': updatedAt.toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
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
          throw const SourceStoreConflict('A deleted material cannot be silently resurrected.');
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
        whereArgs: [learner.id.value, sourceVersion.identity.sourceVersionId.value],
        limit: 1,
      );

      if (existingSourceRows.isNotEmpty) {
        final existingSource = _sourceFromRow(existingSourceRows.single);
        if (existingSource.revokedAt != null) {
          throw const SourceStoreConflict('A revoked source version cannot be silently resurrected.');
        }

        final refreshedMaterialRows = await transaction.query(
          'materials',
          where: 'learner_id = ? AND material_id = ?',
          whereArgs: [learner.id.value, material.id.value],
          limit: 1,
        );
        final refreshedMaterial = _materialFromRow(refreshedMaterialRows.single);
        if (refreshedMaterial.currentSourceVersionId != existingSource.identity.sourceVersionId) {
          throw const SourceStoreConflict('A retry of a superseded source version is stale and fails closed.');
        }

        final extractionRows = await transaction.query(
          'extracted_contents',
          where:
              'learner_id = ? AND source_version_id = ? '
              'AND invalidated_at_utc IS NULL',
          whereArgs: [learner.id.value, existingSource.identity.sourceVersionId.value],
          limit: 1,
        );
        if (extractionRows.isEmpty) {
          throw const SourceStoreConflict('Current source version is missing valid extracted content.');
        }
        return SourceIngestResult(
          material: refreshedMaterial,
          sourceVersion: existingSource,
          extractedContent: _extractedFromRow(extractionRows.single),
        );
      }

      await transaction.insert(
        'source_versions',
        _sourceToRow(learner: learner, record: sourceVersion, rawSourceBytes: rawSourceBytes),
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
        await transaction.update(
          'retention_schedules',
          {'invalidated_at_utc': supersededAt},
          where:
              'learner_id = ? AND source_version_id = ? '
              'AND invalidated_at_utc IS NULL',
          whereArgs: [learner.id.value, previousSourceId.value],
        );
      }

      if (previousSourceId != null) {
        // Passive resume positions describe the superseded source, not the material
        // abstractly. Remove them when the authoritative source changes so a new
        // source can never inherit an old Reader/Listen position. Flashcard sets
        // are intentionally retained: each set is source-version bound history,
        // while openCurrentSet() only selects the current source version.
        await transaction.delete(
          'listen_progress',
          where: 'learner_id = ? AND material_id = ?',
          whereArgs: [learner.id.value, material.id.value],
        );
        await transaction.delete(
          'reader_progress',
          where: 'learner_id = ? AND material_id = ?',
          whereArgs: [learner.id.value, material.id.value],
        );
      }

      await transaction.delete(
        'active_recall_attempts',
        where: 'learner_id = ? AND material_id = ?',
        whereArgs: [learner.id.value, material.id.value],
      );
      await transaction.delete(
        'next_learning_actions',
        where: 'learner_id = ? AND material_id = ?',
        whereArgs: [learner.id.value, material.id.value],
      );
      await transaction.delete(
        'learner_states',
        where: 'learner_id = ? AND material_id = ?',
        whereArgs: [learner.id.value, material.id.value],
      );

      await transaction.update(
        'materials',
        {
          'title': material.title,
          'media_type': material.mediaType.name,
          'processing_state': MaterialProcessingState.ready.name,
          'current_source_version_id': sourceVersion.identity.sourceVersionId.value,
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

  Future<FlashcardSetRecord?> flashcardSet({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    required SourceVersionId sourceVersionId,
    required String generationVersion,
  }) async {
    final setRows = await _database.query(
      'flashcard_sets',
      where:
          'learner_id = ? AND material_id = ? AND source_version_id = ? '
          'AND generation_version = ?',
      whereArgs: [learner.id.value, materialId.value, sourceVersionId.value, generationVersion],
      limit: 1,
    );
    if (setRows.isEmpty) return null;
    final row = setRows.single;
    final setId = FlashcardSetId(row['flashcard_set_id']! as String);
    final cardRows = await _database.query(
      'flashcards',
      where: 'learner_id = ? AND flashcard_set_id = ?',
      whereArgs: [learner.id.value, setId.value],
      orderBy: 'ordinal ASC',
    );
    return FlashcardSetRecord(
      id: setId,
      materialId: MaterialId(row['material_id']! as String),
      sourceVersionId: SourceVersionId(row['source_version_id']! as String),
      generationVersion: row['generation_version']! as String,
      createdAt: DateTime.parse(row['created_at_utc']! as String).toUtc(),
      cards: cardRows
          .map(
            (card) => FlashcardRecord(
              id: FlashcardId(card['card_id']! as String),
              setId: setId,
              ordinal: card['ordinal']! as int,
              front: card['front_text']! as String,
              back: card['back_text']! as String,
              sourceAnchor: SourceAnchor(
                startOffset: card['source_start']! as int,
                endOffset: card['source_end']! as int,
                pageNumber: card['page_number'] as int?,
              ),
              sourceExcerpt: card['source_excerpt']! as String,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> saveFlashcardSet({required AuthenticatedLearner learner, required FlashcardSetRecord set}) {
    return _database.transaction((transaction) async {
      await transaction.insert('flashcard_sets', {
        'learner_id': learner.id.value,
        'flashcard_set_id': set.id.value,
        'material_id': set.materialId.value,
        'source_version_id': set.sourceVersionId.value,
        'generation_version': set.generationVersion,
        'created_at_utc': set.createdAt.toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      for (final card in set.cards) {
        await transaction.insert('flashcards', {
          'learner_id': learner.id.value,
          'card_id': card.id.value,
          'flashcard_set_id': set.id.value,
          'ordinal': card.ordinal,
          'front_text': card.front,
          'back_text': card.back,
          'source_start': card.sourceAnchor.startOffset,
          'source_end': card.sourceAnchor.endOffset,
          'page_number': card.sourceAnchor.pageNumber,
          'source_excerpt': card.sourceExcerpt,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  Future<List<FlashcardReviewState>> flashcardReviews({
    required AuthenticatedLearner learner,
    required FlashcardSetId setId,
  }) async {
    final rows = await _database.rawQuery(
      '''
SELECT r.card_id, r.review_count, r.remembered_count, r.again_count,
       r.last_response, r.last_reviewed_at_utc
FROM flashcard_reviews r
JOIN flashcards c
  ON c.learner_id = r.learner_id AND c.card_id = r.card_id
WHERE r.learner_id = ? AND c.flashcard_set_id = ?
ORDER BY c.ordinal ASC
''',
      [learner.id.value, setId.value],
    );
    return rows
        .map(
          (row) => FlashcardReviewState(
            cardId: FlashcardId(row['card_id']! as String),
            reviewCount: row['review_count']! as int,
            rememberedCount: row['remembered_count']! as int,
            againCount: row['again_count']! as int,
            lastResponse: FlashcardResponse.values.byName(row['last_response']! as String),
            lastReviewedAt: DateTime.parse(row['last_reviewed_at_utc']! as String).toUtc(),
          ),
        )
        .toList(growable: false);
  }

  Future<FlashcardSessionState?> flashcardSession({
    required AuthenticatedLearner learner,
    required FlashcardSetId setId,
  }) async {
    final rows = await _database.query(
      'flashcard_sessions',
      where: 'learner_id = ? AND flashcard_set_id = ?',
      whereArgs: [learner.id.value, setId.value],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return FlashcardSessionState(
      setId: setId,
      cursorIndex: row['cursor_index']! as int,
      rememberedCount: row['remembered_count']! as int,
      againCount: row['again_count']! as int,
      isCompleted: row['is_completed'] == 1,
      updatedAt: DateTime.parse(row['updated_at_utc']! as String).toUtc(),
    );
  }

  Future<FlashcardResponseCommit> recordFlashcardResponse({
    required AuthenticatedLearner learner,
    required FlashcardSetRecord set,
    required FlashcardRecord card,
    required FlashcardResponse response,
    required DateTime reviewedAt,
  }) {
    return _database.transaction((transaction) async {
      final materialRows = await transaction.query(
        'materials',
        columns: ['current_source_version_id', 'lifecycle_status', 'deleted_at_utc'],
        where: 'learner_id = ? AND material_id = ?',
        whereArgs: [learner.id.value, set.materialId.value],
        limit: 1,
      );
      if (materialRows.isEmpty ||
          materialRows.single['lifecycle_status'] != MaterialLifecycleStatus.active.name ||
          materialRows.single['deleted_at_utc'] != null ||
          materialRows.single['current_source_version_id'] != set.sourceVersionId.value) {
        throw const SourceStoreConflict('Flashcard response is stale for the current source version.');
      }

      final sessionRows = await transaction.query(
        'flashcard_sessions',
        where: 'learner_id = ? AND flashcard_set_id = ?',
        whereArgs: [learner.id.value, set.id.value],
        limit: 1,
      );
      final cursor = sessionRows.isEmpty ? 0 : sessionRows.single['cursor_index']! as int;
      final completed = sessionRows.isNotEmpty && sessionRows.single['is_completed'] == 1;
      if (completed || cursor < 0 || cursor >= set.cards.length || set.cards[cursor].id != card.id) {
        throw const SourceStoreConflict('Flashcard response does not match the active durable session.');
      }

      final timestamp = reviewedAt.toUtc().toIso8601String();
      await transaction.rawInsert(
        '''
INSERT INTO flashcard_reviews (
  learner_id, card_id, review_count, remembered_count, again_count,
  last_response, last_reviewed_at_utc
)
VALUES (?, ?, 1, ?, ?, ?, ?)
ON CONFLICT(learner_id, card_id) DO UPDATE SET
  review_count = flashcard_reviews.review_count + 1,
  remembered_count = flashcard_reviews.remembered_count + excluded.remembered_count,
  again_count = flashcard_reviews.again_count + excluded.again_count,
  last_response = excluded.last_response,
  last_reviewed_at_utc = excluded.last_reviewed_at_utc
''',
        [
          learner.id.value,
          card.id.value,
          response == FlashcardResponse.remembered ? 1 : 0,
          response == FlashcardResponse.again ? 1 : 0,
          response.name,
          timestamp,
        ],
      );

      final nextCursor = cursor + 1;
      final remembered =
          (sessionRows.isEmpty ? 0 : sessionRows.single['remembered_count']! as int) +
          (response == FlashcardResponse.remembered ? 1 : 0);
      final again =
          (sessionRows.isEmpty ? 0 : sessionRows.single['again_count']! as int) +
          (response == FlashcardResponse.again ? 1 : 0);
      await transaction.rawInsert(
        '''
INSERT INTO flashcard_sessions (
  learner_id, flashcard_set_id, cursor_index, remembered_count, again_count,
  is_completed, updated_at_utc
)
VALUES (?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(learner_id, flashcard_set_id) DO UPDATE SET
  cursor_index = excluded.cursor_index,
  remembered_count = excluded.remembered_count,
  again_count = excluded.again_count,
  is_completed = excluded.is_completed,
  updated_at_utc = excluded.updated_at_utc
''',
        [
          learner.id.value,
          set.id.value,
          nextCursor,
          remembered,
          again,
          nextCursor >= set.cards.length ? 1 : 0,
          timestamp,
        ],
      );

      final reviewRows = await transaction.query(
        'flashcard_reviews',
        where: 'learner_id = ? AND card_id = ?',
        whereArgs: [learner.id.value, card.id.value],
        limit: 1,
      );
      final reviewRow = reviewRows.single;
      await _upsertRetentionSchedule(
        transaction,
        learnerId: learner.id.value,
        materialId: set.materialId,
        sourceVersionId: set.sourceVersionId,
        sourceAnchor: card.sourceAnchor,
        evidenceKind: RetentionEvidenceKind.flashcard,
        outcomeBand: response == FlashcardResponse.remembered
            ? RetentionOutcomeBand.independentRetrieval
            : RetentionOutcomeBand.repairNeeded,
        eventId: 'flashcard:${card.id.value}:${reviewRow['review_count']! as int}',
        occurredAt: reviewedAt.toUtc(),
      );
      return FlashcardResponseCommit(
        review: FlashcardReviewState(
          cardId: card.id,
          reviewCount: reviewRow['review_count']! as int,
          rememberedCount: reviewRow['remembered_count']! as int,
          againCount: reviewRow['again_count']! as int,
          lastResponse: FlashcardResponse.values.byName(reviewRow['last_response']! as String),
          lastReviewedAt: DateTime.parse(reviewRow['last_reviewed_at_utc']! as String).toUtc(),
        ),
        session: FlashcardSessionState(
          setId: set.id,
          cursorIndex: nextCursor,
          rememberedCount: remembered,
          againCount: again,
          isCompleted: nextCursor >= set.cards.length,
          updatedAt: reviewedAt.toUtc(),
        ),
      );
    });
  }

  Future<FlashcardSessionState> resetFlashcardSession({
    required AuthenticatedLearner learner,
    required FlashcardSetRecord set,
    required DateTime updatedAt,
  }) {
    return _database.transaction((transaction) async {
      final materialRows = await transaction.query(
        'materials',
        columns: ['current_source_version_id', 'lifecycle_status', 'deleted_at_utc'],
        where: 'learner_id = ? AND material_id = ?',
        whereArgs: [learner.id.value, set.materialId.value],
        limit: 1,
      );
      if (materialRows.isEmpty ||
          materialRows.single['lifecycle_status'] != MaterialLifecycleStatus.active.name ||
          materialRows.single['deleted_at_utc'] != null ||
          materialRows.single['current_source_version_id'] != set.sourceVersionId.value) {
        throw const SourceStoreConflict('Flashcard session reset is stale for the current source version.');
      }

      final resetAt = updatedAt.toUtc();
      await transaction.insert('flashcard_sessions', {
        'learner_id': learner.id.value,
        'flashcard_set_id': set.id.value,
        'cursor_index': 0,
        'remembered_count': 0,
        'again_count': 0,
        'is_completed': 0,
        'updated_at_utc': resetAt.toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return FlashcardSessionState(
        setId: set.id,
        cursorIndex: 0,
        rememberedCount: 0,
        againCount: 0,
        isCompleted: false,
        updatedAt: resetAt,
      );
    });
  }

  Future<QuizSetRecord?> quizSet({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    required SourceVersionId sourceVersionId,
    required String generationVersion,
  }) async {
    final setRows = await _database.query(
      'quiz_sets',
      where:
          'learner_id = ? AND material_id = ? AND source_version_id = ? '
          'AND generation_version = ?',
      whereArgs: [learner.id.value, materialId.value, sourceVersionId.value, generationVersion],
      limit: 1,
    );
    if (setRows.isEmpty) return null;
    final row = setRows.single;
    final setId = QuizSetId(row['quiz_set_id']! as String);
    final questionRows = await _database.query(
      'quiz_questions',
      where: 'learner_id = ? AND quiz_set_id = ?',
      whereArgs: [learner.id.value, setId.value],
      orderBy: 'ordinal ASC',
    );
    return QuizSetRecord(
      id: setId,
      materialId: MaterialId(row['material_id']! as String),
      sourceVersionId: SourceVersionId(row['source_version_id']! as String),
      generationVersion: row['generation_version']! as String,
      createdAt: DateTime.parse(row['created_at_utc']! as String).toUtc(),
      questions: questionRows
          .map((question) {
            final options = (jsonDecode(question['options_json']! as String) as List<dynamic>).cast<String>().toList(
              growable: false,
            );
            return QuizQuestionRecord(
              id: QuizQuestionId(question['question_id']! as String),
              setId: setId,
              ordinal: question['ordinal']! as int,
              prompt: question['prompt_text']! as String,
              options: options,
              correctOptionIndex: question['correct_option_index']! as int,
              sourceAnchor: SourceAnchor(
                startOffset: question['source_start']! as int,
                endOffset: question['source_end']! as int,
                pageNumber: question['page_number'] as int?,
              ),
              sourceExcerpt: question['source_excerpt']! as String,
            );
          })
          .toList(growable: false),
    );
  }

  Future<void> saveQuizSet({required AuthenticatedLearner learner, required QuizSetRecord set}) {
    return _database.transaction((transaction) async {
      await transaction.insert('quiz_sets', {
        'learner_id': learner.id.value,
        'quiz_set_id': set.id.value,
        'material_id': set.materialId.value,
        'source_version_id': set.sourceVersionId.value,
        'generation_version': set.generationVersion,
        'created_at_utc': set.createdAt.toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      for (final question in set.questions) {
        await transaction.insert('quiz_questions', {
          'learner_id': learner.id.value,
          'question_id': question.id.value,
          'quiz_set_id': set.id.value,
          'ordinal': question.ordinal,
          'prompt_text': question.prompt,
          'options_json': jsonEncode(question.options),
          'correct_option_index': question.correctOptionIndex,
          'source_start': question.sourceAnchor.startOffset,
          'source_end': question.sourceAnchor.endOffset,
          'page_number': question.sourceAnchor.pageNumber,
          'source_excerpt': question.sourceExcerpt,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  Future<List<QuizAnswerRecord>> quizAnswerHistory({
    required AuthenticatedLearner learner,
    required QuizSetId setId,
  }) async {
    final rows = await _database.query(
      'quiz_answers',
      where: 'learner_id = ? AND quiz_set_id = ?',
      whereArgs: [learner.id.value, setId.value],
      orderBy: 'id ASC',
    );
    return rows
        .map(
          (row) => QuizAnswerRecord(
            questionId: QuizQuestionId(row['question_id']! as String),
            setId: QuizSetId(row['quiz_set_id']! as String),
            kind: QuizAnswerKind.values.byName(row['answer_kind']! as String),
            selectedOptionIndex: row['selected_option_index'] as int?,
            isCorrect: row['is_correct'] == null ? null : row['is_correct'] == 1,
            answeredAt: DateTime.parse(row['answered_at_utc']! as String).toUtc(),
          ),
        )
        .toList(growable: false);
  }

  Future<List<QuizQuestionReviewState>> quizReviews({
    required AuthenticatedLearner learner,
    required QuizSetId setId,
  }) async {
    final rows = await _database.rawQuery(
      '''
SELECT r.question_id, r.answer_count, r.correct_count, r.incorrect_count,
       r.unknown_count, r.last_answer_kind, r.last_selected_option_index,
       r.last_is_correct, r.last_answered_at_utc
FROM quiz_reviews r
JOIN quiz_questions q
  ON q.learner_id = r.learner_id AND q.question_id = r.question_id
WHERE r.learner_id = ? AND q.quiz_set_id = ?
ORDER BY q.ordinal ASC
''',
      [learner.id.value, setId.value],
    );
    return rows
        .map(
          (row) => QuizQuestionReviewState(
            questionId: QuizQuestionId(row['question_id']! as String),
            answerCount: row['answer_count']! as int,
            correctCount: row['correct_count']! as int,
            incorrectCount: row['incorrect_count']! as int,
            unknownCount: row['unknown_count']! as int,
            lastAnswerKind: QuizAnswerKind.values.byName(row['last_answer_kind']! as String),
            lastSelectedOptionIndex: row['last_selected_option_index'] as int?,
            lastIsCorrect: row['last_is_correct'] == null ? null : row['last_is_correct'] == 1,
            lastAnsweredAt: DateTime.parse(row['last_answered_at_utc']! as String).toUtc(),
          ),
        )
        .toList(growable: false);
  }

  Future<QuizSessionState?> quizSession({required AuthenticatedLearner learner, required QuizSetId setId}) async {
    final rows = await _database.query(
      'quiz_sessions',
      where: 'learner_id = ? AND quiz_set_id = ?',
      whereArgs: [learner.id.value, setId.value],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return QuizSessionState(
      setId: setId,
      cursorIndex: row['cursor_index']! as int,
      correctCount: row['correct_count']! as int,
      incorrectCount: row['incorrect_count']! as int,
      unknownCount: row['unknown_count']! as int,
      isCompleted: row['is_completed'] == 1,
      updatedAt: DateTime.parse(row['updated_at_utc']! as String).toUtc(),
    );
  }

  Future<QuizAnswerCommit> recordQuizAnswer({
    required AuthenticatedLearner learner,
    required QuizSetRecord set,
    required QuizQuestionRecord question,
    required QuizAnswerKind kind,
    required int? selectedOptionIndex,
    required DateTime answeredAt,
  }) {
    return _database.transaction((transaction) async {
      final materialRows = await transaction.query(
        'materials',
        columns: ['current_source_version_id', 'lifecycle_status', 'deleted_at_utc'],
        where: 'learner_id = ? AND material_id = ?',
        whereArgs: [learner.id.value, set.materialId.value],
        limit: 1,
      );
      if (materialRows.isEmpty ||
          materialRows.single['lifecycle_status'] != MaterialLifecycleStatus.active.name ||
          materialRows.single['deleted_at_utc'] != null ||
          materialRows.single['current_source_version_id'] != set.sourceVersionId.value) {
        throw const SourceStoreConflict('Quiz answer is stale for the current source version.');
      }

      final sessionRows = await transaction.query(
        'quiz_sessions',
        where: 'learner_id = ? AND quiz_set_id = ?',
        whereArgs: [learner.id.value, set.id.value],
        limit: 1,
      );
      final cursor = sessionRows.isEmpty ? 0 : sessionRows.single['cursor_index']! as int;
      final completed = sessionRows.isNotEmpty && sessionRows.single['is_completed'] == 1;
      if (completed || cursor < 0 || cursor >= set.questions.length || set.questions[cursor].id != question.id) {
        throw const SourceStoreConflict('Quiz answer does not match the active durable session.');
      }
      if (kind == QuizAnswerKind.selected &&
          (selectedOptionIndex == null || selectedOptionIndex < 0 || selectedOptionIndex >= question.options.length)) {
        throw const SourceStoreConflict('Quiz answer option is outside the active question.');
      }
      if (kind == QuizAnswerKind.unknown && selectedOptionIndex != null) {
        throw const SourceStoreConflict('Unknown quiz answer cannot carry a selected option.');
      }

      final isCorrect = kind == QuizAnswerKind.selected ? selectedOptionIndex == question.correctOptionIndex : null;
      final correctIncrement = isCorrect == true ? 1 : 0;
      final incorrectIncrement = isCorrect == false ? 1 : 0;
      final unknownIncrement = kind == QuizAnswerKind.unknown ? 1 : 0;
      final timestamp = answeredAt.toUtc().toIso8601String();

      await transaction.insert('quiz_answers', {
        'learner_id': learner.id.value,
        'question_id': question.id.value,
        'quiz_set_id': set.id.value,
        'answer_kind': kind.name,
        'selected_option_index': selectedOptionIndex,
        'is_correct': isCorrect == null ? null : (isCorrect ? 1 : 0),
        'answered_at_utc': timestamp,
      });

      await transaction.rawInsert(
        '''
INSERT INTO quiz_reviews (
  learner_id, question_id, answer_count, correct_count, incorrect_count,
  unknown_count, last_answer_kind, last_selected_option_index, last_is_correct,
  last_answered_at_utc
)
VALUES (?, ?, 1, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(learner_id, question_id) DO UPDATE SET
  answer_count = quiz_reviews.answer_count + 1,
  correct_count = quiz_reviews.correct_count + excluded.correct_count,
  incorrect_count = quiz_reviews.incorrect_count + excluded.incorrect_count,
  unknown_count = quiz_reviews.unknown_count + excluded.unknown_count,
  last_answer_kind = excluded.last_answer_kind,
  last_selected_option_index = excluded.last_selected_option_index,
  last_is_correct = excluded.last_is_correct,
  last_answered_at_utc = excluded.last_answered_at_utc
''',
        [
          learner.id.value,
          question.id.value,
          correctIncrement,
          incorrectIncrement,
          unknownIncrement,
          kind.name,
          selectedOptionIndex,
          isCorrect == null ? null : (isCorrect ? 1 : 0),
          timestamp,
        ],
      );

      final nextCursor = cursor + 1;
      final correct = (sessionRows.isEmpty ? 0 : sessionRows.single['correct_count']! as int) + correctIncrement;
      final incorrect = (sessionRows.isEmpty ? 0 : sessionRows.single['incorrect_count']! as int) + incorrectIncrement;
      final unknown = (sessionRows.isEmpty ? 0 : sessionRows.single['unknown_count']! as int) + unknownIncrement;
      await transaction.rawInsert(
        '''
INSERT INTO quiz_sessions (
  learner_id, quiz_set_id, cursor_index, correct_count, incorrect_count,
  unknown_count, is_completed, updated_at_utc
)
VALUES (?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(learner_id, quiz_set_id) DO UPDATE SET
  cursor_index = excluded.cursor_index,
  correct_count = excluded.correct_count,
  incorrect_count = excluded.incorrect_count,
  unknown_count = excluded.unknown_count,
  is_completed = excluded.is_completed,
  updated_at_utc = excluded.updated_at_utc
''',
        [
          learner.id.value,
          set.id.value,
          nextCursor,
          correct,
          incorrect,
          unknown,
          nextCursor >= set.questions.length ? 1 : 0,
          timestamp,
        ],
      );

      final reviewRows = await transaction.query(
        'quiz_reviews',
        where: 'learner_id = ? AND question_id = ?',
        whereArgs: [learner.id.value, question.id.value],
        limit: 1,
      );
      final reviewRow = reviewRows.single;
      await _upsertRetentionSchedule(
        transaction,
        learnerId: learner.id.value,
        materialId: set.materialId,
        sourceVersionId: set.sourceVersionId,
        sourceAnchor: question.sourceAnchor,
        evidenceKind: RetentionEvidenceKind.quiz,
        outcomeBand: kind == QuizAnswerKind.unknown
            ? RetentionOutcomeBand.unassessed
            : isCorrect == true
            ? RetentionOutcomeBand.independentRetrieval
            : RetentionOutcomeBand.repairNeeded,
        eventId: 'quiz:${question.id.value}:${reviewRow['answer_count']! as int}',
        occurredAt: answeredAt.toUtc(),
      );
      return QuizAnswerCommit(
        review: QuizQuestionReviewState(
          questionId: question.id,
          answerCount: reviewRow['answer_count']! as int,
          correctCount: reviewRow['correct_count']! as int,
          incorrectCount: reviewRow['incorrect_count']! as int,
          unknownCount: reviewRow['unknown_count']! as int,
          lastAnswerKind: QuizAnswerKind.values.byName(reviewRow['last_answer_kind']! as String),
          lastSelectedOptionIndex: reviewRow['last_selected_option_index'] as int?,
          lastIsCorrect: reviewRow['last_is_correct'] == null ? null : reviewRow['last_is_correct'] == 1,
          lastAnsweredAt: DateTime.parse(reviewRow['last_answered_at_utc']! as String).toUtc(),
        ),
        session: QuizSessionState(
          setId: set.id,
          cursorIndex: nextCursor,
          correctCount: correct,
          incorrectCount: incorrect,
          unknownCount: unknown,
          isCompleted: nextCursor >= set.questions.length,
          updatedAt: answeredAt.toUtc(),
        ),
      );
    });
  }

  Future<QuizSessionState> resetQuizSession({
    required AuthenticatedLearner learner,
    required QuizSetRecord set,
    required DateTime updatedAt,
  }) {
    return _database.transaction((transaction) async {
      final materialRows = await transaction.query(
        'materials',
        columns: ['current_source_version_id', 'lifecycle_status', 'deleted_at_utc'],
        where: 'learner_id = ? AND material_id = ?',
        whereArgs: [learner.id.value, set.materialId.value],
        limit: 1,
      );
      if (materialRows.isEmpty ||
          materialRows.single['lifecycle_status'] != MaterialLifecycleStatus.active.name ||
          materialRows.single['deleted_at_utc'] != null ||
          materialRows.single['current_source_version_id'] != set.sourceVersionId.value) {
        throw const SourceStoreConflict('Quiz session reset is stale for the current source version.');
      }

      final resetAt = updatedAt.toUtc();
      await transaction.insert('quiz_sessions', {
        'learner_id': learner.id.value,
        'quiz_set_id': set.id.value,
        'cursor_index': 0,
        'correct_count': 0,
        'incorrect_count': 0,
        'unknown_count': 0,
        'is_completed': 0,
        'updated_at_utc': resetAt.toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return QuizSessionState(
        setId: set.id,
        cursorIndex: 0,
        correctCount: 0,
        incorrectCount: 0,
        unknownCount: 0,
        isCompleted: false,
        updatedAt: resetAt,
      );
    });
  }

  Future<List<RetentionScheduleRecord>> retentionSchedulesForMaterial({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  }) async {
    final rows = await _database.rawQuery(
      '''
SELECT r.*
FROM retention_schedules r
JOIN materials m
  ON m.learner_id = r.learner_id AND m.material_id = r.material_id
WHERE r.learner_id = ?
  AND r.material_id = ?
  AND m.lifecycle_status = ?
  AND m.deleted_at_utc IS NULL
  AND m.current_source_version_id = r.source_version_id
  AND r.invalidated_at_utc IS NULL
ORDER BY r.due_at_utc ASC, r.source_start ASC, r.source_end ASC
''',
      [learner.id.value, materialId.value, MaterialLifecycleStatus.active.name],
    );
    return rows.map(_retentionFromRow).toList(growable: false);
  }

  Future<List<RetentionScheduleRecord>> dueRetentionSchedules({
    required AuthenticatedLearner learner,
    required DateTime at,
    int limit = 20,
  }) async {
    if (limit < 1 || limit > 100) {
      throw ArgumentError.value(limit, 'limit', 'Expected 1-100 due retention items.');
    }
    final rows = await _database.rawQuery(
      '''
SELECT r.*
FROM retention_schedules r
JOIN materials m
  ON m.learner_id = r.learner_id AND m.material_id = r.material_id
WHERE r.learner_id = ?
  AND m.lifecycle_status = ?
  AND m.deleted_at_utc IS NULL
  AND m.current_source_version_id = r.source_version_id
  AND r.invalidated_at_utc IS NULL
  AND r.due_at_utc <= ?
ORDER BY r.due_at_utc ASC, r.last_reviewed_at_utc ASC
LIMIT ?
''',
      [learner.id.value, MaterialLifecycleStatus.active.name, at.toUtc().toIso8601String(), limit],
    );
    return rows.map(_retentionFromRow).toList(growable: false);
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
        whereArgs: [learner.id.value, materialId.value, MaterialLifecycleStatus.active.name],
      );
      if (changed == 0) {
        return;
      }

      await transaction.delete(
        'retention_schedules',
        where: 'learner_id = ? AND material_id = ?',
        whereArgs: [learner.id.value, materialId.value],
      );
      await transaction.delete(
        'summary_jobs',
        where: 'learner_id = ? AND material_id = ?',
        whereArgs: [learner.id.value, materialId.value],
      );
      await transaction.delete(
        'flashcard_sets',
        where: 'learner_id = ? AND material_id = ?',
        whereArgs: [learner.id.value, materialId.value],
      );
      await transaction.delete(
        'quiz_sets',
        where: 'learner_id = ? AND material_id = ?',
        whereArgs: [learner.id.value, materialId.value],
      );
      await transaction.delete(
        'server_material_bindings',
        where: 'learner_id = ? AND material_id = ?',
        whereArgs: [learner.id.value, materialId.value],
      );
      await transaction.delete(
        'active_recall_attempts',
        where: 'learner_id = ? AND material_id = ?',
        whereArgs: [learner.id.value, materialId.value],
      );
      await transaction.delete(
        'listen_progress',
        where: 'learner_id = ? AND material_id = ?',
        whereArgs: [learner.id.value, materialId.value],
      );
      await transaction.delete(
        'next_learning_actions',
        where: 'learner_id = ? AND material_id = ?',
        whereArgs: [learner.id.value, materialId.value],
      );
      await transaction.delete(
        'learner_states',
        where: 'learner_id = ? AND material_id = ?',
        whereArgs: [learner.id.value, materialId.value],
      );

      await transaction.delete(
        'extracted_contents',
        where:
            'learner_id = ? AND source_version_id IN ('
            'SELECT source_version_id FROM source_versions '
            'WHERE learner_id = ? AND material_id = ?'
            ')',
        whereArgs: [learner.id.value, learner.id.value, materialId.value],
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
        where: 'learner_id = ? AND material_id = ? AND revoked_at_utc IS NULL',
        whereArgs: [learner.id.value, materialId.value],
      );
    });
  }

  Future<bool> onboardingCompleted({required AuthenticatedLearner learner}) async {
    final rows = await _database.query(
      'learner_preferences',
      columns: ['onboarding_completed'],
      where: 'learner_id = ?',
      whereArgs: [learner.id.value],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return rows.single['onboarding_completed'] == 1;
  }

  Future<void> markOnboardingCompleted({required AuthenticatedLearner learner, required DateTime updatedAt}) async {
    await _database.rawInsert(
      '''
INSERT INTO learner_preferences (learner_id, onboarding_completed, updated_at_utc)
VALUES (?, 1, ?)
ON CONFLICT(learner_id) DO UPDATE SET
  onboarding_completed = 1,
  updated_at_utc = excluded.updated_at_utc
''',
      [learner.id.value, updatedAt.toUtc().toIso8601String()],
    );
  }

  Future<double> listenRate({required AuthenticatedLearner learner}) async {
    final rows = await _database.query(
      'learner_preferences',
      columns: ['listen_rate'],
      where: 'learner_id = ?',
      whereArgs: [learner.id.value],
      limit: 1,
    );
    if (rows.isEmpty) return 1.0;
    final raw = rows.single['listen_rate'];
    if (raw is! num) return 1.0;
    final value = raw.toDouble();
    return const <double>[0.75, 1.0, 1.25, 1.5].contains(value) ? value : 1.0;
  }

  Future<void> saveListenRate({
    required AuthenticatedLearner learner,
    required double rate,
    required DateTime updatedAt,
  }) async {
    if (!const <double>[0.75, 1.0, 1.25, 1.5].contains(rate)) {
      throw ArgumentError.value(rate, 'rate', 'Unsupported listening rate.');
    }
    await _database.rawInsert(
      '''
INSERT INTO learner_preferences (learner_id, listen_rate, updated_at_utc)
VALUES (?, ?, ?)
ON CONFLICT(learner_id) DO UPDATE SET
  listen_rate = excluded.listen_rate,
  updated_at_utc = excluded.updated_at_utc
''',
      [learner.id.value, rate, updatedAt.toUtc().toIso8601String()],
    );
  }

  @override
  Future<void> purgeLearnerData({required AuthenticatedLearner learner}) {
    return _database.transaction((transaction) async {
      final id = learner.id.value;
      await transaction.delete('learner_preferences', where: 'learner_id = ?', whereArgs: [id]);
      await transaction.delete('retention_schedules', where: 'learner_id = ?', whereArgs: [id]);
      await transaction.delete('active_recall_attempts', where: 'learner_id = ?', whereArgs: [id]);
      await transaction.delete('recall_attempt_support', where: 'learner_id = ?', whereArgs: [id]);
      await transaction.delete('next_learning_actions', where: 'learner_id = ?', whereArgs: [id]);
      await transaction.delete('learner_states', where: 'learner_id = ?', whereArgs: [id]);
      await transaction.delete('learner_evidence', where: 'learner_id = ?', whereArgs: [id]);
      await transaction.delete('recall_actions', where: 'learner_id = ?', whereArgs: [id]);
      await transaction.delete('listen_progress', where: 'learner_id = ?', whereArgs: [id]);
      await transaction.delete('flashcard_sets', where: 'learner_id = ?', whereArgs: [id]);
      await transaction.delete('quiz_sets', where: 'learner_id = ?', whereArgs: [id]);
      await transaction.delete('extracted_contents', where: 'learner_id = ?', whereArgs: [id]);
      await transaction.delete('source_versions', where: 'learner_id = ?', whereArgs: [id]);
      await transaction.delete('materials', where: 'learner_id = ?', whereArgs: [id]);
      await transaction.delete('operational_events', where: 'learner_id = ?', whereArgs: [id]);
    });
  }

  static RetentionScheduleId _retentionScheduleId(SourceVersionId sourceVersionId, SourceAnchor anchor) {
    final digest = sha256
        .convert(
          utf8.encode(
            '${sourceVersionId.value}\u0000${anchor.startOffset}\u0000'
            '${anchor.endOffset}\u0000${anchor.pageNumber ?? -1}',
          ),
        )
        .toString();
    return RetentionScheduleId('rs_${digest.substring(0, 32)}');
  }

  static Future<RetentionScheduleRecord> _upsertRetentionSchedule(
    DatabaseExecutor executor, {
    required String learnerId,
    required MaterialId materialId,
    required SourceVersionId sourceVersionId,
    required SourceAnchor sourceAnchor,
    required RetentionEvidenceKind evidenceKind,
    required RetentionOutcomeBand outcomeBand,
    required String eventId,
    required DateTime occurredAt,
  }) async {
    final scheduleId = _retentionScheduleId(sourceVersionId, sourceAnchor);
    final rows = await executor.query(
      'retention_schedules',
      where: 'learner_id = ? AND retention_schedule_id = ? AND invalidated_at_utc IS NULL',
      whereArgs: [learnerId, scheduleId.value],
      limit: 1,
    );
    final existing = rows.isEmpty ? null : _retentionFromRow(rows.single);
    final next = RetentionPolicy.advance(
      existing: existing,
      id: scheduleId,
      materialId: materialId,
      sourceVersionId: sourceVersionId,
      sourceAnchor: sourceAnchor,
      evidenceKind: evidenceKind,
      outcomeBand: outcomeBand,
      eventId: eventId,
      occurredAt: occurredAt.toUtc(),
    );
    await executor.insert('retention_schedules', {
      'learner_id': learnerId,
      'retention_schedule_id': next.id.value,
      'material_id': next.materialId.value,
      'source_version_id': next.sourceVersionId.value,
      'source_start': next.sourceAnchor.startOffset,
      'source_end': next.sourceAnchor.endOffset,
      'page_number': next.sourceAnchor.pageNumber,
      'latest_evidence_kind': next.latestEvidenceKind.name,
      'latest_outcome_band': next.latestOutcomeBand.name,
      'latest_event_id': next.latestEventId,
      'reason_code': next.reasonCode,
      'review_count': next.reviewCount,
      'success_streak': next.successStreak,
      'interval_seconds': next.interval.inSeconds,
      'due_at_utc': next.dueAt.toUtc().toIso8601String(),
      'last_reviewed_at_utc': next.lastReviewedAt.toUtc().toIso8601String(),
      'policy_version': next.policyVersion,
      'invalidated_at_utc': null,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return next;
  }

  static RetentionScheduleRecord _retentionFromRow(Map<String, Object?> row) {
    return RetentionScheduleRecord(
      id: RetentionScheduleId(row['retention_schedule_id']! as String),
      materialId: MaterialId(row['material_id']! as String),
      sourceVersionId: SourceVersionId(row['source_version_id']! as String),
      sourceAnchor: SourceAnchor(
        startOffset: row['source_start']! as int,
        endOffset: row['source_end']! as int,
        pageNumber: row['page_number'] as int?,
      ),
      latestEvidenceKind: RetentionEvidenceKind.values.byName(row['latest_evidence_kind']! as String),
      latestOutcomeBand: RetentionOutcomeBand.values.byName(row['latest_outcome_band']! as String),
      latestEventId: row['latest_event_id']! as String,
      reasonCode: row['reason_code']! as String,
      reviewCount: row['review_count']! as int,
      successStreak: row['success_streak']! as int,
      interval: Duration(seconds: row['interval_seconds']! as int),
      dueAt: DateTime.parse(row['due_at_utc']! as String).toUtc(),
      lastReviewedAt: DateTime.parse(row['last_reviewed_at_utc']! as String).toUtc(),
      policyVersion: row['policy_version']! as String,
    );
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
      throw const SourceStoreConflict('Source version does not belong to the material being persisted.');
    }
    if (extractedContent.sourceVersionId != sourceVersion.identity.sourceVersionId) {
      throw const SourceStoreConflict('Extracted content does not belong to the source version.');
    }
    if (extractedContent.sourceContentDigest != sourceVersion.identity.contentDigest) {
      throw const SourceStoreConflict('Extracted content digest does not match the source version.');
    }
    if (sourceVersion.mediaType == SourceMediaType.pdf && (rawSourceBytes == null || rawSourceBytes.isEmpty)) {
      throw const SourceStoreConflict('PDF source bytes are required for durable source authority.');
    }
    if (sourceVersion.mediaType == SourceMediaType.pastedText && rawSourceBytes != null) {
      throw const SourceStoreConflict('Pasted text must not carry a parallel raw binary source.');
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
      'anchors_json': jsonEncode(record.anchors.map((anchor) => anchor.toJson()).toList(growable: false)),
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
      lifecycleStatus: MaterialLifecycleStatus.values.byName(row['lifecycle_status']! as String),
      processingState: MaterialProcessingState.values.byName(row['processing_state']! as String),
      currentSourceVersionId: row['current_source_version_id'] == null
          ? null
          : SourceVersionId(row['current_source_version_id']! as String),
      createdAt: DateTime.parse(row['created_at_utc']! as String).toUtc(),
      updatedAt: DateTime.parse(row['updated_at_utc']! as String).toUtc(),
      deletedAt: row['deleted_at_utc'] == null ? null : DateTime.parse(row['deleted_at_utc']! as String).toUtc(),
    );
  }

  static SourceVersionRecord _sourceFromRow(Map<String, Object?> row) {
    return SourceVersionRecord(
      identity: SourceVersionIdentity(
        materialId: MaterialId(row['material_id']! as String),
        sourceVersionId: SourceVersionId(row['source_version_id']! as String),
        contentDigest: row['content_digest']! as String,
        trustClass: SourceTrustClass.values.byName(row['trust_class']! as String),
        knowledgeClass: SourceKnowledgeClass.values.byName(row['knowledge_class']! as String),
      ),
      mediaType: SourceMediaType.values.byName(row['media_type']! as String),
      sourceName: row['source_name']! as String,
      mimeType: row['mime_type']! as String,
      byteSize: row['byte_size']! as int,
      inlineText: row['inline_text'] as String?,
      createdAt: DateTime.parse(row['created_at_utc']! as String).toUtc(),
      supersededBy: row['superseded_by'] == null ? null : SourceVersionId(row['superseded_by']! as String),
      revokedAt: row['revoked_at_utc'] == null ? null : DateTime.parse(row['revoked_at_utc']! as String).toUtc(),
    );
  }

  static ExtractedContentRecord _extractedFromRow(Map<String, Object?> row) {
    final anchorsJson = jsonDecode(row['anchors_json']! as String) as List;
    final warningsJson = jsonDecode(row['warnings_json']! as String) as List;
    return ExtractedContentRecord(
      id: ExtractedContentId(row['extracted_content_id']! as String),
      sourceVersionId: SourceVersionId(row['source_version_id']! as String),
      normalizedText: row['normalized_text']! as String,
      method: row['method']! as String,
      methodVersion: row['method_version']! as String,
      anchors: anchorsJson
          .map((value) => SourceAnchor.fromJson(Map<String, Object?>.from(value as Map)))
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

class SqliteLearningTruthStore implements LearningTruthStore {
  SqliteLearningTruthStore._(this._database);

  final Database _database;

  @override
  Future<RecallAction> persistRecallAction({required AuthenticatedLearner learner, required RecallAction action}) {
    return _database.transaction((transaction) async {
      final authorityRows = await transaction.rawQuery(
        '''
SELECT 1
FROM materials m
JOIN source_versions s
  ON s.learner_id = m.learner_id
 AND s.source_version_id = m.current_source_version_id
JOIN extracted_contents e
  ON e.learner_id = s.learner_id
 AND e.source_version_id = s.source_version_id
WHERE m.learner_id = ?
  AND m.material_id = ?
  AND m.lifecycle_status = ?
  AND m.deleted_at_utc IS NULL
  AND s.source_version_id = ?
  AND s.revoked_at_utc IS NULL
  AND e.extracted_content_id = ?
  AND e.invalidated_at_utc IS NULL
LIMIT 1
''',
        [
          learner.id.value,
          action.materialId.value,
          MaterialLifecycleStatus.active.name,
          action.sourceVersionId.value,
          action.extractedContentId.value,
        ],
      );
      if (authorityRows.isEmpty) {
        throw const LearningTruthConflict('Recall action does not point at current authoritative source truth.');
      }

      final existingRows = await transaction.query(
        'recall_actions',
        where: 'learner_id = ? AND action_id = ?',
        whereArgs: [learner.id.value, action.id.value],
        limit: 1,
      );
      if (existingRows.isNotEmpty) {
        final existing = _actionFromRow(existingRows.single);
        if (!_sameAction(existing, action)) {
          throw const LearningTruthConflict('Recall action ID replay conflicts with existing action truth.');
        }
        return existing;
      }

      await transaction.insert(
        'recall_actions',
        _actionToRow(learner: learner, action: action),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      return action;
    });
  }

  @override
  Future<RecallAction?> recallAction({required AuthenticatedLearner learner, required RecallActionId actionId}) async {
    final rows = await _database.query(
      'recall_actions',
      where: 'learner_id = ? AND action_id = ?',
      whereArgs: [learner.id.value, actionId.value],
      limit: 1,
    );
    return rows.isEmpty ? null : _actionFromRow(rows.single);
  }

  @override
  Future<LearnerEvidence?> evidenceForAttempt({
    required AuthenticatedLearner learner,
    required RecallAttemptId attemptId,
  }) async {
    final rows = await _database.query(
      'learner_evidence',
      where: 'learner_id = ? AND attempt_id = ?',
      whereArgs: [learner.id.value, attemptId.value],
      limit: 1,
    );
    return rows.isEmpty ? null : _evidenceFromRow(rows.single);
  }

  @override
  Future<ActiveRecallAttempt> openRecallAttempt({
    required AuthenticatedLearner learner,
    required RecallActionId actionId,
    required RecallAttemptId proposedAttemptId,
    required DateTime openedAt,
  }) {
    return _database.transaction((transaction) async {
      final actionRows = await transaction.query(
        'recall_actions',
        where: 'learner_id = ? AND action_id = ?',
        whereArgs: [learner.id.value, actionId.value],
        limit: 1,
      );
      if (actionRows.isEmpty) {
        throw const LearningTruthConflict('Active attempt cannot reference a missing recall action.');
      }
      final action = _actionFromRow(actionRows.single);

      final authorityRows = await transaction.query(
        'materials',
        columns: ['current_source_version_id'],
        where:
            'learner_id = ? AND material_id = ? AND lifecycle_status = ? '
            'AND deleted_at_utc IS NULL',
        whereArgs: [learner.id.value, action.materialId.value, MaterialLifecycleStatus.active.name],
        limit: 1,
      );
      if (authorityRows.isEmpty || authorityRows.single['current_source_version_id'] != action.sourceVersionId.value) {
        throw const LearningTruthConflict('Active attempt cannot attach to a stale recall action.');
      }

      final existingRows = await transaction.query(
        'active_recall_attempts',
        where: 'learner_id = ? AND material_id = ?',
        whereArgs: [learner.id.value, action.materialId.value],
        limit: 1,
      );
      if (existingRows.isNotEmpty) {
        final existing = _activeAttemptFromRow(existingRows.single);
        if (existing.actionId != action.id || existing.sourceVersionId != action.sourceVersionId) {
          throw const LearningTruthConflict(
            'Existing active Recall attempt is stale or conflicts with the current action.',
          );
        }
        return existing;
      }

      await transaction.insert('active_recall_attempts', {
        'learner_id': learner.id.value,
        'material_id': action.materialId.value,
        'source_version_id': action.sourceVersionId.value,
        'action_id': action.id.value,
        'attempt_id': proposedAttemptId.value,
        'opened_at_utc': openedAt.toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.abort);
      return ActiveRecallAttempt(
        attemptId: proposedAttemptId,
        actionId: action.id,
        materialId: action.materialId,
        sourceVersionId: action.sourceVersionId,
        openedAt: openedAt.toUtc(),
      );
    });
  }

  @override
  Future<RecallAssistance> registerAssistance({
    required AuthenticatedLearner learner,
    required RecallAttemptId attemptId,
    required RecallActionId actionId,
    required RecallAssistance assistance,
    required DateTime recordedAt,
  }) {
    if (assistance == RecallAssistance.none) {
      throw const LearningTruthConflict('Only actual support exposure can be registered.');
    }
    return _database.transaction((transaction) async {
      final evidenceRows = await transaction.query(
        'learner_evidence',
        where: 'learner_id = ? AND attempt_id = ?',
        whereArgs: [learner.id.value, attemptId.value],
        limit: 1,
      );
      if (evidenceRows.isNotEmpty) {
        throw const LearningTruthConflict('Support cannot be changed after learner evidence is recorded.');
      }

      final actionRows = await transaction.query(
        'recall_actions',
        where: 'learner_id = ? AND action_id = ?',
        whereArgs: [learner.id.value, actionId.value],
        limit: 1,
      );
      if (actionRows.isEmpty) {
        throw const LearningTruthConflict('Support cannot attach to a missing recall action.');
      }
      final action = _actionFromRow(actionRows.single);

      final activeRows = await transaction.query(
        'active_recall_attempts',
        where: 'learner_id = ? AND material_id = ?',
        whereArgs: [learner.id.value, action.materialId.value],
        limit: 1,
      );
      if (activeRows.isEmpty) {
        throw const LearningTruthConflict('Support requires an active Recall attempt.');
      }
      final active = _activeAttemptFromRow(activeRows.single);
      if (active.attemptId != attemptId ||
          active.actionId != action.id ||
          active.sourceVersionId != action.sourceVersionId) {
        throw const LearningTruthConflict('Support does not match the active Recall attempt.');
      }

      final existingRows = await transaction.query(
        'recall_attempt_support',
        where: 'learner_id = ? AND attempt_id = ?',
        whereArgs: [learner.id.value, attemptId.value],
        limit: 1,
      );
      var canonical = assistance;
      if (existingRows.isNotEmpty) {
        final existingActionId = existingRows.single['action_id']! as String;
        if (existingActionId != actionId.value) {
          throw const LearningTruthConflict('Attempt support cannot move between recall actions.');
        }
        final existing = RecallAssistance.values.byName(existingRows.single['assistance']! as String);
        canonical = _strongerAssistance(existing, assistance);
      }

      await transaction.rawInsert(
        '''
INSERT INTO recall_attempt_support (
  learner_id, attempt_id, action_id, assistance, updated_at_utc
) VALUES (?, ?, ?, ?, ?)
ON CONFLICT(learner_id, attempt_id) DO UPDATE SET
  assistance = excluded.assistance,
  updated_at_utc = excluded.updated_at_utc
''',
        [learner.id.value, attemptId.value, actionId.value, canonical.name, recordedAt.toUtc().toIso8601String()],
      );
      return canonical;
    });
  }

  @override
  Future<RecallAssistance> assistanceForAttempt({
    required AuthenticatedLearner learner,
    required RecallAttemptId attemptId,
    required RecallActionId actionId,
  }) async {
    final rows = await _database.query(
      'recall_attempt_support',
      where: 'learner_id = ? AND attempt_id = ?',
      whereArgs: [learner.id.value, attemptId.value],
      limit: 1,
    );
    if (rows.isEmpty) {
      return RecallAssistance.none;
    }
    if (rows.single['action_id'] != actionId.value) {
      throw const LearningTruthConflict('Attempt support belongs to a different recall action.');
    }
    return RecallAssistance.values.byName(rows.single['assistance']! as String);
  }

  @override
  Future<List<LearnerEvidence>> evidenceForMaterial({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    required SourceVersionId sourceVersionId,
  }) async {
    final rows = await _database.query(
      'learner_evidence',
      where: 'learner_id = ? AND material_id = ? AND source_version_id = ?',
      whereArgs: [learner.id.value, materialId.value, sourceVersionId.value],
      orderBy: 'created_at_utc ASC, evidence_id ASC',
    );
    return rows.map(_evidenceFromRow).toList(growable: false);
  }

  @override
  Future<LearnerState?> learnerState({required AuthenticatedLearner learner, required MaterialId materialId}) async {
    final rows = await _database.query(
      'learner_states',
      where: 'learner_id = ? AND material_id = ?',
      whereArgs: [learner.id.value, materialId.value],
      limit: 1,
    );
    return rows.isEmpty ? null : _stateFromRow(rows.single);
  }

  @override
  Future<NextLearningAction?> nextLearningAction({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  }) async {
    final rows = await _database.query(
      'next_learning_actions',
      where: 'learner_id = ? AND material_id = ?',
      whereArgs: [learner.id.value, materialId.value],
      limit: 1,
    );
    return rows.isEmpty ? null : _nextActionFromRow(rows.single);
  }

  @override
  Future<PersistedLearningTruth> persistEvidenceStateAndNextAction({
    required AuthenticatedLearner learner,
    required LearnerEvidence evidence,
    required RecallResponseDisposition disposition,
    required String normalizedResponse,
    required RecallStateKind stateKind,
    required String stateRuleVersion,
    required NextLearningAction nextAction,
  }) {
    if (nextAction.materialId != evidence.materialId ||
        nextAction.sourceVersionId != evidence.sourceVersionId ||
        nextAction.latestEvidenceId != evidence.id) {
      throw const LearningTruthConflict('Next action lineage does not match the evidence transition.');
    }

    return _database.transaction((transaction) async {
      final actionRows = await transaction.query(
        'recall_actions',
        where: 'learner_id = ? AND action_id = ?',
        whereArgs: [learner.id.value, evidence.actionId.value],
        limit: 1,
      );
      if (actionRows.isEmpty) {
        throw const LearningTruthConflict('Evidence cannot reference a missing recall action.');
      }
      final action = _actionFromRow(actionRows.single);
      if (action.materialId != evidence.materialId ||
          action.sourceVersionId != evidence.sourceVersionId ||
          action.extractedContentId != evidence.extractedContentId) {
        throw const LearningTruthConflict('Evidence provenance does not match its recall action.');
      }

      final supportRows = await transaction.query(
        'recall_attempt_support',
        where: 'learner_id = ? AND attempt_id = ?',
        whereArgs: [learner.id.value, evidence.attemptId.value],
        limit: 1,
      );
      var canonicalAssistance = RecallAssistance.none;
      if (supportRows.isNotEmpty) {
        if (supportRows.single['action_id'] != evidence.actionId.value) {
          throw const LearningTruthConflict('Attempt support does not belong to the evidence action.');
        }
        canonicalAssistance = RecallAssistance.values.byName(supportRows.single['assistance']! as String);
      }
      if (canonicalAssistance != evidence.assistance) {
        throw const LearningTruthConflict('Learner evidence assistance does not match canonical support history.');
      }

      final canonicalOutcome = RecallTruthPolicy.evaluate(
        expectedAnswer: action.expectedAnswer,
        response: normalizedResponse,
        disposition: disposition,
        assistance: canonicalAssistance,
      );
      final canonicalResponseDigest = sha256.convert(utf8.encode(normalizedResponse)).toString();
      if (canonicalOutcome != evidence.outcome ||
          canonicalResponseDigest != evidence.responseDigest ||
          normalizedResponse.length != evidence.responseLength ||
          evidence.ruleVersion != RecallTruthPolicy.evidenceRuleVersion) {
        throw const LearningTruthConflict('Learner evidence does not match canonical Recall evaluation.');
      }
      final canonicalStateKind = RecallTruthPolicy.stateForOutcome(canonicalOutcome);
      final canonicalNextAction = RecallTruthPolicy.nextActionFor(
        materialId: evidence.materialId,
        sourceVersionId: evidence.sourceVersionId,
        evidenceId: evidence.id,
        outcome: canonicalOutcome,
        createdAt: evidence.createdAt,
      );
      if (stateKind != canonicalStateKind ||
          stateRuleVersion != RecallTruthPolicy.stateRuleVersion ||
          !RecallTruthPolicy.sameNextAction(nextAction, canonicalNextAction)) {
        throw const LearningTruthConflict('Derived learning state or next action does not match canonical policy.');
      }

      final authorityRows = await transaction.query(
        'materials',
        columns: ['current_source_version_id'],
        where:
            'learner_id = ? AND material_id = ? AND lifecycle_status = ? '
            'AND deleted_at_utc IS NULL',
        whereArgs: [learner.id.value, evidence.materialId.value, MaterialLifecycleStatus.active.name],
        limit: 1,
      );
      if (authorityRows.isEmpty ||
          authorityRows.single['current_source_version_id'] != evidence.sourceVersionId.value) {
        throw const LearningTruthConflict('Evidence source is no longer the current authoritative source.');
      }

      final existingRows = await transaction.query(
        'learner_evidence',
        where: 'learner_id = ? AND attempt_id = ?',
        whereArgs: [learner.id.value, evidence.attemptId.value],
        limit: 1,
      );
      if (existingRows.isNotEmpty) {
        final existing = _evidenceFromRow(existingRows.single);
        if (!_sameEvidence(existing, evidence)) {
          throw const LearningTruthConflict('Attempt ID replay conflicts with existing learner evidence.');
        }
        final stateRows = await transaction.query(
          'learner_states',
          where: 'learner_id = ? AND material_id = ?',
          whereArgs: [learner.id.value, evidence.materialId.value],
          limit: 1,
        );
        final nextRows = await transaction.query(
          'next_learning_actions',
          where: 'learner_id = ? AND material_id = ?',
          whereArgs: [learner.id.value, evidence.materialId.value],
          limit: 1,
        );
        if (stateRows.isEmpty || nextRows.isEmpty) {
          throw const LearningTruthConflict('Idempotent evidence replay found incomplete learning projection.');
        }
        return PersistedLearningTruth(
          evidence: existing,
          state: _stateFromRow(stateRows.single),
          nextAction: _nextActionFromRow(nextRows.single),
        );
      }

      final activeRows = await transaction.query(
        'active_recall_attempts',
        where: 'learner_id = ? AND material_id = ?',
        whereArgs: [learner.id.value, evidence.materialId.value],
        limit: 1,
      );
      if (activeRows.isEmpty) {
        throw const LearningTruthConflict('New learner evidence requires an active Recall attempt.');
      }
      final active = _activeAttemptFromRow(activeRows.single);
      if (active.attemptId != evidence.attemptId ||
          active.actionId != evidence.actionId ||
          active.sourceVersionId != evidence.sourceVersionId) {
        throw const LearningTruthConflict('Learner evidence does not match the active Recall attempt.');
      }

      await transaction.insert(
        'learner_evidence',
        _evidenceToRow(learner: learner, evidence: evidence),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      final countRows = await transaction.rawQuery(
        '''
SELECT COUNT(*) AS evidence_count
FROM learner_evidence
WHERE learner_id = ?
  AND material_id = ?
  AND source_version_id = ?
''',
        [learner.id.value, evidence.materialId.value, evidence.sourceVersionId.value],
      );
      final evidenceCount = countRows.single['evidence_count']! as int;
      final state = LearnerState(
        materialId: evidence.materialId,
        sourceVersionId: evidence.sourceVersionId,
        kind: stateKind,
        evidenceCount: evidenceCount,
        latestEvidenceId: evidence.id,
        ruleVersion: stateRuleVersion,
        updatedAt: evidence.createdAt,
      );

      final stateRow = {
        'source_version_id': state.sourceVersionId.value,
        'state_kind': state.kind.name,
        'evidence_count': state.evidenceCount,
        'latest_evidence_id': state.latestEvidenceId.value,
        'rule_version': state.ruleVersion,
        'updated_at_utc': state.updatedAt.toUtc().toIso8601String(),
      };
      final updatedState = await transaction.update(
        'learner_states',
        stateRow,
        where: 'learner_id = ? AND material_id = ?',
        whereArgs: [learner.id.value, state.materialId.value],
      );
      if (updatedState == 0) {
        await transaction.insert('learner_states', {
          'learner_id': learner.id.value,
          'material_id': state.materialId.value,
          ...stateRow,
        }, conflictAlgorithm: ConflictAlgorithm.abort);
      }

      final nextRow = _nextActionToRow(learner: learner, action: nextAction);
      final updatedNext = await transaction.update(
        'next_learning_actions',
        nextRow,
        where: 'learner_id = ? AND material_id = ?',
        whereArgs: [learner.id.value, nextAction.materialId.value],
      );
      if (updatedNext == 0) {
        await transaction.insert('next_learning_actions', nextRow, conflictAlgorithm: ConflictAlgorithm.abort);
      }

      await transaction.delete(
        'active_recall_attempts',
        where: 'learner_id = ? AND material_id = ? AND attempt_id = ?',
        whereArgs: [learner.id.value, evidence.materialId.value, evidence.attemptId.value],
      );

      await SqliteSourceStore._upsertRetentionSchedule(
        transaction,
        learnerId: learner.id.value,
        materialId: evidence.materialId,
        sourceVersionId: evidence.sourceVersionId,
        sourceAnchor: action.anchor,
        evidenceKind: RetentionEvidenceKind.recall,
        outcomeBand: switch (canonicalOutcome) {
          RecallOutcome.correct => RetentionOutcomeBand.independentRetrieval,
          RecallOutcome.helpedCorrect || RecallOutcome.partial => RetentionOutcomeBand.supportedRetrieval,
          RecallOutcome.incorrect => RetentionOutcomeBand.repairNeeded,
          RecallOutcome.answerExposed || RecallOutcome.unknown => RetentionOutcomeBand.unassessed,
        },
        eventId: 'recall:${evidence.id.value}',
        occurredAt: evidence.createdAt,
      );

      return PersistedLearningTruth(evidence: evidence, state: state, nextAction: nextAction);
    });
  }

  @override
  Future<LearningContinuation> repairDerivedProjection({
    required AuthenticatedLearner learner,
    required LearnerState state,
    required NextLearningAction nextAction,
  }) {
    if (nextAction.materialId != state.materialId ||
        nextAction.sourceVersionId != state.sourceVersionId ||
        nextAction.latestEvidenceId != state.latestEvidenceId) {
      throw const LearningTruthConflict('Repair projection lineage is internally inconsistent.');
    }

    return _database.transaction((transaction) async {
      final authorityRows = await transaction.query(
        'materials',
        columns: ['current_source_version_id'],
        where:
            'learner_id = ? AND material_id = ? AND lifecycle_status = ? '
            'AND deleted_at_utc IS NULL',
        whereArgs: [learner.id.value, state.materialId.value, MaterialLifecycleStatus.active.name],
        limit: 1,
      );
      if (authorityRows.isEmpty || authorityRows.single['current_source_version_id'] != state.sourceVersionId.value) {
        throw const LearningTruthConflict('Repair cannot project learning truth from a stale source version.');
      }

      final evidenceRows = await transaction.query(
        'learner_evidence',
        where: 'learner_id = ? AND evidence_id = ?',
        whereArgs: [learner.id.value, state.latestEvidenceId.value],
        limit: 1,
      );
      if (evidenceRows.isEmpty) {
        throw const LearningTruthConflict('Repair requires durable canonical learner evidence.');
      }
      final latestEvidence = _evidenceFromRow(evidenceRows.single);
      if (latestEvidence.materialId != state.materialId || latestEvidence.sourceVersionId != state.sourceVersionId) {
        throw const LearningTruthConflict('Repair evidence does not belong to the current material/source.');
      }

      final canonicalStateKind = RecallTruthPolicy.stateForOutcome(latestEvidence.outcome);
      if (state.ruleVersion != RecallTruthPolicy.stateRuleVersion ||
          state.kind != canonicalStateKind ||
          state.latestEvidenceId != latestEvidence.id ||
          state.updatedAt.toUtc() != latestEvidence.createdAt.toUtc()) {
        throw const LearningTruthConflict('Repair state does not match canonical evidence derivation.');
      }
      final canonicalNextAction = RecallTruthPolicy.nextActionFor(
        materialId: state.materialId,
        sourceVersionId: state.sourceVersionId,
        evidenceId: latestEvidence.id,
        outcome: latestEvidence.outcome,
        createdAt: latestEvidence.createdAt,
      );
      if (!RecallTruthPolicy.sameNextAction(nextAction, canonicalNextAction)) {
        throw const LearningTruthConflict('Repair next action does not match canonical evidence policy.');
      }

      final countRows = await transaction.rawQuery(
        '''
SELECT COUNT(*) AS evidence_count
FROM learner_evidence
WHERE learner_id = ?
  AND material_id = ?
  AND source_version_id = ?
''',
        [learner.id.value, state.materialId.value, state.sourceVersionId.value],
      );
      final canonicalCount = countRows.single['evidence_count']! as int;
      if (canonicalCount != state.evidenceCount) {
        throw const LearningTruthConflict('Repair state evidence count does not match canonical evidence.');
      }

      final stateRow = {
        'source_version_id': state.sourceVersionId.value,
        'state_kind': state.kind.name,
        'evidence_count': state.evidenceCount,
        'latest_evidence_id': state.latestEvidenceId.value,
        'rule_version': state.ruleVersion,
        'updated_at_utc': state.updatedAt.toUtc().toIso8601String(),
      };
      final updatedState = await transaction.update(
        'learner_states',
        stateRow,
        where: 'learner_id = ? AND material_id = ?',
        whereArgs: [learner.id.value, state.materialId.value],
      );
      if (updatedState == 0) {
        await transaction.insert('learner_states', {
          'learner_id': learner.id.value,
          'material_id': state.materialId.value,
          ...stateRow,
        }, conflictAlgorithm: ConflictAlgorithm.abort);
      }

      final nextRow = _nextActionToRow(learner: learner, action: nextAction);
      final updatedNext = await transaction.update(
        'next_learning_actions',
        nextRow,
        where: 'learner_id = ? AND material_id = ?',
        whereArgs: [learner.id.value, nextAction.materialId.value],
      );
      if (updatedNext == 0) {
        await transaction.insert('next_learning_actions', nextRow, conflictAlgorithm: ConflictAlgorithm.abort);
      }

      return LearningContinuation(state: state, nextAction: nextAction);
    });
  }

  static ActiveRecallAttempt _activeAttemptFromRow(Map<String, Object?> row) {
    return ActiveRecallAttempt(
      attemptId: RecallAttemptId(row['attempt_id']! as String),
      actionId: RecallActionId(row['action_id']! as String),
      materialId: MaterialId(row['material_id']! as String),
      sourceVersionId: SourceVersionId(row['source_version_id']! as String),
      openedAt: DateTime.parse(row['opened_at_utc']! as String).toUtc(),
    );
  }

  static RecallAssistance _strongerAssistance(RecallAssistance left, RecallAssistance right) {
    int rank(RecallAssistance value) => switch (value) {
      RecallAssistance.none => 0,
      RecallAssistance.hint => 1,
      RecallAssistance.answerExposed => 2,
    };
    return rank(left) >= rank(right) ? left : right;
  }

  static bool _sameAction(RecallAction left, RecallAction right) {
    return left.materialId == right.materialId &&
        left.sourceVersionId == right.sourceVersionId &&
        left.extractedContentId == right.extractedContentId &&
        left.promptText == right.promptText &&
        left.expectedAnswer == right.expectedAnswer &&
        left.anchor.startOffset == right.anchor.startOffset &&
        left.anchor.endOffset == right.anchor.endOffset &&
        left.anchor.pageNumber == right.anchor.pageNumber &&
        left.ruleVersion == right.ruleVersion;
  }

  static bool _sameEvidence(LearnerEvidence left, LearnerEvidence right) {
    return left.id == right.id &&
        left.actionId == right.actionId &&
        left.materialId == right.materialId &&
        left.sourceVersionId == right.sourceVersionId &&
        left.extractedContentId == right.extractedContentId &&
        left.outcome == right.outcome &&
        left.assistance == right.assistance &&
        left.responseDigest == right.responseDigest &&
        left.responseLength == right.responseLength &&
        left.ruleVersion == right.ruleVersion;
  }

  static Map<String, Object?> _actionToRow({required AuthenticatedLearner learner, required RecallAction action}) {
    return {
      'learner_id': learner.id.value,
      'action_id': action.id.value,
      'material_id': action.materialId.value,
      'source_version_id': action.sourceVersionId.value,
      'extracted_content_id': action.extractedContentId.value,
      'prompt_text': action.promptText,
      'expected_answer': action.expectedAnswer,
      'anchor_start': action.anchor.startOffset,
      'anchor_end': action.anchor.endOffset,
      'page_number': action.anchor.pageNumber,
      'rule_version': action.ruleVersion,
      'created_at_utc': action.createdAt.toUtc().toIso8601String(),
    };
  }

  static Map<String, Object?> _evidenceToRow({
    required AuthenticatedLearner learner,
    required LearnerEvidence evidence,
  }) {
    return {
      'learner_id': learner.id.value,
      'evidence_id': evidence.id.value,
      'attempt_id': evidence.attemptId.value,
      'action_id': evidence.actionId.value,
      'material_id': evidence.materialId.value,
      'source_version_id': evidence.sourceVersionId.value,
      'extracted_content_id': evidence.extractedContentId.value,
      'outcome': evidence.outcome.name,
      'assistance': evidence.assistance.name,
      'help_used': evidence.helpUsed ? 1 : 0,
      'response_digest': evidence.responseDigest,
      'response_length': evidence.responseLength,
      'rule_version': evidence.ruleVersion,
      'created_at_utc': evidence.createdAt.toUtc().toIso8601String(),
    };
  }

  static Map<String, Object?> _nextActionToRow({
    required AuthenticatedLearner learner,
    required NextLearningAction action,
  }) {
    return {
      'learner_id': learner.id.value,
      'material_id': action.materialId.value,
      'source_version_id': action.sourceVersionId.value,
      'latest_evidence_id': action.latestEvidenceId.value,
      'action_kind': action.kind.name,
      'reason_code': action.reasonCode,
      'reason_text': action.reasonText,
      'policy_version': action.policyVersion,
      'created_at_utc': action.createdAt.toUtc().toIso8601String(),
    };
  }

  static RecallAction _actionFromRow(Map<String, Object?> row) {
    return RecallAction(
      id: RecallActionId(row['action_id']! as String),
      materialId: MaterialId(row['material_id']! as String),
      sourceVersionId: SourceVersionId(row['source_version_id']! as String),
      extractedContentId: ExtractedContentId(row['extracted_content_id']! as String),
      promptText: row['prompt_text']! as String,
      expectedAnswer: row['expected_answer']! as String,
      anchor: SourceAnchor(
        startOffset: row['anchor_start']! as int,
        endOffset: row['anchor_end']! as int,
        pageNumber: row['page_number'] as int?,
      ),
      ruleVersion: row['rule_version']! as String,
      createdAt: DateTime.parse(row['created_at_utc']! as String).toUtc(),
    );
  }

  static LearnerEvidence _evidenceFromRow(Map<String, Object?> row) {
    final assistance = row['assistance'] == null
        ? ((row['help_used']! as int) == 1 ? RecallAssistance.hint : RecallAssistance.none)
        : RecallAssistance.values.byName(row['assistance']! as String);
    return LearnerEvidence(
      id: LearnerEvidenceId(row['evidence_id']! as String),
      attemptId: RecallAttemptId(row['attempt_id']! as String),
      actionId: RecallActionId(row['action_id']! as String),
      materialId: MaterialId(row['material_id']! as String),
      sourceVersionId: SourceVersionId(row['source_version_id']! as String),
      extractedContentId: ExtractedContentId(row['extracted_content_id']! as String),
      outcome: RecallOutcome.values.byName(row['outcome']! as String),
      assistance: assistance,
      responseDigest: row['response_digest']! as String,
      responseLength: row['response_length']! as int,
      ruleVersion: row['rule_version']! as String,
      createdAt: DateTime.parse(row['created_at_utc']! as String).toUtc(),
    );
  }

  static LearnerState _stateFromRow(Map<String, Object?> row) {
    return LearnerState(
      materialId: MaterialId(row['material_id']! as String),
      sourceVersionId: SourceVersionId(row['source_version_id']! as String),
      kind: RecallStateKind.values.byName(row['state_kind']! as String),
      evidenceCount: row['evidence_count']! as int,
      latestEvidenceId: LearnerEvidenceId(row['latest_evidence_id']! as String),
      ruleVersion: row['rule_version']! as String,
      updatedAt: DateTime.parse(row['updated_at_utc']! as String).toUtc(),
    );
  }

  static NextLearningAction _nextActionFromRow(Map<String, Object?> row) {
    return NextLearningAction(
      materialId: MaterialId(row['material_id']! as String),
      sourceVersionId: SourceVersionId(row['source_version_id']! as String),
      latestEvidenceId: LearnerEvidenceId(row['latest_evidence_id']! as String),
      kind: NextLearningActionKind.values.byName(row['action_kind']! as String),
      reasonCode: row['reason_code']! as String,
      reasonText: row['reason_text']! as String,
      policyVersion: row['policy_version']! as String,
      createdAt: DateTime.parse(row['created_at_utc']! as String).toUtc(),
    );
  }
}

class SqliteOperationalTelemetry implements OperationalTelemetry {
  SqliteOperationalTelemetry._(this._database);

  final Database _database;

  @override
  Future<void> record({required AuthenticatedLearner learner, required OperationalEvent event}) async {
    await _database.insert('operational_events', {
      'learner_id': learner.id.value,
      'schema_version': event.schemaVersion,
      'event_type': event.type.name,
      'phase': event.phase.name,
      'material_id': event.materialId?.value,
      'source_version_id': event.sourceVersionId?.value,
      'action_id': event.actionId?.value,
      'attempt_id': event.attemptId?.value,
      'evidence_id': event.evidenceId?.value,
      'outcome': event.outcome?.name,
      'state_kind': event.stateKind?.name,
      'reason_code': event.reasonCode,
      'rule_version': event.ruleVersion,
      'policy_version': event.policyVersion,
      'duration_ms': event.durationMs,
      'error_class': event.errorClass,
      'created_at_utc': event.createdAt.toUtc().toIso8601String(),
    });
  }

  @override
  Future<List<OperationalEvent>> events({required AuthenticatedLearner learner}) async {
    final rows = await _database.query(
      'operational_events',
      where: 'learner_id = ?',
      whereArgs: [learner.id.value],
      orderBy: 'id ASC',
    );
    return rows
        .map((row) {
          return OperationalEvent(
            schemaVersion: (row['schema_version'] as int?) ?? 1,
            type: OperationalEventType.values.byName(row['event_type']! as String),
            phase: OperationalEventPhase.values.byName(row['phase']! as String),
            materialId: row['material_id'] == null ? null : MaterialId(row['material_id']! as String),
            sourceVersionId: row['source_version_id'] == null
                ? null
                : SourceVersionId(row['source_version_id']! as String),
            actionId: row['action_id'] == null ? null : RecallActionId(row['action_id']! as String),
            attemptId: row['attempt_id'] == null ? null : RecallAttemptId(row['attempt_id']! as String),
            evidenceId: row['evidence_id'] == null ? null : LearnerEvidenceId(row['evidence_id']! as String),
            outcome: row['outcome'] == null ? null : RecallOutcome.values.byName(row['outcome']! as String),
            stateKind: row['state_kind'] == null ? null : RecallStateKind.values.byName(row['state_kind']! as String),
            reasonCode: row['reason_code'] as String?,
            ruleVersion: row['rule_version'] as String?,
            policyVersion: row['policy_version'] as String?,
            durationMs: row['duration_ms'] as int?,
            errorClass: row['error_class'] as String?,
            createdAt: DateTime.parse(row['created_at_utc']! as String).toUtc(),
          );
        })
        .toList(growable: false);
  }
}

class CachedSummaryResult {
  const CachedSummaryResult({required this.summary, required this.keyPoints, required this.cachedAt});

  final String summary;
  final List<String> keyPoints;
  final DateTime cachedAt;
}
