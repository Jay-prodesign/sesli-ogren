import 'dart:math' as math;

import 'package:flutter/material.dart';

enum CompanionVisualState { idle, listen, think, speak, correct, success }

class CompanionView extends StatefulWidget {
  const CompanionView({required this.state, this.size = 128, super.key});

  final CompanionVisualState state;
  final double size;

  @override
  State<CompanionView> createState() => _CompanionViewState();
}

class _CompanionViewState extends State<CompanionView> with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.maybeOf(context);
    final reduced = (media?.disableAnimations ?? false) || (media?.accessibleNavigation ?? false);
    if (reduced == _reducedMotion) {
      return;
    }
    _reducedMotion = reduced;
    if (_reducedMotion) {
      _motion
        ..stop()
        ..value = 0;
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: _semanticLabel(widget.state),
      child: SizedBox.square(
        dimension: widget.size,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _motion,
            builder: (context, child) {
              final t = _reducedMotion ? 0.0 : _motion.value;
              final wave = math.sin(t * math.pi * 2);
              final pulse = wave.abs();
              final pose = switch (widget.state) {
                CompanionVisualState.idle => (angle: 0.0, dx: 0.0, dy: -1.7 * wave, scale: 1.0 + 0.014 * wave),
                CompanionVisualState.listen => (angle: 0.047, dx: 1.35, dy: -0.55 * wave, scale: 1.01),
                CompanionVisualState.think => (angle: -0.051 + 0.017 * wave, dx: 0.0, dy: 0.68 * wave, scale: 0.99),
                CompanionVisualState.speak => (
                  angle: 0.018 * wave,
                  dx: 0.0,
                  dy: -1.2 * wave,
                  scale: 1.012 + 0.012 * pulse,
                ),
                CompanionVisualState.correct => (angle: -0.038, dx: -1.0, dy: 0.0, scale: 0.99),
                CompanionVisualState.success => (angle: 0.0, dx: 0.0, dy: -3.4 * pulse, scale: 1.025 + 0.025 * pulse),
              };

              return Transform.translate(
                offset: Offset(pose.dx, pose.dy),
                child: Transform.rotate(
                  angle: pose.angle,
                  child: Transform.scale(scale: pose.scale, child: child),
                ),
              );
            },
            child: Image.asset(
              'assets/companions/D_KNOT_128.webp',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) =>
                  Center(child: Text('Düğüm', style: Theme.of(context).textTheme.titleMedium)),
            ),
          ),
        ),
      ),
    );
  }

  static String _semanticLabel(CompanionVisualState state) => switch (state) {
    CompanionVisualState.idle => 'Düğüm hazır',
    CompanionVisualState.listen => 'Düğüm seni dinliyor',
    CompanionVisualState.think => 'Düğüm düşünüyor',
    CompanionVisualState.speak => 'Düğüm konuşuyor',
    CompanionVisualState.correct => 'Düğüm destek oluyor',
    CompanionVisualState.success => 'Düğüm başarıyı kutluyor',
  };
}
