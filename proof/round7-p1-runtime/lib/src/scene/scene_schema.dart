// Renderer-neutral scene schema (Round 7 executable proof matrix, "Renderer-Neutral
// Scene Schema"). Proof-level contract only: engineering-owned, not a production schema lock.

enum EvidenceState { strong, partial, misconception, unknown }

enum FallbackLevel { full, reduced, simple, neutral, content }

enum Primitive { node, path, group, partition, pair, trace, focusMark }

enum LayoutHint { flow, compare, partition, balance, trace }

/// Per-element visibility used for progressive reveal and answer-leak control.
/// `open` marks a relation the learner still has to supply (a visible gap).
enum Vis { shown, dimmed, hidden, open }

T _enumByName<T extends Enum>(List<T> values, String raw, String field) {
  final key = raw.replaceAll('_', '').toLowerCase();
  for (final v in values) {
    if (v.name.toLowerCase() == key) return v;
  }
  throw FormatException('unknown $field value "$raw"');
}

EvidenceState evidenceFromWire(String raw) => _enumByName(EvidenceState.values, raw, 'evidence_state');
FallbackLevel fallbackFromWire(String raw) => _enumByName(FallbackLevel.values, raw, 'fallback_level');
Primitive primitiveFromWire(String raw) => _enumByName(Primitive.values, raw, 'primitive');
LayoutHint layoutFromWire(String raw) => _enumByName(LayoutHint.values, raw, 'layout_hint');
Vis visFromWire(String raw) => _enumByName(Vis.values, raw, 'visibility');

String wireName(Enum e) {
  final out = StringBuffer();
  for (final ch in e.name.split('')) {
    if (ch.toUpperCase() == ch && ch.toLowerCase() != ch) out.write('_');
    out.write(ch.toUpperCase());
  }
  return out.toString();
}

class SceneNode {
  const SceneNode({
    required this.id,
    required this.role,
    required this.label,
    required this.semanticRef,
    this.attrs = const {},
  });

  factory SceneNode.fromJson(Map<String, dynamic> j) => SceneNode(
    id: _req<String>(j, 'id'),
    role: _req<String>(j, 'role'),
    label: _req<String>(j, 'label'),
    semanticRef: _req<String>(j, 'semantic_ref'),
    attrs: Map<String, Object?>.from((j['attrs'] as Map?) ?? const {}),
  );

  final String id;

  /// Semantic role, e.g. `enabler`, `input`, `process`, `output`, `whole`, `part`,
  /// `event`, `classification`, `effect`, `contrast`, `invariant`.
  final String role;
  final String label;

  /// Pointer into the bounded source's allowed derived relations.
  final String semanticRef;

  /// Renderer hints that carry meaning (for example partition counts).
  final Map<String, Object?> attrs;

  int intAttr(String k, int fallback) => (attrs[k] as num?)?.toInt() ?? fallback;
}

class SceneEdge {
  const SceneEdge({
    required this.id,
    required this.from,
    required this.to,
    required this.relation,
    required this.directed,
    required this.semanticRef,
  });

  factory SceneEdge.fromJson(Map<String, dynamic> j) => SceneEdge(
    id: _req<String>(j, 'id'),
    from: _req<String>(j, 'from'),
    to: _req<String>(j, 'to'),
    relation: _req<String>(j, 'relation'),
    directed: (j['direction'] as String? ?? 'forward') != 'none',
    semanticRef: _req<String>(j, 'semantic_ref'),
  );

  final String id;
  final String from;
  final String to;
  final String relation;
  final bool directed;
  final String semanticRef;
}

/// The scene a renderer consumes. Evidence, focus and visibility change per flow step;
/// nodes, edges and primitives stay fixed for a fixture so every tier shows the same truth.
class SceneSpec {
  const SceneSpec({
    required this.sourceRef,
    required this.domainTheme,
    required this.themeConfidence,
    required this.nodes,
    required this.edges,
    required this.primitives,
    required this.layoutHint,
    required this.decorativeTokens,
    this.focus = const [],
    this.evidenceState = EvidenceState.unknown,
    this.visibility = const {},
    this.fallbackLevel = FallbackLevel.full,
    this.motionCue,
  });

