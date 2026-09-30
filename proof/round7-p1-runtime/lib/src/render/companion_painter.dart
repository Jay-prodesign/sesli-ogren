import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../flow/flow_engine.dart';
import 'world_painter.dart' show PaintStats;

String companionLabel(CompanionState s, CompanionTone tone) => switch (s) {
  CompanionState.idle => 'Available',
  CompanionState.listen => 'Listening',
  CompanionState.think => 'Thinking',
  CompanionState.speak => 'Speaking',
  CompanionState.correct => tone == CompanionTone.correction ? 'Supportive correction' : 'Supportive attention',
  CompanionState.success => 'Success',
};

/// Provisional "D/Knot" runtime proxy: two interlaced loops plus two small offset attention
/// marks, drawn locally with CustomPaint. It exists to measure state-rendering cost and
/// state legibility. It is NOT the Founder-selected Companion identity or final art.
class KnotPainter extends CustomPainter {
  KnotPainter({
    required this.state,
    required this.tone,
    required this.motion,
    required this.animate,
    required this.stats,
    this.color = const Color(0xFF1F3A5F),
  }) : super(repaint: motion);

  final CompanionState state;
  final CompanionTone tone;
  final Animation<double> motion;
  final bool animate;
  final PaintStats stats;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    stats.frames++;
    final t = animate ? motion.value : 0.0;
    final wave = math.sin(t * math.pi * 2);
    final c = size.center(Offset.zero);
    final r = size.shortestSide * 0.3;

    // Static pose per state; motion only modulates it (reduced motion keeps the pose).
    final (lean, spread, scale) = switch (state) {
      CompanionState.idle => (0.0, 0.55, 1.0 + 0.02 * wave),
      CompanionState.listen => (0.14, 0.7, 1.0),
      CompanionState.think => (-0.08 + 0.1 * t, 0.45, 1.0),
      CompanionState.speak => (0.04, 0.6, 1.0 + 0.05 * wave.abs()),
      CompanionState.correct => (-0.12, tone == CompanionTone.correction ? 0.4 : 0.5, 1.0),
      CompanionState.success => (0.0, 0.85, 1.08 + 0.03 * wave),
    };

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(lean);
    canvas.scale(scale);

    final loop = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = r * (state == CompanionState.speak ? 0.2 + 0.05 * wave.abs() : 0.2)
      ..color = color;
    final under = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.3
      ..color = Colors.white;

    // Two loops rotated apart; the second is drawn over the first with a gap to read as interlaced.
    final a = Rect.fromCenter(center: Offset(-r * spread * 0.5, 0), width: r * 1.5, height: r * 1.9);
    final b = Rect.fromCenter(center: Offset(r * spread * 0.5, r * 0.08), width: r * 1.5, height: r * 1.7);
    _oval(canvas, a, loop);
    _arc(canvas, b, -math.pi * 0.35, math.pi * 1.3, under);
    _oval(canvas, b, loop..color = color.withValues(alpha: 0.9));
    _arc(canvas, a, math.pi * 0.2, math.pi * 0.35, under);
    _arc(canvas, a, math.pi * 0.2, math.pi * 0.35, loop..color = color);

    // Attention marks: two small, unequal, offset marks (no face).
    final gaze = switch (state) {
      CompanionState.listen => Offset(r * 0.25, -r * 0.2),
      CompanionState.think => Offset(-r * 0.25 + r * 0.2 * t, -r * 0.3),
      CompanionState.correct => Offset(r * 0.05, r * 0.05),
      _ => Offset.zero,
    };
    final mark = Paint()..color = color;
    _dot(canvas, Offset(-r * 0.12, -r * 0.45) + gaze, r * (state == CompanionState.listen ? 0.11 : 0.08), mark);
    _dot(canvas, Offset(r * 0.18, -r * 0.4) + gaze, r * 0.06, mark);

    switch (state) {
      case CompanionState.speak:
        final arc = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: 0.5);
        for (var i = 0; i < 2; i++) {
          final rr = r * (1.3 + i * 0.25 + (animate ? 0.1 * wave.abs() : 0));
          _arc(canvas, Rect.fromCircle(center: Offset.zero, radius: rr), -0.4, 0.8, arc);
        }
      case CompanionState.think:
        final dots = Paint()..color = color.withValues(alpha: 0.6);
        for (var i = 0; i < 3; i++) {
          final ang = -math.pi / 2 + i * 0.5 + t * math.pi * 2;
          _dot(canvas, Offset(math.cos(ang), math.sin(ang)) * r * 1.35, 3, dots);
        }
      case CompanionState.success:
        final ring = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = const Color(0xFF0B5D63);
        _oval(canvas, Rect.fromCircle(center: Offset.zero, radius: r * 1.45), ring);
      case CompanionState.correct:
        if (tone == CompanionTone.correction) {
          // Guiding arc toward the world: correction points somewhere, it does not punish.
          final guide = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0xFF0B5D63);
          _arc(canvas, Rect.fromCircle(center: Offset.zero, radius: r * 1.35), -math.pi * 0.9, math.pi * 0.5, guide);
        }
      case CompanionState.idle || CompanionState.listen:
        break;
    }
    canvas.restore();
  }

  void _oval(Canvas c, Rect r, Paint p) {
    stats.ops++;
    c.drawOval(r, p);
  }

  void _arc(Canvas c, Rect r, double start, double sweep, Paint p) {
    stats.ops++;
    c.drawArc(r, start, sweep, false, p);
  }

  void _dot(Canvas c, Offset o, double r, Paint p) {
    stats.ops++;
    c.drawCircle(o, r, p);
  }

  @override
  bool shouldRepaint(KnotPainter old) => old.state != state || old.tone != tone || old.animate != animate;
}
