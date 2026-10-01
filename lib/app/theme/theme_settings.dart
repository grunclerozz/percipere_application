import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/settings_controller.dart';
import 'app_palette.dart';

/// Bundled font families the user can pick (all under `assets/fonts/`).
enum AppFont {
  /// Default design font.
  montserrat('Montserrat'),

  /// Designed by the Braille Institute for low-vision readers.
  atkinsonHyperlegible('AtkinsonHyperlegible'),

  /// Designed to reduce visual stress and improve reading fluency.
  lexend('Lexend');

  const AppFont(this.family);

  /// Family name as declared in `pubspec.yaml`.
  final String family;
}

/// The user-adjustable visual settings that drive the theme.
///
/// Persisted per user in Phase 6; for now it lives only in memory.
@immutable
class ThemeSettings {
  /// Creates theme settings; defaults match the screenshots.
  const ThemeSettings({
    this.palette = PaletteId.defaultCream,
    this.font = AppFont.montserrat,
    this.textScale = 1.0,
  });

  /// Smallest user text scale offered in Settings.
  static const double minTextScale = 0.8;

  /// Largest user text scale offered in Settings.
  static const double maxTextScale = 2.0;

  /// Active color theme.
  final PaletteId palette;

  /// Active font family.
  final AppFont font;

  /// User text size multiplier, applied on top of the Android system font size.
  final double textScale;

  /// Returns a copy with the given fields replaced.
  ThemeSettings copyWith({
    PaletteId? palette,
    AppFont? font,
    double? textScale,
  }) {
    return ThemeSettings(
      palette: palette ?? this.palette,
      font: font ?? this.font,
      textScale: (textScale ?? this.textScale)
          .clamp(minTextScale, maxTextScale)
          .toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ThemeSettings &&
      other.palette == palette &&
      other.font == font &&
      other.textScale == textScale;

  @override
  int get hashCode => Object.hash(palette, font, textScale);
}

/// The app-wide theme settings; a view of [settingsProvider].
final themeSettingsProvider = Provider<ThemeSettings>(
  (ref) => ref.watch(settingsProvider.select((s) => s.theme)),
);
