import 'dart:async';

import 'package:flutter/foundation.dart';

import '../flow/flow_engine.dart';
import '../scene/fixture.dart';
import '../scene/scene_schema.dart';
import '../speech/device_speech_output.dart';

enum CompanionIdentity { knot, tilt }

/// Holds the proof session: fixture choice, companion identity, render tier,
/// accessibility/audio conditions and simulated capability failures. The benchmark
/// runner drives the same controller as the UI.
class ProofController extends ChangeNotifier {
  ProofController(this.fixtures, {this.evaluationDelay = const Duration(milliseconds: 450), this.speechOutput})
    : assert(fixtures.isNotEmpty) {
    _engine = _newEngine(0);
  }

  final List<ProofFixture> fixtures;

  /// How long THINK is shown while the deterministic evaluation runs.
  final Duration evaluationDelay;

  /// Real device speech for the app. Null keeps the deterministic timer used by
  /// tests/benchmarks so plugin availability never blocks proof automation.
  final SpeechOutput? speechOutput;

  late FlowEngine _engine;
  int _fixtureIndex = 0;
  CompanionIdentity _companionIdentity = CompanionIdentity.knot;
  FallbackLevel _tier = FallbackLevel.full;
  FallbackLevel? _tierBeforeWorldFailure;
  bool _reducedMotion = false;
  bool _audioAvailable = true;
  bool _companionAssetFailed = false;
  bool _worldAssetFailed = false;
  bool _speaking = false;
  int _speechGeneration = 0;
  Timer? _speechTimer;
  Timer? _evalTimer;

  FlowEngine get engine => _engine;
  int get fixtureIndex => _fixtureIndex;
  CompanionIdentity get companionIdentity => _companionIdentity;
  ProofFixture get fixture => fixtures[_fixtureIndex];
  FallbackLevel get tier => _tier;
  bool get reducedMotion => _reducedMotion;
  bool get audioAvailable => _audioAvailable;
  bool get companionAssetFailed => _companionAssetFailed;
  bool get worldAssetFailed => _worldAssetFailed;
  bool get usingRealSpeech => speechOutput != null;

  /// True only while actual device playback is active, or while the deterministic
  /// test/benchmark timer is active when no device speech output is injected.
  bool get speaking => _speaking;

  /// SPEAK is shown only while voice is actually active; otherwise the Companion is available.
  CompanionState get companionState {
    final s = _engine.companion;
    if (s == CompanionState.speak && !_speaking) return CompanionState.idle;
    return s;
  }

  FlowEngine _newEngine(int index) {
    final e = FlowEngine(fixtures[index], audioAvailable: _audioAvailable, fallback: _tier);
    e.addListener(_onEngine);
    return e;
  }

  void selectFixture(int index) {
    _cancelTimers();
    _engine
      ..exit()
      ..removeListener(_onEngine)
      ..dispose();
    _fixtureIndex = index;
    _lastStep = null;
    _lastTeach = -2;
    _engine = _newEngine(index);
    notifyListeners();
  }

  void restart() => selectFixture(_fixtureIndex);

  void setCompanionIdentity(CompanionIdentity identity) {
    if (identity == _companionIdentity) return;
    _companionIdentity = identity;
    _engine.events.add(ProofEvent('companion_identity_selected', fixture.id, fixture.version, detail: identity.name));
    notifyListeners();
  }

  void setTier(FallbackLevel t, {bool capabilityFailure = false}) {
    _tier = t;
    _engine.setFallback(t, capabilityFailure: capabilityFailure);
    notifyListeners();
  }

  void setReducedMotion(bool v) {
    if (v == _reducedMotion) return;
    _reducedMotion = v;
    if (v) _engine.noteReducedMotion();
    notifyListeners();
  }

  void setAudioAvailable(bool v) {
    _audioAvailable = v;
    _engine.setAudioAvailable(v);
    if (!v) _stopSpeaking();
    notifyListeners();
  }

  /// B12: Companion asset failure. The state label and teacher UI remain.
  void setCompanionAssetFailed(bool v) {
    _companionAssetFailed = v;
    if (v) _engine.setFallback(_tier, capabilityFailure: true);
    notifyListeners();
  }

