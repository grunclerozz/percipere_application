import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_palette.dart';
import 'theme_settings.dart';

/// Builds the app [ThemeData] from the user's [ThemeSettings].
///
/// Text roles used across the app:
/// - `headlineLarge` — screen titles ("Welcome to" / "Percipere")
/// - `titleMedium`   — screen subtitles ("An app built on your behalf")
/// - `bodyLarge`     — Speaking Zone subtitle
/// - `bodyMedium`    — secondary lines (the "Narinig" line, captions)
/// - `labelLarge`    — pill button labels
/// - `labelMedium`   — Gesture Pad hint
/// - `documentText`  — see [AppTheme.documentText]
abstract final class AppTheme {
  /// Returns the theme for [settings].
  static ThemeData build(ThemeSettings settings) {
    final p = AppPalette.of(settings.palette);
    final scheme = ColorScheme(
      brightness: p.brightness,
      primary: p.primary,
      onPrimary: p.onPrimary,
      secondary: p.secondary,
      onSecondary: p.onSecondary,
      surface: p.background,
      onSurface: p.body,
      error: p.brightness == Brightness.light
          ? const Color(0xFFB00020)
          : const Color(0xFFFF8A80),
      onError: p.brightness == Brightness.light
          ? const Color(0xFFFFFFFF)
          : const Color(0xFF000000),
      outline: p.border,
    );

    final textTheme = TextTheme(
      headlineLarge: TextStyle(
        fontSize: 34,
        height: 1.1,
        fontWeight: FontWeight.w700,
        color: p.heading,
      ),
      titleLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: p.heading,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: p.body,
      ),
      bodyLarge: TextStyle(
        fontSize: 15,
        height: 1.3,
        fontWeight: FontWeight.w500,
        color: p.body,
      ),
      bodyMedium: TextStyle(fontSize: 14, color: p.body),
      labelLarge: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      labelMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: p.muted,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.background,
      fontFamily: settings.font.family,
      textTheme: textTheme,
      extensions: [p],
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.heading,
        elevation: 0,
        systemOverlayStyle: p.brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: const WidgetStatePropertyAll(true),
        thumbColor: WidgetStatePropertyAll(p.primary),
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(3),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.primary),
    );
  }

  /// Style for document text in the Document Box: bold and slightly larger
  /// than body text for low-vision readers.
  static TextStyle documentText(BuildContext context) {
    return TextStyle(
      fontSize: 16,
      height: 1.25,
      fontWeight: FontWeight.w700,
      color: context.palette.body,
    );
  }
}
