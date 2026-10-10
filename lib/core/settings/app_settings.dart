import 'package:flutter/widgets.dart';

import '../../app/locale_provider.dart';
import '../../app/theme/theme_settings.dart';
import '../../config/palette.dart';
import '../accessibility/navigation_mode.dart';
import '../db/daos/preferences_dao.dart';
import '../percy/percy_responses.dart';
import '../tts/reading_rate.dart';

/// How much the app says when a screen opens.
enum Verbosity {
  /// Screen name and question only.
  brief,

  /// Plus the options and a hint for the navigation mode (default).
  normal,

  /// Plus the gestures for the screen.
  detailed,

  /// Normal on the first visits to a screen, shorter once it is familiar
  /// (no navigation hint), more help after the user gets stuck (default).
  auto,
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

/// Whether the user allows sending images to the server for a detailed
/// description (Maglarawan).
enum DescribeConsent {
  /// Not asked yet: ask before the first detailed description.
  ask,

  /// Agreed.
  allowed,

  /// Declined: detailed descriptions are not offered.
  declined,
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
    this.readingVoice = '',
    this.locale = AppLocales.filipino,
    this.documentVoice = DocumentVoice.auto,
    this.textSize = TextSize.standard,
    this.textColor,
    this.font = AppFont.montserrat,
    this.themeId = ThemeId.creamNavy,
    this.haptics = true,
    this.verbosity = Verbosity.auto,
    this.autoCapture = true,
    this.autoRead = true,
    this.listenWhileReading = true,
    this.stayLoggedIn = true,
    this.describeConsent = DescribeConsent.ask,
    this.percyPoliteness = PercyPoliteness.po,
    this.percyTalk = PercyTalk.normal,
    this.percyLogging = true,
    this.percyElevenLabs = false,
  });

  /// Voice or gestures; null until chosen (profiling Step 1).
  final NavMode? navMode;

  /// Reading speed multiplier (0.5–2.0, steps of 0.25).
  final double readingRate;

  /// Voice pitch (0.5–2.0, steps of 0.25).
  final double pitch;

  /// Reading voice (`ReadingVoicePref`): empty for the engine default,
  /// `female`, `male`, or `name:<voice>`. Used for documents and prompts.
  final String readingVoice;

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

  /// Voice mode: keep listening while a document is read aloud, so
  /// "i-pause" works at once (barge-in).
  final bool listenWhileReading;

  /// Keep the session between launches.
  final bool stayLoggedIn;

  /// Permission to send images for a detailed description.
  final DescribeConsent describeConsent;

  /// How formally Percy talks (with "po" or casual).
  final PercyPoliteness percyPoliteness;

  /// How much Percy says around actions.
  final PercyTalk percyTalk;

  /// Keep a local log of what is said to Percy, for retraining.
  final bool percyLogging;

  /// Developer option: the online ElevenLabs Percy instead of the
  /// self-built one. Off by default; nothing goes to ElevenLabs unless on.
  final bool percyElevenLabs;

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
    String? readingVoice,
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
    bool? listenWhileReading,
    bool? stayLoggedIn,
    DescribeConsent? describeConsent,
    PercyPoliteness? percyPoliteness,
    PercyTalk? percyTalk,
    bool? percyLogging,
    bool? percyElevenLabs,
  }) => AppSettings(
    navMode: identical(navMode, _keep) ? this.navMode : navMode as NavMode?,
    readingRate: ReadingRate.normalize(readingRate ?? this.readingRate),
    pitch: ReadingRate.normalize(pitch ?? this.pitch),
    readingVoice: readingVoice ?? this.readingVoice,
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
    listenWhileReading: listenWhileReading ?? this.listenWhileReading,
    stayLoggedIn: stayLoggedIn ?? this.stayLoggedIn,
    describeConsent: describeConsent ?? this.describeConsent,
    percyPoliteness: percyPoliteness ?? this.percyPoliteness,
    percyTalk: percyTalk ?? this.percyTalk,
    percyLogging: percyLogging ?? this.percyLogging,
    percyElevenLabs: percyElevenLabs ?? this.percyElevenLabs,
  );

  /// Preference key → JSON value.
  Map<String, Object?> toPrefs() => {
    PrefKeys.navigationMode: navMode?.name,
    PrefKeys.readingRate: readingRate,
    PrefKeys.pitch: pitch,
    PrefKeys.readingVoice: readingVoice,
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
    PrefKeys.listenWhileReading: listenWhileReading,
    PrefKeys.stayLoggedIn: stayLoggedIn,
    PrefKeys.describeConsent: describeConsent.name,
    PrefKeys.percyPoliteness: percyPoliteness.name,
    PrefKeys.percyTalk: percyTalk.name,
    PrefKeys.percyLogging: percyLogging,
    PrefKeys.percyElevenLabs: percyElevenLabs,
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
      readingVoice: p[PrefKeys.readingVoice] is String
          ? p[PrefKeys.readingVoice]! as String
          : null,
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
      listenWhileReading: bool_(p[PrefKeys.listenWhileReading]),
      stayLoggedIn: bool_(p[PrefKeys.stayLoggedIn]),
      describeConsent: byName(
        DescribeConsent.values,
        p[PrefKeys.describeConsent],
      ),
      percyPoliteness: byName(
        PercyPoliteness.values,
        p[PrefKeys.percyPoliteness],
      ),
      percyTalk: byName(PercyTalk.values, p[PrefKeys.percyTalk]),
      percyLogging: bool_(p[PrefKeys.percyLogging]),
      percyElevenLabs: bool_(p[PrefKeys.percyElevenLabs]),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.navMode == navMode &&
      other.readingRate == readingRate &&
      other.pitch == pitch &&
      other.readingVoice == readingVoice &&
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
      other.listenWhileReading == listenWhileReading &&
      other.stayLoggedIn == stayLoggedIn &&
      other.describeConsent == describeConsent &&
      other.percyPoliteness == percyPoliteness &&
      other.percyTalk == percyTalk &&
      other.percyLogging == percyLogging &&
      other.percyElevenLabs == percyElevenLabs;

  @override
  int get hashCode => Object.hashAll([
    navMode,
    readingRate,
    pitch,
    readingVoice,
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
    listenWhileReading,
    stayLoggedIn,
    describeConsent,
    percyPoliteness,
    percyTalk,
    percyLogging,
    percyElevenLabs,
  ]);
}
