import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../scene/scene_schema.dart';

/// Counts draw operations so tiers can be compared for cost (degradation must reduce work).
class PaintStats {
  int ops = 0;
  int frames = 0;
}

class WorldPalette {
  const WorldPalette({required this.accent, required this.ink, required this.surface, required this.focus});

  final Color accent;
  final Color ink;
  final Color surface;
  final Color focus;

  static const neutral = WorldPalette(
    accent: Color(0xFF4B5563),
    ink: Color(0xFF111827),
    surface: Color(0xFFF3F4F6),
    focus: Color(0xFF111827),
  );

  /// Domain theme selects accent only; structure comes from the layout grammar, not colour.
  static WorldPalette forTheme(String theme) => switch (theme) {
    'biology_process' => const WorldPalette(
      accent: Color(0xFF2F6B45),
      ink: Color(0xFF14261B),
      surface: Color(0xFFEFF5EF),
      focus: Color(0xFF0B5D63),
    ),
    'fraction_relation' => const WorldPalette(
      accent: Color(0xFF3E4FB8),
      ink: Color(0xFF151A3B),
      surface: Color(0xFFF0F1FA),
      focus: Color(0xFF0B5D63),
    ),
    'accounting_relation' => const WorldPalette(
      accent: Color(0xFF8A5A12),
      ink: Color(0xFF2A1D08),
      surface: Color(0xFFF7F2EA),
      focus: Color(0xFF0B5D63),
    ),
    _ => neutral,
  };
}

/// One reusable renderer for every fixture. It maps the bounded primitive vocabulary
/// (NODE/PATH/GROUP/PARTITION/PAIR/TRACE/FOCUS_MARK) through a layout grammar chosen by
/// `layout_hint`; there is no per-domain renderer class.
class WorldPainter extends CustomPainter {
  WorldPainter({
    required this.scene,
    required this.motion,
    required this.reducedMotion,
    required this.textScaler,
    required this.stats,
  }) : super(repaint: motion);

  final SceneSpec scene;
  final Animation<double> motion;
  final bool reducedMotion;
  final TextScaler textScaler;
  final PaintStats stats;

  FallbackLevel get tier => scene.fallbackLevel;

  /// Neutral grammar is used for the NEUTRAL tier and for low-confidence themes.
  bool get neutralGrammar => tier == FallbackLevel.neutral || !scene.themeTrusted;
  bool get animate => !reducedMotion && tier == FallbackLevel.full;
  bool get decorate => tier == FallbackLevel.full;
  bool get domainColour => tier == FallbackLevel.full || tier == FallbackLevel.reduced;

  WorldPalette get palette =>
      domainColour && !neutralGrammar ? WorldPalette.forTheme(scene.domainTheme) : WorldPalette.neutral;

  @override
  void paint(Canvas canvas, Size size) {
    stats.frames++;
    final p = palette;
    _rect(canvas, Offset.zero & size, Paint()..color = p.surface);
    if (decorate && !neutralGrammar) _decorate(canvas, size);
    final layout = neutralGrammar ? _layoutNeutral(size) : _layoutFor(size);
    if (!neutralGrammar && scene.primitives.contains(Primitive.group)) _groups(canvas, layout, p);
    if (!neutralGrammar && scene.layoutHint == LayoutHint.partition) {
      _partitionWorld(canvas, size, layout, p);
    } else {
      for (final e in scene.edges) {
        _edge(canvas, e, layout, p);
      }
      for (final n in scene.nodes) {
        _node(canvas, n, layout[n.id]!, p);
      }
    }
  }

  // --- layout grammars ----------------------------------------------------------

  Map<String, Rect> _layoutFor(Size s) => switch (scene.layoutHint) {
    LayoutHint.flow => _layoutFlow(s),
    LayoutHint.partition => _layoutPartition(s),
    LayoutHint.trace || LayoutHint.balance || LayoutHint.compare => _layoutTrace(s),
  };

