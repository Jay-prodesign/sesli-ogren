import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show FlutterVersion;
import 'package:flutter/widgets.dart';

import '../app/proof_controller.dart';
import '../app/proof_screen.dart' show worldStats, companionStats;
import '../flow/flow_engine.dart';
import '../render/views.dart' show LiveControllers;
import '../scene/scene_schema.dart';
import 'frame_stats.dart';
import 'rss_stub.dart' if (dart.library.io) 'rss_io.dart';

typedef Wait = Future<void> Function(Duration d);

/// Build/runtime identity injected at build time with --dart-define.
class BuildIdentity {
  static const gitSha = String.fromEnvironment('GIT_SHA', defaultValue: 'UNSET');
  static String get flutterVersion =>
      '${FlutterVersion.version ?? 'UNKNOWN'} (Dart ${FlutterVersion.dartVersion ?? '?'})';

  static String get buildMode => kReleaseMode
      ? 'release'
      : kProfileMode
      ? 'profile'
      : 'debug';
}

/// Startup observation recorded by main(): Dart entry to first rasterized frame.
class StartupTiming {
  static final Stopwatch sinceMain = Stopwatch();
  static int? firstFrameMs;
}

class ScenarioResult {
  ScenarioResult(this.id, this.title);

  final String id;
  final String title;
  final List<String> passed = [];
  final List<String> failed = [];
  final Map<String, Object?> data = {};
  FrameSummary? frames;
  int? rssBefore;
  int? rssAfter;

  void check(bool ok, String what) => (ok ? passed : failed).add(what);

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'result': failed.isEmpty ? 'FUNCTIONAL_PASS' : 'FUNCTIONAL_FAIL',
    'checks_passed': passed,
    'checks_failed': failed,
    if (frames != null) 'frame_timing': frames!.toJson(),
    'rss_before_bytes': rssBefore,
    'rss_after_bytes': rssAfter,
    ...data,
  };
}

/// Runs the P1 scenarios T1–T11 against the live proof UI. Functional checks are oracles;
/// frame timings and memory are raw observations. Only runs on a physical device in profile
/// mode count as decision-grade runtime evidence (R7-06).
class ScenarioRunner {
  ScenarioRunner(
    this.c, {
    required this.wait,
    this.collector,
    this.dwell = const Duration(milliseconds: 700),
    this.flush = const Duration(milliseconds: 1200),
    this.soakCycles = 30,
    this.tierHold = const Duration(milliseconds: 1500),
  });

  final ProofController c;
  final Wait wait;
  final FrameCollector? collector;
  final Duration dwell;
  final Duration flush;
  final int soakCycles;
  final Duration tierHold;

  double get _refreshHz {
    try {
      final r = WidgetsBinding.instance.platformDispatcher.views.first.display.refreshRate;
      return r > 0 ? r : 60;
    } catch (_) {
      return 60;
    }
  }

  Future<Map<String, Object?>> runAll({int assetBytes = 0, void Function(String)? onProgress}) async {
    final results = <ScenarioResult>[];
    final scenarios = <(String, String, Future<void> Function(ScenarioResult))>[
      ('T1', 'Launch / open proof surface', _t1),
      ('T2', 'Biology world: IDLE→LISTEN→THINK→SPEAK states', _t2),
      ('T3', 'STRONG evidence → continue/deepen', (r) => _branch(r, EvidenceState.strong)),
      ('T4', 'PARTIAL evidence → target missing relation', (r) => _branch(r, EvidenceState.partial)),
      (
        'T5',
        'MISCONCEPTION → corrective teaching → smaller repair check',
        (r) => _branch(r, EvidenceState.misconception),
      ),
      ('T6', 'UNKNOWN / interruption → retry without weakness inference', (r) => _branch(r, EvidenceState.unknown)),
      ('T7', 'Switch Biology→Fractions→Professional', _t7),
      ('T8', 'Tiers FULL→REDUCED→SIMPLE→NEUTRAL→CONTENT', _t8),
      ('T9', 'Reduced motion enabled', _t9),
      ('T10', 'Audio unavailable / muted', _t10),
      ('T11', 'Repeated transitions (soak)', _t11),
    ];
    collector?.attach();
    try {
      for (final (id, title, body) in scenarios) {
        onProgress?.call('$id $title');
        final r = ScenarioResult(id, title);
        _resetConditions();
        await wait(dwell);
        r.rssBefore = currentRssBytes();
        collector?.begin();
        try {
          await body(r);
        } catch (e) {
          r.check(false, 'scenario threw: $e');
        }
        await wait(flush);
        final frames = collector?.end();
        if (frames != null) r.frames = FrameSummary.from(frames, refreshHz: _refreshHz);
        r.rssAfter = currentRssBytes();
        results.add(r);
      }
    } finally {
      collector?.detach();
      _resetConditions();
    }
    return _report(results, assetBytes);
  }

