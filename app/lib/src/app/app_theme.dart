import 'package:flutter/material.dart';

/// Product-level visual tokens for the grounded Living Visual Learning Studio.
///
/// These tokens are intentionally product-local. They express the current
/// material-first / active-learning presentation without inventing learning
/// state. They are not a generic design system and should grow only when
/// Sesli Öğren has a concrete experience need.
abstract final class AppPalette {
  // LA-0040 Founder-locked Visual Learning Studio × Student Momentum roles.
  static const canvas = Color(0xFFF7F8FC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF2F4F7);
  static const ink = Color(0xFF111827);
  static const inkMuted = Color(0xFF667085);

  // Pulse Blue is the primary brand/action anchor.
  static const primary = Color(0xFF3657FF);
  static const primaryDark = Color(0xFF14224A);
  static const primarySoft = Color(0xFFEEF1FF);

  // Signal Aqua belongs to Listen/supportive states, not primary CTAs.
  static const signal = Color(0xFF20BFA9);
  static const signalSoft = Color(0xFFE6F8F4);

  // Volt Lime is a bounded momentum/highlight cue.
  static const momentum = Color(0xFFC9F45D);
  static const momentumInk = Color(0xFF14224A);

  static const success = Color(0xFF138A72);
  static const successSoft = Color(0xFFE7F5F1);

  static const attention = Color(0xFFE99024);
  static const attentionAccent = Color(0xFFE99024);
  static const attentionSoft = Color(0xFFFFF3E4);

  static const destructive = Color(0xFFD64550);
  static const outline = Color(0xFFE4E7EC);
}

abstract final class SesliOgrenTheme {
  static ThemeData light() {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    final scheme = ColorScheme.fromSeed(seedColor: AppPalette.primary, brightness: Brightness.light).copyWith(
      primary: AppPalette.primary,
      onPrimary: Colors.white,
      primaryContainer: AppPalette.primarySoft,
      onPrimaryContainer: AppPalette.primaryDark,
      secondary: AppPalette.signal,
      onSecondary: AppPalette.ink,
      secondaryContainer: AppPalette.signalSoft,
      onSecondaryContainer: const Color(0xFF0A5E53),
      tertiary: AppPalette.attention,
      onTertiary: AppPalette.ink,
      tertiaryContainer: AppPalette.attentionSoft,
      error: AppPalette.destructive,
      surface: AppPalette.surface,
      onSurface: AppPalette.ink,
      onSurfaceVariant: AppPalette.inkMuted,
      outline: AppPalette.outline,
      outlineVariant: const Color(0xFFEEF0F4),
      surfaceContainerLowest: AppPalette.canvas,
      surfaceContainerLow: AppPalette.surface,
      surfaceContainer: AppPalette.surfaceMuted,
      surfaceContainerHigh: const Color(0xFFEFF2F8),
      surfaceContainerHighest: const Color(0xFFE7EBF3),
    );

    final text = base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(
        color: AppPalette.ink,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
        height: 1.05,
      ),
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        color: AppPalette.ink,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        height: 1.08,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        color: AppPalette.ink,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        height: 1.12,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        color: AppPalette.ink,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.25,
        height: 1.16,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(color: AppPalette.ink, fontWeight: FontWeight.w700, height: 1.2),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        color: AppPalette.ink,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(color: AppPalette.ink, height: 1.48),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(color: AppPalette.ink, height: 1.45),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        color: AppPalette.ink,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppPalette.canvas,
      textTheme: text,
      cardTheme: CardThemeData(
        color: AppPalette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppPalette.outline),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppPalette.canvas,
        foregroundColor: AppPalette.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppPalette.surface,
        indicatorColor: AppPalette.primarySoft,
        elevation: 0,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) =>
              IconThemeData(color: states.contains(WidgetState.selected) ? AppPalette.primary : AppPalette.inkMuted),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected) ? AppPalette.primaryDark : AppPalette.inkMuted,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          side: const BorderSide(color: AppPalette.outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppPalette.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppPalette.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppPalette.primary, width: 2),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppPalette.outline, thickness: 1, space: 1),
    );
  }
}
