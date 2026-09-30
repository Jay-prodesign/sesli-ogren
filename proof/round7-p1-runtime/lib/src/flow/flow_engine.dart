import 'package:flutter/foundation.dart';

import '../scene/fixture.dart';
import '../scene/scene_schema.dart';

/// Proof-level steps of ROUND_7_ONE_FLOW_INTERACTION_CONTRACT_001 §13.
enum FlowStep {
  context, // S1
  orient, // S2
  teach, // S3
  challenge, // S4
  evaluating, // EVALUATE_FIXTURE
  feedback, // S5A–S5D + S6 next-action selection
  repairTeach, // corrective teaching after MISCONCEPTION
  repairCheck, // smaller repair check
  complete, // S7
}

/// The six P1 Companion states (ROUND_7_P1_RUNTIME_PROOF_SPEC_001).
enum CompanionState { idle, listen, think, speak, correct, success }

/// CORRECT carries a tone so PARTIAL (supportive attention) and MISCONCEPTION
/// (supportive correction) stay visibly different without adding states.
enum CompanionTone { neutral, attention, correction }

/// World state labels W0–W7 from the one-flow contract §15.
enum WorldStage { w1Context, w2Teach, w3Challenge, w4Strong, w5Partial, w6Misconception, w7Complete }

class ProofEvent {
  const ProofEvent(this.name, this.fixtureId, this.fixtureVersion, {this.reasonCode, this.detail});

  final String name;
  final String fixtureId;
  final String fixtureVersion;
  final String? reasonCode;
  final String? detail;

  Map<String, Object?> toJson() => {
    'event': name,
    'fixture': fixtureId,
    'fixture_version': fixtureVersion,
    if (reasonCode != null) 'reason_code': reasonCode,
    if (detail != null) 'detail': detail,
  };
}

/// Deterministic, fixture-driven proof flow. It labels evidence classes from simulated learner
/// responses; it is not a learner model and stores no mastery (contract §0, §19).
class FlowEngine extends ChangeNotifier {
  FlowEngine(this.fixture, {this._audioAvailable = true, this._fallback = FallbackLevel.full}) {
    _enter(FlowStep.context);
    _log('session_started');
  }

  final ProofFixture fixture;
  final List<ProofEvent> events = [];

  FlowStep _step = FlowStep.context;
  int _teachIndex = -1;
  bool _repairTeaching = false;
  EvidenceState? _evidence;
  String? _reasonCode;
  bool _audioAvailable;
  FallbackLevel _fallback;
  bool _sessionComplete = false;
  int _repairAttempts = 0;

  FlowStep get step => _step;
  int get teachIndex => _teachIndex;
  EvidenceState? get evidence => _evidence;
  String? get reasonCode => _reasonCode;
  bool get audioAvailable => _audioAvailable;
  FallbackLevel get fallback => _fallback;

  /// Session-bounded completion only; never global mastery (contract §12).
  bool get sessionComplete => _sessionComplete;
  int get repairAttempts => _repairAttempts;
  Branch? get branch => _evidence == null ? null : fixture.branches[_evidence];

  CompanionState get companion => switch (_step) {
    FlowStep.context => CompanionState.idle,
    FlowStep.orient ||
    FlowStep.teach ||
    FlowStep.repairTeach => _audioAvailable ? CompanionState.speak : CompanionState.idle,
    FlowStep.challenge || FlowStep.repairCheck => CompanionState.listen,
    FlowStep.evaluating => CompanionState.think,
    FlowStep.feedback => switch (_evidence!) {
      EvidenceState.strong => CompanionState.success,
      EvidenceState.partial || EvidenceState.misconception => CompanionState.correct,
      EvidenceState.unknown => CompanionState.idle,
    },
    FlowStep.complete => CompanionState.success,
  };

  CompanionTone get companionTone => switch ((_step, _evidence)) {
    (FlowStep.feedback, EvidenceState.partial) ||
    (FlowStep.repairCheck, EvidenceState.partial) => CompanionTone.attention,
    (FlowStep.feedback, EvidenceState.misconception) ||
    (FlowStep.repairTeach, _) ||
    (FlowStep.repairCheck, EvidenceState.misconception) => CompanionTone.correction,
    _ => CompanionTone.neutral,
  };

