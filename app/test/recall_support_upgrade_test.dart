import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/domain/authenticated_learner.dart';
import 'package:sesli_ogren/src/domain/learning_truth.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('v2 database upgrades to canonical Recall support schema without reset', () async {
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

      upgraded = await SqliteSourceStore.open(
        factory: databaseFactoryFfi,
        path: path,
      );

      final assistance = await upgraded.learningTruthStore().assistanceForAttempt(
        learner: const AuthenticatedLearner(id: LearnerId('learner-upgrade')),
        attemptId: const RecallAttemptId('attempt-upgrade'),
        actionId: const RecallActionId('action-upgrade'),
      );
      expect(assistance, RecallAssistance.none);
    } finally {
      await legacy?.close();
      await upgraded?.close();
      await temp.delete(recursive: true);
    }
  });
}
