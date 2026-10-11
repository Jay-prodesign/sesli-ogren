import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_theme.dart';

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
  void didUpdateWidget(covariant CompanionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state && !_reducedMotion) {
      _motion
        ..reset()
        ..repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.maybeOf(context);
    final reduced =
        (media?.disableAnimations ?? false) ||
        (media?.accessibleNavigation ?? false) ||
        !TickerMode.valuesOf(context).enabled;
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
              final listeningBeat = math.sin(t * math.pi * 4);
              final thinkingDrift = math.sin(t * math.pi * 2 - math.pi / 3);
              final pose = switch (widget.state) {
                CompanionVisualState.idle => (angle: 0.0, dx: 0.0, dy: -1.7 * wave, scale: 1.0 + 0.014 * wave),
                CompanionVisualState.listen => (
                  angle: 0.045 + 0.008 * listeningBeat,
                  dx: 1.1,
                  dy: -0.7 * listeningBeat,
                  scale: 1.005 + 0.008 * listeningBeat.abs(),
                ),
                CompanionVisualState.think => (
                  angle: -0.045 + 0.024 * thinkingDrift,
                  dx: -0.6 * thinkingDrift,
                  dy: 0.9 * thinkingDrift,
                  scale: 0.985 + 0.006 * pulse,
                ),
                CompanionVisualState.speak => (
                  angle: 0.018 * wave,
                  dx: 0.0,
                  dy: -1.2 * wave,
                  scale: 1.012 + 0.012 * pulse,
                ),
                CompanionVisualState.correct => (angle: -0.035 + 0.008 * wave, dx: -0.8, dy: 0.3 * wave, scale: 0.99),
                CompanionVisualState.success => (
                  angle: 0.025 * wave,
                  dx: 0.0,
                  dy: -3.4 * pulse,
                  scale: 1.025 + 0.025 * pulse,
                ),
              };

              return Transform.translate(
                offset: Offset(pose.dx, pose.dy),
                child: Transform.rotate(
                  angle: pose.angle,
                  child: Transform.scale(scale: pose.scale, child: child),
                ),
              );
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: AnimatedContainer(
                    duration: _reducedMotion ? Duration.zero : const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    margin: EdgeInsets.all(widget.size * 0.025),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _haloColor(widget.state), width: widget.size * 0.018),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.all(widget.size * 0.13),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: switch (widget.state) {
                          CompanionVisualState.success => AppPalette.momentum.withValues(alpha: 0.28),
                          CompanionVisualState.correct => AppPalette.attentionSoft,
                          CompanionVisualState.listen => AppPalette.signalSoft,
                          CompanionVisualState.think => AppPalette.primarySoft,
                          CompanionVisualState.speak => AppPalette.surfaceMuted,
                          CompanionVisualState.idle => AppPalette.surfaceMuted,
                        },
                      ),
                    ),
                  ),
                ),
                Image.asset(
                  'assets/companions/D_KNOT_128.webp',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stackTrace) =>
                      Center(child: Text('Düğüm', style: Theme.of(context).textTheme.titleMedium)),
                ),
                if (widget.state != CompanionVisualState.idle)
                  Positioned(
                    right: widget.size * 0.035,
                    bottom: widget.size * 0.035,
                    child: _CompanionStateBadge(state: widget.state, companionSize: widget.size),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Color _haloColor(CompanionVisualState state) => switch (state) {
    CompanionVisualState.idle => AppPalette.outline,
    CompanionVisualState.listen => AppPalette.signal,
    CompanionVisualState.think => AppPalette.primary,
    CompanionVisualState.speak => AppPalette.primaryDark,
    CompanionVisualState.correct => AppPalette.attention,
    CompanionVisualState.success => AppPalette.momentumInk,
  };

  static String _semanticLabel(CompanionVisualState state) => switch (state) {
    CompanionVisualState.idle => 'Düğüm hazır',
    CompanionVisualState.listen => 'Düğüm dinleme modunda',
    CompanionVisualState.think => 'Düğüm düşünüyor',
    CompanionVisualState.speak => 'Düğüm konuşuyor',
    CompanionVisualState.correct => 'Düğüm destek oluyor',
    CompanionVisualState.success => 'Düğüm başarıyı kutluyor',
  };
}

class _CompanionStateBadge extends StatelessWidget {
  const _CompanionStateBadge({required this.state, required this.companionSize});

  final CompanionVisualState state;
  final double companionSize;

  IconData get _icon => switch (state) {
    CompanionVisualState.listen => Icons.headphones_rounded,
    CompanionVisualState.think => Icons.lightbulb_outline_rounded,
    CompanionVisualState.speak => Icons.graphic_eq_rounded,
    CompanionVisualState.correct => Icons.check_rounded,
    CompanionVisualState.success => Icons.star_rounded,
    CompanionVisualState.idle => Icons.circle,
  };

  Color get _background => switch (state) {
    CompanionVisualState.listen => AppPalette.signal,
    CompanionVisualState.think => AppPalette.primary,
    CompanionVisualState.speak => AppPalette.primaryDark,
    CompanionVisualState.correct => AppPalette.attention,
    CompanionVisualState.success => AppPalette.momentum,
    CompanionVisualState.idle => AppPalette.inkMuted,
  };

  Color get _foreground => switch (state) {
    CompanionVisualState.listen => AppPalette.ink,
    CompanionVisualState.think => Colors.white,
    CompanionVisualState.speak => Colors.white,
    CompanionVisualState.correct => AppPalette.ink,
    CompanionVisualState.success => AppPalette.momentumInk,
    CompanionVisualState.idle => Colors.white,
  };

  @override
  Widget build(BuildContext context) {
    final badgeSize = (companionSize * 0.27).clamp(16.0, 34.0);
    return ExcludeSemantics(
      child: Container(
        width: badgeSize,
        height: badgeSize,
        decoration: BoxDecoration(
          color: _background,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: (badgeSize * 0.09).clamp(1.5, 2.5)),
          boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        alignment: Alignment.center,
        child: Icon(_icon, color: _foreground, size: badgeSize * 0.56),
      ),
    );
  }
}
