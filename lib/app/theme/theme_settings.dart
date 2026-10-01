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

/// The user's text size, in sp (profiling Step 2 and Settings).
abstract final class TextSize {
  /// Smallest size (and the default: the design's own size).
  static const double min = 18;

  /// Largest size.
  static const double max = 48;

  /// One "palakihin"/"paliitin" step.
  static const double step = 2;

  /// Default size.
  static const double standard = 18;

  /// UI text (buttons, prompts) grows with the text size up to this factor;
  /// beyond it only document text keeps growing, so buttons stay usable.
  static const double maxUiScale = 2;

  /// Clamps to the range and rounds to whole steps.
  static double normalize(double size) =>
      ((size.clamp(min, max) - min) / step).round() * step + min;

  /// How much UI text is scaled for [size].
  static double uiScale(double size) =>
      (normalize(size) / standard).clamp(1.0, maxUiScale).toDouble();

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

  /// Text size in sp (document text uses it exactly).
  final double textSize;

  /// Text color id (see `TextColors`); null = the theme default.
  final String? textColor;

  /// Multiplier applied to UI text (on top of Android's font size).
  double get uiScale => TextSize.uiScale(textSize);

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
