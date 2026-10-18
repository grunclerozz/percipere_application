import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/palette.dart';
import '../../core/settings/settings_controller.dart';

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

/// The user's reading-text size, in sp (profiling Step 2 and Settings).
abstract final class TextSize {
  /// Smallest size (and the default: the design's own size).
  static const double min = 18;

  /// Largest size.
  static const double max = 48;

  /// One "palakihin"/"paliitin" step.
  static const double step = 2;

  /// Default size.
  static const double standard = 18;

  /// Clamps to the range and rounds to whole steps.
  static double normalize(double size) =>
      ((size.clamp(min, max) - min) / step).round() * step + min;

  /// One step bigger ([direction] > 0) or smaller from [current]. At the end
  /// of the range the size stays and [atLimit] is true (the screen then says
  /// "pinakamalaki na" / "pinakamaliit na").
  static ({double size, bool atLimit}) change(double current, int direction) {
    final from = normalize(current);
    final to = normalize(from + (direction >= 0 ? step : -step));
    return (size: to, atLimit: to == from);
  }

  /// Converts the pre-6B percentage multiplier (0.8–2.0) to a size.
  static double fromLegacyScale(double scale) => normalize(standard * scale);
}

/// The user-adjustable visual settings that drive the theme.
@immutable
class ThemeSettings {
  /// Creates theme settings; defaults match the mockups.
  const ThemeSettings({
    this.theme = ThemeId.creamNavy,
    this.font = AppFont.montserrat,
    this.textSize = TextSize.standard,
    this.textColor,
  });

  /// Active color theme.
  final ThemeId theme;

  /// Active font family.
  final AppFont font;

  /// Size of the reading text in sp (Document Box, setup preview). The rest
  /// of the UI keeps its design size.
  final double textSize;

  /// Text color id (see `TextColors`); null = the theme default.
  final String? textColor;

  @override
  bool operator ==(Object other) =>
      other is ThemeSettings &&
      other.theme == theme &&
      other.font == font &&
      other.textSize == textSize &&
      other.textColor == textColor;

  @override
  int get hashCode => Object.hash(theme, font, textSize, textColor);
}

/// The app-wide theme settings; a view of [settingsProvider].
final themeSettingsProvider = Provider<ThemeSettings>(
  (ref) => ref.watch(settingsProvider.select((s) => s.theme)),
);
