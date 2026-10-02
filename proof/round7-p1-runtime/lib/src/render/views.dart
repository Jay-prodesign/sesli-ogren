import 'package:flutter/material.dart';

import '../flow/flow_engine.dart';
import '../scene/scene_schema.dart';
import 'companion_painter.dart';
import 'companion_renderer.dart';
import 'world_painter.dart';

/// Live animation-controller count, used to detect leaked/duplicated controllers (B13).
class LiveControllers {
  static int count = 0;
}

/// Textual scene description in semantic order. Used for screen readers and for the
/// CONTENT tier, so critical meaning never depends on the canvas.
List<String> describeScene(SceneSpec s) {
  String label(String id) => s.nodes.firstWhere((n) => n.id == id).label;
  final lines = <String>[];
  for (final e in s.edges) {
    final v = s.visOf(e.id);
    if (v == Vis.hidden || s.visOf(e.from) == Vis.hidden || s.visOf(e.to) == Vis.hidden) continue;
    final from = s.visOf(e.from) == Vis.open ? '(missing)' : label(e.from);
    final to = s.visOf(e.to) == Vis.open ? '(missing)' : label(e.to);
    final focus = s.focus.contains(e.id) ? ' [focus]' : '';
    if (v == Vis.open) {
      lines.add('$from → ? → $to (relation still to explain)$focus');
    } else {
      final arrow = e.directed ? '→' : '↔';
      lines.add('$from $arrow ${e.relation} $arrow $to$focus');
    }
  }
  for (final n in s.nodes) {
    if (s.visOf(n.id) == Vis.open && !lines.any((l) => l.contains('(missing)'))) {
      lines.add('Missing element to explain${s.focus.contains(n.id) ? ' [focus]' : ''}');
    }
  }
  return lines;
}

class WorldView extends StatefulWidget {
  const WorldView({super.key, required this.scene, required this.reducedMotion, required this.stats});

  final SceneSpec scene;
  final bool reducedMotion;
  final PaintStats stats;
  final CompanionRenderer renderer;

  @override
  State<WorldView> createState() => _WorldViewState();
}

class _WorldViewState extends State<WorldView> with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(vsync: this, duration: const Duration(seconds: 3));

  bool get _animate => !widget.reducedMotion && widget.scene.fallbackLevel == FallbackLevel.full;

  @override
  void initState() {
    super.initState();
    LiveControllers.count++;
    _sync();
  }

  @override
  void didUpdateWidget(WorldView old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (_animate) {
      if (!_motion.isAnimating) _motion.repeat();
    } else {
      _motion.stop();
    }
  }

  @override
  void dispose() {
    LiveControllers.count--;
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lines = describeScene(widget.scene);
    if (widget.scene.fallbackLevel == FallbackLevel.content) {
      return ContentFirstWorld(lines: lines);
    }
    return Semantics(
      label: 'Learning world. ${lines.join('. ')}',
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: WorldPainter(
              scene: widget.scene,
              motion: _motion,
              reducedMotion: widget.reducedMotion,
              textScaler: MediaQuery.textScalerOf(context),
              stats: widget.stats,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

/// CONTENT tier: the same relations as text. No canvas, no animation.
class ContentFirstWorld extends StatelessWidget {
  const ContentFirstWorld({super.key, required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('content-first-world'),
      color: const Color(0xFFF3F4F6),
      padding: const EdgeInsets.all(12),
      child: ListView(
        children: [
          Text('Relations (content-first)', style: Theme.of(context).textTheme.titleSmall),
          for (final l in lines) Padding(padding: const EdgeInsets.only(top: 6), child: Text('• $l')),
        ],
      ),
    );
  }
}

class CompanionView extends StatefulWidget {
  const CompanionView({
    super.key,
    required this.state,
    required this.tone,
    required this.tier,
    required this.reducedMotion,
    required this.assetFailed,
    required this.stats,
    this.renderer = const KnotProxyCompanionRenderer(),
  });

  final CompanionState state;
  final CompanionTone tone;
  final FallbackLevel tier;
  final bool reducedMotion;
  final bool assetFailed;
  final PaintStats stats;

  @override
  State<CompanionView> createState() => _CompanionViewState();
}

class _CompanionViewState extends State<CompanionView> with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  bool get _drawn =>
      !widget.assetFailed && widget.tier != FallbackLevel.neutral && widget.tier != FallbackLevel.content;
  bool get _animate => _drawn && !widget.reducedMotion && widget.tier == FallbackLevel.full;

  @override
  void initState() {
    super.initState();
    LiveControllers.count++;
    _sync();
  }

  @override
  void didUpdateWidget(CompanionView old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (_animate) {
      if (!_motion.isAnimating) _motion.repeat();
    } else {
      _motion.stop();
    }
  }

  @override
  void dispose() {
    LiveControllers.count--;
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = companionLabel(widget.state, widget.tone);
    final chip = Semantics(
      liveRegion: true,
      label: 'Companion: $label',
      child: ExcludeSemantics(
        child: Container(
          key: const Key('companion-label'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF1F3A5F)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
    if (!_drawn) return chip;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: RepaintBoundary(
            child: widget.renderer.build(
              state: widget.state,
              tone: widget.tone,
              motion: _motion,
              animate: _animate,
              stats: widget.stats,
            ),
          ),
        ),
        const SizedBox(height: 4),
        chip,
      ],
    );
  }
}
