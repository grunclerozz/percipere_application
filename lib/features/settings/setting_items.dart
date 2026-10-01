import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ids.dart';
import '../../app/locale_provider.dart';
import '../../app/router.dart';
import '../../app/theme/theme_settings.dart';
import '../../config/palette.dart';
import '../../core/accessibility/command_bus.dart';
import '../../core/accessibility/haptics.dart';
import '../../core/accessibility/navigation_mode.dart';
import '../../core/auth/account.dart';
import '../../core/auth/account_repository.dart';
import '../../core/auth/biometrics.dart';
import '../../core/auth/session.dart';
import '../../core/auth/session_store.dart';
import '../../core/platform/system_settings.dart';
import '../../core/settings/app_settings.dart';
import '../../core/tts/reading_rate.dart';
import '../../core/tts/tts_service.dart';
import '../../l10n/app_localizations.dart';
import '../setup/profiling_screen.dart';
import '../setup/setup_labels.dart';

/// How a setting is changed.
enum SettingKind {
  /// A number stepped up/down (speed, pitch, text size).
  stepper,

  /// One of several options, cycled.
  choice,

  /// On/off (or one of two options).
  toggle,

  /// Opens or does something (TTS voices, Ulitin ang setup, Logout).
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

  /// Current value as text ("1.25x").
  final String Function(SettingContext c) value;

  /// Next settings for a step in [direction] (+1 / −1). Returning the same
  /// settings means "at the limit".
  final AppSettings Function(AppSettings s, int direction)? adjust;

  /// For [SettingKind.link]: what activating does.
  final FutureOr<void> Function(WidgetRef ref, CommandBus bus)? open;
}

T _cycle<T>(List<T> values, T current, int direction) =>
    values[(values.indexOf(current) + direction) % values.length];

String _fontName(AppFont f) => switch (f) {
  AppFont.montserrat => 'Montserrat',
  AppFont.atkinsonHyperlegible => 'Atkinson Hyperlegible',
  AppFont.lexend => 'Lexend',
};

/// Logs out after a spoken confirmation; then "log in or register?" (or
/// Welcome, for a guest).
Future<void> confirmLogout(WidgetRef ref, CommandBus bus) {
  final account = ref.read(currentAccountProvider);
  final l = bus.strings;
  return bus.offer(
    account?.isGuest == true ? l.logoutGuestConfirm : l.logoutConfirm,
    () async {
      final router = ref.read(routerProvider);
      final haptics = ref.read(hapticsProvider);
      await ref.read(currentAccountProvider.notifier).logout();
      unawaited(haptics.confirm());
      await bus.say(bus.strings.loggedOut, protect: true);
      router.go(
        account?.isGuest == true ? AppRoutes.welcome : AppRoutes.authChoice,
      );
    },
  );
}

/// Turns fingerprint login on (after checking the finger) or off.
Future<void> _toggleFingerprint(WidgetRef ref, CommandBus bus) async {
  final account = ref.read(currentAccountProvider);
  if (account == null || account.isGuest) return bus.notAvailable();
  final l = bus.strings;
  final repo = ref.read(accountRepositoryProvider);
  final session = ref.read(sessionStoreProvider);
  if (account.fingerprintEnabled) {
    await repo.setFingerprint(account.id, false);
    await session.writeFingerprintUserId(null);
    await ref.read(currentAccountProvider.notifier).refresh();
    return bus.say(l.settingValue(l.setFingerprint, l.valueOff));
  }
  final biometrics = ref.read(biometricsProvider);
  if (!await biometrics.available()) return bus.say(l.fingerprintNoSensor);
  if (await biometrics.authenticate(l.fingerprintReason) !=
      BiometricResult.success) {
    unawaited(ref.read(hapticsProvider).error());
    return bus.say(l.fingerprintNotSet);
  }
  await repo.setFingerprint(account.id, true);
  await session.writeFingerprintUserId(account.id);
  await ref.read(currentAccountProvider.notifier).refresh();
  await bus.say(l.settingValue(l.setFingerprint, l.valueOn));
}