  /// B12: world asset failure forces the content-first tier; the learning loop continues.
  void setWorldAssetFailed(bool v) {
    _worldAssetFailed = v;
    if (v) {
      _tierBeforeWorldFailure = _tier;
      setTier(FallbackLevel.content, capabilityFailure: true);
    } else {
      setTier(_tierBeforeWorldFailure ?? FallbackLevel.full);
    }
  }

  // --- flow actions (UI and benchmark use the same entry points) --------------------

  void orient() => _engine.orient();
  void advance() => _engine.advanceTeaching();
  void requestSupport() => _engine.requestSupport();
  void follow() => _engine.followNextAction();
  void interrupt() => _engine.interrupt();
  void submitRepair({required bool correct}) => _engine.submitRepair(correct: correct);

  void submit(EvidenceState e) {
    _engine.submit(e);
    if (_engine.step == FlowStep.evaluating) {
      _evalTimer?.cancel();
      _evalTimer = Timer(evaluationDelay, () {
        if (_engine.step == FlowStep.evaluating) _engine.completeEvaluation();
      });
    }
  }

  void stopSpeaking() => _stopSpeaking();

  void replaySpeech() => _startSpeakingIfNeeded(force: true);

  FlowStep? _lastStep;
  int _lastTeach = -2;

  void _onEngine() {
    final stepChanged = _engine.step != _lastStep || _engine.teachIndex != _lastTeach;
    _lastStep = _engine.step;
    _lastTeach = _engine.teachIndex;
    if (stepChanged) _startSpeakingIfNeeded();
    notifyListeners();
  }

  void _startSpeakingIfNeeded({bool force = false}) {
    _speechTimer?.cancel();
    final voiceStep = const {FlowStep.orient, FlowStep.teach, FlowStep.repairTeach}.contains(_engine.step);

    if (!_audioAvailable || !(voiceStep || force)) {
      _speechGeneration++;
      final output = speechOutput;
      if (output != null) unawaited(output.stop());
      _speaking = false;
      return;
    }

    final output = speechOutput;
    if (output != null) {
      final generation = ++_speechGeneration;
      _speaking = false;
      unawaited(
        output.speak(
          _engine.spokenText,
          locale: fixture.voiceLocale,
          onStart: () {
            if (generation != _speechGeneration) return;
            _speaking = true;
            notifyListeners();
          },
          onDone: () {
            if (generation != _speechGeneration) return;
            _speaking = false;
            notifyListeners();
          },
          onError: (error) {
            if (generation != _speechGeneration) return;
            _speaking = false;
            _engine.events.add(
              ProofEvent('audio_unavailable', fixture.id, fixture.version, detail: error.runtimeType.toString()),
            );
            notifyListeners();
          },
        ),
      );
      return;
    }

    // Deterministic fallback retained for tests/benchmarks only.
    _speaking = true;
    final words = _engine.spokenText.split(' ').length;
    final ms = (words * 260).clamp(900, 4000);
    _speechTimer = Timer(Duration(milliseconds: ms), () {
      _speaking = false;
      notifyListeners();
    });
  }

  void _stopSpeaking() {
    _speechGeneration++;
    _speechTimer?.cancel();
    final output = speechOutput;
    if (output != null) unawaited(output.stop());
    if (_speaking) {
      _speaking = false;
      _engine.events.add(ProofEvent('teaching_completed_or_stopped', fixture.id, fixture.version, detail: 'stopped'));
      notifyListeners();
    }
  }

  void _cancelTimers() {
    _speechGeneration++;
    _speechTimer?.cancel();
    _evalTimer?.cancel();
    final output = speechOutput;
    if (output != null) unawaited(output.stop());
    _speaking = false;
  }

  @override
  void dispose() {
    _cancelTimers();
    final output = speechOutput;
    if (output != null) unawaited(output.dispose());
    _engine.removeListener(_onEngine);
    _engine.dispose();
    super.dispose();
  }
}