  WorldStage get worldStage => switch (_step) {
    FlowStep.context || FlowStep.orient => WorldStage.w1Context,
    FlowStep.teach => WorldStage.w2Teach,
    FlowStep.challenge || FlowStep.evaluating => WorldStage.w3Challenge,
    FlowStep.feedback || FlowStep.repairTeach || FlowStep.repairCheck => switch (_evidence!) {
      EvidenceState.strong => WorldStage.w4Strong,
      EvidenceState.partial => WorldStage.w5Partial,
      EvidenceState.misconception => WorldStage.w6Misconception,
      EvidenceState.unknown => WorldStage.w3Challenge, // no evidence mutation (contract §10)
    },
    FlowStep.complete => WorldStage.w7Complete,
  };

  /// The scene the renderer consumes for the current step. Nodes and edges never change;
  /// only focus, visibility and evidence do, so every tier renders the same truth.
  SceneSpec get scene {
    final base = fixture.scene;
    final ids = base.ids;
    Map<String, Vis> all(Vis v) => {for (final id in ids) id: v};
    final spec = switch (worldStage) {
      WorldStage.w1Context => base.copyWith(
        focus: fixture.challengeFocus,
        visibility: {
          for (final n in base.nodes) n.id: fixture.challengeFocus.contains(n.id) ? Vis.shown : Vis.dimmed,
          for (final e in base.edges) e.id: Vis.hidden,
        },
        evidenceState: EvidenceState.unknown,
      ),
      WorldStage.w2Teach => base.copyWith(
        focus: fixture.teaching[_teachIndex].reveal,
        visibility: {
          for (final n in base.nodes) n.id: Vis.dimmed,
          for (final e in base.edges) e.id: Vis.hidden,
          for (var i = 0; i <= _teachIndex; i++)
            for (final id in fixture.teaching[i].reveal) id: Vis.shown,
        },
        evidenceState: EvidenceState.unknown,
      ),
      WorldStage.w3Challenge => base.copyWith(
        focus: fixture.challengeFocus,
        visibility: {...all(Vis.shown), ...fixture.challengeVisibility},
        evidenceState: EvidenceState.unknown,
      ),
      WorldStage.w4Strong || WorldStage.w5Partial || WorldStage.w6Misconception => base.copyWith(
        focus: branch!.focus,
        visibility: {...all(Vis.shown), ...branch!.visibility},
        evidenceState: _evidence,
      ),
      WorldStage.w7Complete => base.copyWith(
        focus: const [],
        visibility: all(Vis.shown),
        evidenceState: EvidenceState.strong,
      ),
    };
    return spec.copyWith(fallbackLevel: _fallback);
  }

  /// Text that the (simulated) voice would speak; always shown as transcript as well.
  String get spokenText => switch (_step) {
    FlowStep.context => fixture.objective,
    FlowStep.orient => fixture.orientation,
    FlowStep.teach => fixture.teaching[_teachIndex].text,
    FlowStep.challenge => fixture.challengePrompt,
    FlowStep.evaluating => 'Checking your answer against this source…',
    FlowStep.feedback => branch!.feedback,
    FlowStep.repairTeach => branch!.corrective ?? '',
    FlowStep.repairCheck => branch!.repairPrompt ?? fixture.challengePrompt,
    FlowStep.complete => fixture.completionSummary,
  };

  // --- transitions --------------------------------------------------------------

  void orient() {
    _expect({FlowStep.context});
    _enter(FlowStep.orient);
    _log('orientation_shown');
  }

  /// Advances through teaching steps; after the last one the challenge is presented.
  void advanceTeaching() {
    _expect({FlowStep.orient, FlowStep.teach, FlowStep.repairTeach});
    if (_step == FlowStep.repairTeach) {
      _enter(FlowStep.repairCheck);
      _log('challenge_presented', detail: 'repair_check');
      return;
    }
    if (_step == FlowStep.orient) {
      _teachIndex = 0;
      _enter(FlowStep.teach);
      _log('teaching_started');
      return;
    }
    if (_teachIndex < fixture.teaching.length - 1) {
      _teachIndex++;
      _enter(FlowStep.teach);
      return;
    }
    _log('teaching_completed_or_stopped');
    _evidence = null;
    _enter(_repairTeaching ? FlowStep.repairCheck : FlowStep.challenge);
    _log('challenge_presented', detail: _repairTeaching ? 'repair_check' : 'main');
  }

  void requestSupport() {
    _expect({FlowStep.challenge, FlowStep.repairCheck});
    _log('support_requested');
  }

