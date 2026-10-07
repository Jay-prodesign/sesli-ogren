import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/domain/authenticated_learner.dart';
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
}
