import 'package:flutter/painting.dart';

/// The three color themes (profiling Step 7 and Settings).
enum ThemeId {
  /// Cream background, navy accents (the mockups). Default.
  creamNavy,

  /// Black background, yellow text: high contrast, color-blind friendly.
  darkYellow,

  /// Black background, white text.
  darkWhite;

  /// Parses a stored name. Names used before Phase 6B map to the closest
  /// theme ("Black on white" was dropped → Cream & Navy).
  static ThemeId? tryParse(Object? name) => switch (name) {
    'creamNavy' || 'defaultCream' || 'blackOnWhite' => creamNavy,
    'darkYellow' || 'yellowOnBlack' => darkYellow,
    'darkWhite' || 'highContrast' => darkWhite,
    _ => null,
  };
}

/// A text color the user can choose.
class TextColorOption {
  /// Creates an option.
  const TextColorOption(this.id, this.filipino, this.english, this.color);

  /// Stable id, saved in preferences.
  final String id;

  /// Spoken/visible Filipino name ("Kayumanggi").
  final String filipino;

  /// English name ("Dark brown").
  final String english;

  /// The color.
  final Color color;
}

/// Text colors per theme, in the order offered; the first is the theme's
/// default. Every color has at least 7:1 contrast against its theme
/// background (enforced by `test/config/palette_test.dart`).
abstract final class TextColors {
  static const TextColorOption _navy = TextColorOption(
    'navy',
    'Navy',
    'Navy',
    Color(0xFF0B2A45),
  );
  static const TextColorOption _black = TextColorOption(
    'black',
    'Itim',
    'Black',
    Color(0xFF111111),
  );
  static const TextColorOption _brown = TextColorOption(
    'brown',
    'Kayumanggi',
    'Dark brown',
    Color(0xFF3E2723),
  );
  static const TextColorOption _purple = TextColorOption(
    'purple',
    'Lila',
    'Deep purple',
    Color(0xFF4A148C),
  );
  static const TextColorOption _blue = TextColorOption(
    'blue',
    'Asul',
    'Dark blue',
    Color(0xFF0D47A1),
  );
  static const TextColorOption _yellow = TextColorOption(
    'yellow',
    'Dilaw',
    'Yellow',
    Color(0xFFFFEB3B),
  );
  static const TextColorOption _peach = TextColorOption(
    'peach',
    'Melokoton',
    'Peach',
    Color(0xFFFFCC80),
  );
  static const TextColorOption _white = TextColorOption(
    'white',
    'Puti',
    'White',
    Color(0xFFFFFFFF),
  );
  static const TextColorOption _offWhite = TextColorOption(
    'offWhite',
    'Malambot na puti',
    'Off-white',
    Color(0xFFE8E6E3),
  );
  static const TextColorOption _lightCyan = TextColorOption(
    'lightCyan',
    'Mapusyaw na cyan',
    'Light cyan',
    Color(0xFF80DEEA),
  );
  static const TextColorOption _lightBlue = TextColorOption(
    'lightBlue',
    'Mapusyaw na asul',
    'Light blue',
    Color(0xFF90CAF9),
  );

  /// The colors offered with [theme]; the first is its default.
  static List<TextColorOption> forTheme(ThemeId theme) => switch (theme) {
    ThemeId.creamNavy => const [_navy, _black, _brown, _purple, _blue],
    ThemeId.darkYellow => const [
      _yellow,
      _peach,
      _white,
      _offWhite,
      _lightCyan,
      _lightBlue,
    ],
    ThemeId.darkWhite => const [
      _white,
      _offWhite,
      _yellow,
      _peach,
      _lightCyan,
      _lightBlue,
    ],
  };

  /// The default text color of [theme].
  static TextColorOption defaultFor(ThemeId theme) => forTheme(theme).first;

  /// The option [id] if [theme] offers it, else the theme default.
  static TextColorOption resolve(ThemeId theme, String? id) {
    for (final o in forTheme(theme)) {
      if (o.id == id) return o;
    }
    return defaultFor(theme);
  }

  /// Whether [theme] offers color [id].
  static bool offers(ThemeId theme, String? id) =>
      forTheme(theme).any((o) => o.id == id);
}