  /// FLOW: enablers/inputs converge on the process; outputs diverge from it.
  Map<String, Rect> _layoutFlow(Size s) {
    final w = s.width, h = s.height;
    final nw = w * 0.27, nh = h * 0.16;
    final left = scene.nodes.where((n) => n.role == 'input' || n.role == 'enabler').toList();
    final right = scene.nodes.where((n) => n.role == 'output').toList();
    final out = <String, Rect>{};
    for (var i = 0; i < left.length; i++) {
      final cy = h * (i + 1) / (left.length + 1);
      out[left[i].id] = Rect.fromCenter(center: Offset(w * 0.16, cy), width: nw, height: nh);
    }
    for (var i = 0; i < right.length; i++) {
      final cy = h * (i + 1) / (right.length + 1);
      out[right[i].id] = Rect.fromCenter(center: Offset(w * 0.84, cy), width: nw, height: nh);
    }
    for (final n in scene.nodes.where((n) => !out.containsKey(n.id))) {
      out[n.id] = Rect.fromCenter(center: Offset(w * 0.5, h * 0.5), width: w * 0.3, height: h * 0.3);
    }
    return out;
  }

  /// PARTITION: one whole bar and aligned part bars of the same width, plus an invariant marker.
  Map<String, Rect> _layoutPartition(Size s) {
    final w = s.width, h = s.height;
    final barW = w * 0.62, barH = h * 0.14, x = w * 0.08;
    final parts = scene.nodes.where((n) => n.role == 'part').toList();
    final out = <String, Rect>{};
    for (final n in scene.nodes.where((n) => n.role == 'whole')) {
      out[n.id] = Rect.fromLTWH(x, h * 0.1, barW, barH);
    }
    for (var i = 0; i < parts.length; i++) {
      out[parts[i].id] = Rect.fromLTWH(x, h * (0.38 + i * 0.26), barW, barH);
    }
    for (final n in scene.nodes.where((n) => n.role == 'invariant')) {
      out[n.id] = Rect.fromLTWH(x + barW + w * 0.04, h * 0.38, w * 0.22, h * 0.4);
    }
    return out;
  }

  /// TRACE: event → classification → paired effects, with a contrast branch below.
  Map<String, Rect> _layoutTrace(Size s) {
    final w = s.width, h = s.height;
    final nw = w * 0.24, nh = h * 0.17;
    final out = <String, Rect>{};
    final effects = scene.nodes.where((n) => n.role == 'effect').toList();
    for (final n in scene.nodes) {
      switch (n.role) {
        case 'event':
          out[n.id] = Rect.fromCenter(center: Offset(w * 0.14, h * 0.38), width: nw, height: nh);
        case 'classification':
          out[n.id] = Rect.fromCenter(center: Offset(w * 0.46, h * 0.38), width: nw, height: nh);
        case 'contrast':
          out[n.id] = Rect.fromCenter(center: Offset(w * 0.46, h * 0.82), width: nw, height: nh);
      }
    }
    for (var i = 0; i < effects.length; i++) {
      out[effects[i].id] = Rect.fromCenter(center: Offset(w * 0.84, h * (0.2 + i * 0.36)), width: nw, height: nh);
    }
    for (final n in scene.nodes.where((n) => !out.containsKey(n.id))) {
      out[n.id] = Rect.fromCenter(center: Offset(w * 0.5, h * 0.5), width: nw, height: nh);
    }
    return out;
  }

  /// NEUTRAL: generic columns by topological depth; nodes, arrows and labels only.
  Map<String, Rect> _layoutNeutral(Size s) {
    final depth = <String, int>{for (final n in scene.nodes) n.id: 0};
    for (var pass = 0; pass < scene.nodes.length; pass++) {
      for (final e in scene.edges.where((e) => e.directed)) {
        depth[e.to] = math.max(depth[e.to]!, depth[e.from]! + 1);
      }
    }
    final maxD = depth.values.fold(0, math.max);
    final cols = <int, List<String>>{};
    for (final n in scene.nodes) {
      cols.putIfAbsent(depth[n.id]!, () => []).add(n.id);
    }
    final out = <String, Rect>{};
    final nw = s.width / (maxD + 1) * 0.78, nh = s.height * 0.14;
    cols.forEach((d, ids) {
      for (var i = 0; i < ids.length; i++) {
        final c = Offset(s.width * (d + 0.5) / (maxD + 1), s.height * (i + 1) / (ids.length + 1));
        out[ids[i]] = Rect.fromCenter(center: c, width: nw, height: nh);
      }
    });
    return out;
  }

