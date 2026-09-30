import 'package:flutter_test/flutter_test.dart';
import 'package:r7_p1_runtime_proof/src/render/views.dart';
import 'package:r7_p1_runtime_proof/src/scene/fixture.dart';
import 'package:r7_p1_runtime_proof/src/scene/scene_schema.dart';

import 'helpers.dart';

void main() {
  late List<ProofFixture> fixtures;
  setUpAll(() async => fixtures = await loadFixtures());

  group('renderer-neutral scene schema', () {
    test('all three bounded fixtures parse and validate', () {
      expect(fixtures.map((f) => f.source.id), ['R7-SRC-BIO-001', 'R7-SRC-FRA-001', 'R7-SRC-PRO-001']);
      for (final f in fixtures) {
        expect(f.scene.sourceRef, f.source.id);
        expect(f.version, '1.0');
        expect(f.source.version, '1.0');
      }
    });

    test('rejects an edge that references an unknown node', () async {
      final raw = await rawFixture(kFixtureAssets.first);
      (raw['scene']['edges'] as List).add({
        'id': 'e_bad',
        'from': 'light',
        'to': 'nowhere',
        'relation': 'x',
        'semantic_ref': 'x', //
      });
      expect(() => ProofFixture.fromJson(raw), throwsFormatException);
    });

    test('rejects missing source_ref and source/scene mismatch', () async {
      final a = await rawFixture(kFixtureAssets.first);
      (a['scene'] as Map).remove('source_ref');
      expect(() => ProofFixture.fromJson(a), throwsFormatException);
      final b = await rawFixture(kFixtureAssets.first);
      b['scene']['source_ref'] = 'R7-SRC-FRA-001';
      expect(() => ProofFixture.fromJson(b), throwsFormatException);
    });

    test('rejects focus or visibility on unknown ids and unknown reason codes', () async {
      final a = await rawFixture(kFixtureAssets[1]);
      a['challenge']['focus'] = ['ghost'];
      expect(() => ProofFixture.fromJson(a), throwsFormatException);
      final b = await rawFixture(kFixtureAssets[1]);
      b['branches']['STRONG']['reason_code'] = 'R_AI_DECIDED';
      expect(() => ProofFixture.fromJson(b), throwsFormatException);
    });

    test('rejects a fixture whose teaching never reveals part of the world', () async {
      final a = await rawFixture(kFixtureAssets[2]);
      (a['teaching'] as List).removeLast();
      expect(() => ProofFixture.fromJson(a), throwsFormatException);
    });

    test('low theme confidence is representable (renderer falls back to neutral grammar)', () async {
      final a = await rawFixture(kFixtureAssets.first);
      a['scene']['theme_confidence'] = 0.3;
      expect(ProofFixture.fromJson(a).scene.themeTrusted, isFalse);
    });
  });

  group('cross-domain primitive jury (XDP)', () {
    test('XDP-01: shared primitive vocabulary matches the proof matrix', () {
      Set<String> prims(int i) => fixtures[i].scene.primitives.map(wireName).toSet();
      expect(prims(0), containsAll(['NODE', 'PATH', 'GROUP']));
      expect(prims(1), containsAll(['NODE', 'PARTITION', 'PAIR', 'PATH']));
      expect(prims(2), containsAll(['NODE', 'TRACE', 'PAIR', 'PATH']));
    });

    test('XDP-02: domain differences are structural, not palette/label swaps', () {
      final sigs = fixtures.map((f) => f.scene.topologySignature).toSet();
      expect(sigs, hasLength(3));
      expect(fixtures.map((f) => f.scene.layoutHint).toSet(), hasLength(3));
    });

    test('XDP-03/04: decorative tokens are optional; no generative field exists', () async {
      for (final path in kFixtureAssets) {
        final raw = await rawFixture(path);
        final withDecor = ProofFixture.fromJson(raw);
        (raw['scene'] as Map).remove('decorative_tokens');
        (raw['scene'] as Map).remove('motion_cue');
        final without = ProofFixture.fromJson(raw);
        expect(describeScene(without.scene), describeScene(withDecor.scene));
        expect(raw.toString().toLowerCase(), isNot(contains('generat')));
      }
    });

    test('XDP-07: source_ref survives every fallback level', () {
      for (final f in fixtures) {
        for (final t in FallbackLevel.values) {
          expect(f.scene.copyWith(fallbackLevel: t).sourceRef, f.source.id);
        }
      }
    });

    test('XDP-08: static text description carries every shown relation (motion removable)', () {
      for (final f in fixtures) {
        final lines = describeScene(f.scene);
        expect(lines, hasLength(f.scene.edges.length));
      }
    });
  });

  group('evidence-branch jury', () {
    test('no two branches share the same next action or reason', () {
      for (final f in fixtures) {
        final actions = f.branches.values.map((b) => '${b.nextAction}|${b.reasonCode}').toSet();
        expect(actions, hasLength(4), reason: f.id);
        expect(f.branches.values.map((b) => b.reasonCode).toSet(), hasLength(4), reason: f.id);
      }
    });

    test('PARTIAL and MISCONCEPTION carry a smaller repair check; only MISCONCEPTION re-teaches', () {
      for (final f in fixtures) {
        expect(f.branches[EvidenceState.partial]!.repairPrompt, isNotNull);
        expect(f.branches[EvidenceState.partial]!.hint, isNotNull);
        expect(f.branches[EvidenceState.misconception]!.corrective, isNotNull);
        expect(f.branches[EvidenceState.partial]!.corrective, isNull);
      }
    });

    test('copy never claims mastery', () async {
      for (final path in kFixtureAssets) {
        final text = (await rawFixture(path)).toString().toLowerCase();
        expect(text, isNot(contains('master')));
        expect(text, isNot(contains('forever')));
      }
    });
  });
}
