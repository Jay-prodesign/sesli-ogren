import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/app_runtime.dart';
import 'package:sesli_ogren/src/app/product_shell_screen.dart';
import 'package:sesli_ogren/src/app/living_study_desk_home.dart';
import 'package:sesli_ogren/src/continuity/cloud_continuity_gateway.dart';
import 'package:sesli_ogren/src/continuity/cloud_continuity_service.dart';
import 'package:sesli_ogren/src/continuity/passive_resume_continuity_service.dart';
import 'package:sesli_ogren/src/continuity/passive_resume_gateway.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/domain/authenticated_learner.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sesli_ogren/src/domain/passive_resume.dart';
import 'package:sesli_ogren/src/learning/recall_learning_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _UnusedPdfExtractor implements PdfTextExtractor {
  const _UnusedPdfExtractor();

  @override
  Future<ExtractedPdf> extract(Uint8List bytes, {required String sourceName}) {
    throw UnimplementedError();
  }
}

class _EmptyPassiveResumeGateway implements PassiveResumeGateway {
  const _EmptyPassiveResumeGateway();

  @override
  Future<List<PassiveResumeRemoteState>> read({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  }) async => const [];

  @override
  Future<PassiveResumeRemoteState> write({
    required AuthenticatedLearner learner,
    required PassiveResumeLocalState local,
    required int? expectedRevision,
    required String clientUpdateId,
  }) {
    throw UnimplementedError();
  }
}

class _RecoveringContinuityGateway implements CloudContinuityGateway {
  bool unavailable = true;
  int listCalls = 0;

  @override
  Future<List<CloudMaterialSnapshot>> listMaterials({required AuthenticatedLearner learner}) async {
    listCalls += 1;
    if (unavailable) {
      throw const CloudContinuityException('temporary cloud failure', kind: CloudContinuityFailureKind.unavailable);
    }
    return const [];
  }

  @override
  Future<CloudMaterialSnapshot?> readMaterial({required AuthenticatedLearner learner, required MaterialId materialId}) {
    throw UnimplementedError();
  }

  @override
  Future<CloudMaterialSnapshot> ensureTextSource({
    required AuthenticatedLearner learner,
    required SourceIngestResult source,
    SourceVersionId? expectedPreviousSourceVersionId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CloudMaterialSnapshot> ensureMediaSource({
    required AuthenticatedLearner learner,
    required SourceIngestResult source,
    required Uint8List rawSourceBytes,
    SourceVersionId? expectedPreviousSourceVersionId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Uint8List> downloadMediaSource({
    required AuthenticatedLearner learner,
    required CloudMaterialSnapshot source,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> cleanupSupersededMedia({required AuthenticatedLearner learner, required MaterialId materialId}) async {}
}

Future<AppRuntime> _runtime({
  required AuthenticatedLearner learner,
  required _RecoveringContinuityGateway gateway,
}) async {
  final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
  final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
  return AppRuntime(
    learner: learner,
    store: store,
    ingest: ingest,
    recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
    telemetry: store.operationalTelemetry(),
    continuity: CloudContinuityService(store: store, ingest: ingest, gateway: gateway),
    passiveResume: PassiveResumeContinuityService(store: store, gateway: const _EmptyPassiveResumeGateway()),
  );
}

void main() {
  sqfliteFfiInit();

  testWidgets('authenticated Home preserves local access and surfaces retry when cloud continuity is unavailable', (
    tester,
  ) async {
    const learner = AuthenticatedLearner(id: LearnerId('cloud-shell-authenticated'));
    final gateway = _RecoveringContinuityGateway();
    final runtime = await _runtime(learner: learner, gateway: gateway);
    addTearDown(runtime.close);

    await tester.pumpWidget(MaterialApp(home: ProductShellScreen(runtime: runtime)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('cloud-continuity-notice')), findsOneWidget);
    expect(find.textContaining('Yerel çalışmaların korunuyor'), findsOneWidget);
    expect(find.byKey(const ValueKey('la0040-living-add')), findsOneWidget);
    expect(gateway.listCalls, 1);

    gateway.unavailable = false;
    await tester.tap(find.byKey(const ValueKey('cloud-continuity-retry')));
    await tester.pumpAndSettle();

    expect(gateway.listCalls, 2);
    expect(find.byKey(const ValueKey('cloud-continuity-notice')), findsNothing);
    expect(find.byKey(const ValueKey('la0040-living-add')), findsOneWidget);
  });

  testWidgets('guest Home never invokes cloud continuity', (tester) async {
    final gateway = _RecoveringContinuityGateway();
    final runtime = await _runtime(learner: AppRuntime.localLearner, gateway: gateway);
    addTearDown(runtime.close);

    await tester.pumpWidget(MaterialApp(home: ProductShellScreen(runtime: runtime)));
    await tester.pumpAndSettle();

    expect(gateway.listCalls, 0);
    expect(find.byKey(const ValueKey('cloud-continuity-notice')), findsNothing);
    expect(find.byKey(const ValueKey('la0040-living-add')), findsOneWidget);
  });

  testWidgets('cloud recovery stays explicit without displacing the primary action at 320px large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const learner = AuthenticatedLearner(id: LearnerId('cloud-shell-large-text'));
    final gateway = _RecoveringContinuityGateway();
    final runtime = await _runtime(learner: learner, gateway: gateway);
    addTearDown(runtime.close);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true, textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: LivingDeskReviewScope(child: ProductShellScreen(runtime: runtime)),
      ),
    );
    await tester.pumpAndSettle();

    final notice = find.byKey(const ValueKey('cloud-continuity-notice'));
    expect(notice, findsOneWidget);
    expect(find.byKey(const ValueKey('cloud-continuity-retry')), findsOneWidget);
    final primary = find.byKey(const ValueKey('la0040-living-add'));
    expect(primary, findsOneWidget);
    expect(primary.hitTestable(), findsOneWidget);
    expect(tester.getBottomRight(primary).dy, lessThanOrEqualTo(844));
    expect(tester.getTopLeft(notice).dy, greaterThan(tester.getBottomRight(primary).dy));
  });
}
