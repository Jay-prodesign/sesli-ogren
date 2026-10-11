import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/account/account_deletion_gateway.dart';
import 'package:sesli_ogren/src/account/account_overview_gateway.dart';
import 'package:sesli_ogren/src/app/app_runtime.dart';
import 'package:sesli_ogren/src/app/companion_view.dart';
import 'package:sesli_ogren/src/app/learning_slice_screen.dart';
import 'package:sesli_ogren/src/app/listen_screen.dart';
import 'package:sesli_ogren/src/app/living_study_desk_home.dart';
import 'package:sesli_ogren/src/app/material_workspace_screen.dart';
import 'package:sesli_ogren/src/app/product_shell_screen.dart';
import 'package:sesli_ogren/src/app/profile_surface.dart';
import 'package:sesli_ogren/src/app/progress_surface.dart';
import 'package:sesli_ogren/src/app/sesli_ogren_app.dart';
import 'package:sesli_ogren/src/app/source_reader_screen.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/learning/recall_learning_service.dart';
import 'package:sesli_ogren/src/speech/device_speech_output.dart';
import 'package:sesli_ogren/src/domain/authenticated_learner.dart';
import 'package:sesli_ogren/src/domain/learning_truth.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sesli_ogren/src/domain/operational_event.dart';
import 'package:sesli_ogren/src/generation/supabase_source_summary_gateway.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _UnusedPdfExtractor implements PdfTextExtractor {
  const _UnusedPdfExtractor();

  @override
  Future<ExtractedPdf> extract(Uint8List bytes, {required String sourceName}) {
    throw UnimplementedError();
  }
}

class _NoTextPdfExtractor implements PdfTextExtractor {
  const _NoTextPdfExtractor();

  @override
  Future<ExtractedPdf> extract(Uint8List bytes, {required String sourceName}) {
    throw const PdfTextExtractionException(
      'PDF contains no extractable text. OCR is not enabled in M5.',
      kind: PdfTextExtractionFailureKind.noExtractableText,
    );
  }
}

final class _MemoryPlatformFile extends PlatformFile {
  _MemoryPlatformFile({required this.name, required Uint8List bytes}) : _bytes = Uint8List.fromList(bytes);

  final Uint8List _bytes;

  @override
  final String name;

  @override
  String? get path => null;

  @override
  Uri get uri => Uri.parse('memory:///$name');

  @override
  Never get xFile => throw UnsupportedError('Memory test file has no platform XFile.');

  @override
  int? lengthSync() => _bytes.length;

  @override
  Future<int?> length() async => _bytes.length;

  @override
  Future<Uint8List> readAsBytes() async => Uint8List.fromList(_bytes);

  @override
  Stream<Uint8List> readAsByteStream() => Stream<Uint8List>.value(Uint8List.fromList(_bytes));
}

class _RecordingAccountDeletionGateway implements AccountDeletionGateway {
  int calls = 0;

  @override
  Future<void> deleteAccount({required AuthenticatedLearner learner}) async {
    calls += 1;
  }
}

class _FailingAccountDeletionGateway implements AccountDeletionGateway {
  const _FailingAccountDeletionGateway();

  @override
  Future<void> deleteAccount({required AuthenticatedLearner learner}) {
    throw const AccountDeletionException('test failure');
  }
}

class _ReadyAccountOverviewGateway implements AccountOverviewGateway {
  const _ReadyAccountOverviewGateway();

  @override
  Future<AccountOverview?> load({required AuthenticatedLearner learner}) async => AccountOverview(
    locale: 'tr-TR',
    accountStatus: 'active',
    plan: 'free',
    entitlementStatus: 'active',
    usage: [
      AccountUsageEntry(periodStart: DateTime.utc(2026, 10, 11), capability: 'explain', consumed: 3),
      AccountUsageEntry(periodStart: DateTime.utc(2026, 10, 11), capability: 'focus', consumed: 2),
    ],
    dailyLimits: const {'summary_daily': 20, 'explain_daily': 20, 'focus_daily': 20, 'explain_back_daily': 20},
  );
}

class _UnverifiedPlanOverviewGateway implements AccountOverviewGateway {
  const _UnverifiedPlanOverviewGateway();

  @override
  Future<AccountOverview?> load({required AuthenticatedLearner learner}) async => const AccountOverview(
    locale: 'tr-TR',
    accountStatus: 'active',
    plan: 'unrecognized-plan',
    entitlementStatus: 'active',
    usage: [],
  );
}

class _PendingDeletionOverviewGateway implements AccountOverviewGateway {
  const _PendingDeletionOverviewGateway();

  @override
  Future<AccountOverview?> load({required AuthenticatedLearner learner}) async => const AccountOverview(
    locale: 'tr-TR',
    accountStatus: 'deletion_requested',
    plan: 'free',
    entitlementStatus: 'active',
    usage: [],
  );
}

class _UnknownUsageOverviewGateway implements AccountOverviewGateway {
  const _UnknownUsageOverviewGateway();

  @override
  Future<AccountOverview?> load({required AuthenticatedLearner learner}) async => AccountOverview(
    locale: 'unexpected-locale',
    accountStatus: 'active',
    plan: 'free',
    entitlementStatus: 'active',
    usage: [
      AccountUsageEntry(periodStart: DateTime.utc(2026, 10, 1), capability: 'internal_future_capability', consumed: 7),
    ],
  );
}

class _RecordingSourceCleanupGateway extends SupabaseSourceSummaryGateway {
  final List<String> deletedMaterialIds = <String>[];

  @override
  Future<bool> deleteServerMaterial(String serverMaterialId) async {
    deletedMaterialIds.add(serverMaterialId);
    return true;
  }
}

class _FakeSpeechOutput implements SpeechOutput {
  String? lastText;
  double? lastRateMultiplier;
  VoidCallback? _onDone;

  @override
  Future<void> speak(
    String text, {
    required String locale,
    required VoidCallback onStart,
    required VoidCallback onDone,
    required ValueChanged<Object> onError,
    double rateMultiplier = 1.0,
  }) async {
    lastText = text;
    lastRateMultiplier = rateMultiplier;
    _onDone = onDone;
    onStart();
  }

  void complete() {
    final callback = _onDone;
    _onDone = null;
    callback?.call();
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

void _noopMaterialOpen(MaterialId _) {}

void usePhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget testShell(AppRuntime runtime) {
  return MaterialApp(
    builder: (context, child) =>
        MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
    home: LearningSliceScreen(runtime: runtime),
  );
}

Future<void> pumpUntilFound(WidgetTester tester, Finder finder, {int maxPumps = 100}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  fail('Expected widget was not reached within bounded pumps.');
}

Future<void> pumpUntilGone(WidgetTester tester, Finder finder, {int maxPumps = 100}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isEmpty) {
      return;
    }
  }
  fail('Expected widget to leave the tree within bounded pumps.');
}

