import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/app/locale_provider.dart';
import 'package:percipere_app/app/theme/theme_settings.dart';
import 'package:percipere_app/config/palette.dart';
import 'package:percipere_app/core/accessibility/navigation_mode.dart';
import 'package:percipere_app/core/db/daos/preferences_dao.dart';
import 'package:percipere_app/core/settings/app_settings.dart';
import 'package:percipere_app/core/settings/settings_controller.dart';
import 'package:percipere_app/core/tts/reading_rate.dart';

import '../../helpers/fakes.dart';

void main() {
  late TestEnv env;
  late ProviderContainer container;
  SettingsController settings() => container.read(settingsProvider.notifier);
  PreferencesDao prefs() => PreferencesDao(env.database.db);

  setUp(() async {
    env = await TestEnv.create();
    container = ProviderContainer(overrides: env.overrides);
    addTearDown(container.dispose);
  });

  test('round-trips through preferences; bad values keep defaults', () {
    const s = AppSettings(
      navMode: NavMode.voice,
      readingRate: 1.25,
      pitch: 0.75,
      locale: AppLocales.english,
      documentVoice: DocumentVoice.english,
      textSize: 30,
      textColor: 'peach',
      font: AppFont.lexend,
      themeId: ThemeId.darkYellow,
      haptics: false,
      verbosity: Verbosity.brief,
      autoCapture: false,
      autoRead: false,
      stayLoggedIn: false,
    );
    expect(AppSettings.fromPrefs(s.toPrefs()), s);
    expect(
      AppSettings.fromPrefs({
        PrefKeys.readingRate: 'fast',
        PrefKeys.font: 'comic sans',
        PrefKeys.haptics: 'yes',
      }),
      const AppSettings(),
    );
  });

  test('values are clamped', () {
    final s = const AppSettings().copyWith(
      readingRate: 9,
      pitch: 0.1,
      textSize: 99,
    );
    expect(s.readingRate, ReadingRate.max);
    expect(s.pitch, ReadingRate.min);
    expect(s.textSize, TextSize.max);
    expect(const AppSettings().copyWith(readingRate: 1.3).readingRate, 1.25);
  });

  test(
    'update saves only what changed, and derived providers follow',
    () async {
      await settings().update(
        (s) => s.copyWith(
          readingRate: 1.25,
          themeId: ThemeId.darkWhite,
          locale: AppLocales.english,
          navMode: NavMode.gestures,
        ),
      );
      final stored = await prefs().getAll();
      expect(stored[PrefKeys.readingRate], 1.25);
      expect(stored[PrefKeys.palette], 'darkWhite');
      expect(stored[PrefKeys.locale], 'en');
      expect(stored[PrefKeys.navigationMode], 'gestures');
      expect(stored.containsKey(PrefKeys.font), isFalse, reason: 'unchanged');

      expect(container.read(readingRateProvider), 1.25);
      expect(container.read(themeSettingsProvider).theme, ThemeId.darkWhite);
      expect(container.read(appLocaleProvider), AppLocales.english);
      expect(container.read(navigationModeProvider), NavMode.gestures);
    },
  );

  test('pitch changes reach the TTS engine', () async {
    await settings().update((s) => s.copyWith(pitch: 1.25));
    expect(env.tts.pitches.last, 1.25);
  });

  test('named speed presets round-trip through the existing profile setting',
      () async {
    for (final speed in SpeechSpeed.values) {
      await settings().update((s) => s.copyWith(readingRate: speed.rate));
      expect(container.read(readingRateProvider), speed.rate);
      await settings().reload();
      expect(container.read(settingsProvider).readingRate, speed.rate);
    }
  });

  test('relative speed steps stop at the minimum and maximum', () {
    expect(
      ReadingRate.normalize(ReadingRate.max + ReadingRate.step),
      ReadingRate.max,
    );
    expect(
      ReadingRate.normalize(ReadingRate.min - ReadingRate.step),
      ReadingRate.min,
    );
  });

  test('a new profile starts from the current settings; switching back '
      'restores the device settings', () async {
    await settings().update((s) => s.copyWith(textSize: 28));
    await settings().switchScope('user-1');
    expect(container.read(settingsProvider).textSize, 28);
    expect((await prefs().getAll(userId: 'user-1'))[PrefKeys.textSize], 28);

    await settings().update((s) => s.copyWith(textSize: 40));
    expect(settings().scope, 'user-1');
    await settings().switchScope(PreferencesDao.deviceScope);
    expect(container.read(settingsProvider).textSize, 28);

    await settings().switchScope('user-1');
    expect(container.read(settingsProvider).textSize, 40);
  });

  test('theme change resets a text color the new theme lacks', () {
    const s = AppSettings(textColor: 'brown');
    final dark = s.withTheme(ThemeId.darkYellow);
    expect(dark.textColorReset, isTrue);
    expect(dark.settings.textColor, isNull);
    expect(dark.settings.resolvedTextColor.id, 'yellow');

    // Yellow exists in both dark themes: kept.
    const y = AppSettings(themeId: ThemeId.darkWhite, textColor: 'yellow');
    final kept = y.withTheme(ThemeId.darkYellow);
    expect(kept.textColorReset, isFalse);
    expect(kept.settings.textColor, 'yellow');

    // No chosen color (theme default): nothing to announce.
    expect(
      const AppSettings().withTheme(ThemeId.darkWhite).textColorReset,
      isFalse,
    );
  });

  test('keepCurrent: logging out keeps the look on the device', () async {
    await settings().switchScope('user-2');
    await settings().update((s) => s.copyWith(textSize: 40));
    await settings().switchScope(PreferencesDao.deviceScope, keepCurrent: true);
    expect(container.read(settingsProvider).textSize, 40);
    expect((await prefs().getAll())[PrefKeys.textSize], 40);
  });
}