  /// Submits a simulated learner response of the given fixture evidence class.
  void submit(EvidenceState response) {
    _expect({FlowStep.challenge});
    if (response == EvidenceState.unknown) {
      interrupt();
      return;
    }
    _log('response_submitted', detail: wireName(response));
    _pendingEvidence = response;
    _enter(FlowStep.evaluating);
  }

  EvidenceState? _pendingEvidence;

  /// Completes deterministic evaluation (THINK is shown only while this is pending).
  void completeEvaluation() {
    _expect({FlowStep.evaluating});
    _classify(_pendingEvidence!);
    _pendingEvidence = null;
  }

  /// Input interrupted or channel failed: UNKNOWN, never PARTIAL/MISCONCEPTION (contract §17).
  void interrupt() {
    _expect({FlowStep.challenge, FlowStep.repairCheck, FlowStep.evaluating});
    _pendingEvidence = null;
    _log('response_submitted', detail: 'INTERRUPTED');
    if (_step == FlowStep.repairCheck) {
      // Keep the repair branch; the interrupted attempt carries no evidence.
      _reasonCode = 'R_RETRY_UNKNOWN';
      _log('next_action_selected', reason: _reasonCode);
      notifyListeners();
      return;
    }
    _classify(EvidenceState.unknown);
  }

  void _classify(EvidenceState e) {
    _evidence = e;
    _log('evidence_classified', detail: wireName(e));
    _reasonCode = fixture.branches[e]!.reasonCode;
    _log('next_action_selected', reason: _reasonCode);
    _enter(FlowStep.feedback);
  }

  /// Follows the selected next action (S6).
  void followNextAction() {
    _expect({FlowStep.feedback});
    switch (_evidence!) {
      case EvidenceState.strong:
        _complete();
      case EvidenceState.partial:
        _repairAttempts++;
        _log('repair_started', reason: _reasonCode);
        _enter(FlowStep.repairCheck);
        _log('challenge_presented', detail: 'repair_check');
      case EvidenceState.misconception:
        _repairAttempts++;
        _log('repair_started', reason: _reasonCode);
        _enter(FlowStep.repairTeach);
      case EvidenceState.unknown:
        _evidence = null;
        _log('challenge_retried', reason: _reasonCode);
        _enter(FlowStep.challenge);
    }
  }

  /// Result of the smaller repair check. A correct repair continues; an incorrect one
  /// returns to teaching (no punitive consequence, no progress unlock).
  void submitRepair({required bool correct}) {
    _expect({FlowStep.repairCheck});
    _log('response_submitted', detail: correct ? 'REPAIR_CORRECT' : 'REPAIR_INCORRECT');
    if (correct) {
      _reasonCode = 'R_CONTINUE_AFTER_STRONG';
      _log('evidence_classified', detail: 'STRONG');
      _log('next_action_selected', reason: _reasonCode);
      _evidence = EvidenceState.strong;
      _complete();
      return;
    }
    _log('next_action_selected', reason: _reasonCode);
    _repairTeaching = true;
    _teachIndex = 0;
    _enter(FlowStep.teach);
    _log('teaching_started', detail: 'repair');
  }

  void _complete() {
    _sessionComplete = true;
    _enter(FlowStep.complete);
    _log('session_completed');
  }

  void exit() => _log('session_exited');

  void setAudioAvailable(bool v) {
    if (v == _audioAvailable) return;
    _audioAvailable = v;
    if (!v) _log('audio_unavailable');
    notifyListeners();
  }

  /// Switches the render tier. A capability-driven downgrade records R_FALLBACK_CAPABILITY.
  void setFallback(FallbackLevel level, {bool capabilityFailure = false}) {
    if (level == _fallback) return;
    _fallback = level;
    _log('fallback_activated', reason: capabilityFailure ? 'R_FALLBACK_CAPABILITY' : null, detail: wireName(level));
    notifyListeners();
  }

  void noteReducedMotion() => _log('reduced_motion_active');

  void _enter(FlowStep s) {
    _step = s;
    if (s == FlowStep.challenge || s == FlowStep.context) _repairTeaching = false;
    notifyListeners();
  }

  void _expect(Set<FlowStep> allowed) {
    if (!allowed.contains(_step)) {
      throw StateError('invalid transition from $_step (allowed: $allowed)');
    }
  }

  void _log(String name, {String? reason, String? detail}) =>
      events.add(ProofEvent(name, fixture.id, fixture.version, reasonCode: reason, detail: detail));
}