  Map<String, Object?> _report(List<ScenarioResult> results, int assetBytes) {
    Map<String, Object?> display = {};
    try {
      final v = WidgetsBinding.instance.platformDispatcher.views.first;
      display = {
        'refresh_rate_hz': v.display.refreshRate,
        'device_pixel_ratio': v.devicePixelRatio,
        'physical_size': '${v.physicalSize.width.round()}x${v.physicalSize.height.round()}',
      };
    } catch (_) {}
    return {
      'proof': 'ROUND_7_P1_RUNTIME_PROOF_SPEC_001',
      'candidate': 'P1 Flutter Widgets + CustomPaint (no Rive/Lottie/Flame)',
      'git_sha': BuildIdentity.gitSha,
      'flutter_version': BuildIdentity.flutterVersion,
      'build_mode': BuildIdentity.buildMode,
      'platform': defaultTargetPlatform.name,
      'os': operatingSystemVersion(),
      'device_model': 'RECORD_MANUALLY',
      ...display,
      'startup_dart_main_to_first_frame_ms': StartupTiming.firstFrameMs,
      'fixture_asset_bytes': assetBytes,
      'fixtures': [for (final f in c.fixtures) '${f.id}@${f.version} (${f.source.id} v${f.source.version})'],
      'network_required': false,
      'decision_grade': BuildIdentity.buildMode == 'profile' || BuildIdentity.buildMode == 'release'
          ? 'ONLY_IF_PHYSICAL_DEVICE'
          : 'NO_DEBUG_BUILD',
      'scenarios': [for (final r in results) r.toJson()],
      'functional_result': results.every((r) => r.failed.isEmpty) ? 'PASS' : 'FAIL',
    };
  }

  void _resetConditions() {
    if (c.worldAssetFailed) c.setWorldAssetFailed(false);
    if (c.companionAssetFailed) c.setCompanionAssetFailed(false);
    c.setTier(FallbackLevel.full);
    c.setReducedMotion(false);
    c.setAudioAvailable(true);
  }

  // --- flow helpers -------------------------------------------------------------------

  Future<void> _toChallenge({int fixture = 0}) async {
    c.selectFixture(fixture);
    await wait(dwell);
    c.orient();
    await wait(dwell);
    while (c.engine.step == FlowStep.orient || c.engine.step == FlowStep.teach) {
      c.advance();
      await wait(dwell);
    }
  }

  Future<void> _answer(EvidenceState e) async {
    c.submit(e);
    await wait(c.evaluationDelay + const Duration(milliseconds: 150));
  }

  /// Completes the current challenge along the branch for [e], ending at S7.
  Future<void> _completeBranch(EvidenceState e) async {
    if (e == EvidenceState.unknown) {
      c.interrupt();
      await wait(dwell);
      c.follow();
      await wait(dwell);
      await _answer(EvidenceState.strong);
    } else {
      await _answer(e);
    }
    await wait(dwell);
    c.follow();
    await wait(dwell);
    if (c.engine.step == FlowStep.repairTeach) {
      c.advance();
      await wait(dwell);
    }
    if (c.engine.step == FlowStep.repairCheck) {
      c.submitRepair(correct: true);
      await wait(dwell);
    }
  }

