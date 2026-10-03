import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../flow/flow_engine.dart';
import 'companion_painter.dart';
import 'world_painter.dart' show PaintStats;

/// Visual seam for the Companion body.
///
/// State, semantics, fallback behavior and motion policy remain owned by
/// CompanionView. The renderer expresses that contract; it never decides
/// learning truth.
abstract interface class CompanionRenderer {
  Widget build({
    required CompanionState state,
    required CompanionTone tone,
    required Animation<double> motion,
    required bool animate,
    required PaintStats stats,
  });
}

final class _RasterProfile {
  const _RasterProfile({required this.mouthRect});

  /// Normalized to the source image canvas.
  final Rect mouthRect;

  Alignment get mouthAlignment {
    return Alignment(mouthRect.center.dx * 2 - 1, mouthRect.center.dy * 2 - 1);
  }
}

final class _MotionPose {
  const _MotionPose(this.angle, this.dx, this.dy, this.scale);

  final double angle;
  final double dx;
  final double dy;
  final double scale;
}

/// Founder-selected raster identity rendered with bounded, deterministic motion.
///
/// V1 is intentionally limbless. The canonical raster remains intact:
/// - body/state language uses whole-character transform/squash-style motion;
/// - SPEAK adds a local mouth-region warp from the same raster;
/// - blink is intentionally deferred: painting eyelids over flattened art failed visual QA.
///
/// This avoids regenerating state PNGs and avoids inventing hidden limb anatomy.
/// A heavier layered rig is admitted only if device QA proves this path
/// insufficient.
final class RasterCompanionRenderer implements CompanionRenderer {
  const RasterCompanionRenderer.knot()
    : assetPath = 'assets/companions/D_KNOT_128.webp',
      motionGain = 0.85,
      _profile = const _RasterProfile(
        mouthRect: Rect.fromLTRB(0.523, 0.447, 0.657, 0.560),
      );

  const RasterCompanionRenderer.tilt()
    : assetPath = 'assets/companions/E_TILT_128.webp',
      motionGain = 1.0,
      _profile = const _RasterProfile(
        mouthRect: Rect.fromLTRB(0.507, 0.398, 0.630, 0.507),
      );

  final String assetPath;
  final double motionGain;
  final _RasterProfile _profile;

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

        final gain = motionGain;
        final pose = switch (state) {
          CompanionState.idle => _MotionPose(0.0, 0.0, -1.2 * wave * gain, 1.0 + 0.012 * wave * gain),
          CompanionState.listen => _MotionPose(0.035 * gain, 1.0 * gain, -0.4 * wave, 1.005),
          CompanionState.think => _MotionPose(-0.035 * gain + 0.012 * wave, 0.0, 0.5 * wave, 0.995),
          CompanionState.speak => _MotionPose(0.012 * gain, 0.0, -0.5 * pulse, 1.0 + 0.025 * pulse * gain),
          CompanionState.correct => _MotionPose(-0.022 * gain, -0.5 * gain, 0.0, 0.995),
          CompanionState.success => _MotionPose(0.0, 0.0, -2.2 * pulse * gain, 1.025 + 0.018 * pulse * gain),
        };

        final mouthScaleY = state == CompanionState.speak && animate ? 0.86 + 0.24 * pulse : 1.0;
        Widget raster({Key? key}) {
          return Image.asset(
            assetPath,
            key: key,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => key == null
                ? const SizedBox.shrink()
                : CustomPaint(
                    painter: KnotPainter(state: state, tone: tone, motion: motion, animate: animate, stats: stats),
                  ),
          );
        }

        final body = Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            raster(key: const Key('companion-raster')),
            if (state == CompanionState.speak && animate)
              ClipPath(
                key: const Key('companion-mouth-warp'),
                clipper: _NormalizedOvalClipper(_profile.mouthRect),
                child: Transform(
                  alignment: _profile.mouthAlignment,
                  transform: Matrix4.diagonal3Values(1.0, mouthScaleY, 1.0),
                  child: raster(),
                ),
              ),
          ],
        );

        return Transform.translate(
          offset: Offset(pose.dx, pose.dy),
          child: Transform.rotate(
            angle: pose.angle,
            child: Transform.scale(scale: pose.scale, child: body),
          ),
        );
      },
    );
  }

}

final class _NormalizedOvalClipper extends CustomClipper<Path> {
  const _NormalizedOvalClipper(this.normalizedRect);

  final Rect normalizedRect;

  @override
  Path getClip(Size size) {
    final r = Rect.fromLTRB(
      normalizedRect.left * size.width,
      normalizedRect.top * size.height,
      normalizedRect.right * size.width,
      normalizedRect.bottom * size.height,
    );
    return Path()..addOval(r);
  }

  @override
  bool shouldReclip(_NormalizedOvalClipper oldClipper) => oldClipper.normalizedRect != normalizedRect;
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
      painter: KnotPainter(state: state, tone: tone, motion: motion, animate: animate, stats: stats),
    );
  }
}
