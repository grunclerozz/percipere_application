import 'package:flutter/widgets.dart';

import '../../app/locale_provider.dart';
import '../../app/theme/app_palette.dart';
import '../../app/theme/theme_settings.dart';
import '../accessibility/navigation_mode.dart';
import '../db/daos/preferences_dao.dart';
import '../tts/reading_rate.dart';

/// How much the app says when a screen opens.
enum Verbosity {
  /// Screen name and question only.
  brief,

  /// Plus the options and a hint for the navigation mode (default).
  normal,

  /// Plus the gestures for the screen.
  detailed,
}

/// Which voice reads documents.
enum DocumentVoice {
  /// Chosen per document by language detection (default).
  auto,

  /// Always the Filipino voice.
  filipino,

  /// Always the English voice.
  english,
}

/// Every user-adjustable setting, saved per profile (or for the device when
/// no one is logged in). One key per field in the `preferences` table, so
/// adding a setting never needs a migration.
@immutable
class AppSettings {
  /// Creates settings; defaults are the first-run values.
  const AppSettings({
    this.navMode,
    this.readingRate = 1.0,
    this.pitch = 1.0,
    this.locale = AppLocales.filipino,
    this.documentVoice = DocumentVoice.auto,
    this.textScale = 1.0,
    this.font = AppFont.montserrat,
    this.palette = PaletteId.defaultCream,
    this.haptics = true,
    this.verbosity = Verbosity.normal,
    this.autoCapture = true,
  });

  /// Voice or gestures; null until chosen on Welcome.
  final NavMode? navMode;

  /// Reading speed multiplier (0.5–2.0).
  final double readingRate;

  /// Voice pitch (0.5–2.0).
  final double pitch;

  /// UI and prompt language.
  final Locale locale;

  /// Document voice override.
  final DocumentVoice documentVoice;

  /// In-app text size multiplier.
  final double textScale;

  /// Font family.
  final AppFont font;

  /// Color theme.
  final PaletteId palette;

  /// Vibration cues on/off.
  final bool haptics;

  /// Screen announcement length.
  final Verbosity verbosity;

  /// Camera takes the photo by itself when the text is clear.
  final bool autoCapture;

  /// The theme-related part.
  ThemeSettings get theme =>
      ThemeSettings(palette: palette, font: font, textScale: textScale);

  static const Object _keep = Object();

  /// Returns a copy with the given fields replaced.
  AppSettings copyWith({
    Object? navMode = _keep,
    double? readingRate,
    double? pitch,
    Locale? locale,
    DocumentVoice? documentVoice,
    double? textScale,
    AppFont? font,
    PaletteId? palette,
    bool? haptics,
    Verbosity? verbosity,
    bool? autoCapture,
  }) => AppSettings(
    navMode: identical(navMode, _keep) ? this.navMode : navMode as NavMode?,
    readingRate: ReadingRate.normalize(readingRate ?? this.readingRate),
    pitch: ReadingRate.normalize(pitch ?? this.pitch),
    locale: locale ?? this.locale,
    documentVoice: documentVoice ?? this.documentVoice,
    textScale: (textScale ?? this.textScale)
        .clamp(ThemeSettings.minTextScale, ThemeSettings.maxTextScale)
        .toDouble(),
    font: font ?? this.font,
    palette: palette ?? this.palette,
    haptics: haptics ?? this.haptics,
    verbosity: verbosity ?? this.verbosity,
    autoCapture: autoCapture ?? this.autoCapture,
  );

  /// Preference key → JSON value.
  Map<String, Object?> toPrefs() => {
    PrefKeys.navigationMode: navMode?.name,
    PrefKeys.readingRate: readingRate,
    PrefKeys.pitch: pitch,
    PrefKeys.locale: locale.languageCode,
    PrefKeys.documentVoice: documentVoice.name,
    PrefKeys.textScale: textScale,
    PrefKeys.font: font.name,
    PrefKeys.palette: palette.name,
    PrefKeys.haptics: haptics,
    PrefKeys.verbosity: verbosity.name,
    PrefKeys.autoCapture: autoCapture,
  };

  /// Reads settings from stored preferences; anything missing or invalid
  /// keeps its default.
  static AppSettings fromPrefs(Map<String, Object?> p) {
    T? byName<T extends Enum>(List<T> values, Object? name) {
      for (final v in values) {
        if (v.name == name) return v;
      }
      return null;
    }

    double? num_(Object? v) => v is num ? v.toDouble() : null;
    bool? bool_(Object? v) => v is bool ? v : null;

    const d = AppSettings();
    return d.copyWith(
      navMode: NavMode.tryParse(p[PrefKeys.navigationMode]),
      readingRate: num_(p[PrefKeys.readingRate]),
      pitch: num_(p[PrefKeys.pitch]),
      locale: p[PrefKeys.locale] == 'en' ? AppLocales.english : null,
      documentVoice: byName(DocumentVoice.values, p[PrefKeys.documentVoice]),
      textScale: num_(p[PrefKeys.textScale]),
      font: byName(AppFont.values, p[PrefKeys.font]),
      palette: byName(PaletteId.values, p[PrefKeys.palette]),
      haptics: bool_(p[PrefKeys.haptics]),
      verbosity: byName(Verbosity.values, p[PrefKeys.verbosity]),
      autoCapture: bool_(p[PrefKeys.autoCapture]),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.navMode == navMode &&
      other.readingRate == readingRate &&
      other.pitch == pitch &&
      other.locale == locale &&
      other.documentVoice == documentVoice &&
      other.textScale == textScale &&
      other.font == font &&
      other.palette == palette &&
      other.haptics == haptics &&
      other.verbosity == verbosity &&
      other.autoCapture == autoCapture;

  @override
  int get hashCode => Object.hash(
    navMode,
    readingRate,
    pitch,
    locale,
    documentVoice,
    textScale,
    font,
    palette,
    haptics,
    verbosity,
    autoCapture,
  );
}