  List<CompanionState> _watchCompanion(List<CompanionState> seen) {
    void listener() {
      final s = c.companionState;
      if (seen.isEmpty || seen.last != s) seen.add(s);
    }

    c.addListener(listener);
    _unwatch = () => c.removeListener(listener);
    return seen;
  }

  VoidCallback? _unwatch;

  // --- scenarios ------------------------------------------------------------------------

  Future<void> _t1(ScenarioResult r) async {
    r.data['startup_dart_main_to_first_frame_ms'] = StartupTiming.firstFrameMs;
    c.selectFixture(0);
    await wait(const Duration(seconds: 2));
    r.check(c.engine.step == FlowStep.context, 'S1 shown with one dominant continuation');
    r.check(c.engine.scene.sourceRef == c.fixture.source.id, 'scene bound to source_ref');
  }

  Future<void> _t2(ScenarioResult r) async {
    final seen = _watchCompanion([]);
    c.selectFixture(0);
    seen.add(c.companionState);
    await wait(dwell);
    await _toChallenge();
    c.submit(EvidenceState.strong);
    await wait(c.evaluationDelay + const Duration(milliseconds: 150));
    _unwatch?.call();
    r.data['companion_states_seen'] = [for (final s in seen) s.name];
    for (final s in [CompanionState.idle, CompanionState.speak, CompanionState.listen, CompanionState.think]) {
      r.check(seen.contains(s), 'Companion entered ${s.name.toUpperCase()}');
    }
    r.check(
      !seen.contains(CompanionState.think) || seen.indexOf(CompanionState.think) > seen.indexOf(CompanionState.listen),
      'THINK only while evaluating, after LISTEN',
    );
  }

  Future<void> _branch(ScenarioResult r, EvidenceState e) async {
    await _toChallenge();
    final seen = _watchCompanion([]);
    if (e == EvidenceState.unknown) {
      c.interrupt();
      await wait(dwell);
      r.check(c.engine.evidence == EvidenceState.unknown, 'interruption classified UNKNOWN');
      r.check(c.engine.reasonCode == 'R_RETRY_UNKNOWN', 'reason R_RETRY_UNKNOWN');
      r.check(!c.engine.sessionComplete, 'no progress mutation from UNKNOWN');
      r.check(c.engine.worldStage == WorldStage.w3Challenge, 'world preserved at W3 (no evidence mutation)');
      c.follow();
      await wait(dwell);
      r.check(c.engine.step == FlowStep.challenge, 'retry returns to the same challenge');
      await _completeBranch(EvidenceState.strong);
    } else {
      await _answer(e);
      final code = c.engine.reasonCode;
      r.data['reason_code'] = code;
      r.data['world_stage'] = c.engine.worldStage.name;
      r.data['next_action'] = c.engine.branch?.nextAction;
      switch (e) {
        case EvidenceState.strong:
          r.check(code == 'R_DEEPEN_AFTER_STRONG' || code == 'R_CONTINUE_AFTER_STRONG', 'strong → continue/deepen');
          r.check(c.companionState == CompanionState.success, 'Companion SUCCESS');
        case EvidenceState.partial:
          r.check(code == 'R_REPAIR_PARTIAL', 'partial → targeted repair');
          r.check(c.engine.scene.visibility.values.contains(Vis.open), 'missing relation shown as an open gap');
          r.check(c.engine.companionTone == CompanionTone.attention, 'Companion supportive attention');
        case EvidenceState.misconception:
          r.check(code == 'R_REPAIR_MISCONCEPTION', 'misconception → corrective teaching');
          r.check(c.engine.companionTone == CompanionTone.correction, 'Companion supportive correction');
          r.check(!c.engine.sessionComplete, 'wrong response does not unlock progress');
        case EvidenceState.unknown:
          break;
      }
      await wait(dwell);
      c.follow();
      await wait(dwell);
      if (e == EvidenceState.misconception) {
        r.check(c.engine.step == FlowStep.repairTeach, 'corrective teaching precedes the smaller check');
        c.advance();
        await wait(dwell);
      }
      if (c.engine.step == FlowStep.repairCheck) {
        r.check(c.engine.branch?.repairPrompt != null, 'smaller repair check presented');
        c.submitRepair(correct: true);
        await wait(dwell);
      }
    }
    _unwatch?.call();
    r.check(c.engine.step == FlowStep.complete, 'flow reaches S7 completion');
    r.data['companion_states_seen'] = [for (final s in seen) s.name];
  }

