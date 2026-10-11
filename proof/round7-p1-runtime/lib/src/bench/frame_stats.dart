import 'package:flutter/scheduler.dart';

/// Collects engine frame timings (build + raster) per labelled segment.
class FrameCollector {
  final List<FrameTiming> _current = [];
  bool _active = false;

  void attach() => SchedulerBinding.instance.addTimingsCallback(_onTimings);
  void detach() => SchedulerBinding.instance.removeTimingsCallback(_onTimings);

  void _onTimings(List<FrameTiming> timings) {
    if (_active) _current.addAll(timings);
  }

  void begin() {
    _current.clear();
    _active = true;
  }

  List<FrameTiming> end() {
    _active = false;
    return List.of(_current);
  }
}

class FrameSummary {
  FrameSummary.from(List<FrameTiming> frames, {required double refreshHz})
    : count = frames.length,
      budgetMs = 1000 / refreshHz,
      build = Percentiles([for (final f in frames) _ms(f.buildDuration)]),
      raster = Percentiles([for (final f in frames) _ms(f.rasterDuration)]),
      total = Percentiles([for (final f in frames) _ms(f.totalSpan)]),
      jankyBuild = frames.where((f) => _ms(f.buildDuration) > 1000 / refreshHz).length,
      jankyRaster = frames.where((f) => _ms(f.rasterDuration) > 1000 / refreshHz).length;

  final int count;
  final double budgetMs;
  final Percentiles build;
  final Percentiles raster;
  final Percentiles total;

  /// Frames whose UI-thread build or raster-thread work exceeded the active frame budget.
  final int jankyBuild;
  final int jankyRaster;

  Map<String, Object?> toJson() => {
    'frames': count,
    'frame_budget_ms': _r(budgetMs),
    'build_ms': build.toJson(),
    'raster_ms': raster.toJson(),
    'total_span_ms': total.toJson(),
    'janky_build_frames': jankyBuild,
    'janky_raster_frames': jankyRaster,
  };

  static double _ms(Duration d) => d.inMicroseconds / 1000;
}

class Percentiles {
  Percentiles(List<double> v) : _v = (List.of(v)..sort());

  final List<double> _v;

  double _at(double q) => _v.isEmpty ? 0 : _v[((_v.length - 1) * q).round()];

  Map<String, Object?> toJson() => {
    'p50': _r(_at(0.5)),
    'p90': _r(_at(0.9)),
    'p99': _r(_at(0.99)),
    'max': _r(_v.isEmpty ? 0 : _v.last),
  };
}

double _r(double v) => (v * 100).round() / 100;
