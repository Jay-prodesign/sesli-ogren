import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/domain/authenticated_learner.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sesli_ogren/src/domain/learning_truth.dart';
import 'package:sesli_ogren/src/domain/operational_event.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('v2 database upgrades to current Recall and telemetry schema without reset', () async {
    final temp = await Directory.systemTemp.createTemp('sesli-ogren-v2-upgrade-');
    final path = '${temp.path}/upgrade.db';
    Database? legacy;
    SqliteSourceStore? upgraded;

    try {
      legacy = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, version) async {
            await db.execute('''
CREATE TABLE recall_actions (
  learner_id TEXT NOT NULL,
  action_id TEXT NOT NULL,
  PRIMARY KEY (learner_id, action_id)
)
''');
          },
        ),
      );
      await legacy.close();
      legacy = null;

      upgraded = await SqliteSourceStore.open(factory: databaseFactoryFfi, path: path);

      final assistance = await upgraded.learningTruthStore().assistanceForAttempt(
        learner: const AuthenticatedLearner(id: LearnerId('learner-upgrade')),
        attemptId: const RecallAttemptId('attempt-upgrade'),
        actionId: const RecallActionId('action-upgrade'),
      );
      expect(assistance, RecallAssistance.none);

      await upgraded.operationalTelemetry().record(
        learner: const AuthenticatedLearner(id: LearnerId('learner-upgrade')),
        event: OperationalEvent(
          type: OperationalEventType.runtimeRestore,
          phase: OperationalEventPhase.completed,
          durationMs: 1,
          createdAt: DateTime.utc(2026, 10, 4, 16),
        ),
      );
      final events = await upgraded.operationalTelemetry().events(
        learner: const AuthenticatedLearner(id: LearnerId('learner-upgrade')),
      );
      expect(events, hasLength(1));
      expect(events.single.schemaVersion, 1);
      expect(events.single.type, OperationalEventType.runtimeRestore);
      expect(events.single.durationMs, 1);
    } finally {
      await legacy?.close();
      await upgraded?.close();
      await temp.delete(recursive: true);
    }
  });

  test('v6 database upgrades durable Listen progress schema without reset', () async {
    final temp = await Directory.systemTemp.createTemp('sesli-ogren-v6-upgrade-');
    final path = '${temp.path}/upgrade.db';
    Database? legacy;
    SqliteSourceStore? upgraded;
    Database? inspected;

    try {
      legacy = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 6,
          onCreate: (db, version) async {
            await db.execute('''
CREATE TABLE source_versions (
  learner_id TEXT NOT NULL,
  source_version_id TEXT NOT NULL,
  PRIMARY KEY (learner_id, source_version_id)
)
''');
            await db.execute('''
CREATE TABLE sentinel (
  value TEXT NOT NULL
)
''');
            await db.insert('sentinel', {'value': 'preserved'});
          },
        ),
      );
      await legacy.close();
      legacy = null;

      upgraded = await SqliteSourceStore.open(factory: databaseFactoryFfi, path: path);
      await upgraded.close();
      upgraded = null;

      inspected = await databaseFactoryFfi.openDatabase(path);
      final tables = await inspected.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'");
      expect(tables.map((row) => row['name']), contains('listen_progress'));
      final sentinel = await inspected.query('sentinel');
      expect(sentinel.single['value'], 'preserved');
    } finally {
      await legacy?.close();
      await upgraded?.close();
      await inspected?.close();
      await temp.delete(recursive: true);
    }
  });

  test('v7 database upgrades learner onboarding preferences without reset', () async {
    final temp = await Directory.systemTemp.createTemp('sesli-ogren-v7-upgrade-');
    final path = '${temp.path}/upgrade.db';
    Database? legacy;
    SqliteSourceStore? upgraded;
    Database? inspected;

    try {
      legacy = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 7,
          onCreate: (db, version) async {
            await db.execute('''
CREATE TABLE sentinel (
  value TEXT NOT NULL
)
''');
            await db.insert('sentinel', {'value': 'preserved'});
          },
        ),
      );
      await legacy.close();
      legacy = null;

      upgraded = await SqliteSourceStore.open(factory: databaseFactoryFfi, path: path);
      await upgraded.close();
      upgraded = null;

      inspected = await databaseFactoryFfi.openDatabase(path);
      final tables = await inspected.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'");
      expect(tables.map((row) => row['name']), contains('learner_preferences'));
      final sentinel = await inspected.query('sentinel');
      expect(sentinel.single['value'], 'preserved');
    } finally {
      await legacy?.close();
      await upgraded?.close();
      await inspected?.close();
      await temp.delete(recursive: true);
    }
  });

  test('v5 database upgrades active Recall attempt schema without reset', () async {
    final temp = await Directory.systemTemp.createTemp('sesli-ogren-v5-upgrade-');
    final path = '${temp.path}/upgrade.db';
    Database? legacy;
    SqliteSourceStore? upgraded;
    Database? inspected;

    try {
      legacy = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 5,
          onCreate: (db, version) async {
            await db.execute('''
CREATE TABLE recall_actions (
  learner_id TEXT NOT NULL,
  action_id TEXT NOT NULL,
  PRIMARY KEY (learner_id, action_id)
)
''');
            await db.execute('''
CREATE TABLE sentinel (
  value TEXT NOT NULL
)
''');
            await db.insert('sentinel', {'value': 'preserved'});
          },
        ),
      );
      await legacy.close();
      legacy = null;

      upgraded = await SqliteSourceStore.open(factory: databaseFactoryFfi, path: path);
      await upgraded.close();
      upgraded = null;

      inspected = await databaseFactoryFfi.openDatabase(path);
      final tables = await inspected.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'");
      expect(tables.map((row) => row['name']), contains('active_recall_attempts'));
      final sentinel = await inspected.query('sentinel');
      expect(sentinel.single['value'], 'preserved');
    } finally {
      await legacy?.close();
      await upgraded?.close();
      await inspected?.close();
      await temp.delete(recursive: true);
    }
  });

  test('summary job survives reopen and respects learner and source version', () async {
    final temp = await Directory.systemTemp.createTemp('sesli-ogren-summary-job-');
    final path = '${temp.path}/summary.db';
    SqliteSourceStore? store;
    Database? database;
    const owner = AuthenticatedLearner(id: LearnerId('owner'));
    const other = AuthenticatedLearner(id: LearnerId('other'));
    const material = MaterialId('material-a');
    const sourceA = SourceVersionId('source-a');
    const sourceB = SourceVersionId('source-b');

    try {
      store = await SqliteSourceStore.open(factory: databaseFactoryFfi, path: path);
      database = await databaseFactoryFfi.openDatabase(path);
      await database.insert('materials', {
        'learner_id': 'owner',
        'material_id': 'material-a',
        'title': 'Sample',
        'media_type': 'pastedText',
        'lifecycle_status': 'active',
        'processing_state': 'ready',
        'created_at_utc': '2026-10-09T00:00:00Z',
        'updated_at_utc': '2026-10-09T00:00:00Z',
      });
      await database.close();
      database = null;

      await store.saveSummaryJob(
        learner: owner,
        materialId: material,
        sourceVersionId: sourceA,
        serverMaterialId: 'server-a',
        jobId: 'job-a',
      );
      expect(
        await store.summaryJobId(learner: owner, materialId: material, sourceVersionId: sourceA),
        'job-a',
      );
      expect(
        await store.summaryJobId(learner: other, materialId: material, sourceVersionId: sourceA),
        isNull,
      );
      expect(
        await store.summaryJobId(learner: owner, materialId: material, sourceVersionId: sourceB),
        isNull,
      );
      await store.close();
      store = null;

      store = await SqliteSourceStore.open(factory: databaseFactoryFfi, path: path);
      expect(
        await store.summaryJobId(learner: owner, materialId: material, sourceVersionId: sourceA),
        'job-a',
      );
      await store.saveSummaryJob(
        learner: owner,
        materialId: material,
        sourceVersionId: sourceB,
        serverMaterialId: 'server-b',
        jobId: 'job-b',
      );
      expect(
        await store.summaryJobId(learner: owner, materialId: material, sourceVersionId: sourceA),
        isNull,
      );
      expect(
        await store.summaryJobId(learner: owner, materialId: material, sourceVersionId: sourceB),
        'job-b',
      );
    } finally {
      await database?.close();
      await store?.close();
      await temp.delete(recursive: true);
    }
  });
}
