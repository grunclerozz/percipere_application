import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ids.dart';
import '../../app/locale_provider.dart';
import '../../app/router.dart';
import '../../app/theme/app_palette.dart';
import '../../app/theme/theme_settings.dart';
import '../../core/accessibility/command_bus.dart';
import '../../core/accessibility/navigation_mode.dart';
import '../../core/platform/system_settings.dart';
import '../../core/settings/app_settings.dart';
import '../../core/tts/reading_rate.dart';
import '../../core/tts/tts_service.dart';
import '../../l10n/app_localizations.dart';
import '../account/account_repository.dart';

/// How a setting is changed.
enum SettingKind {
  /// A number stepped up/down (speed, pitch, text size).
  stepper,

  /// One of several options, cycled.
  choice,

  /// On/off (or one of two options).
  toggle,

  /// Opens something (Account, Android TTS settings).
  link,
}

/// What a setting's value text needs.
@immutable
class SettingContext {
  /// Creates a context.
  const SettingContext(this.settings, this.l, this.ref);

  /// Current settings.
  final AppSettings settings;

  /// Strings in the language to show/speak.
  final AppLocalizations l;

  /// For values that depend on other state (account, voices).
  final WidgetRef ref;
}

/// One row of the Settings screen.
@immutable
class SettingItem {
  /// Creates a setting item.
  const SettingItem({
    required this.id,
    required this.kind,
    required this.label,
    required this.value,
    this.adjust,
    this.open,
  });

  /// Stable action id (`settings.readingRate`, …).
  final String id;

  /// How it changes.
  final SettingKind kind;

  /// Name ("Bilis ng pagbasa").
  final String Function(AppLocalizations l) label;

  /// Current value as text ("1.2x").
  final String Function(SettingContext c) value;

  /// Next settings for a step in [direction] (+1 / −1). Returning the same
  /// settings means "at the limit".
  final AppSettings Function(AppSettings s, int direction)? adjust;

  /// For [SettingKind.link]: what opening does.
  final FutureOr<void> Function(WidgetRef ref, CommandBus bus)? open;
}

T _cycle<T>(List<T> values, T current, int direction) =>
    values[(values.indexOf(current) + direction) % values.length];

String _fontName(AppFont f) => switch (f) {
  AppFont.montserrat => 'Montserrat',
  AppFont.atkinsonHyperlegible => 'Atkinson Hyperlegible',
  AppFont.lexend => 'Lexend',
};

/// All settings, in the order they are offered.
final List<SettingItem> settingItems = [
  SettingItem(
    id: Ids.settingReadingRate,
    kind: SettingKind.stepper,
    label: (l) => l.setReadingRate,
    value: (c) => '${ReadingRate.label(c.settings.readingRate)}x',
    adjust: (s, d) =>
        s.copyWith(readingRate: s.readingRate + d * ReadingRate.step),
  ),
  SettingItem(
    id: Ids.settingPitch,
    kind: SettingKind.stepper,
    label: (l) => l.setPitch,
    value: (c) => ReadingRate.label(c.settings.pitch),
    adjust: (s, d) => s.copyWith(pitch: s.pitch + d * 0.1),
  ),
  SettingItem(
    id: Ids.settingLanguage,
    kind: SettingKind.toggle,
    label: (l) => l.setLanguage,
    value: (c) => c.settings.locale == AppLocales.english
        ? c.l.langEnglish
        : c.l.langFilipino,
    adjust: (s, d) =>
        s.copyWith(locale: _cycle(AppLocales.supported, s.locale, d)),
  ),
  SettingItem(
    id: Ids.settingDocumentVoice,
    kind: SettingKind.choice,
    label: (l) => l.setDocumentVoice,
    value: (c) => switch (c.settings.documentVoice) {
      DocumentVoice.auto => c.l.valueAuto,
      DocumentVoice.filipino => c.l.langFilipino,
      DocumentVoice.english => c.l.langEnglish,
    },
    adjust: (s, d) => s.copyWith(
      documentVoice: _cycle(DocumentVoice.values, s.documentVoice, d),
    ),
  ),
  SettingItem(
    id: Ids.settingTextSize,
    kind: SettingKind.stepper,
    label: (l) => l.setTextSize,
    value: (c) => '${(c.settings.textScale * 100).round()}%',
    adjust: (s, d) => s.copyWith(textScale: s.textScale + d * 0.1),
  ),
  SettingItem(
    id: Ids.settingFont,
    kind: SettingKind.choice,
    label: (l) => l.setFont,
    value: (c) => _fontName(c.settings.font),
    adjust: (s, d) => s.copyWith(font: _cycle(AppFont.values, s.font, d)),
  ),
  SettingItem(
    id: Ids.settingColors,
    kind: SettingKind.choice,
    label: (l) => l.setColors,
    value: (c) => switch (c.settings.palette) {
      PaletteId.defaultCream => c.l.paletteDefault,
      PaletteId.highContrast => c.l.paletteHighContrast,
      PaletteId.yellowOnBlack => c.l.paletteYellow,
      PaletteId.blackOnWhite => c.l.paletteBlackOnWhite,
    },
    adjust: (s, d) =>
        s.copyWith(palette: _cycle(PaletteId.values, s.palette, d)),
  ),
  SettingItem(
    id: Ids.settingNavMode,
    kind: SettingKind.toggle,
    label: (l) => l.setNavMode,
    value: (c) =>
        c.settings.navMode == NavMode.voice ? c.l.navVoice : c.l.navGestures,
    adjust: (s, d) => s.copyWith(
      navMode: s.navMode == NavMode.voice ? NavMode.gestures : NavMode.voice,
    ),
  ),
  SettingItem(
    id: Ids.settingHaptics,
    kind: SettingKind.toggle,
    label: (l) => l.setHaptics,
    value: (c) => c.settings.haptics ? c.l.valueOn : c.l.valueOff,
    adjust: (s, d) => s.copyWith(haptics: !s.haptics),
  ),
  SettingItem(
    id: Ids.settingVerbosity,
    kind: SettingKind.choice,
    label: (l) => l.setVerbosity,
    value: (c) => switch (c.settings.verbosity) {
      Verbosity.brief => c.l.verbosityBrief,
      Verbosity.normal => c.l.verbosityNormal,
      Verbosity.detailed => c.l.verbosityDetailed,
    },
    adjust: (s, d) =>
        s.copyWith(verbosity: _cycle(Verbosity.values, s.verbosity, d)),
  ),
  SettingItem(
    id: Ids.settingAutoCapture,
    kind: SettingKind.toggle,
    label: (l) => l.setAutoCapture,
    value: (c) => c.settings.autoCapture ? c.l.valueOn : c.l.valueOff,
    adjust: (s, d) => s.copyWith(autoCapture: !s.autoCapture),
  ),
  SettingItem(
    id: Ids.settingAccount,
    kind: SettingKind.link,
    label: (l) => l.setAccount,
    value: (c) {
      final user = c.ref.read(currentAccountProvider);
      return user == null ? c.l.accountNone : c.l.accountAs(user.name);
    },
    open: (ref, bus) =>
        unawaited(ref.read(routerProvider).push(AppRoutes.account)),
  ),
  SettingItem(
    id: Ids.settingTtsVoices,
    kind: SettingKind.link,
    label: (l) => l.setTtsVoices,
    value: (c) => c.ref.read(voiceStatusProvider).filipinoReady
        ? c.l.ttsFilipinoInstalled
        : c.l.ttsFilipinoNotInstalled,
    open: (ref, bus) => ref.read(systemSettingsProvider).openTtsSettings(),
  ),
];
