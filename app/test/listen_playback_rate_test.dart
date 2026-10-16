import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:sesli_ogren/src/app/app_runtime.dart';
import 'package:sesli_ogren/src/app/listen_screen.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';
import 'package:sesli_ogren/src/data/source_ingest_service.dart';
import 'package:sesli_ogren/src/data/sqlite_source_store.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sesli_ogren/src/learning/recall_learning_service.dart';
import 'package:sesli_ogren/src/speech/device_speech_output.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _UnusedPdfExtractor implements PdfTextExtractor {
  const _UnusedPdfExtractor();

  @override
  Future<ExtractedPdf> extract(Uint8List bytes, {required String sourceName}) {
    throw UnimplementedError();
  }
}

class _UnavailableTurkishFlutterTts extends FlutterTts {
  var speakCalls = 0;

  @override
  Future<dynamic> stop() async => 1;

  @override
  Future<dynamic> isLanguageAvailable(String language) async => false;

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    speakCalls += 1;
    return 1;
  }
}

class _ThrowingSpeechOutput implements SpeechOutput {
  @override
  Future<void> speak(
    String text, {
    required String locale,
    required VoidCallback onStart,
    required VoidCallback onDone,
    required ValueChanged<Object> onError,
    double rateMultiplier = 1.0,
  }) {
    throw StateError('speech provider unavailable');
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

class _StopFailingSpeechOutput implements SpeechOutput {
  VoidCallback? _onDone;
  int stopCalls = 0;

  @override
  Future<void> speak(
    String text, {
    required String locale,
    required VoidCallback onStart,
    required VoidCallback onDone,
    required ValueChanged<Object> onError,
    double rateMultiplier = 1.0,
  }) async {
    _onDone = onDone;
    onStart();
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
    throw StateError('native stop failed');
  }

  @override
  Future<void> dispose() async {}

  void finishUnexpectedly() => _onDone?.call();
}

class _RecordingSpeechOutput implements SpeechOutput {
  double? lastRateMultiplier;
  String? lastText;
  VoidCallback? _onDone;
  int stopCalls = 0;

  void finishCurrentChunk() {
    final callback = _onDone;
    _onDone = null;
    callback?.call();
  }

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

  @override
  Future<void> stop() async {
    stopCalls += 1;
  }

  @override
  Future<void> dispose() async {}
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder, {int maxPumps = 100}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Expected Listen widget was not reached within bounded pumps.');
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

void main() {
  sqfliteFfiInit();

  test('device speech fails closed when the requested Turkish locale is unavailable', () async {
    final tts = _UnavailableTurkishFlutterTts();
    final output = DeviceSpeechOutput(tts: tts);
    final errors = <Object>[];
    var started = false;

    await output.speak(
      'Türkçe kaynak metni',
      locale: 'tr-TR',
      onStart: () => started = true,
      onDone: () {},
      onError: errors.add,
    );

    expect(started, isFalse);
    expect(tts.speakCalls, 0);
    expect(errors, hasLength(1));
    expect(errors.single.toString(), contains('device_tts_language_unavailable:tr-TR'));
  });

  testWidgets('Listen exposes an in-place retry when the current source cannot be loaded', (tester) async {
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

    await tester.pumpWidget(
      MaterialApp(
        home: ListenScreen(
          runtime: runtime,
          materialId: const MaterialId('missing-listen-source'),
          speechOutput: _RecordingSpeechOutput(),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('Dinlenecek güncel kaynak bulunamadı.'));

    expect(find.text('Tekrar dene'), findsOneWidget);
    await tester.tap(find.text('Tekrar dene'));
    await _pumpUntilFound(tester, find.text('Dinlenecek güncel kaynak bulunamadı.'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing Listen source lets the learner return to the material', (tester) async {
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

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => ListenScreen(
                      runtime: runtime,
                      materialId: const MaterialId('missing-listen-source'),
                      speechOutput: _RecordingSpeechOutput(),
                    ),
                  ),
                ),
                child: const Text('Dinlemeyi aç'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Dinlemeyi aç'));
    await _pumpUntilFound(tester, find.text('Dinlenecek güncel kaynak bulunamadı.'));

    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(find.text('Materyale dön'), findsOneWidget);
    await tester.tap(find.text('Materyale dön'));
    await tester.pumpAndSettle();

    expect(find.text('Dinlemeyi aç'), findsOneWidget);
  });

  testWidgets('Listen never starts playback from a superseded source version', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    const materialId = MaterialId('listen-current-source-guard');
    await ingest.ingestPastedText(
      learner: AppRuntime.localM5LearnerFixture,
      materialId: materialId,
      text: 'Eski kaynak fotosentezin ışık enerjisini kimyasal enerjiye dönüştürdüğünü anlatır.',
      sourceName: 'Eski biyoloji notu',
    );
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
    );
    final speech = _RecordingSpeechOutput();

    await tester.pumpWidget(
      MaterialApp(
        home: ListenScreen(runtime: runtime, materialId: materialId, speechOutput: speech),
      ),
    );
    await _pumpUntilFound(tester, find.textContaining('Eski kaynak fotosentezin'));

    await ingest.ingestPastedText(
      learner: AppRuntime.localM5LearnerFixture,
      materialId: materialId,
      text: 'Yeni kaynak mitokondrinin hücresel solunum sırasında enerji üretimine katkısını anlatır.',
      sourceName: 'Yeni biyoloji notu',
    );

    await _tapVisible(tester, find.text('Dinlemeye başla'));
    await _pumpUntilFound(tester, find.textContaining('Yeni kaynak mitokondrinin'));

    expect(speech.lastText, isNull);
    expect(find.textContaining('Eski kaynak fotosentezin'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Listen persists playback speed and passes it to device speech', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    const materialId = MaterialId('listen-speed-material');
    await ingest.ingestPastedText(
      learner: AppRuntime.localM5LearnerFixture,
      materialId: materialId,
      text: 'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürmeye yardımcı olur.',
      sourceName: 'Biyoloji notu',
    );
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
    );

    final firstSpeech = _RecordingSpeechOutput();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: ListenScreen(runtime: runtime, materialId: materialId, speechOutput: firstSpeech),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('Dinleme hızı'));
    expect(find.bySemanticsLabel('Dinleme ilerlemesi'), findsOneWidget);
    await _tapVisible(tester, find.text('1.25×'));
    await tester.pump(const Duration(milliseconds: 50));

    expect(await store.listenRate(learner: runtime.learner), 1.25);

    await _tapVisible(tester, find.text('Dinlemeye başla'));
    await tester.pump();
    expect(firstSpeech.lastRateMultiplier, 1.25);
    expect(
      tester.widget<LinearProgressIndicator>(find.byKey(const ValueKey('listen-progress'), skipOffstage: false)).value,
      0,
    );

    firstSpeech.finishCurrentChunk();
    await tester.pump(const Duration(milliseconds: 120));
    final listenScrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
    listenScrollable.position.jumpTo(0);
    await tester.pump();
    await _pumpUntilFound(tester, find.text('Tüm bölümler dinlendi · Hatırlamayı deneyebilirsin'));
    expect(
      tester.widget<LinearProgressIndicator>(find.byKey(const ValueKey('listen-progress'), skipOffstage: false)).value,
      1,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    final secondSpeech = _RecordingSpeechOutput();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: ListenScreen(runtime: runtime, materialId: materialId, speechOutput: secondSpeech),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('Dinleme hızı'));
    await _tapVisible(tester, find.text('Dinlemeye başla'));
    await tester.pump();

    expect(secondSpeech.lastRateMultiplier, 1.25);
  });

  testWidgets('Listen opens Recall without touching native speech when playback never started', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    const materialId = MaterialId('listen-recall-without-playback');
    await ingest.ingestPastedText(
      learner: AppRuntime.localM5LearnerFixture,
      materialId: materialId,
      text: 'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürmeye yardımcı olur.',
      sourceName: 'Biyoloji kaynağı',
    );
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
    );
    final speech = _StopFailingSpeechOutput();
    var recallOpens = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ListenScreen(
          runtime: runtime,
          materialId: materialId,
          speechOutput: speech,
          onRecall: () => recallOpens++,
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('Şimdi hatırlamayı dene'));
    await _tapVisible(tester, find.text('Şimdi hatırlamayı dene'));
    await tester.pump();

    expect(recallOpens, 1);
    expect(speech.stopCalls, 0);
    expect(find.textContaining('Hatırla açılmadı'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Listen never opens source-hidden Recall while native speech may still be audible', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    const materialId = MaterialId('listen-stop-failure');
    await ingest.ingestPastedText(
      learner: AppRuntime.localM5LearnerFixture,
      materialId: materialId,
      text: 'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürmeye yardımcı olur.',
      sourceName: 'Biyoloji kaynağı',
    );
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
    );
    final speech = _StopFailingSpeechOutput();
    var recallOpens = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ListenScreen(
          runtime: runtime,
          materialId: materialId,
          speechOutput: speech,
          onRecall: () => recallOpens++,
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('Dinlemeye başla'));
    await _tapVisible(tester, find.text('Dinlemeye başla'));
    await tester.pump();

    expect(find.text('Durdur'), findsOneWidget);
    await _tapVisible(tester, find.text('Şimdi hatırlamayı dene'));
    await tester.pump();

    expect(recallOpens, 0);
    expect(speech.stopCalls, 1);
    expect(find.textContaining('Hatırla açılmadı'), findsOneWidget);
    expect(find.text('Durdur'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Listen preserves intentional background playback across app lifecycle changes', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    const materialId = MaterialId('listen-background-lifecycle');
    await ingest.ingestPastedText(
      learner: AppRuntime.localM5LearnerFixture,
      materialId: materialId,
      text: List.filled(
        18,
        'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür ve klorofil ışığın soğurulmasına yardım eder.',
      ).join(' '),
      sourceName: 'Uzun biyoloji kaynağı',
    );
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
    );
    final speech = _RecordingSpeechOutput();

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: ListenScreen(runtime: runtime, materialId: materialId, speechOutput: speech),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('Dinlemeye başla'));
    await _tapVisible(tester, find.text('Dinlemeye başla'));
    await tester.pump();
    expect(find.text('Durdur'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(speech.stopCalls, 0);
    expect(find.text('Durdur'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(speech.stopCalls, 0);
    expect(find.text('Durdur'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Listen remains operable with semantics at 320px and 200% text scale', (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);

    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    const materialId = MaterialId('listen-accessibility-200');
    await ingest.ingestPastedText(
      learner: AppRuntime.localM5LearnerFixture,
      materialId: materialId,
      text: 'Fotosentez ışık enerjisini kimyasal enerjiye dönüştürmeye yardımcı olur.',
      sourceName: 'Biyoloji erişilebilirlik kaynağı',
    );
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true, textScaler: TextScaler.linear(2)),
          child: ListenScreen(runtime: runtime, materialId: materialId, speechOutput: _RecordingSpeechOutput()),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.bySemanticsLabel('Dinleme ilerlemesi'));
    expect(find.bySemanticsLabel('Dinleme ilerlemesi'), findsOneWidget);
    expect(find.bySemanticsLabel('Düğüm hazır'), findsOneWidget);

    final play = find.text('Dinlemeye başla');
    await tester.scrollUntilVisible(play, 180, scrollable: find.byType(Scrollable).first);
    await tester.pump();
    expect(play.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Listen keeps the source usable when the speech provider throws', (tester) async {
    final store = await SqliteSourceStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.close);
    final ingest = SourceIngestService(store: store, pdfTextExtractor: const _UnusedPdfExtractor());
    const materialId = MaterialId('listen-provider-failure');
    await ingest.ingestPastedText(
      learner: AppRuntime.localM5LearnerFixture,
      materialId: materialId,
      text: 'Klorofil ışık enerjisinin soğurulmasına yardım eder.',
      sourceName: 'Biyoloji kaynağı',
    );
    final runtime = AppRuntime(
      learner: AppRuntime.localM5LearnerFixture,
      store: store,
      ingest: ingest,
      recall: RecallLearningService(sourceStore: store, learningStore: store.learningTruthStore()),
      telemetry: store.operationalTelemetry(),
    );
    var recallOpens = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ListenScreen(
          runtime: runtime,
          materialId: materialId,
          speechOutput: _ThrowingSpeechOutput(),
          onRecall: () => recallOpens++,
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('Dinlemeye başla'));

    await _tapVisible(tester, find.text('Dinlemeye başla'));
    await tester.pump();

    expect(find.textContaining('Kaynağın ve dinleme konumun korunuyor'), findsOneWidget);
    expect(find.text('Klorofil ışık enerjisinin soğurulmasına yardım eder.'), findsWidgets);
    expect(find.byKey(const ValueKey('listen-current-source-segment')), findsOneWidget);
    expect(find.byKey(const ValueKey('listen-source-transcript')), findsOneWidget);
    expect(find.text('Şimdi hatırlamayı dene'), findsOneWidget);
    await _tapVisible(tester, find.text('Şimdi hatırlamayı dene'));
    await tester.pump();

    expect(recallOpens, 1);
    expect(tester.takeException(), isNull);
  });
}
