import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/app_theme.dart';

double _contrast(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance ? foregroundLuminance : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance ? backgroundLuminance : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  test('semantic action colors keep normal-text AA contrast', () {
    final scheme = SesliOgrenTheme.light().colorScheme;

    expect(_contrast(scheme.onPrimary, scheme.primary), greaterThanOrEqualTo(4.5));
    expect(_contrast(scheme.onSecondary, scheme.secondary), greaterThanOrEqualTo(4.5));
    expect(_contrast(scheme.onTertiary, scheme.tertiary), greaterThanOrEqualTo(4.5));
    expect(_contrast(AppPalette.momentumInk, AppPalette.momentum), greaterThanOrEqualTo(4.5));
  });

  test('Signal Aqua uses dark semantic foreground', () {
    final scheme = SesliOgrenTheme.light().colorScheme;

    expect(scheme.secondary, AppPalette.signal);
    expect(scheme.onSecondary, AppPalette.ink);
    expect(_contrast(scheme.onSecondary, scheme.secondary), greaterThan(7));
  });
}