  // --- primitives ------------------------------------------------------------------

  void _groups(Canvas canvas, Map<String, Rect> layout, WorldPalette p) {
    if (tier == FallbackLevel.simple) return;
    Rect? bounds(Iterable<String> ids) {
      Rect? r;
      for (final id in ids) {
        if (scene.visOf(id) == Vis.hidden) continue;
        final b = layout[id]!;
        r = r == null ? b : r.expandToInclude(b);
      }
      return r?.inflate(8);
    }

    final inputs = bounds(scene.nodes.where((n) => n.role == 'input' || n.role == 'enabler').map((n) => n.id));
    final outputs = bounds(scene.nodes.where((n) => n.role == 'output').map((n) => n.id));
    final paint = Paint()..color = p.accent.withValues(alpha: 0.07);
    for (final g in [inputs, outputs]) {
      if (g != null) _rrect(canvas, RRect.fromRectAndRadius(g, const Radius.circular(18)), paint);
    }
  }

  void _decorate(Canvas canvas, Size size) {
    final token = scene.decorativeTokens.isEmpty ? '' : scene.decorativeTokens.first;
    final paint = Paint()
      ..color = palette.accent.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final drift = animate ? motion.value * 12 : 0.0;
    switch (token) {
      case 'soft_cellular_texture':
        for (var i = 0; i < 18; i++) {
          final x = (i * 97 % 100) / 100 * size.width;
          final y = ((i * 53 + 17) % 100) / 100 * size.height;
          _circle(canvas, Offset(x, y + drift), 14 + (i % 4) * 6.0, paint);
        }
      case 'subtle_grid':
        for (var x = 0.0; x < size.width; x += 24) {
          _line(canvas, Offset(x, 0), Offset(x, size.height), paint);
        }
        for (var y = drift % 24; y < size.height; y += 24) {
          _line(canvas, Offset(0, y), Offset(size.width, y), paint);
        }
      case 'subtle_ledger_rhythm':
        for (var y = 12.0 + drift % 18; y < size.height; y += 18) {
          _line(canvas, Offset(0, y), Offset(size.width, y), paint);
        }
    }
  }

  void _node(Canvas canvas, SceneNode n, Rect r, WorldPalette p) {
    final vis = scene.visOf(n.id);
    if (vis == Vis.hidden) return;
    final focused = scene.focus.contains(n.id);
    final alpha = vis == Vis.dimmed ? 0.35 : 1.0;
    final rr = RRect.fromRectAndRadius(r, Radius.circular(neutralGrammar ? 6 : 14));
    final fill = Paint()..color = Colors.white.withValues(alpha: alpha);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = focused ? 3 : 1.5
      ..color = (focused ? p.focus : p.accent).withValues(alpha: alpha);
    if (decorate && !neutralGrammar && vis != Vis.open) {
      _rrect(canvas, rr.shift(const Offset(0, 2)), Paint()..color = Colors.black.withValues(alpha: 0.06 * alpha));
    }
    if (vis == Vis.open) {
      _dashedRRect(canvas, rr, stroke..strokeWidth = focused ? 3 : 2);
      _label(canvas, '?', r, p.ink.withValues(alpha: 0.8), bold: true);
      return;
    }
    _rrect(canvas, rr, fill);
    _rrect(canvas, rr, stroke);
    if (focused) _focusMark(canvas, r, p);
    if (!neutralGrammar && n.role == 'process' && animate) {
      final glow = Paint()
        ..color = p.accent.withValues(alpha: 0.10 + 0.08 * math.sin(motion.value * math.pi * 2).abs());
      _rrect(canvas, rr.deflate(4), glow);
    }
    _label(canvas, n.label, r, p.ink.withValues(alpha: alpha));
  }

