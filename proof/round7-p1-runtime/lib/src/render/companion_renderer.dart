import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../flow/flow_engine.dart';
import 'companion_painter.dart';
import 'world_painter.dart' show PaintStats;

/// Visual seam for the Companion body.
///
/// State, semantics, fallback behavior and motion policy remain owned by
/// [CompanionView]. Concrete finalist art only needs to render the supplied
/// state/tone/motion contract, so replacing the provisional proxy does not
/// require rewriting the learning-flow UI.
abstract interface class CompanionRenderer {
  Widget build({
    required CompanionState state,
    required CompanionTone tone,
    required Animation<double> motion,
    required bool animate,
    required PaintStats stats,
  });
}

/// Founder-selected raster identity rendered with bounded whole-character motion.
///
/// This is the APP-FIRST V1 path: the canonical character art stays intact while
/// the existing semantic state machine supplies motion. Facial layer extraction
/// from a flattened PNG is intentionally not faked; blink/lip-sync can be added
/// later from a properly authored layered source if device evidence justifies it.
final class RasterCompanionRenderer implements CompanionRenderer {
  const RasterCompanionRenderer({
    required this.assetPath,
    this.motionGain = 1.0,
  });

  const RasterCompanionRenderer.knot()
      : assetPath = 'assets/companions/D_KNOT_128.webp',
        motionGain = 0.85;

  const RasterCompanionRenderer.tilt()
      : assetPath = 'assets/companions/E_TILT_128.webp',
        motionGain = 1.0;

  final String assetPath;
  final double motionGain;

  @override
  Widget build({
    required CompanionState state,
    required CompanionTone tone,
    required Animation<double> motion,
    required bool animate,
    required PaintStats stats,
  }) {
    return AnimatedBuilder(
      key: const Key('companion-canvas'),
      animation: motion,
      builder: (context, _) {
        stats.frames++;
        stats.ops++;

        final t = animate ? motion.value : 0.0;
        final wave = math.sin(t * math.pi * 2);
        final pulse = wave.abs();

        final (angle, dx, dy, scale) = switch (state) {
          CompanionState.idle => (
            0.0,
            0.0,
            -1.2 * wave * motionGain,
            1.0 + 0.012 * wave * motionGain,
          ),
          CompanionState.listen => (
            0.035 * motionGain,
            1.0 * motionGain,
            -0.4 * wave,
            1.005,
          ),
          CompanionState.think => (
            -0.035 * motionGain + 0.012 * wave,
            0.0,
            0.5 * wave,
            0.995,
          ),
          CompanionState.speak => (
            0.012 * motionGain,
            0.0,
            -0.5 * pulse,
            1.0 + 0.025 * pulse * motionGain,
          ),
          CompanionState.correct => (
            -0.022 * motionGain,
            -0.5 * motionGain,
            0.0,
            0.995,
          ),
          CompanionState.success => (
            0.0,
            0.0,
            -2.2 * pulse * motionGain,
            1.025 + 0.018 * pulse * motionGain,
          ),
        };

        return Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.rotate(
            angle: angle,
            child: Transform.scale(
              scale: scale,
              child: Image.asset(
                assetPath,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) => CustomPaint(
                  painter: KnotPainter(
                    state: state,
                    tone: tone,
                    motion: motion,
                    animate: animate,
                    stats: stats,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Original Round 7 runtime proxy kept as a technical fallback.
final class KnotProxyCompanionRenderer implements CompanionRenderer {
  const KnotProxyCompanionRenderer();

  @override
  Widget build({
    required CompanionState state,
    required CompanionTone tone,
    required Animation<double> motion,
    required bool animate,
    required PaintStats stats,
  }) {
    return CustomPaint(
      key: const Key('companion-canvas'),
      painter: KnotPainter(
        state: state,
        tone: tone,
        motion: motion,
        animate: animate,
        stats: stats,
      ),
    );
  }
}
