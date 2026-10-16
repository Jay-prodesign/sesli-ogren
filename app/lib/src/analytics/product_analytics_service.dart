import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../data/sqlite_source_store.dart';
import '../domain/authenticated_learner.dart';
import 'product_analytics.dart';
import 'product_analytics_gateway.dart';

class ProductAnalyticsService implements ProductAnalytics {
  ProductAnalyticsService({
    required this.store,
    required this.gateway,
    required this.sessionId,
    this.environment = 'test',
    this.appVersion,
    this.platform,
    this.locale,
  });

  factory ProductAnalyticsService.forRuntime({
    required SqliteSourceStore store,
    required ProductAnalyticsGateway gateway,
    String environment = 'production',
    String? appVersion,
    String? platform,
    String? locale,
    DateTime Function()? now,
  }) {
    final clock = now ?? DateTime.now;
    final seed = '${clock().toUtc().microsecondsSinceEpoch}:${identityHashCode(store)}';
    final digest = sha256.convert(utf8.encode(seed)).toString();
    return ProductAnalyticsService(
      store: store,
      gateway: gateway,
      sessionId: 'session_${digest.substring(0, 32)}',
      environment: environment,
      appVersion: appVersion,
      platform: platform,
      locale: locale,
    );
  }

  final SqliteSourceStore store;
  final ProductAnalyticsGateway gateway;
  final String environment;
  final String? appVersion;
  final String? platform;
  final String? locale;

  @override
  final String sessionId;

  int _sequence = 0;
  bool _flushing = false;

  @override
  Future<void> record({required AuthenticatedLearner learner, required ProductAnalyticsEvent event}) async {
    if (!_privacySafe(event)) return;

    try {
      final envelope = ProductAnalyticsEnvelope(
        eventId: _eventId(learner, event),
        sessionId: sessionId,
        environment: environment,
        appVersion: appVersion,
        platform: platform,
        locale: locale,
        event: event,
      );
      await store.enqueueProductAnalyticsEvent(learner: learner, envelope: envelope);
      if (learner.isAuthenticated) {
        unawaited(flush(learner: learner));
      }
    } catch (_) {
      // Analytics is evidence about the product, never product authority.
      // Local study must remain available even if instrumentation storage fails.
    }
  }

  @override
  Future<void> flush({required AuthenticatedLearner learner}) async {
    if (!learner.isAuthenticated || _flushing) return;
    _flushing = true;
    try {
      final pending = await store.pendingProductAnalyticsEvents(learner: learner, limit: 100);
      for (final envelope in pending) {
        try {
          final event = envelope.event;
          final serverMaterialId = event.materialId == null
              ? null
              : await store.summaryServerMaterialId(
                  learner: learner,
                  materialId: event.materialId!,
                  sourceVersionId: event.sourceVersionId,
                );
          await gateway.record(learner: learner, envelope: envelope, serverMaterialId: serverMaterialId);
          await store.markProductAnalyticsEventSynced(
            learner: learner,
            eventId: envelope.eventId,
            syncedAt: DateTime.now().toUtc(),
          );
        } catch (_) {
          // Preserve ordering and retry the unsent suffix on the next safe
          // opportunity. Never spin through an offline queue.
          break;
        }
      }
    } catch (_) {
      // A telemetry flush failure cannot interrupt learning.
    } finally {
      _flushing = false;
    }
  }

  String _eventId(AuthenticatedLearner learner, ProductAnalyticsEvent event) {
    final sequence = _sequence++;
    final seed =
        '${learner.id.value}|$sessionId|${event.createdAt.toUtc().microsecondsSinceEpoch}|'
        '${event.name.wireValue}|${event.phase?.name ?? 'none'}|$sequence';
    final digest = sha256.convert(utf8.encode(seed)).toString();
    return 'evt_${digest.substring(0, 40)}';
  }

  bool _privacySafe(ProductAnalyticsEvent event) {
    if (event.eventVersion != 1) return false;
    if (!const {'development', 'test', 'staging', 'production'}.contains(environment)) {
      return false;
    }
    if (event.durationMs != null && (event.durationMs! < 0 || event.durationMs! > 86400000)) {
      return false;
    }
    if (event.quantity != null && (event.quantity! < 0 || event.quantity! > 1000000000)) {
      return false;
    }
    return _safeCode(event.outcomeClass, 64) &&
        _safeCode(event.reasonCode, 96) &&
        _safeCode(event.failureClass, 96) &&
        _safeCode(event.ruleVersion, 96) &&
        _safeCode(event.policyVersion, 96);
  }

  static bool _safeCode(String? value, int maxLength) {
    if (value == null) return true;
    if (value.isEmpty || value.length > maxLength) return false;
    return RegExp(r'^[A-Za-z0-9_.:-]+$').hasMatch(value);
  }
}