/// The settings offered to [account], in order. Guests get "Mag-register"
/// instead of the account rows.
List<SettingItem> settingItemsFor(Account? account) => [
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
    adjust: (s, d) => s.copyWith(pitch: s.pitch + d * ReadingRate.step),
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
    value: (c) => '${c.settings.textSize.round()}',
    adjust: (s, d) => s.copyWith(textSize: s.textSize + d * TextSize.step),
  ),
  SettingItem(
    id: Ids.settingColors,
    kind: SettingKind.choice,
    label: (l) => l.setTheme,
    value: (c) => themeName(c.settings.themeId, c.l),
    // Same rule as the setup: an unavailable text color resets.
    adjust: (s, d) =>
        s.withTheme(_cycle(ThemeId.values, s.themeId, d)).settings,
  ),
  SettingItem(
    id: Ids.settingTextColor,
    kind: SettingKind.choice,
    label: (l) => l.setTextColor,
    value: (c) => colorName(c.settings.resolvedTextColor, c.l),
    adjust: (s, d) {
      final options = TextColors.forTheme(s.themeId);
      final next = _cycle(options, s.resolvedTextColor, d);
      return s.copyWith(
        textColor: next == TextColors.defaultFor(s.themeId) ? null : next.id,
      );
    },
  ),
  SettingItem(
    id: Ids.settingFont,
    kind: SettingKind.choice,
    label: (l) => l.setFont,
    value: (c) => _fontName(c.settings.font),
    adjust: (s, d) => s.copyWith(font: _cycle(AppFont.values, s.font, d)),
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
    id: Ids.settingAutoRead,
    kind: SettingKind.toggle,
    label: (l) => l.setAutoRead,
    value: (c) => c.settings.autoRead ? c.l.valueOn : c.l.valueOff,
    adjust: (s, d) => s.copyWith(autoRead: !s.autoRead),
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
    id: Ids.settingTtsVoices,
    kind: SettingKind.link,
    label: (l) => l.setTtsVoices,
    value: (c) => c.ref.read(voiceStatusProvider).filipinoReady
        ? c.l.ttsFilipinoInstalled
        : c.l.ttsFilipinoNotInstalled,
    open: (ref, bus) => ref.read(systemSettingsProvider).openTtsSettings(),
  ),
  if (account != null && !account.isGuest) ...[
    SettingItem(
      id: Ids.settingStayLoggedIn,
      kind: SettingKind.toggle,
      label: (l) => l.setStayLoggedIn,
      value: (c) => c.settings.stayLoggedIn ? c.l.valueOn : c.l.valueOff,
      adjust: (s, d) => s.copyWith(stayLoggedIn: !s.stayLoggedIn),
    ),
    SettingItem(
      id: Ids.settingFingerprint,
      kind: SettingKind.link,
      label: (l) => l.setFingerprint,
      value: (c) =>
          c.ref.read(currentAccountProvider)?.fingerprintEnabled == true
          ? c.l.valueOn
          : c.l.valueOff,
      open: _toggleFingerprint,
    ),
  ],
  if (account != null && account.isGuest)
    SettingItem(
      id: Ids.settingRegister,
      kind: SettingKind.link,
      label: (l) => l.actionRegister,
      value: (c) => c.l.guestValue,
      open: (ref, bus) =>
          unawaited(ref.read(routerProvider).push(AppRoutes.register)),
    ),
  SettingItem(
    id: Ids.settingRedoSetup,
    kind: SettingKind.link,
    label: (l) => l.setRedoSetup,
    value: (c) => c.l.setRedoSetupValue,
    open: (ref, bus) => unawaited(
      ref.read(routerProvider).push(AppRoutes.setup, extra: SetupMode.redo),
    ),
  ),
  SettingItem(
    id: Ids.settingLogout,
    kind: SettingKind.link,
    label: (l) => l.setLogout,
    value: (c) {
      final user = c.ref.read(currentAccountProvider);
      if (user == null) return c.l.accountNone;
      return user.isGuest ? c.l.guestValue : c.l.accountAs(user.name);
    },
    open: confirmLogout,
  ),
];
