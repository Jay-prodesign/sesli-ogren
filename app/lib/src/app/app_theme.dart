import 'package:flutter/material.dart';

/// Product-level visual tokens for the Premium Active Learning Studio lane.
///
/// These tokens are intentionally product-local. They are not a generic design
/// system and should only grow when Sesli Öğren has a concrete experience need.
abstract final class AppPalette {
  static const canvas = Color(0xFFF8F6F1);
  static const surface = Color(0xFFFFFEFB);
  static const surfaceMuted = Color(0xFFF0EFEA);
  static const ink = Color(0xFF101828);
  static const inkMuted = Color(0xFF5E6678);

  static const primary = Color(0xFF3D4ED8);
  static const primaryDark = Color(0xFF27369F);
  static const primarySoft = Color(0xFFE8EBFF);

  static const success = Color(0xFF167C6A);
  static const successSoft = Color(0xFFDFF7F0);

  static const attention = Color(0xFFB45309);
  static const attentionSoft = Color(0xFFFFEFD8);

  static const destructive = Color(0xFFB42318);
  static const outline = Color(0xFFD9DCE5);
}

abstract final class SesliOgrenTheme {
  static ThemeData light() {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    final scheme = ColorScheme.fromSeed(seedColor: AppPalette.primary, brightness: Brightness.light).copyWith(
      primary: AppPalette.primary,
      onPrimary: Colors.white,
      primaryContainer: AppPalette.primarySoft,
      onPrimaryContainer: AppPalette.primaryDark,
      secondary: AppPalette.success,
      onSecondary: Colors.white,
      secondaryContainer: AppPalette.successSoft,
      onSecondaryContainer: const Color(0xFF0B4E43),
      tertiary: AppPalette.attention,
      tertiaryContainer: AppPalette.attentionSoft,
      error: AppPalette.destructive,
      surface: AppPalette.surface,
      onSurface: AppPalette.ink,
      onSurfaceVariant: AppPalette.inkMuted,
      outline: AppPalette.outline,
      outlineVariant: const Color(0xFFE7E8ED),
      surfaceContainerLowest: AppPalette.canvas,
      surfaceContainerLow: AppPalette.surface,
      surfaceContainer: AppPalette.surfaceMuted,
      surfaceContainerHigh: const Color(0xFFE9E8E3),
      surfaceContainerHighest: const Color(0xFFE2E1DC),
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
          borderRadius: BorderRadius.circular(20),
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
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppPalette.surface,
        indicatorColor: AppPalette.primarySoft,
        elevation: 0,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          side: const BorderSide(color: AppPalette.outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
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
