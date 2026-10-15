import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/analytics/product_analytics.dart';
import 'package:sesli_ogren/src/analytics/product_analytics_gateway.dart';
import 'package:sesli_ogren/src/analytics/product_analytics_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/domain/authenticated_learner.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeAnalyticsGateway implements ProductAnalyticsGateway {
  bool unavailable = false;
  final List<ProductAnalyticsEnvelope> sent = [];

  @override
  Future<void> record({
    required AuthenticatedLearner learner,
    required ProductAnalyticsEnvelope envelope,
    String? serverMaterialId,
  }) async {
    if (unavailable) {
      throw const ProductAnalyticsGatewayException('offline');
    }
    sent.add(envelope);
  }
}

void main() {
  sqfliteFfiInit();

  test('guest analytics stays durable and never calls the remote gateway', () async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final gateway = _FakeAnalyticsGateway();
    final analytics = ProductAnalyticsService(store: store, gateway: gateway, sessionId: 'session_guest_test_0001');

    await analytics.record(
      learner: const AuthenticatedLearner.local(),
      event: ProductAnalyticsEvent(
        type: ProductAnalyticsEventType.readerSession,
        phase: ProductAnalyticsPhase.completed,
        createdAt: DateTime.utc(2026, 10, 15, 9),
        materialId: const MaterialId('material_guest_analytics'),
        surface: ProductAnalyticsSurface.reader,
        capability: ProductAnalyticsCapability.reader,
        outcomeClass: 'completed',
        durationMs: 1200,
        quantity: 1,
      ),
    );

    final stored = await store.productAnalyticsEvents(learner: const AuthenticatedLearner.local());
    expect(stored, hasLength(1));
    expect(stored.single.event.type, ProductAnalyticsEventType.readerSession);
    expect(stored.single.event.materialId, const MaterialId('material_guest_analytics'));
    expect(gateway.sent, isEmpty);

    await analytics.flush(learner: const AuthenticatedLearner.local());
    expect(gateway.sent, isEmpty);
  });

  test('authenticated analytics keeps an offline event pending and flushes it exactly once after recovery', () async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final gateway = _FakeAnalyticsGateway()..unavailable = true;
    final analytics = ProductAnalyticsService(store: store, gateway: gateway, sessionId: 'session_auth_test_000001');
    const learner = AuthenticatedLearner(id: LearnerId('analytics-auth-learner'));

    await analytics.record(
      learner: learner,
      event: ProductAnalyticsEvent(
        type: ProductAnalyticsEventType.recallAttempt,
        phase: ProductAnalyticsPhase.completed,
        createdAt: DateTime.utc(2026, 10, 15, 10),
        materialId: const MaterialId('material_auth_analytics'),
        sourceVersionId: const SourceVersionId('source_auth_analytics'),
        surface: ProductAnalyticsSurface.recall,
        capability: ProductAnalyticsCapability.recall,
        outcomeClass: 'correct',
        reasonCode: 'next_useful_action',
        durationMs: 800,
        quantity: 1,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    var pending = await store.pendingProductAnalyticsEvents(learner: learner);
    expect(pending, hasLength(1));
    expect(gateway.sent, isEmpty);

    gateway.unavailable = false;
    await analytics.flush(learner: learner);
    pending = await store.pendingProductAnalyticsEvents(learner: learner);
    expect(pending, isEmpty);
    expect(gateway.sent, hasLength(1));

    await analytics.flush(learner: learner);
    expect(gateway.sent, hasLength(1));
  });

  test('privacy-invalid free-form metadata is dropped before durable analytics storage', () async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final analytics = ProductAnalyticsService(
      store: store,
      gateway: _FakeAnalyticsGateway(),
      sessionId: 'session_privacy_test_01',
    );
    const learner = AuthenticatedLearner.local();

    await analytics.record(
      learner: learner,
      event: ProductAnalyticsEvent(
        type: ProductAnalyticsEventType.sourceIngest,
        phase: ProductAnalyticsPhase.failed,
        createdAt: DateTime.utc(2026, 10, 15, 11),
        surface: ProductAnalyticsSurface.sourceEditor,
        capability: ProductAnalyticsCapability.sourceProcessing,
        reasonCode: 'this contains raw learner text and spaces',
      ),
    );

    expect(await store.productAnalyticsEvents(learner: learner), isEmpty);
  });

  test('account purge removes the local analytics outbox for that learner only', () async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final analytics = ProductAnalyticsService(
      store: store,
      gateway: _FakeAnalyticsGateway()..unavailable = true,
      sessionId: 'session_delete_test_001',
    );
    const owner = AuthenticatedLearner(id: LearnerId('analytics-delete-owner'));
    const other = AuthenticatedLearner(id: LearnerId('analytics-delete-other'));

    for (final learner in [owner, other]) {
      await analytics.record(
        learner: learner,
        event: ProductAnalyticsEvent(
          type: ProductAnalyticsEventType.materialOpened,
          phase: ProductAnalyticsPhase.completed,
          createdAt: DateTime.utc(2026, 10, 15, 12),
          materialId: const MaterialId('material_delete_test'),
          surface: ProductAnalyticsSurface.workspace,
          quantity: 1,
        ),
      );
    }
    await Future<void>.delayed(Duration.zero);

    await store.purgeLearnerData(learner: owner);

    expect(await store.productAnalyticsEvents(learner: owner), isEmpty);
    expect(await store.productAnalyticsEvents(learner: other), hasLength(1));
  });
}
