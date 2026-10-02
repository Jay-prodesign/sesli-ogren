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

/// Current Round 7 runtime proxy. This is deliberately not a finalist identity.
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
