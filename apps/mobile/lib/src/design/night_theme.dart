import 'package:flutter/material.dart';

/// The approved “Midnight club” palette. No network fonts or runtime assets.
abstract final class NightColors {
  static const background = Color(0xFF141B1C);
  static const surface = Color(0xFF202C2A);
  static const raised = Color(0xFF2B3A35);
  static const accent = Color(0xFFB7E77C);
  static const ink = Color(0xFF182323);
  static const text = Color(0xFFF3EFE7);
  static const muted = Color(0xFFB5C2BA);
  static const border = Color(0xFF66806D);
  static const error = Color(0xFFFFB4AB);
}

abstract final class NightMotion {
  static const quick = Duration(milliseconds: 120);
  static const enter = Duration(milliseconds: 180);
  static const route = Duration(milliseconds: 240);
  static const verdict = Duration(milliseconds: 420);
  static const curve = Curves.easeOutCubic;

  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.accessibleNavigationOf(context);
}

ThemeData nightTheme() {
  const scheme = ColorScheme.dark(
    primary: NightColors.accent,
    onPrimary: NightColors.ink,
    secondary: NightColors.accent,
    onSecondary: NightColors.ink,
    surface: NightColors.surface,
    onSurface: NightColors.text,
    onSurfaceVariant: NightColors.muted,
    outline: NightColors.border,
    error: NightColors.error,
    onError: NightColors.ink,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Manrope',
    scaffoldBackgroundColor: NightColors.background,
  );
  return base.copyWith(
    textTheme: base.textTheme
        .copyWith(
          displaySmall: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 40,
            height: 1.1,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.6,
          ),
          headlineLarge: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 34,
            height: 1.14,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
          headlineMedium: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 30,
            height: 1.16,
            fontWeight: FontWeight.w800,
            letterSpacing: -.8,
          ),
          bodyLarge: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 16,
            height: 1.55,
          ),
          bodyMedium: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 15,
            height: 1.5,
          ),
          labelLarge: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        )
        .apply(bodyColor: NightColors.text, displayColor: NightColors.text),
    appBarTheme: const AppBarTheme(
      backgroundColor: NightColors.background,
      foregroundColor: NightColors.text,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Manrope',
        color: NightColors.text,
        fontSize: 16,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: NightColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(color: NightColors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 56),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        disabledBackgroundColor: NightColors.raised,
        disabledForegroundColor: NightColors.muted,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: NightColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      labelStyle: const TextStyle(color: NightColors.muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: NightColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: NightColors.accent, width: 2),
      ),
      errorMaxLines: 3,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: NightColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: NightColors.accent,
      linearTrackColor: NightColors.raised,
    ),
  );
}
