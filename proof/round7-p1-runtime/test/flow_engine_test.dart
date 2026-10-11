import 'package:flutter_test/flutter_test.dart';
import 'package:r7_p1_runtime_proof/src/flow/flow_engine.dart';
import 'package:r7_p1_runtime_proof/src/scene/fixture.dart';
import 'package:r7_p1_runtime_proof/src/scene/scene_schema.dart';

import 'helpers.dart';

FlowEngine toChallenge(ProofFixture f, {bool audio = true}) {
  final e = FlowEngine(f, audioAvailable: audio)..orient();
  while (e.step != FlowStep.challenge) {
    e.advanceTeaching();
  }
  return e;
}

FlowEngine answered(ProofFixture f, EvidenceState s) {
  final e = toChallenge(f);
  if (s == EvidenceState.unknown) {
    e.interrupt();
  } else {
    e.submit(s);
    expect(e.step, FlowStep.evaluating);
    expect(e.companion, CompanionState.think);
    e.completeEvaluation();
  }
  return e;
}

void main() {
  late List<ProofFixture> fixtures;
  setUpAll(() async => fixtures = await loadFixtures());

  test('S1→S7 order holds for every fixture (strong path)', () {
    for (final f in fixtures) {
      final e = FlowEngine(f);
      expect(e.step, FlowStep.context);
      expect(e.companion, CompanionState.idle);
      e.orient();
      expect(e.step, FlowStep.orient);
      e.advanceTeaching();
      expect(e.step, FlowStep.teach);
      while (e.step == FlowStep.teach) {
        e.advanceTeaching();
      }
      expect(e.step, FlowStep.challenge);
      expect(e.companion, CompanionState.listen);
      e.submit(EvidenceState.strong);
      e.completeEvaluation();
      expect(e.companion, CompanionState.success);
      e.followNextAction();
      expect(e.step, FlowStep.complete);
      expect(e.sessionComplete, isTrue);
    }
  });

  test('challenge does not leak the answer: focal relations are open gaps', () {
    for (final f in fixtures) {
      final e = toChallenge(f);
      final open = e.scene.visibility.entries.where((x) => x.value == Vis.open).map((x) => x.key);
      expect(open, isNotEmpty, reason: f.id);
      expect(e.scene.evidenceState, EvidenceState.unknown);
    }
  });

  test('four evidence branches produce four different next actions, stages and Companion states', () {
    for (final f in fixtures) {
      final seen = <String>{};
      for (final s in EvidenceState.values) {
        final e = answered(f, s);
        seen.add('${e.reasonCode}|${e.worldStage}|${e.companion}|${e.companionTone}');
      }
      expect(seen, hasLength(4), reason: f.id);
    }
  });

  test('PARTIAL preserves correct structure and opens only the missing relation', () {
    for (final f in fixtures) {
      final e = answered(f, EvidenceState.partial);
      expect(e.reasonCode, 'R_REPAIR_PARTIAL');
      final vis = e.scene.visibility;
      expect(
        vis.values.where((v) => v == Vis.shown).length,
        greaterThan(vis.values.where((v) => v == Vis.open).length),
      );
      expect(vis.values, contains(Vis.open));
      e.followNextAction();
      expect(e.step, FlowStep.repairCheck);
      expect(e.companionTone, CompanionTone.attention);
      e.submitRepair(correct: true);
      expect(e.step, FlowStep.complete);
    }
  });

  test('MISCONCEPTION: no unlock, corrective teaching, then a smaller check', () {
    for (final f in fixtures) {
      final e = answered(f, EvidenceState.misconception);
      expect(e.reasonCode, 'R_REPAIR_MISCONCEPTION');
      expect(e.sessionComplete, isFalse);
      expect(e.companionTone, CompanionTone.correction);
      e.followNextAction();
      expect(e.step, FlowStep.repairTeach);
      expect(e.spokenText, f.branches[EvidenceState.misconception]!.corrective);
      e.advanceTeaching();
      expect(e.step, FlowStep.repairCheck);
      e.submitRepair(correct: false);
      expect(e.step, FlowStep.teach, reason: 'incorrect repair returns to teaching, no punishment');
      expect(e.sessionComplete, isFalse);
      while (e.step == FlowStep.teach) {
        e.advanceTeaching();
      }
      expect(e.step, FlowStep.repairCheck);
      e.submitRepair(correct: true);
      expect(e.sessionComplete, isTrue);
    }
  });

  test('UNKNOWN: interruption is never PARTIAL/MISCONCEPTION and mutates nothing', () {
    for (final f in fixtures) {
      final e = toChallenge(f);
      final before = e.scene.visibility;
      e.interrupt();
      expect(e.evidence, EvidenceState.unknown);
      expect(e.reasonCode, 'R_RETRY_UNKNOWN');
      expect(e.worldStage, WorldStage.w3Challenge);
      expect(e.scene.visibility, before);
      expect(e.sessionComplete, isFalse);
      expect(e.companion, CompanionState.idle);
      expect(e.events.where((x) => x.name == 'evidence_classified').single.detail, 'UNKNOWN');
      e.followNextAction();
      expect(e.step, FlowStep.challenge);
    }
  });

  test('interruption during evaluation is UNKNOWN, not the pending answer', () {
    final e = toChallenge(fixtures[1])..submit(EvidenceState.misconception);
    e.interrupt();
    expect(e.evidence, EvidenceState.unknown);
  });

  test('interruption during a repair check keeps the repair branch and records no evidence', () {
    final e = answered(fixtures[2], EvidenceState.partial)..followNextAction();
    final n = e.events.where((x) => x.name == 'evidence_classified').length;
    e.interrupt();
    expect(e.step, FlowStep.repairCheck);
    expect(e.evidence, EvidenceState.partial);
    expect(e.events.where((x) => x.name == 'evidence_classified').length, n);
  });

  test('audio unavailable: Companion never enters SPEAK', () {
    final e = FlowEngine(fixtures.first, audioAvailable: false)..orient();
    final states = <CompanionState>{e.companion};
    while (e.step != FlowStep.challenge) {
      e.advanceTeaching();
      states.add(e.companion);
    }
    expect(states, isNot(contains(CompanionState.speak)));
  });

  test('telemetry records fixture/version and reason codes for every next action', () {
    final e = answered(fixtures.first, EvidenceState.partial);
    final next = e.events.where((x) => x.name == 'next_action_selected').toList();
    expect(next.single.reasonCode, 'R_REPAIR_PARTIAL');
    for (final ev in e.events) {
      expect(ev.fixtureId, fixtures.first.id);
      expect(ev.fixtureVersion, '1.0');
    }
    expect(e.events.map((x) => x.name), containsAll(['session_started', 'orientation_shown', 'challenge_presented']));
  });

  test('capability fallback records R_FALLBACK_CAPABILITY and keeps semantic state', () {
    final e = toChallenge(fixtures.first);
    final ids = e.scene.ids;
    e.setFallback(FallbackLevel.content, capabilityFailure: true);
    expect(e.events.last.reasonCode, 'R_FALLBACK_CAPABILITY');
    expect(e.scene.ids, ids);
    expect(e.step, FlowStep.challenge);
  });

  test('invalid transitions are rejected', () {
    final e = FlowEngine(fixtures.first);
    expect(() => e.submit(EvidenceState.strong), throwsStateError);
    expect(e.followNextAction, throwsStateError);
  });
}
