import 'package:flutter/widgets.dart';

import '../../app/locale_provider.dart';
import '../../app/theme/theme_settings.dart';
import '../../config/palette.dart';
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
    this.textSize = TextSize.standard,
    this.textColor,
    this.font = AppFont.montserrat,
    this.themeId = ThemeId.creamNavy,
    this.haptics = true,
    this.verbosity = Verbosity.normal,
    this.autoCapture = true,
    this.autoRead = true,
    this.stayLoggedIn = true,
  });

  /// Voice or gestures; null until chosen (profiling Step 1).
  final NavMode? navMode;

  /// Reading speed multiplier (0.5–2.0, steps of 0.25).
  final double readingRate;

  /// Voice pitch (0.5–2.0, steps of 0.25).
  final double pitch;

  /// UI and prompt language.
  final Locale locale;

  /// Document voice override.
  final DocumentVoice documentVoice;

  /// Text size in sp (18–48).
  final double textSize;

  /// Text color id (see `TextColors`); null = the theme's default.
  final String? textColor;

  /// Font family.
  final AppFont font;

  /// Color theme.
  final ThemeId themeId;

  /// Vibration cues on/off.
  final bool haptics;

  /// Screen announcement length.
  final Verbosity verbosity;

  /// Camera takes the photo by itself when the text is clear.
  final bool autoCapture;

  /// Start reading as soon as a new document's text is ready.
  final bool autoRead;

  /// Keep the session between launches.
  final bool stayLoggedIn;

  /// The theme-related part.
  ThemeSettings get theme => ThemeSettings(
    theme: themeId,
    font: font,
    textSize: textSize,
    textColor: textColor,
  );

  /// The text color actually shown (the theme default if none is chosen).
  TextColorOption get resolvedTextColor =>
      TextColors.resolve(themeId, textColor);

  /// Switches to [theme]. If the chosen text color isn't offered by it, the
  /// text color goes back to the theme default; `textColorReset` says so
  /// (the app then announces it).
  ({AppSettings settings, bool textColorReset}) withTheme(ThemeId theme) {
    final reset = textColor != null && !TextColors.offers(theme, textColor);
    return (
      settings: copyWith(themeId: theme, textColor: reset ? null : textColor),
      textColorReset: reset,
    );
  }

  static const Object _keep = Object();

  /// Returns a copy with the given fields replaced. [navMode] and
  /// [textColor] can be set to null explicitly.
  AppSettings copyWith({
    Object? navMode = _keep,
    double? readingRate,
    double? pitch,
    Locale? locale,
    DocumentVoice? documentVoice,
    double? textSize,
    Object? textColor = _keep,
    AppFont? font,
    ThemeId? themeId,
    bool? haptics,
    Verbosity? verbosity,
    bool? autoCapture,
    bool? autoRead,
    bool? stayLoggedIn,
  }) => AppSettings(
    navMode: identical(navMode, _keep) ? this.navMode : navMode as NavMode?,
    readingRate: ReadingRate.normalize(readingRate ?? this.readingRate),
    pitch: ReadingRate.normalize(pitch ?? this.pitch),
    locale: locale ?? this.locale,
    documentVoice: documentVoice ?? this.documentVoice,
    textSize: TextSize.normalize(textSize ?? this.textSize),
    textColor: identical(textColor, _keep)
        ? this.textColor
        : textColor as String?,
    font: font ?? this.font,
    themeId: themeId ?? this.themeId,
    haptics: haptics ?? this.haptics,
    verbosity: verbosity ?? this.verbosity,
    autoCapture: autoCapture ?? this.autoCapture,
    autoRead: autoRead ?? this.autoRead,
    stayLoggedIn: stayLoggedIn ?? this.stayLoggedIn,
  );

  /// Preference key → JSON value.
  Map<String, Object?> toPrefs() => {
    PrefKeys.navigationMode: navMode?.name,
    PrefKeys.readingRate: readingRate,
    PrefKeys.pitch: pitch,
    PrefKeys.locale: locale.languageCode,
    PrefKeys.documentVoice: documentVoice.name,
    PrefKeys.textSize: textSize,
    PrefKeys.textColor: textColor,
    PrefKeys.font: font.name,
    PrefKeys.palette: themeId.name,
    PrefKeys.haptics: haptics,
    PrefKeys.verbosity: verbosity.name,
    PrefKeys.autoCapture: autoCapture,
    PrefKeys.autoRead: autoRead,
    PrefKeys.stayLoggedIn: stayLoggedIn,
  };

  /// Reads settings from stored preferences; anything missing or invalid
  /// keeps its default. Pre-6B values (text scale %, four palettes) are
  /// converted.
  static AppSettings fromPrefs(Map<String, Object?> p) {
    T? byName<T extends Enum>(List<T> values, Object? name) {
      for (final v in values) {
        if (v.name == name) return v;
      }
      return null;
    }

    double? num_(Object? v) => v is num ? v.toDouble() : null;
    bool? bool_(Object? v) => v is bool ? v : null;

    final legacyScale = num_(p[PrefKeys.textScale]);
    final themeId = ThemeId.tryParse(p[PrefKeys.palette]) ?? ThemeId.creamNavy;
    final color = p[PrefKeys.textColor];

    const d = AppSettings();
    return d.copyWith(
      navMode: NavMode.tryParse(p[PrefKeys.navigationMode]),
      readingRate: num_(p[PrefKeys.readingRate]),
      pitch: num_(p[PrefKeys.pitch]),
      locale: p[PrefKeys.locale] == 'en' ? AppLocales.english : null,
      documentVoice: byName(DocumentVoice.values, p[PrefKeys.documentVoice]),
      textSize:
          num_(p[PrefKeys.textSize]) ??
          (legacyScale == null ? null : TextSize.fromLegacyScale(legacyScale)),
      textColor: color is String && TextColors.offers(themeId, color)
          ? color
          : null,
      font: byName(AppFont.values, p[PrefKeys.font]),
      themeId: themeId,
      haptics: bool_(p[PrefKeys.haptics]),
      verbosity: byName(Verbosity.values, p[PrefKeys.verbosity]),
      autoCapture: bool_(p[PrefKeys.autoCapture]),
      autoRead: bool_(p[PrefKeys.autoRead]),
      stayLoggedIn: bool_(p[PrefKeys.stayLoggedIn]),
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
      other.textSize == textSize &&
      other.textColor == textColor &&
      other.font == font &&
      other.themeId == themeId &&
      other.haptics == haptics &&
      other.verbosity == verbosity &&
      other.autoCapture == autoCapture &&
      other.autoRead == autoRead &&
      other.stayLoggedIn == stayLoggedIn;

  @override
  int get hashCode => Object.hash(
    navMode,
    readingRate,
    pitch,
    locale,
    documentVoice,
    textSize,
    textColor,
    font,
    themeId,
    haptics,
    verbosity,
    autoCapture,
    autoRead,
    stayLoggedIn,
  );
}
