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
  const _RasterProfile({required this.mouthRect, required this.eyeRects, required this.skin, required this.lash});

  /// Normalized to the source image canvas.
  final Rect mouthRect;
  final List<Rect> eyeRects;
  final Color skin;
  final Color lash;

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
/// - blink is a tiny procedural eyelid overlay.
///
/// This avoids regenerating state PNGs and avoids inventing hidden limb anatomy.
/// A heavier layered rig is admitted only if device QA proves this path
/// insufficient.
final class RasterCompanionRenderer implements CompanionRenderer {
  const RasterCompanionRenderer._({required this.assetPath, required _RasterProfile profile, this.motionGain = 1.0})
    : _profile = profile;

  const RasterCompanionRenderer.knot()
    : assetPath = 'assets/companions/D_KNOT_128.webp',
      motionGain = 0.85,
      _profile = const _RasterProfile(
        mouthRect: Rect.fromLTRB(0.523, 0.447, 0.657, 0.560),
        eyeRects: [Rect.fromLTRB(0.416, 0.420, 0.558, 0.531), Rect.fromLTRB(0.557, 0.345, 0.691, 0.448)],
        skin: Color(0xFFF3E2DE),
        lash: Color(0xFF171C4A),
      );

  const RasterCompanionRenderer.tilt()
    : assetPath = 'assets/companions/E_TILT_128.webp',
      motionGain = 1.0,
      profile = const _RasterProfile(
        mouthRect: Rect.fromLTRB(0.507, 0.398, 0.630, 0.507),
        eyeRects: [Rect.fromLTRB(0.374, 0.361, 0.512, 0.466), Rect.fromLTRB(0.541, 0.318, 0.670, 0.419)],
        skin: Color(0xFFF6E2E4),
        lash: Color(0xFF4B1E62),
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
        final blinkClosed = animate && _blinkClosed(t);

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
            if (blinkClosed) CustomPaint(key: const Key('companion-blink-overlay'), painter: _BlinkPainter(_profile)),
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

  static bool _blinkClosed(double t) {
    // One short deterministic blink per 1.6 s motion cycle.
    // No random timer means reproducible tests and no extra controller.
    return t >= 0.13 && t <= 0.19;
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

final class _BlinkPainter extends CustomPainter {
  const _BlinkPainter(this.profile);

  final _RasterProfile profile;

  @override
  void paint(Canvas canvas, Size size) {
    final skin = Paint()
      ..style = PaintingStyle.fill
      ..color = profile.skin;
    final lash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1.4, size.shortestSide * 0.035)
      ..color = profile.lash;

    for (final n in profile.eyeRects) {
      final r = Rect.fromLTRB(n.left * size.width, n.top * size.height, n.right * size.width, n.bottom * size.height);
      canvas.drawOval(r, skin);

      final y = r.center.dy + r.height * 0.03;
      final p = Path()
        ..moveTo(r.left + r.width * 0.18, y)
        ..quadraticBezierTo(r.center.dx, y + r.height * 0.22, r.right - r.width * 0.18, y);
      canvas.drawPath(p, lash);
    }
  }

  @override
  bool shouldRepaint(_BlinkPainter oldDelegate) => oldDelegate.profile != profile;
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