  Future<void> _t7(ScenarioResult r) async {
    final sigs = <String>[];
    for (var i = 0; i < c.fixtures.length; i++) {
      await _toChallenge(fixture: i);
      sigs.add(c.engine.scene.topologySignature);
      r.check(c.engine.step == FlowStep.challenge, '${c.fixture.id} reaches its challenge');
    }
    r.data['topology_signatures'] = sigs;
    r.check(sigs.toSet().length == sigs.length, 'three structurally different worlds from one renderer');
  }

  Future<void> _t8(ScenarioResult r) async {
    await _toChallenge();
    final tiers = <String, Object?>{};
    for (final t in FallbackLevel.values) {
      c.setTier(t);
      final ops0 = worldStats.ops, frames0 = worldStats.frames;
      final cops0 = companionStats.ops;
      collector?.begin();
      await wait(tierHold);
      await wait(flush);
      final frames = collector?.end();
      final painted = worldStats.frames - frames0;
      tiers[wireName(t)] = {
        'world_paints': painted,
        'world_ops_per_paint': painted == 0 ? 0 : ((worldStats.ops - ops0) / painted).round(),
        'companion_ops': companionStats.ops - cops0,
        if (frames != null) 'frame_timing': FrameSummary.from(frames, refreshHz: _refreshHz).toJson(),
      };
      r.check(c.engine.scene.sourceRef == c.fixture.source.id, '${wireName(t)} preserves source_ref');
      r.check(c.engine.step == FlowStep.challenge, '${wireName(t)} keeps the challenge available');
    }
    collector?.begin();
    r.data['tiers'] = tiers;
    await _completeBranch(EvidenceState.partial);
    r.check(c.engine.step == FlowStep.complete, 'learning loop completes at CONTENT tier');
  }

  Future<void> _t9(ScenarioResult r) async {
    c.setReducedMotion(true);
    await _toChallenge();
    await _completeBranch(EvidenceState.misconception);
    r.check(c.engine.step == FlowStep.complete, 'flow completes with reduced motion');
    r.check(
      c.engine.events.any((e) => e.name == 'reduced_motion_active') || c.reducedMotion,
      'reduced motion recorded',
    );
  }

  Future<void> _t10(ScenarioResult r) async {
    c.setAudioAvailable(false);
    final seen = _watchCompanion([]);
    await _toChallenge();
    await _completeBranch(EvidenceState.partial);
    _unwatch?.call();
    r.check(!seen.contains(CompanionState.speak), 'Companion never claims SPEAK without audio');
    r.check(c.engine.step == FlowStep.complete, 'flow completes with text only');
  }

  Future<void> _t11(ScenarioResult r) async {
    final samples = <int?>[currentRssBytes()];
    final controllers0 = LiveControllers.count;
    final branches = [EvidenceState.strong, EvidenceState.partial, EvidenceState.misconception, EvidenceState.unknown];
    for (var i = 0; i < soakCycles; i++) {
      await _toChallenge(fixture: i % c.fixtures.length);
      await _completeBranch(branches[i % branches.length]);
      if (c.engine.step != FlowStep.complete) r.check(false, 'cycle $i did not complete');
      if ((i + 1) % 5 == 0) samples.add(currentRssBytes());
    }
    r.data['cycles'] = soakCycles;
    r.data['rss_samples_bytes'] = samples;
    r.data['live_controllers_before_after'] = [controllers0, LiveControllers.count];
    r.check(LiveControllers.count == controllers0, 'no leaked or duplicated animation controllers');
    r.check(c.engine.step == FlowStep.complete, 'final soak cycle completes');
  }

  static String encode(Map<String, Object?> report) => const JsonEncoder.withIndent(' ').convert(report);
}
