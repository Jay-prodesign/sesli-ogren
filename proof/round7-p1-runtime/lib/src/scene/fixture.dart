import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle;

import 'scene_schema.dart';

/// Reason codes from ROUND_7_ONE_FLOW_INTERACTION_CONTRACT_001 §11.
const kReasonCodes = {
  'R_CONTINUE_AFTER_STRONG',
  'R_DEEPEN_AFTER_STRONG',
  'R_REPAIR_PARTIAL',
  'R_REPAIR_MISCONCEPTION',
  'R_RETRY_UNKNOWN',
  'R_FALLBACK_CAPABILITY',
};

const kFixtureAssets = [
  'assets/fixtures/biology_photosynthesis.json',
  'assets/fixtures/fractions_equivalence.json',
  'assets/fixtures/accounting_owner_contribution.json',
];

class BoundedSource {
  const BoundedSource({
    required this.id,
    required this.version,
    required this.authority,
    required this.text,
    required this.provenance,
  });

  final String id;
  final String version;
  final String authority;
  final String text;
  final String provenance;
}

class TeachStep {
  const TeachStep(this.text, this.reveal);

  final String text;
  final List<String> reveal;
}

class Branch {
  const Branch({
    required this.feedback,
    required this.nextAction,
    required this.reasonCode,
    required this.focus,
    required this.visibility,
    this.hint,
    this.corrective,
    this.repairPrompt,
    this.repairAnswer,
  });

  final String feedback;
  final String nextAction;
  final String reasonCode;
  final List<String> focus;
  final Map<String, Vis> visibility;
  final String? hint;
  final String? corrective;
  final String? repairPrompt;
  final String? repairAnswer;
}

/// One bounded Round 7 QA fixture: source, flow copy, simulated learner evidence and scene.
/// All copy is derived from the bounded source text; nothing here is curriculum authority.
class ProofFixture {
  const ProofFixture({
    required this.id,
    required this.version,
    required this.domainLabel,
    required this.voiceLocale,
    required this.source,
    required this.objective,
    required this.orientation,
    required this.teaching,
    required this.challengePrompt,
    required this.challengeFocus,
    required this.challengeVisibility,
    required this.responses,
    required this.branches,
    required this.completionSummary,
    required this.nextContinuation,
    required this.scene,
  });

  factory ProofFixture.fromJson(Map<String, dynamic> j) {
    Map<String, Vis> vis(Object? m) => {
      for (final e in ((m as Map?) ?? const {}).entries) e.key as String: visFromWire(e.value as String),
    };
    List<String> strs(Object? l) => [for (final s in (l as List? ?? const [])) s as String];
    final src = Map<String, dynamic>.from(j['source'] as Map);
    final ch = Map<String, dynamic>.from(j['challenge'] as Map);
    final comp = Map<String, dynamic>.from(j['completion'] as Map);
    final fx = ProofFixture(
      id: j['fixture_id'] as String,
      version: j['fixture_version'] as String,
      domainLabel: j['domain_label'] as String,
      voiceLocale: j['voice_locale'] as String,
      source: BoundedSource(
        id: src['id'] as String,
        version: src['version'] as String,
        authority: src['authority'] as String,
        text: src['text'] as String,
        provenance: src['provenance'] as String,
      ),
      objective: j['objective'] as String,
      orientation: j['orientation'] as String,
      teaching: [for (final t in j['teaching'] as List) TeachStep((t as Map)['text'] as String, strs(t['reveal']))],
      challengePrompt: ch['prompt'] as String,
      challengeFocus: strs(ch['focus']),
      challengeVisibility: vis(ch['visibility']),
      responses: {
        for (final e in (j['responses'] as Map).entries) evidenceFromWire(e.key as String): e.value as String,
      },
      branches: {
        for (final e in (j['branches'] as Map).entries)
          evidenceFromWire(e.key as String): Branch(
            feedback: (e.value as Map)['feedback'] as String,
            nextAction: e.value['next_action'] as String,
            reasonCode: e.value['reason_code'] as String,
            focus: strs(e.value['focus']),
            visibility: vis(e.value['visibility']),
            hint: e.value['hint'] as String?,
            corrective: e.value['corrective'] as String?,
            repairPrompt: e.value['repair_prompt'] as String?,
            repairAnswer: e.value['repair_answer'] as String?,
          ),
      },
      completionSummary: comp['summary'] as String,
      nextContinuation: comp['next_continuation'] as String,
      scene: SceneSpec.fromJson(Map<String, dynamic>.from(j['scene'] as Map)),
    );
    fx.validate();
    return fx;
  }

  static Future<List<ProofFixture>> loadAll(AssetBundle bundle) async => [
    for (final path in kFixtureAssets)
      ProofFixture.fromJson(jsonDecode(await bundle.loadString(path)) as Map<String, dynamic>),
  ];

  final String id;
  final String version;
  final String domainLabel;
  final String voiceLocale;
  final BoundedSource source;
  final String objective;
  final String orientation;
  final List<TeachStep> teaching;
  final String challengePrompt;
  final List<String> challengeFocus;
  final Map<String, Vis> challengeVisibility;
  final Map<EvidenceState, String> responses;
  final Map<EvidenceState, Branch> branches;
  final String completionSummary;
  final String nextContinuation;
  final SceneSpec scene;

  void validate() {
    if (voiceLocale.trim().isEmpty) {
      throw FormatException('$id: voice_locale is required');
    }
    if (scene.sourceRef != source.id) {
      throw FormatException('$id: scene source_ref ${scene.sourceRef} != source ${source.id}');
    }
    final ids = scene.ids;
    void known(Iterable<String> refs, String where) {
      for (final r in refs) {
        if (!ids.contains(r)) throw FormatException('$id: $where references unknown id $r');
      }
    }

    for (final t in teaching) {
      known(t.reveal, 'teaching');
    }
    known(challengeFocus, 'challenge focus');
    known(challengeVisibility.keys, 'challenge visibility');
    for (final s in EvidenceState.values) {
      final b = branches[s];
      if (b == null) throw FormatException('$id: missing branch ${wireName(s)}');
      if (!kReasonCodes.contains(b.reasonCode)) throw FormatException('$id: unknown reason code ${b.reasonCode}');
      known(b.focus, 'branch focus');
      known(b.visibility.keys, 'branch visibility');
      if (s != EvidenceState.unknown && responses[s] == null) {
        throw FormatException('$id: missing simulated response ${wireName(s)}');
      }
    }
    for (final s in [EvidenceState.partial, EvidenceState.misconception]) {
      if (branches[s]!.repairPrompt == null) throw FormatException('$id: ${wireName(s)} needs a repair check');
    }
    if (branches[EvidenceState.misconception]!.corrective == null) {
      throw FormatException('$id: MISCONCEPTION needs corrective teaching');
    }
    final allRevealed = {for (final t in teaching) ...t.reveal};
    if (!allRevealed.containsAll(ids)) {
      throw FormatException('$id: teaching must reveal every scene element (${ids.difference(allRevealed)})');
    }
  }
}