  /// FOCUS_MARK: corner brackets, a non-colour cue that survives monochrome.
  void _focusMark(Canvas canvas, Rect r, WorldPalette p) {
    final paint = Paint()
      ..color = p.focus
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    const k = 10.0;
    final g = r.inflate(5);
    for (final (c, dx, dy) in [
      (g.topLeft, 1.0, 1.0),
      (g.topRight, -1.0, 1.0),
      (g.bottomLeft, 1.0, -1.0),
      (g.bottomRight, -1.0, -1.0),
    ]) {
      _line(canvas, c, c + Offset(k * dx, 0), paint);
      _line(canvas, c, c + Offset(0, k * dy), paint);
    }
  }

  void _edge(Canvas canvas, SceneEdge e, Map<String, Rect> layout, WorldPalette p) {
    final vis = scene.visOf(e.id);
    if (vis == Vis.hidden) return;
    if (scene.visOf(e.from) == Vis.hidden || scene.visOf(e.to) == Vis.hidden) return;
    final a = layout[e.from]!, b = layout[e.to]!;
    final focused = scene.focus.contains(e.id);
    final alpha = vis == Vis.dimmed ? 0.3 : 1.0;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = focused ? 3.5 : 2
      ..color = (focused ? p.focus : p.accent).withValues(alpha: alpha);
    final start = _anchor(a, b.center), end = _anchor(b, a.center);
    final isPair = !e.directed; // PAIR primitive: undirected, equal-amount relation
    final isContrast = e.relation == 'is not';
    final path = Path()..moveTo(start.dx, start.dy);
    if (!neutralGrammar && scene.layoutHint == LayoutHint.flow) {
      final mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
      path.quadraticBezierTo(mid.dx, start.dy, end.dx, end.dy);
    } else {
      path.lineTo(end.dx, end.dy);
    }
    if (vis == Vis.open || isContrast) {
      _dashedPath(canvas, path, paint);
    } else {
      _path(canvas, path, paint);
    }
    if (isPair && !neutralGrammar) {
      // Balance marks: equal ticks on both ends show "same amount".
      for (final pt in [start, end]) {
        _line(canvas, pt + const Offset(-6, -6), pt + const Offset(6, -6), paint);
        _line(canvas, pt + const Offset(-6, -1), pt + const Offset(6, -1), paint);
      }
    } else if (e.directed) {
      _arrowHead(canvas, end, start, paint);
    }
    if (isContrast) {
      final m = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
      _line(canvas, m + const Offset(-7, -7), m + const Offset(7, 7), paint);
      _line(canvas, m + const Offset(-7, 7), m + const Offset(7, -7), paint);
    }
    final labelAt = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2 - 12);
    final text = vis == Vis.open ? '?' : e.relation;
    _label(
      canvas,
      text,
      Rect.fromCenter(center: labelAt, width: 110, height: 22),
      p.ink.withValues(alpha: 0.75 * alpha),
      small: true,
    );
    if (animate && vis == Vis.shown && scene.motionCue != null) {
      // flow_pulse / effect_trace: a token moving along the relation direction.
      final metric = path.computeMetrics().first;
      final t = (motion.value + e.id.hashCode % 7 / 7) % 1.0;
      final pos = metric.getTangentForOffset(metric.length * t)?.position;
      if (pos != null) _circle(canvas, pos, 4, Paint()..color = p.accent);
    }
  }

  /// PARTITION + PAIR grammar: aligned bars, equal-part segments, shaded extent,
  /// correspondence links and the invariant bracket. Equivalence is shown by geometry.
  void _partitionWorld(Canvas canvas, Size size, Map<String, Rect> layout, WorldPalette p) {
    final bars = scene.nodes.where((n) => n.role == 'part' || n.role == 'whole').toList();
    for (final n in bars) {
      final r = layout[n.id]!;
      final vis = scene.visOf(n.id);
      if (vis == Vis.hidden) continue;
      final alpha = vis == Vis.dimmed ? 0.35 : 1.0;
      final focused = scene.focus.contains(n.id);
      final den = n.intAttr('denominator', 1), num = n.intAttr('numerator', 0);
      final segs = den;
      var morph = 1.0;
      if (animate && scene.motionCue == 'partition_morph' && den > 2) {
        morph = (math.sin(motion.value * math.pi * 2) + 1) / 2; // extra dividers fade in/out
      }
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = focused ? 3 : 1.5
        ..color = (focused ? p.focus : p.accent).withValues(alpha: alpha);
      if (num > 0) {
        final shade = Rect.fromLTWH(r.left, r.top, r.width * num / den, r.height);
        _rect(canvas, shade, Paint()..color = p.accent.withValues(alpha: 0.35 * alpha));
      }
      _rect(canvas, r, stroke);
      for (var i = 1; i < segs; i++) {
        final x = r.left + r.width * i / segs;
        final major = den > 2 && i.isEven;
        final a = major ? alpha : alpha * (animate ? morph : 1.0);
        final divider = Paint()
          ..strokeWidth = 1.5
          ..color = p.accent.withValues(alpha: a);
        _line(canvas, Offset(x, r.top), Offset(x, r.bottom), divider);
      }
      if (focused) _focusMark(canvas, r, p);
      _label(
        canvas,
        n.label,
        Rect.fromLTWH(r.left, r.bottom + 2, r.width, 20),
        p.ink.withValues(alpha: alpha),
        small: true,
      );
    }
    // Correspondence links between part bars at the shaded extent boundary.
    final parts = scene.nodes.where((n) => n.role == 'part').toList();
    for (final e in scene.edges) {
      final vis = scene.visOf(e.id);
      if (vis == Vis.hidden) continue;
      final from = scene.node(e.from), to = scene.node(e.to);
      final focused = scene.focus.contains(e.id);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = focused ? 3 : 1.8
        ..color = (focused ? p.focus : p.accent).withValues(alpha: vis == Vis.dimmed ? 0.3 : 1.0);
      if (from.role == 'part' && to.role == 'part') {
        // Scaling relation: link shaded extent ends; label carries the common factor.
        final a = layout[from.id]!, b = layout[to.id]!;
        final xa = a.left + a.width * from.intAttr('numerator', 0) / from.intAttr('denominator', 1);
        final xb = b.left + b.width * to.intAttr('numerator', 0) / to.intAttr('denominator', 1);
        final path = Path()
          ..moveTo(xa, a.bottom)
          ..lineTo(xb, b.top);
        vis == Vis.open ? _dashedPath(canvas, path, paint) : _path(canvas, path, paint);
        _label(
          canvas,
          vis == Vis.open ? '?' : e.relation,
          Rect.fromCenter(center: Offset(xa + 44, (a.bottom + b.top) / 2), width: 80, height: 20),
          p.ink,
          small: true,
        );
      } else if (to.role == 'invariant') {
        final a = layout[from.id]!, inv = layout[to.id]!;
        final x = a.left + a.width * from.intAttr('numerator', 0) / from.intAttr('denominator', 1);
        final path = Path()
          ..moveTo(x, a.center.dy)
          ..lineTo(inv.left, inv.center.dy);
        vis == Vis.open ? _dashedPath(canvas, path, paint) : _path(canvas, path, paint);
      } else if (from.role == 'whole' && to.role == 'part') {
        final a = layout[from.id]!, b = layout[to.id]!;
        _line(canvas, Offset(a.left - 6, a.center.dy), Offset(b.left - 6, b.center.dy), paint);
      }
    }
    // Invariant: bracket spanning the shared shaded extent across all part bars.
    for (final n in scene.nodes.where((n) => n.role == 'invariant')) {
      final vis = scene.visOf(n.id);
      if (vis == Vis.hidden) continue;
      final r = layout[n.id]!;
      final focused = scene.focus.contains(n.id);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = focused ? 3.5 : 2
        ..color = focused ? p.focus : p.accent;
      if (vis == Vis.open) {
        _dashedRRect(canvas, RRect.fromRectAndRadius(r, const Radius.circular(10)), paint);
        _label(canvas, '?', r, p.ink, bold: true);
        continue;
      }
      if (parts.isNotEmpty) {
        final first = layout[parts.first.id]!, last = layout[parts.last.id]!;
        final x =
            first.left + first.width * parts.first.intAttr('numerator', 0) / parts.first.intAttr('denominator', 1);
        _line(canvas, Offset(x, first.top - 6), Offset(x, last.bottom + 6), paint);
        _line(canvas, Offset(first.left, last.bottom + 6), Offset(x, last.bottom + 6), paint);
      }
      _rrect(canvas, RRect.fromRectAndRadius(r, const Radius.circular(10)), Paint()..color = Colors.white);
      _rrect(canvas, RRect.fromRectAndRadius(r, const Radius.circular(10)), paint);
      if (focused) _focusMark(canvas, r, p);
      _label(canvas, n.label, r, p.ink);
    }
  }

  // --- drawing helpers (each counts one op) -----------------------------------------------

  Offset _anchor(Rect r, Offset toward) {
    final c = r.center;
    final d = toward - c;
    if (d.distance == 0) return c;
    final sx = d.dx == 0 ? double.infinity : (r.width / 2) / d.dx.abs();
    final sy = d.dy == 0 ? double.infinity : (r.height / 2) / d.dy.abs();
    final s = math.min(sx, sy);
    return c + d * s;
  }

  void _arrowHead(Canvas canvas, Offset tip, Offset from, Paint paint) {
    final dir = (tip - from);
    if (dir.distance == 0) return;
    final u = dir / dir.distance;
    final n = Offset(-u.dy, u.dx);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo((tip - u * 10 + n * 5).dx, (tip - u * 10 + n * 5).dy)
      ..moveTo(tip.dx, tip.dy)
      ..lineTo((tip - u * 10 - n * 5).dx, (tip - u * 10 - n * 5).dy);
    _path(canvas, path, paint);
  }

  void _dashedPath(Canvas canvas, Path path, Paint paint) {
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 10) {
        _path(canvas, m.extractPath(d, math.min(d + 6, m.length)), paint);
      }
    }
  }

  void _dashedRRect(Canvas canvas, RRect rr, Paint paint) => _dashedPath(canvas, Path()..addRRect(rr), paint);

  void _label(Canvas canvas, String text, Rect r, Color color, {bool small = false, bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: small ? 11 : 13,
          fontWeight: bold || !small ? FontWeight.w600 : FontWeight.w400,
          height: 1.15,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      textScaler: textScaler.clamp(maxScaleFactor: 1.6),
      maxLines: 3,
      ellipsis: '…',
    )..layout(maxWidth: math.max(24, r.width - 8));
    stats.ops++;
    tp.paint(canvas, Offset(r.center.dx - tp.width / 2, r.center.dy - tp.height / 2));
  }

  void _rect(Canvas c, Rect r, Paint p) {
    stats.ops++;
    c.drawRect(r, p);
  }

  void _rrect(Canvas c, RRect r, Paint p) {
    stats.ops++;
    c.drawRRect(r, p);
  }

  void _line(Canvas c, Offset a, Offset b, Paint p) {
    stats.ops++;
    c.drawLine(a, b, p);
  }

  void _circle(Canvas c, Offset o, double r, Paint p) {
    stats.ops++;
    c.drawCircle(o, r, p);
  }

  void _path(Canvas c, Path path, Paint p) {
    stats.ops++;
    c.drawPath(path, p);
  }

  @override
  bool shouldRepaint(WorldPainter old) =>
      old.scene != scene || old.reducedMotion != reducedMotion || old.textScaler != textScaler;
}