Future<void> scrollUntilFound(
  WidgetTester tester,
  Finder target, {
  required Finder scrollable,
  int maxDrags = 14,
  double delta = -180,
}) async {
  for (var i = 0; i < maxDrags && target.evaluate().isEmpty; i++) {
    final activeScrollables = scrollable.hitTestable();
    expect(activeScrollables, findsWidgets);
    await tester.drag(activeScrollables.first, Offset(0, delta));
    await tester.pump();
  }
  expect(target, findsWidgets);
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 20 && finder.evaluate().isNotEmpty && finder.hitTestable().evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  if (finder.evaluate().isEmpty) {
    final scrollables = find.byType(Scrollable).hitTestable();
    if (scrollables.evaluate().isNotEmpty) {
      await scrollUntilFound(tester, finder, scrollable: scrollables.first);
    }
  }
  var target = finder.hitTestable();
  if (target.evaluate().isEmpty && finder.evaluate().isNotEmpty) {
    await tester.ensureVisible(finder.first);
    for (var i = 0; i < 20 && finder.hitTestable().evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    target = finder.hitTestable();
  }
  expect(target, findsWidgets);
  await tester.tap(target.first);
}

Future<void> tapBottomNavIcon(WidgetTester tester, IconData icon) async {
  final target = find.byIcon(icon).hitTestable();
  await pumpUntilFound(tester, target);
  await tester.tap(target.first);
  await tester.pump();
}

void main() {
  sqfliteFfiInit();

  testWidgets('production app routes a missing restored session to passwordless account entry', (tester) async {
    await tester.pumpWidget(SesliOgrenApp(restoreSession: () async => null));
    await pumpUntilFound(tester, find.text('Öğrenme alanına gir'));

    expect(find.text('Öğrenme alanına gir'), findsOneWidget);
    expect(find.text('Kod gönder'), findsOneWidget);
    expect(find.textContaining('Şifre gerekmiyor'), findsOneWidget);
    expect(find.text('Uygulama bağlantısı henüz yapılandırılmadı.'), findsNothing);
  });

  testWidgets('runtime opening failure is not mislabeled as an OTP failure', (tester) async {
    await tester.pumpWidget(
      SesliOgrenApp(
        restoreSession: () async => const AuthenticatedLearner(id: LearnerId('runtime-error-user')),
        openRuntime: (_) async => throw StateError('local runtime failed'),
      ),
    );
    await pumpUntilFound(tester, find.text('Güvenli öğrenme oturumu açılamadı.'));

    expect(find.text('Güvenli öğrenme oturumu açılamadı.'), findsOneWidget);
    expect(find.text('Yeniden dene'), findsOneWidget);
    expect(find.bySemanticsLabel('Düğüm düşünüyor'), findsOneWidget);
    expect(find.bySemanticsLabel('Düğüm destek oluyor'), findsNothing);
    expect(find.text('Kod doğrulanamadı. Yeni bir kod isteyebilirsin.'), findsNothing);
  });

  testWidgets('learning continuation failure uses unresolved companion state', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor()),
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
    );
    await store.close();

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: LearningSliceScreen(runtime: runtime),
        ),
      ),
    );
    await pumpUntilFound(tester, find.textContaining('Devam kaydı kullanılamadı'));
    await tester.pump();

    final companion = tester.widget<CompanionView>(find.byType(CompanionView).first);
    expect(companion.state, CompanionVisualState.think);
    expect(find.bySemanticsLabel('Düğüm destek oluyor'), findsNothing);
    expect(find.bySemanticsLabel('Düğüm başarıyı kutluyor'), findsNothing);
  });

  testWidgets('bottom navigation stays usable on narrow large-text layouts', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor()),
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: ProductShellScreen(runtime: runtime),
        ),
      ),
    );
    await pumpUntilFound(tester, find.byType(NavigationBar));

    final navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigation.labelBehavior, NavigationDestinationLabelBehavior.onlyShowSelected);
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.byIcon(Icons.library_books_outlined), findsOneWidget);
    expect(find.byIcon(Icons.insights_outlined), findsOneWidget);
    expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Progress and Profile headers stay readable on narrow large-text layouts', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: Scaffold(
            body: ProgressSurface(items: [], onOpenMaterial: _noopMaterialOpen),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('HATIRLAMA GEÇMİŞİN'), findsOneWidget);
    expect(find.text('İlerleme'), findsOneWidget);
    expect(find.textContaining('öğrenme durumunu aktif hatırlama değiştirir'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor()),
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
      accountOverview: const _ReadyAccountOverviewGateway(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: Scaffold(body: ProfileSurface(runtime: runtime)),
        ),
      ),
    );
    await pumpUntilFound(tester, find.byKey(const ValueKey('profile-account-header-stacked')));

    expect(find.text('Ücretsiz plan'), findsOneWidget);
    expect(find.text('AKTİF'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('runtime failure recovery remains reachable on a short large-text screen', (tester) async {
    tester.view.physicalSize = const Size(320, 460);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      SesliOgrenApp(
        restoreSession: () async => const AuthenticatedLearner(id: LearnerId('runtime-large-text-user')),
        openRuntime: (_) async => throw StateError('local runtime failed'),
        signOutSession: () async {},
      ),
    );
    await pumpUntilFound(tester, find.byKey(const ValueKey('runtime-error-scroll')));

    expect(find.text('Güvenli öğrenme oturumu açılamadı.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Başka hesapla giriş yap'),
      160,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('runtime-error-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pump();
    expect(find.text('Yeniden dene'), findsOneWidget);
    expect(find.text('Başka hesapla giriş yap').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('account-deleted recovery remains reachable on a short large-text screen', (tester) async {
    tester.view.physicalSize = const Size(320, 460);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(() async {
      try {
        await store.close();
      } catch (_) {}
    });
    final deletion = _RecordingAccountDeletionGateway();
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor()),
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
      accountOverview: const _ReadyAccountOverviewGateway(),
      accountDeletion: deletion,
    );

    await tester.pumpWidget(
      SesliOgrenApp(
        restoreSession: () async => runtime.learner,
        openRuntime: (_) async => runtime,
        signOutSession: () async {},
      ),
    );
    await pumpUntilFound(tester, find.byType(NavigationBar));
    await tapBottomNavIcon(tester, Icons.person_outline_rounded);
    await pumpUntilFound(tester, find.text('Profil ve Ayarlar'));
    final profileScroll = find.descendant(
      of: find.byKey(const ValueKey('profile-surface')),
      matching: find.byType(Scrollable),
    );
    final deleteAccount = find.widgetWithText(OutlinedButton, 'Hesabımı ve verilerimi sil');
    await scrollUntilFound(tester, deleteAccount, scrollable: profileScroll);
    await tapVisible(tester, deleteAccount);
    await pumpUntilFound(tester, find.text('Hesabı ve verileri sil?'));
    await tapVisible(tester, find.text('Devam et'));
    await pumpUntilFound(tester, find.text('Son onay'));
    await tapVisible(tester, find.text('Kalıcı olarak sil'));
    await pumpUntilFound(tester, find.byKey(const ValueKey('account-deleted-scroll')));

    expect(deletion.calls, 1);
    expect(find.text('Hesabın ve verilerin silindi.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Yeni öğrenme alanı oluştur'),
      160,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('account-deleted-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pump();
    expect(find.text('Yeni öğrenme alanı oluştur').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('runtime failure can safely return to account entry for another account', (tester) async {
    var signOutCalls = 0;
    await tester.pumpWidget(
      SesliOgrenApp(
        restoreSession: () async => const AuthenticatedLearner(id: LearnerId('runtime-switch-user')),
        openRuntime: (_) async => throw StateError('local runtime failed'),
        signOutSession: () async {
          signOutCalls += 1;
        },
      ),
    );
    await pumpUntilFound(tester, find.text('Güvenli öğrenme oturumu açılamadı.'));

    final switchAccount = find.widgetWithText(TextButton, 'Başka hesapla giriş yap');
    expect(switchAccount, findsOneWidget);
    await pumpUntilFound(tester, switchAccount.hitTestable());
    await tester.tap(switchAccount);
    await pumpUntilFound(tester, find.text('Öğrenme alanına gir'));

    expect(signOutCalls, 1);
    expect(find.text('Kod gönder'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('runtime failure keeps current account when sign-out recovery fails', (tester) async {
    await tester.pumpWidget(
      SesliOgrenApp(
        restoreSession: () async => const AuthenticatedLearner(id: LearnerId('runtime-switch-fail-user')),
        openRuntime: (_) async => throw StateError('local runtime failed'),
        signOutSession: () async => throw StateError('sign out unavailable'),
      ),
    );
    await pumpUntilFound(tester, find.text('Güvenli öğrenme oturumu açılamadı.'));

    await tester.tap(find.text('Başka hesapla giriş yap'));
    await pumpUntilFound(tester, find.textContaining('Mevcut hesap açık kalıyor'));

    expect(find.text('Güvenli öğrenme oturumu açılamadı.'), findsOneWidget);
    expect(find.text('Öğrenme alanına gir'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Profile stays available when the learning-library snapshot cannot load', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor()),
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
      accountOverview: const _ReadyAccountOverviewGateway(),
    );
    await store.close();

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: ProductShellScreen(runtime: runtime),
        ),
      ),
    );
    await pumpUntilFound(tester, find.text('Kütüphane şu anda yüklenemedi.'));

    expect(find.text('Kütüphane şu anda yüklenemedi.'), findsOneWidget);
    await tester.tap(find.text('Profil'));
    await tester.pump();
    await pumpUntilFound(tester, find.text('Profil ve Ayarlar'));

    expect(find.text('Profil ve Ayarlar'), findsOneWidget);
    expect(find.text('Ücretsiz plan'), findsOneWidget);
    expect(find.text('Kütüphane şu anda yüklenemedi.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('production learning slice boots at truthful source entry', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);

    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor()),
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
    );

    await tester.pumpWidget(testShell(runtime));
    await pumpUntilFound(tester, find.text('Çalışma materyalini ekle'));

    expect(find.text('Sesli Öğren'), findsOneWidget);
    expect(find.text('Çalışma materyalini ekle'), findsOneWidget);
    expect(find.text('Kaynağı ekle ve aç'), findsOneWidget);
    expect(find.text('İpucu'), findsNothing);
  });

  testWidgets('image-only PDF failure offers a one-tap text fallback without persisting a broken source', (
    tester,
  ) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _NoTextPdfExtractor());
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
    );
    final bytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31]);

    await tester.pumpWidget(
      MaterialApp(
        home: LivingDeskReviewScope(
          child: LearningSliceScreen(
            runtime: runtime,
            pickPdfFile: () async => _MemoryPlatformFile(name: 'scan.pdf', bytes: bytes),
          ),
        ),
      ),
    );
    await pumpUntilFound(tester, find.text('PDF seç'));
    await tapVisible(tester, find.text('PDF seç'));
    await pumpUntilFound(tester, find.textContaining('seçilebilir metin bulunamadı'));

    expect(find.byKey(const ValueKey('source-pdf-fallback-text')), findsOneWidget);
    expect(await store.material(learner: runtime.learner, materialId: AppRuntime.primaryMaterialId), isNull);

    await tapVisible(tester, find.byKey(const ValueKey('source-pdf-fallback-text')));
    await pumpUntilFound(tester, find.byKey(const ValueKey('pasted-material-text')));

    expect(find.textContaining('seçilebilir metin bulunamadı'), findsNothing);
    expect(find.byKey(const ValueKey('pasted-material-text')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Recall result keeps its canonical next-action reason complete at large text', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    final recall = RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore());
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: recall,
      telemetry: store.operationalTelemetry(),
    );

    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: AppRuntime.primaryMaterialId,
      text:
          'Fotosentez sırasında klorofil ışık enerjisini kimyasal enerjiye dönüştürmeye yardımcı olur. '
          'Bitkiler bu süreçte karbondioksit kullanır.',
      sourceName: 'Büyük yazı sonuç notu',
    );

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true, textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: LivingDeskReviewScope(child: LearningSliceScreen(runtime: runtime)),
      ),
    );
    final learningScroll = find.descendant(of: find.byType(LearningSliceScreen), matching: find.byType(Scrollable));
    await scrollUntilFound(tester, find.byKey(const ValueKey('recall')), scrollable: learningScroll);
    await scrollUntilFound(tester, find.text('Bilmiyorum'), scrollable: learningScroll);
    await tapVisible(tester, find.text('Bilmiyorum'));
    await pumpUntilFound(tester, find.byKey(const ValueKey('la0040-result-next-reason')));

    final continuation = await recall.reopen(learner: runtime.learner, materialId: AppRuntime.primaryMaterialId);
    expect(continuation, isNotNull);

    final reason = tester.widget<Text>(find.byKey(const ValueKey('la0040-result-next-reason')));
    expect(reason.data, continuation!.nextAction.reasonText);
    expect(reason.maxLines, isNull);
    expect(reason.overflow, isNull);
    expect(find.byKey(const ValueKey('la0040-result-sticky-next')).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('source to Recall result persists and reopens as one continuation', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);

    final ingest = SourceIngestService(
      store: store,
      pdfTextExtractor: const _UnusedPdfExtractor(),
      now: () => DateTime.utc(2026, 10, 4, 16),
    );
    final recall = RecallLearningService(
      sourceStore: store,
      learningStore: store.learningTruthStore(),
      now: () => DateTime.utc(2026, 10, 4, 16, 1),
    );
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: recall,
      telemetry: store.operationalTelemetry(),
    );

    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: AppRuntime.primaryMaterialId,
      text:
          'Fotosentez sırasında klorofil ışık enerjisini kimyasal enerjiye '
          'dönüştürmeye yardımcı olur. Bitkiler bu süreçte karbondioksit kullanır.',
      sourceName: 'Biyoloji notu',
    );
    final prompt = await recall.createCurrentPrompt(learner: runtime.learner, materialId: AppRuntime.primaryMaterialId);
    final action = await store.learningTruthStore().recallAction(learner: runtime.learner, actionId: prompt.id);
    expect(action, isNotNull);

    await tester.pumpWidget(testShell(runtime));
    await pumpUntilFound(tester, find.text('Hatırla'));

    expect(find.text('Hatırla'), findsOneWidget);
    await tester.enterText(find.byType(TextField), action!.expectedAnswer);
    await tapVisible(tester, find.text('Yanıtla'));
    await pumpUntilFound(tester, find.text('İpucusuz hatırladın'));

    expect(find.text('İpucusuz hatırladın'), findsOneWidget);
    expect(find.text('Sıradaki adım'), findsOneWidget);
    await tapVisible(tester, find.text('Bu denemeyi tamamla'));
    await pumpUntilFound(tester, find.text('Bu deneme kaydedildi'));
    expect(find.text('Bu deneme kaydedildi'), findsOneWidget);
    expect(find.text('Çalışmayı bitir'), findsOneWidget);

    final events = await store.operationalTelemetry().events(learner: runtime.learner);
    expect(
      events.any(
        (event) =>
            event.schemaVersion == 1 &&
            event.type == OperationalEventType.recallAttempt &&
            event.phase == OperationalEventPhase.completed &&
            event.attemptId != null &&
            event.evidenceId != null &&
            event.outcome == RecallOutcome.correct &&
            event.stateKind == RecallStateKind.retrievedOnce &&
            event.reasonCode == 'ONE_UNASSISTED_RETRIEVAL_OBSERVED' &&
            event.ruleVersion == RecallLearningService.evidenceRuleVersion &&
            event.policyVersion == RecallLearningService.nextActionPolicyVersion &&
            event.durationMs != null,
      ),
      isTrue,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: LearningSliceScreen(key: const ValueKey('reopened-slice'), runtime: runtime),
        ),
      ),
    );
    await pumpUntilFound(tester, find.text('Bu deneme kaydedildi'));

    expect(find.text('Bu deneme kaydedildi'), findsOneWidget);
    expect(find.text('Çalışmayı bitir'), findsOneWidget);
    expect(find.textContaining('ONE_UNASSISTED_RETRIEVAL_OBSERVED'), findsNothing);
    expect(find.textContaining('Neden:'), findsNothing);
  });

  testWidgets('full product shell opens one coherent grounded material workspace', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);

    final ingest = SourceIngestService(
      store: store,
      pdfTextExtractor: const _UnusedPdfExtractor(),
      now: () => DateTime.utc(2026, 10, 5, 19),
    );
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
    );

    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: AppRuntime.primaryMaterialId,
      text:
          'Fotosentez, bitkilerin ışık enerjisini kullanarak karbondioksit ve sudan '
          'kimyasal enerji depolamasına yardımcı olan süreçtir.',
      sourceName: 'Fotosentez çalışma notu',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: LivingDeskReviewScope(child: ProductShellScreen(runtime: runtime)),
        ),
      ),
    );
    await pumpUntilFound(tester, find.byKey(const ValueKey('la0040-living-home-populated')));

    expect(find.text('Kütüphane'), findsOneWidget);
    expect(find.text('Fotosentez çalışma notu'), findsWidgets);
    final materialCard = find.byKey(const ValueKey('la0040-living-material-open'));
    expect(materialCard, findsOneWidget);
    await tapVisible(tester, materialCard);

    await pumpUntilFound(tester, find.byType(MaterialWorkspaceScreen));
    await pumpUntilFound(tester, find.byKey(const ValueKey('la0040-atelier-workspace')));
    expect(LivingDeskReviewScope.active(tester.element(find.byType(MaterialWorkspaceScreen))), isTrue);
    expect(find.text('Fotosentez çalışma notu'), findsWidgets);
    expect(find.byKey(const ValueKey('la0040-atelier-workspace-reader')), findsOneWidget);

    Finder workspaceScroll() =>
        find.descendant(of: find.byType(MaterialWorkspaceScreen), matching: find.byType(Scrollable));

    final otherPaths = find.widgetWithText(TextButton, 'Diğer yollar').hitTestable();
    await pumpUntilFound(tester, otherPaths);
    await tester.tap(otherPaths);
    await pumpUntilFound(tester, find.byKey(const ValueKey('workspace-other-study-paths-scroll')));
    await tapVisible(tester, find.text('Odaklan'));
    await pumpUntilFound(tester, find.text('KISA ODAK · 3 ADIM'));
    expect(find.byKey(const ValueKey('focus-source-trust')), findsOneWidget);
    expect(find.text('Fotosentez çalışma notu'), findsWidgets);
    expect(find.text('Sorumu açıkla'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Fotosentezde karbondioksit nasıl kullanılır?');
    await tapVisible(tester, find.text('İpucu ver'));
    await pumpUntilFound(tester, find.textContaining('Kaynak ipucu:'));
    expect(find.textContaining('karbondioksit'), findsWidgets);
    await pumpUntilFound(tester, find.textContaining('öğrenme kanıtı oluşturmaz'));
    Navigator.of(tester.element(find.textContaining('öğrenme kanıtı oluşturmaz'))).pop();
    await pumpUntilFound(tester, find.byType(MaterialWorkspaceScreen));

    final otherPathsAfterFocus = find.widgetWithText(TextButton, 'Diğer yollar').hitTestable();
    await pumpUntilFound(tester, otherPathsAfterFocus);
    await tester.tap(otherPathsAfterFocus);
    await pumpUntilFound(tester, find.byKey(const ValueKey('workspace-other-study-paths-scroll')));
    await tapVisible(tester, find.text('Kendi cümlelerimle anlat'));
    await pumpUntilFound(tester, find.text('Anlatımımı değerlendir'));

    expect(find.text('Kendi cümlelerinle anlat'), findsOneWidget);
    expect(find.textContaining('öğrenme kanıtı veya ustalık iddiası oluşturmaz'), findsOneWidget);
    expect(find.text('Kaynağına dayalı açıklama'), findsNothing);

    Navigator.of(tester.element(find.text('Anlatımımı değerlendir'))).pop();
    await pumpUntilFound(tester, find.byType(MaterialWorkspaceScreen));
    await scrollUntilFound(
      tester,
      find.byKey(const ValueKey('la0040-atelier-workspace-listen')),
      scrollable: workspaceScroll(),
    );
    expect(find.byKey(const ValueKey('la0040-atelier-workspace-listen')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home resumes an active Reader checkpoint ahead of a newer untouched upload', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    var now = DateTime.utc(2026, 10, 6, 9);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor(), now: () => now);
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore(), now: () => now),
      telemetry: store.operationalTelemetry(),
    );

    const olderId = MaterialId('older-material');
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: olderId,
      text: 'Eski materyal için yeterince uzun ve anlamlı bir çalışma metni.',
      sourceName: 'Eski materyal',
    );
    final olderSource = await store.currentSourceVersion(learner: runtime.learner, materialId: olderId);
    expect(olderSource, isNotNull);

    now = DateTime.utc(2026, 10, 6, 10);
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: const MaterialId('recent-material'),
      text: 'Yeni yüklenen materyal için yeterince uzun ve anlamlı bir çalışma metni.',
      sourceName: 'Yeni materyal',
    );

    await store.saveReaderResumeProgress(
      learner: runtime.learner,
      materialId: olderId,
      sourceVersionId: olderSource!.identity.sourceVersionId,
      progress: 0.46,
      updatedAt: DateTime.utc(2026, 10, 6, 11),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LivingDeskReviewScope(child: ProductShellScreen(runtime: runtime)),
      ),
    );
    await pumpUntilFound(tester, find.text('Okumaya kaldığın yerden devam et'));

    final activeMaterialCard = find.byKey(const ValueKey('la0040-living-material-open'));
    expect(find.descendant(of: activeMaterialCard, matching: find.text('Eski materyal')), findsOneWidget);
    expect(find.descendant(of: activeMaterialCard, matching: find.text('Yeni materyal')), findsNothing);
    expect(find.text('Yeni materyal'), findsOneWidget);

    await tapVisible(tester, find.text('Okumaya devam et'));
    await pumpUntilFound(tester, find.byType(SourceReaderScreen));
    expect(find.descendant(of: find.byType(SourceReaderScreen), matching: find.text('Eski materyal')), findsOneWidget);
    expect(find.descendant(of: find.byType(SourceReaderScreen), matching: find.text('Yeni materyal')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('durable Listen checkpoint resumes across Home, Library and Progress without creating mastery', (
    tester,
  ) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    var now = DateTime.utc(2026, 10, 6, 9);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor(), now: () => now);
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
    );

    const listenedId = MaterialId('listened-older-material');
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: listenedId,
      text: List.filled(90, 'Dinlenen eski materyalin kaynak içeriği.').join(' '),
      sourceName: 'Dinlenen eski materyal',
    );
    now = DateTime.utc(2026, 10, 6, 10);
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: const MaterialId('newer-upload-material'),
      text: 'Daha yeni yüklenen fakat henüz çalışılmayan materyal.',
      sourceName: 'Yeni yüklenen materyal',
    );

    final listenedSource = await store.currentSourceVersion(learner: runtime.learner, materialId: listenedId);
    expect(listenedSource, isNotNull);
    await store.saveListenResumeChunk(
      learner: runtime.learner,
      materialId: listenedId,
      sourceVersionId: listenedSource!.identity.sourceVersionId,
      chunkIndex: 1,
      updatedAt: DateTime.utc(2026, 10, 6, 11),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LivingDeskReviewScope(child: ProductShellScreen(runtime: runtime)),
      ),
    );
    await pumpUntilFound(tester, find.text('Dinlemeye devam et'));
    final activeMaterialCard = find.byKey(const ValueKey('la0040-living-material-open'));
    expect(find.descendant(of: activeMaterialCard, matching: find.text('Dinlenen eski materyal')), findsOneWidget);
    expect(find.descendant(of: activeMaterialCard, matching: find.text('Yeni yüklenen materyal')), findsNothing);
    expect(find.text('Yeni yüklenen materyal'), findsOneWidget);

    await tapVisible(tester, find.text('Dinlemeye devam et'));
    await pumpUntilFound(tester, find.byType(ListenScreen));
    expect(find.text('Dinlenen eski materyal'), findsWidgets);
    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 450));
    await pumpUntilFound(tester, find.text('Kütüphane').hitTestable());

    await tapVisible(tester, find.text('Kütüphane').hitTestable().last);
    final libraryContinue = find.byKey(ValueKey('library-continue-${listenedId.value}'));
    await pumpUntilFound(tester, libraryContinue);
    expect(find.text('Dinlemeye devam et'), findsOneWidget);
    await tapVisible(tester, libraryContinue);
    await pumpUntilFound(tester, find.byType(ListenScreen));
    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 450));
    await pumpUntilFound(tester, find.text('İlerleme').hitTestable());

    await tapVisible(tester, find.text('İlerleme').hitTestable().last);
    final progressContinue = find.byKey(ValueKey('progress-continue-${listenedId.value}'));
    await pumpUntilFound(tester, progressContinue);
    expect(find.text('Henüz ölçülmedi'), findsWidgets);
    expect(find.textContaining('Dinleme konumun kayıtlı'), findsOneWidget);
    await tapVisible(tester, progressContinue);
    await pumpUntilFound(tester, find.byType(ListenScreen));
  });

  testWidgets('Library deletion removes the selected material and Home falls back safely', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    var now = DateTime.utc(2026, 10, 6, 11);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor(), now: () => now);
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
    );

    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: const MaterialId('delete-older'),
      text: 'Silme sonrası güvenli geri dönüş için eski materyal içeriği.',
      sourceName: 'Korunacak materyal',
    );
    now = DateTime.utc(2026, 10, 6, 12);
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: const MaterialId('delete-recent'),
      text: 'Silinecek son materyal için yeterince uzun bir çalışma metni.',
      sourceName: 'Silinecek materyal',
    );

    await tester.pumpWidget(MaterialApp(home: ProductShellScreen(runtime: runtime)));
    await pumpUntilFound(tester, find.text('Kütüphane'));
    await tapVisible(tester, find.text('Kütüphane').last);
    await pumpUntilFound(tester, find.text('Silinecek materyal'));

    final recentCard = find.ancestor(of: find.text('Silinecek materyal'), matching: find.byType(Card));
    final deleteButton = find.descendant(of: recentCard, matching: find.byTooltip('Materyali sil'));
    expect(deleteButton, findsOneWidget);
    await tapVisible(tester, deleteButton);
    await pumpUntilFound(tester, find.text('Materyali sil?'));
    await tapVisible(tester, find.text('Sil'));
    await pumpUntilFound(tester, find.text('Materyal silindi.'));
    await pumpUntilGone(tester, find.text('Silinecek materyal'));

    expect(find.text('Silinecek materyal'), findsNothing);
    expect(find.text('Korunacak materyal'), findsOneWidget);
    expect(await store.material(learner: runtime.learner, materialId: const MaterialId('delete-recent')), isNull);

    await tapVisible(tester, find.text('Ana Sayfa').last);
    await pumpUntilFound(tester, find.text('KALDIĞIN MATERYAL'));
    await tapVisible(tester, find.text('Çalışmaya devam et'));
    await pumpUntilFound(tester, find.text('Korunacak materyal'));
    expect(find.text('Korunacak materyal'), findsWidgets);
  });

  testWidgets('Library adds a second material without replacing the current source', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
    );
    const firstId = MaterialId('library-first-material');
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: firstId,
      text: 'İlk kaynak korunurken ikinci kaynak ayrı bir materyal olarak eklenmelidir.',
      sourceName: 'İlk kaynak',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LivingDeskReviewScope(child: ProductShellScreen(runtime: runtime)),
      ),
    );
    await pumpUntilFound(tester, find.text('Kütüphane'));
    await tapVisible(tester, find.text('Kütüphane').last);
    await pumpUntilFound(tester, find.byKey(const ValueKey('library-add-material')));
    await tapVisible(tester, find.byKey(const ValueKey('library-add-material')));
    await pumpUntilFound(tester, find.text('İLK KAYNAĞIN'));
    expect(find.text('KAYNAĞI GÜNCELLE'), findsNothing);

    await tapVisible(tester, find.text('Metin yapıştır'));
    await pumpUntilFound(tester, find.byKey(const ValueKey('pasted-material-text')));
    await tester.enterText(
      find.byKey(const ValueKey('pasted-material-text')),
      'İkinci kaynak birinci kaynağın sürümü olmadan kendi materyali olarak saklanır.',
    );
    await tapVisible(tester, find.byKey(const ValueKey('source-add-title')));
    await pumpUntilFound(tester, find.byKey(const ValueKey('pasted-material-title')));
    await tester.enterText(find.byKey(const ValueKey('pasted-material-title')), 'İkinci kaynak');
    await tapVisible(tester, find.byKey(const ValueKey('source-text-submit')));
    await pumpUntilFound(tester, find.byType(MaterialWorkspaceScreen));

    final materials = await store.activeMaterials(learner: runtime.learner);
    expect(materials, hasLength(2));
    expect(materials.map((item) => item.id), contains(firstId));
    expect(materials.where((item) => item.title == 'İkinci kaynak'), hasLength(1));

    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 350));
    await pumpUntilFound(tester, find.text('İlk kaynak'));
    expect(find.text('İkinci kaynak'), findsWidgets);
    expect(find.text('İlk kaynak'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Library header and add action stay usable on narrow large-text layouts', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
    );
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: const MaterialId('library-large-text-material'),
      text: 'Dar ekranda kütüphane başlığı ve yeni kaynak eylemi okunabilir kalmalıdır.',
      sourceName: 'Dar ekran kaynağı',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: ProductShellScreen(runtime: runtime),
        ),
      ),
    );
    await pumpUntilFound(tester, find.byType(NavigationBar));
    await tester.tap(find.byIcon(Icons.library_books_outlined));
    await tester.pump();
    await pumpUntilFound(tester, find.byKey(const ValueKey('library-header-stacked')));
    expect(find.byKey(const ValueKey('library-add-material')), findsOneWidget);
    expect(find.text('Yeni kaynak ekle'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Listen resumes the exact current source from a durable chunk checkpoint', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
    );
    final text = List.generate(90, (index) => 'kelime$index').join(' ');
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: const MaterialId('listen-resume'),
      text: text,
      sourceName: 'Dinleme devam notu',
    );
    final source = await store.currentSourceVersion(
      learner: runtime.learner,
      materialId: const MaterialId('listen-resume'),
    );
    expect(source, isNotNull);
    await store.saveListenResumeChunk(
      learner: runtime.learner,
      materialId: const MaterialId('listen-resume'),
      sourceVersionId: source!.identity.sourceVersionId,
      chunkIndex: 1,
      updatedAt: DateTime.utc(2026, 10, 7, 8),
    );

    final speech = _FakeSpeechOutput();
    await tester.pumpWidget(
      MaterialApp(
        home: ListenScreen(runtime: runtime, materialId: const MaterialId('listen-resume'), speechOutput: speech),
      ),
    );
    await pumpUntilFound(tester, find.text('Dinleme devam notu'));
    expect(find.textContaining('bölüm 2 / 2'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Kaldığın yerden dinle'), 240, scrollable: find.byType(Scrollable).last);
    await tester.pump();
    expect(find.text('Kaldığın yerden dinle').hitTestable(), findsOneWidget);
    expect(find.byKey(const ValueKey('listen-source-transcript')), findsOneWidget);

    await tapVisible(tester, find.text('Kaldığın yerden dinle'));
    await tester.pump();
    expect(speech.lastText, isNotNull);

    speech.complete();
    await pumpUntilFound(tester, find.text('Dinlemeye başla'));
    expect(
      await store.listenResumeChunk(
        learner: runtime.learner,
        materialId: const MaterialId('listen-resume'),
        sourceVersionId: source.identity.sourceVersionId,
      ),
      0,
    );
  });

  testWidgets('Quick Recap Listen speaks recap text without overwriting source resume', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
    );
    const materialId = MaterialId('listen-recap');
    final sourceText = List.generate(90, (index) => 'kaynak$index').join(' ');
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: materialId,
      text: sourceText,
      sourceName: 'Uzun kaynak notu',
    );
    final source = await store.currentSourceVersion(learner: runtime.learner, materialId: materialId);
    expect(source, isNotNull);
    await store.saveListenResumeChunk(
      learner: runtime.learner,
      materialId: materialId,
      sourceVersionId: source!.identity.sourceVersionId,
      chunkIndex: 1,
      updatedAt: DateTime.utc(2026, 10, 9, 9),
    );

    const recap = 'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürmeye yardımcı olur.';
    final speech = _FakeSpeechOutput();
    await tester.pumpWidget(
      MaterialApp(
        home: ListenScreen(
          runtime: runtime,
          materialId: materialId,
          speechOutput: speech,
          textOverride: recap,
          titleOverride: 'Quick Recap',
          persistProgress: false,
        ),
      ),
    );
    await pumpUntilFound(tester, find.text('Quick Recap'));
    await tester.scrollUntilVisible(find.text('Quick Recap özeti'), 240, scrollable: find.byType(Scrollable).last);
    await tester.pump();
    expect(find.text('Quick Recap özeti'), findsOneWidget);
    expect(find.text(recap), findsWidgets);
    expect(find.textContaining('bölüm 2 / 2'), findsNothing);

    expect(find.text('Dinlemeye başla').hitTestable(), findsOneWidget);
    await tapVisible(tester, find.text('Dinlemeye başla'));
    await tester.pump();
    expect(speech.lastText, recap);

    speech.complete();
    await tester.pump();
    expect(
      await store.listenResumeChunk(
        learner: runtime.learner,
        materialId: materialId,
        sourceVersionId: source.identity.sourceVersionId,
      ),
      1,
    );
  });

  testWidgets('Progress reports canonical unassessed state without invented mastery', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
    );
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: AppRuntime.primaryMaterialId,
      text: 'Aktif kanıt oluşmadan ilerleme ustalık iddiası yapmamalıdır.',
      sourceName: 'İlerleme notu',
    );

    await tester.pumpWidget(MaterialApp(home: ProductShellScreen(runtime: runtime)));
    await pumpUntilFound(tester, find.text('İlerleme'));
    await tapVisible(tester, find.text('İlerleme').last);
    await pumpUntilFound(tester, find.text('Henüz ölçülmedi'));
    expect(find.text('İlerleme notu'), findsOneWidget);
    expect(find.text('Henüz ölçülmedi'), findsOneWidget);
    expect(find.text('Henüz bağımsız bir hatırlama denemen yok.'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('Profile shows only verified plan and usage data', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor()),
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
      accountOverview: const _ReadyAccountOverviewGateway(),
    );

    await tester.pumpWidget(MaterialApp(home: ProductShellScreen(runtime: runtime)));
    await pumpUntilFound(tester, find.text('Profil'));
    await tapVisible(tester, find.text('Profil').last);
    await pumpUntilFound(tester, find.text('Profil ve Ayarlar'));
    await pumpUntilFound(tester, find.text('Ücretsiz plan'));

    expect(find.text('Ücretsiz plan'), findsOneWidget);
    expect(find.text('Plan etkin'), findsOneWidget);
    expect(find.text('Kaynağa dayalı açıklama'), findsOneWidget);
    expect(find.text('3 / 20 bugün'), findsOneWidget);
    expect(find.text('Odak AI yardımı'), findsOneWidget);
    expect(find.text('2 / 20 bugün'), findsOneWidget);
    expect(find.text('Quick Recap'), findsOneWidget);
    expect(find.text('0 / 20 bugün'), findsNWidgets(2));
    expect(find.text('Anlatım değerlendirme'), findsOneWidget);
    expect(find.textContaining('Günlük sınırlar sunucu planından gelir'), findsOneWidget);
    expect(find.text('Dil: Türkçe'), findsOneWidget);
    final profileScroll = find.descendant(
      of: find.byKey(const ValueKey('profile-surface')),
      matching: find.byType(Scrollable),
    );
    await scrollUntilFound(tester, find.text('Cihazın Türkçe sesi'), scrollable: profileScroll);
    await scrollUntilFound(
      tester,
      find.textContaining('Hesap silme tüm hesap ve öğrenme verilerini kapsar'),
      scrollable: profileScroll,
    );
    expect(find.textContaining('Hesap silme tüm hesap ve öğrenme verilerini kapsar'), findsOneWidget);
  });

  testWidgets('Profile fails closed when an active entitlement has an unrecognized plan', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor()),
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
      accountOverview: const _UnverifiedPlanOverviewGateway(),
    );

    await tester.pumpWidget(MaterialApp(home: ProfileSurface(runtime: runtime)));
    await pumpUntilFound(tester, find.text('Plan doğrulanamadı'));

    expect(find.text('Plan veya erişim durumu doğrulanamadı'), findsOneWidget);
    expect(find.text('AKTİF'), findsNothing);
    expect(find.text('DOĞRULANAMADI'), findsOneWidget);
  });

  testWidgets('Profile blocks duplicate account deletion while server deletion is pending', (tester) async {
    usePhoneViewport(tester);
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final deletion = _RecordingAccountDeletionGateway();
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor()),
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
      accountOverview: const _PendingDeletionOverviewGateway(),
      accountDeletion: deletion,
    );

    await tester.pumpWidget(MaterialApp(home: ProfileSurface(runtime: runtime)));
    await pumpUntilFound(tester, find.text('Hesap silme isteği bekliyor'));
    await tester.scrollUntilVisible(
      find.text('Silme isteği zaten bekliyor'),
      260,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump(const Duration(milliseconds: 200));

    final destructiveButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Silme isteği zaten bekliyor'),
    );
    expect(destructiveButton.onPressed, isNull);
    expect(deletion.calls, 0);
    expect(find.textContaining('Aynı silme isteğini tekrar göndermiyoruz'), findsOneWidget);
  });

  testWidgets('Profile hides unknown backend capability and locale keys', (tester) async {
    usePhoneViewport(tester);
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor()),
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
      accountOverview: const _UnknownUsageOverviewGateway(),
    );

    await tester.pumpWidget(MaterialApp(home: ProfileSurface(runtime: runtime)));
    await pumpUntilFound(tester, find.text('Diğer kullanım'));

    expect(find.text('internal_future_capability'), findsNothing);
    expect(find.text('unexpected-locale'), findsNothing);
    expect(find.text('Diğer kullanım'), findsOneWidget);
    expect(find.text('7 işlem'), findsOneWidget);
    expect(find.textContaining('kalan hak veya limit tahmini değildir'), findsOneWidget);
    expect(find.text('Dil: Doğrulanamadı'), findsOneWidget);
  });

  testWidgets('Profile exposes configured support contact without inventing one', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor()),
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
      accountOverview: const _ReadyAccountOverviewGateway(),
    );

    String? copiedSupportEmail;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileSurface(
            runtime: runtime,
            supportEmail: 'destek@example.com',
            clipboardWriter: (value) async {
              copiedSupportEmail = value;
            },
          ),
        ),
      ),
    );
    await pumpUntilFound(tester, find.text('Profil ve Ayarlar'));
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -900));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('destek@example.com'), findsOneWidget);
    await tapVisible(tester, find.text('Destek e-postasını kopyala'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(copiedSupportEmail, 'destek@example.com');
  });

  testWidgets('Profile keeps support usable when clipboard write fails', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor()),
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
      accountOverview: const _ReadyAccountOverviewGateway(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileSurface(
            runtime: runtime,
            supportEmail: 'destek@example.com',
            clipboardWriter: (_) async => throw StateError('clipboard unavailable'),
          ),
        ),
      ),
    );
    await pumpUntilFound(tester, find.text('Profil ve Ayarlar'));
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -900));
    await tester.pump(const Duration(milliseconds: 300));

    await tapVisible(tester, find.text('Destek e-postasını kopyala'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Destek e-postası kopyalanamadı'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Profile fails closed when support contact is not configured', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor()),
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
      accountOverview: const _ReadyAccountOverviewGateway(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileSurface(runtime: runtime, supportEmail: ''),
      ),
    );
    await pumpUntilFound(tester, find.text('Profil ve Ayarlar'));
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -900));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Destek iletişim kanalı henüz yapılandırılmadı'), findsOneWidget);
    expect(find.text('Destek e-postasını kopyala'), findsNothing);
  });

  testWidgets('app sign out returns to account entry without deleting learner data', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
      accountOverview: const _ReadyAccountOverviewGateway(),
    );
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: AppRuntime.primaryMaterialId,
      text: 'Oturum kapansa da bu yerel materyal hesap silme olmadan silinmemelidir.',
      sourceName: 'Oturum koruma notu',
    );
    var signOutCalls = 0;

    await tester.pumpWidget(
      SesliOgrenApp(
        restoreSession: () async => runtime.learner,
        openRuntime: (_) async => runtime,
        signOutSession: () async {
          signOutCalls += 1;
        },
      ),
    );
    await pumpUntilFound(tester, find.byType(NavigationBar));
    await tapBottomNavIcon(tester, Icons.person_outline_rounded);
    await pumpUntilFound(tester, find.text('Profil ve Ayarlar'));
    final profileScroll = find.descendant(
      of: find.byKey(const ValueKey('profile-surface')),
      matching: find.byType(Scrollable),
    );
    final signOut = find.widgetWithText(OutlinedButton, 'Bu cihazda çıkış yap');
    await scrollUntilFound(tester, signOut, scrollable: profileScroll);
    await tapVisible(tester, signOut);
    await pumpUntilFound(tester, find.text('Bu cihazda çıkış yap?'));
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Çıkış yap'));
    await pumpUntilFound(tester, find.text('Öğrenme alanına gir'));

    expect(signOutCalls, 1);
    expect(find.text('Kod gönder'), findsOneWidget);
  });

  testWidgets('Profile sign out requires confirmation and preserves learner local data', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    var signOutCalls = 0;
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
      accountOverview: const _ReadyAccountOverviewGateway(),
    );
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: AppRuntime.primaryMaterialId,
      text: 'Çıkış yapmak bu learner verisini silmemelidir.',
      sourceName: 'Korunacak oturum verisi',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ProductShellScreen(
          runtime: runtime,
          onSignOut: () async {
            signOutCalls += 1;
          },
        ),
      ),
    );
    await pumpUntilFound(tester, find.text('Profil'));
    await tapVisible(tester, find.text('Profil').last);
    await pumpUntilFound(tester, find.text('Profil ve Ayarlar'));
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -420));
    await tester.pump(const Duration(milliseconds: 300));
    await tapVisible(tester, find.text('Bu cihazda çıkış yap'));
    await pumpUntilFound(tester, find.text('Bu cihazda çıkış yap?'));

    expect(signOutCalls, 0);
    await tapVisible(tester, find.text('Çıkış yap'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(signOutCalls, 1);
    expect(await store.material(learner: runtime.learner, materialId: AppRuntime.primaryMaterialId), isNotNull);
  });

  testWidgets('account deletion requires explicit confirmation and purges local data after remote success', (
    tester,
  ) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    final deletion = _RecordingAccountDeletionGateway();
    var deletedCallback = false;
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
      accountOverview: const _ReadyAccountOverviewGateway(),
      accountDeletion: deletion,
    );
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: AppRuntime.primaryMaterialId,
      text: 'Hesap silme sonrası bu yerel veri kalmamalıdır.',
      sourceName: 'Silinecek hesap verisi',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ProductShellScreen(runtime: runtime, onAccountDeleted: () => deletedCallback = true),
      ),
    );
    await pumpUntilFound(tester, find.text('Profil'));
    await tapVisible(tester, find.text('Profil').last);
    await pumpUntilFound(tester, find.text('Profil ve Ayarlar'));
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -720));
    await tester.pump(const Duration(milliseconds: 300));
    await tapVisible(tester, find.text('Hesabımı ve verilerimi sil'));
    await pumpUntilFound(tester, find.text('Hesabı ve verileri sil?'));
    await tapVisible(tester, find.text('Devam et'));
    await pumpUntilFound(tester, find.text('Son onay'));
    await tapVisible(tester, find.text('Kalıcı olarak sil'));

    for (var i = 0; i < 20 && !deletedCallback; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(deletion.calls, 1);
    expect(deletedCallback, isTrue);
    expect(await store.activeMaterials(learner: runtime.learner), isEmpty);
  });

  testWidgets('remote deletion is never resubmitted when only local cleanup failed', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(() async {
      try {
        await store.close();
      } catch (_) {}
    });
    final deletion = _RecordingAccountDeletionGateway();
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor()),
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
      accountOverview: const _ReadyAccountOverviewGateway(),
      accountDeletion: deletion,
    );
    var deletedCallback = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileSurface(runtime: runtime, onAccountDeleted: () => deletedCallback = true),
        ),
      ),
    );
    await pumpUntilFound(tester, find.text('Ücretsiz plan'));
    await store.close();

    final profileScroll = find.descendant(
      of: find.byKey(const ValueKey('profile-surface')),
      matching: find.byType(Scrollable),
    );
    final deleteAccount = find.widgetWithText(OutlinedButton, 'Hesabımı ve verilerimi sil');
    await scrollUntilFound(tester, deleteAccount, scrollable: profileScroll);
    await tester.tap(deleteAccount);
    await pumpUntilFound(tester, find.text('Hesabı ve verileri sil?'));
    await tester.tap(find.text('Devam et'));
    await pumpUntilFound(tester, find.text('Son onay'));
    await tester.tap(find.text('Kalıcı olarak sil'));
    await pumpUntilFound(tester, find.textContaining('Hesap sunucuda silindi ancak'));

    expect(deletion.calls, 1);
    expect(deletedCallback, isFalse);
    expect(find.text('Yerel veriyi temizlemeyi tekrar dene'), findsOneWidget);

    await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Yerel veriyi temizlemeyi tekrar dene'));
    await pumpUntilFound(tester, find.textContaining('Sunucuya yeni silme isteği gönderilmedi'));

    expect(deletion.calls, 1);
    expect(deletedCallback, isFalse);
  });

  test('failed remote account deletion preserves local learner data', () async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
      accountDeletion: const _FailingAccountDeletionGateway(),
    );
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: AppRuntime.primaryMaterialId,
      text: 'Remote silme başarısızsa yerel veri korunmalıdır.',
    );

    await expectLater(runtime.deleteAccount(), throwsA(isA<AccountDeletionException>()));
    expect(await store.material(learner: runtime.learner, materialId: AppRuntime.primaryMaterialId), isNotNull);
  });

  testWidgets('workspace Explain stays active self-explanation and fails closed without evaluator', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
    );
    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: AppRuntime.primaryMaterialId,
      text: 'Fotosentez ışık enerjisinin kimyasal enerjiye dönüşmesine yardımcı olur.',
      sourceName: 'Biyoloji notu',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LivingDeskReviewScope(child: ProductShellScreen(runtime: runtime)),
      ),
    );
    await pumpUntilFound(tester, find.byKey(const ValueKey('la0040-living-home-populated')));
    await tapVisible(tester, find.byKey(const ValueKey('la0040-living-material-open')));
    await pumpUntilFound(tester, find.byType(MaterialWorkspaceScreen));

    final otherPaths = find.widgetWithText(TextButton, 'Diğer yollar').hitTestable();
    await pumpUntilFound(tester, otherPaths);
    await tester.tap(otherPaths);
    await pumpUntilFound(tester, find.byKey(const ValueKey('workspace-other-study-paths-scroll')));
    await tapVisible(tester, find.text('Kendi cümlelerimle anlat'));
    await pumpUntilFound(tester, find.text('Anlatımımı değerlendir'));

    expect(find.text('Kendi cümlelerinle anlat'), findsOneWidget);
    expect(find.text('Kaynağına dayalı açıklama'), findsNothing);
    expect(find.textContaining('öğrenme kanıtı veya ustalık iddiası oluşturmaz'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür.');
    await tapVisible(tester, find.text('Anlatımımı değerlendir'));
    await pumpUntilFound(tester, find.text('Henüz güvenilir değerlendirme yok'));
    await tester.pump();

    expect(find.textContaining('öğrenme kanıtı olarak kaydetmiyoruz'), findsOneWidget);
    final companion = tester.widget<CompanionView>(find.byType(CompanionView).first);
    expect(companion.state, CompanionVisualState.think);
    expect(find.bySemanticsLabel('Düğüm destek oluyor'), findsNothing);
    expect(find.text('Anlatımında temel fikirler görünüyor'), findsNothing);
  });

  testWidgets('answer exposure survives close and reopen without becoming independent', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);

    final ingest = SourceIngestService(
      store: store,
      pdfTextExtractor: const _UnusedPdfExtractor(),
      now: () => DateTime.utc(2026, 10, 4, 17),
    );
    final recall = RecallLearningService(
      sourceStore: store,
      learningStore: store.learningTruthStore(),
      now: () => DateTime.utc(2026, 10, 4, 17, 1),
    );
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: recall,
      telemetry: store.operationalTelemetry(),
    );

    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: AppRuntime.primaryMaterialId,
      text:
          'Fotosentez sırasında klorofil ışık enerjisini kimyasal enerjiye '
          'dönüştürmeye yardımcı olur. Bitkiler bu süreçte karbondioksit kullanır.',
    );
    final prompt = await recall.createCurrentPrompt(learner: runtime.learner, materialId: AppRuntime.primaryMaterialId);
    final action = await store.learningTruthStore().recallAction(learner: runtime.learner, actionId: prompt.id);
    expect(action, isNotNull);

    await tester.pumpWidget(testShell(runtime));
    await pumpUntilFound(tester, find.text('Hatırla'));
    expect(find.text('Hatırla'), findsOneWidget);

    await tapVisible(tester, find.text('Yanıtı göster'));
    await pumpUntilFound(tester, find.textContaining('Yanıt:'));
    expect(find.textContaining('Yanıt:'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: LearningSliceScreen(key: const ValueKey('reopened-supported-attempt'), runtime: runtime),
        ),
      ),
    );
    await pumpUntilFound(tester, find.text('Hatırla'));

    expect(find.text('Hatırla'), findsOneWidget);
    expect(find.textContaining('yanıt daha önce gösterildi'), findsOneWidget);

    await tester.enterText(find.byType(TextField), action!.expectedAnswer);
    await tapVisible(tester, find.text('Yanıtla'));
    await pumpUntilFound(tester, find.textContaining('geri çağırma başarısı olarak sayılmadı'));

    expect(find.text('İpucusuz hatırladın'), findsNothing);
    expect(find.textContaining('geri çağırma başarısı olarak sayılmadı'), findsOneWidget);
  });

  testWidgets('unknown Recall repairs from the focused source and retries directly', (tester) async {
    usePhoneViewport(tester);
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    final recall = RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore());
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: recall,
      telemetry: store.operationalTelemetry(),
    );

    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: AppRuntime.primaryMaterialId,
      text:
          'Fotosentez sırasında klorofil ışık enerjisini kimyasal enerjiye dönüştürmeye yardımcı olur. '
          'Bitkiler bu süreçte karbondioksit kullanır ve oksijen açığa çıkarır. '
          'Mitokondri hücresel solunumla kullanılabilir enerji üretimine katkı sağlar.',
      sourceName: 'Biyoloji onarım notu',
    );
    final prompt = await recall.createCurrentPrompt(learner: runtime.learner, materialId: AppRuntime.primaryMaterialId);
    final action = await store.learningTruthStore().recallAction(learner: runtime.learner, actionId: prompt.id);
    expect(action, isNotNull);

    await tester.pumpWidget(testShell(runtime));
    await pumpUntilFound(tester, find.text('Hatırla'));
    await tapVisible(tester, find.text('Bilmiyorum'));
    await pumpUntilFound(tester, find.text('Geri bildirim'));
    await tapVisible(tester, find.text('Kaynağı gözden geçir'));
    await pumpUntilFound(tester, find.text('Bu bölümü yeniden kur'));

    expect(find.textContaining(action!.expectedAnswer), findsWidgets);
    expect(find.bySemanticsLabel('Kaynak bölümü. Çalışılacak cümle vurgulandı.'), findsOneWidget);
    expect(find.byKey(const ValueKey('atelier-source-trust')), findsOneWidget);

    final retryFromSource = find.byKey(const ValueKey('focused-source-retry'));
    await tester.pump(const Duration(milliseconds: 450));
    expect(retryFromSource, findsOneWidget);
    await tapVisible(tester, retryFromSource);
    await pumpUntilGone(tester, find.text('Bu bölümü yeniden kur'));
    await pumpUntilFound(tester, find.text('Hatırla'));
    expect(find.text('Yanıtla'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('auto-advances the persisted Home next action into focused source repair', (tester) async {
    usePhoneViewport(tester);
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    final recall = RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore());
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: recall,
      telemetry: store.operationalTelemetry(),
    );

    await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: AppRuntime.primaryMaterialId,
      text:
          'Fotosentez sırasında klorofil ışık enerjisini kimyasal enerjiye dönüştürmeye yardımcı olur. '
          'Bitkiler bu süreçte karbondioksit kullanır ve oksijen açığa çıkarır.',
      sourceName: 'Biyoloji devam notu',
    );

    await tester.pumpWidget(testShell(runtime));
    await pumpUntilFound(tester, find.text('Hatırla'));
    await tapVisible(tester, find.text('Bilmiyorum'));
    await pumpUntilFound(tester, find.text('Geri bildirim'));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: LearningSliceScreen(
            key: const ValueKey('auto-advance-needs-review'),
            runtime: runtime,
            autoAdvanceContinuation: true,
          ),
        ),
      ),
    );

    await pumpUntilFound(tester, find.text('Bu bölümü yeniden kur'));
    expect(find.text('Kaynağı kapat ve yeniden dene'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Workspace exposes source replacement without creating a second material', (tester) async {
    usePhoneViewport(tester);
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
    );
    const materialId = MaterialId('workspace-source-update');
    final original = await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: materialId,
      text: 'İlk kaynak sürümü hücre ve enerji hakkında yeterince uzun bir açıklama içerir.',
      sourceName: 'İlk çalışma kaynağı',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LivingDeskReviewScope(
          child: MaterialWorkspaceScreen(runtime: runtime, materialId: materialId),
        ),
      ),
    );
    await pumpUntilFound(tester, find.byKey(const ValueKey('la0040-atelier-workspace-update-source')));
    await tapVisible(tester, find.byKey(const ValueKey('la0040-atelier-workspace-update-source')));
    await pumpUntilFound(tester, find.text('KAYNAĞI GÜNCELLE'));

    await tapVisible(tester, find.text('Metin yapıştır'));
    await pumpUntilFound(tester, find.byKey(const ValueKey('pasted-material-text')));
    await tester.enterText(
      find.byKey(const ValueKey('pasted-material-text')),
      'Yeni kaynak sürümü mitokondri ve hücresel solunum hakkında güncel bilgi içerir.',
    );
    await tapVisible(tester, find.byKey(const ValueKey('source-text-submit')));
    await pumpUntilFound(tester, find.byKey(const ValueKey('la0040-atelier-workspace-update-source')));

    final current = await store.currentSourceVersion(learner: runtime.learner, materialId: materialId);
    final materials = await store.activeMaterials(learner: runtime.learner);
    expect(current, isNotNull);
    expect(current!.identity.materialId, materialId);
    expect(current.identity.sourceVersionId, isNot(original.sourceVersion.identity.sourceVersionId));
    expect(materials, hasLength(1));
    expect(materials.single.id, materialId);
    expect(tester.takeException(), isNull);
  });

  testWidgets('source replacement proactively removes the superseded server mirror', (tester) async {
    usePhoneViewport(tester);
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    final recall = RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore());
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: recall,
      telemetry: store.operationalTelemetry(),
    );
    final gateway = _RecordingSourceCleanupGateway();

    final original = await ingest.ingestPastedText(
      learner: runtime.learner,
      materialId: AppRuntime.primaryMaterialId,
      text: 'Eski kaynak metni fotosentez hakkında bilgi verir ve artık değiştirilecektir.',
      sourceName: 'Eski kaynak',
    );
    await store.saveSummaryJob(
      learner: runtime.learner,
      materialId: AppRuntime.primaryMaterialId,
      sourceVersionId: original.sourceVersion.identity.sourceVersionId,
      serverMaterialId: '55555555-5555-4555-8555-555555555555',
      jobId: '66666666-6666-4666-8666-666666666666',
    );
    final prompt = await recall.createCurrentPrompt(learner: runtime.learner, materialId: AppRuntime.primaryMaterialId);
    final session = await recall.openAttempt(learner: runtime.learner, actionId: prompt.id);
    await recall.submit(
      learner: runtime.learner,
      actionId: prompt.id,
      attemptId: session.attempt.attemptId,
      disposition: RecallResponseDisposition.unknown,
      answer: '',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: LearningSliceScreen(runtime: runtime, sourceGateway: gateway),
        ),
      ),
    );
    await pumpUntilFound(tester, find.text('Materyali güncelle'));
    await tapVisible(tester, find.text('Materyali güncelle'));
    final editorScroll = find.descendant(of: find.byType(LearningSliceScreen), matching: find.byType(Scrollable));
    await scrollUntilFound(tester, find.text('Metin yapıştır'), scrollable: editorScroll);
    await tapVisible(tester, find.text('Metin yapıştır'));
    await tester.enterText(
      find.byKey(const ValueKey('pasted-material-text')),
      'Yeni kaynak sürümü mitokondri ve hücresel solunum hakkında ayrı bilgi verir.',
    );
    await tapVisible(tester, find.text('Yeni sürümü ekle ve aç'));
    for (var i = 0; i < 80 && gateway.deletedMaterialIds.isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    final current = await store.currentSourceVersion(
      learner: runtime.learner,
      materialId: AppRuntime.primaryMaterialId,
    );
    expect(current, isNotNull);
    expect(current!.identity.sourceVersionId, isNot(original.sourceVersion.identity.sourceVersionId));
    expect(gateway.deletedMaterialIds, ['55555555-5555-4555-8555-555555555555']);
    expect(
      await store.summaryServerMaterialId(learner: runtime.learner, materialId: AppRuntime.primaryMaterialId),
      isNull,
    );
    expect(
      await store.summaryJobId(
        learner: runtime.learner,
        materialId: AppRuntime.primaryMaterialId,
        sourceVersionId: original.sourceVersion.identity.sourceVersionId,
      ),
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('source acquisition asks for one source path before showing the text form', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor()),
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5), disableAnimations: true),
          child: LivingDeskReviewScope(child: LearningSliceScreen(runtime: runtime)),
        ),
      ),
    );
    await pumpUntilFound(tester, find.text('PDF seç'));

    expect(find.text('PDF seç'), findsOneWidget);
    expect(find.text('Metin yapıştır'), findsOneWidget);
    expect(find.byKey(const ValueKey('pasted-material-text')), findsNothing);

    await tapVisible(tester, find.text('Metin yapıştır'));
    await tester.pump();

    expect(find.byKey(const ValueKey('pasted-material-text')), findsOneWidget);
    expect(find.byKey(const ValueKey('pasted-material-title')), findsNothing);
    expect(find.text('Başlık ekle · isteğe bağlı'), findsOneWidget);
    expect(find.text('Metni ekle · çalışma alanını aç'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('pasted-material-text')),
      'Fotosentez ve ışık. Klorofil, ışık enerjisinin yakalanmasına yardım eder.',
    );
    await tapVisible(tester, find.text('Metni ekle · çalışma alanını aç'));
    final sourceFlowScroll = find.descendant(of: find.byType(LearningSliceScreen), matching: find.byType(Scrollable));
    await scrollUntilFound(tester, find.byKey(const ValueKey('recall')), scrollable: sourceFlowScroll);

    final material = await store.material(learner: runtime.learner, materialId: AppRuntime.primaryMaterialId);
    expect(material, isNotNull);
    expect(material!.title, 'Fotosentez ve ışık');
  });

  testWidgets('Reduced Motion keeps the learning slice usable', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor()),
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: LearningSliceScreen(runtime: runtime),
        ),
      ),
    );
    await pumpUntilFound(tester, find.text('Çalışma materyalini ekle'));

    expect(find.text('Çalışma materyalini ekle'), findsOneWidget);
    expect(find.text('Kaynağı ekle ve aç'), findsOneWidget);
  });
}