  factory SceneSpec.fromJson(Map<String, dynamic> j) {
    final spec = SceneSpec(
      sourceRef: _req<String>(j, 'source_ref'),
      domainTheme: _req<String>(j, 'domain_theme'),
      themeConfidence: (_req<num>(j, 'theme_confidence')).toDouble(),
      nodes: [for (final n in _req<List>(j, 'nodes')) SceneNode.fromJson(Map<String, dynamic>.from(n as Map))],
      edges: [for (final e in _req<List>(j, 'edges')) SceneEdge.fromJson(Map<String, dynamic>.from(e as Map))],
      primitives: {for (final p in _req<List>(j, 'primitives')) primitiveFromWire(p as String)},
      layoutHint: layoutFromWire(_req<String>(j, 'layout_hint')),
      decorativeTokens: [for (final t in (j['decorative_tokens'] as List? ?? const [])) t as String],
      focus: [for (final f in (j['focus'] as List? ?? const [])) f as String],
      evidenceState: evidenceFromWire(j['evidence_state'] as String? ?? 'UNKNOWN'),
      visibility: {
        for (final e in ((j['visibility'] as Map?) ?? const {}).entries)
          e.key as String: visFromWire(e.value as String),
      },
      fallbackLevel: fallbackFromWire(j['fallback_level'] as String? ?? 'FULL'),
      motionCue: j['motion_cue'] as String?,
    );
    spec.validate();
    return spec;
  }

  final String sourceRef;
  final String domainTheme;
  final double themeConfidence;
  final List<SceneNode> nodes;
  final List<SceneEdge> edges;
  final List<String> focus;
  final EvidenceState evidenceState;
  final Map<String, Vis> visibility;
  final Set<Primitive> primitives;
  final LayoutHint layoutHint;
  final List<String> decorativeTokens;
  final FallbackLevel fallbackLevel;
  final String? motionCue;

  /// Low theme confidence falls back to the neutral grammar (schema: "neutral when low confidence").
  static const double minThemeConfidence = 0.6;

  bool get themeTrusted => themeConfidence >= minThemeConfidence;

  Vis visOf(String id) => visibility[id] ?? Vis.shown;

  SceneNode node(String id) => nodes.firstWhere((n) => n.id == id);

  Set<String> get ids => {...nodes.map((n) => n.id), ...edges.map((e) => e.id)};

  void validate() {
    if (sourceRef.isEmpty) throw const FormatException('source_ref is required');
    final nodeIds = <String>{};
    for (final n in nodes) {
      if (!nodeIds.add(n.id)) throw FormatException('duplicate node ${n.id}');
    }
    final all = <String>{...nodeIds};
    for (final e in edges) {
      if (!nodeIds.contains(e.from) || !nodeIds.contains(e.to)) {
        throw FormatException('edge ${e.id} references an unknown node');
      }
      if (!all.add(e.id)) throw FormatException('duplicate id ${e.id}');
    }
    for (final f in focus) {
      if (!all.contains(f)) throw FormatException('focus references unknown id $f');
    }
    for (final k in visibility.keys) {
      if (!all.contains(k)) throw FormatException('visibility references unknown id $k');
    }
    if (nodes.isEmpty || edges.isEmpty) throw const FormatException('nodes and edges are required');
    if (primitives.isEmpty) throw const FormatException('primitive set is required');
  }

  SceneSpec copyWith({
    List<String>? focus,
    EvidenceState? evidenceState,
    Map<String, Vis>? visibility,
    FallbackLevel? fallbackLevel,
    String? motionCue,
    bool clearMotionCue = false,
  }) => SceneSpec(
    sourceRef: sourceRef,
    domainTheme: domainTheme,
    themeConfidence: themeConfidence,
    nodes: nodes,
    edges: edges,
    primitives: primitives,
    layoutHint: layoutHint,
    decorativeTokens: decorativeTokens,
    focus: focus ?? this.focus,
    evidenceState: evidenceState ?? this.evidenceState,
    visibility: visibility ?? this.visibility,
    fallbackLevel: fallbackLevel ?? this.fallbackLevel,
    motionCue: clearMotionCue ? null : (motionCue ?? this.motionCue),
  );

  /// Topology signature used by the cross-domain jury: differences must be structural,
  /// not palette or label swaps.
  String get topologySignature {
    final inDeg = <String, int>{for (final n in nodes) n.id: 0};
    final outDeg = <String, int>{for (final n in nodes) n.id: 0};
    for (final e in edges) {
      outDeg[e.from] = outDeg[e.from]! + 1;
      inDeg[e.to] = inDeg[e.to]! + 1;
    }
    final shape = [for (final n in nodes) '${inDeg[n.id]}/${outDeg[n.id]}']..sort();
    final prims = primitives.map(wireName).toList()..sort();
    return '${wireName(layoutHint)}|${prims.join(',')}|${shape.join(' ')}';
  }
}

T _req<T>(Map<String, dynamic> j, String k) {
  final v = j[k];
  if (v is! T) throw FormatException('missing or invalid field "$k"');
  return v;
}
