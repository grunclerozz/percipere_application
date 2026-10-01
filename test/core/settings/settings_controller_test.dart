import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/app/locale_provider.dart';
import 'package:percipere_app/app/theme/app_palette.dart';
import 'package:percipere_app/app/theme/theme_settings.dart';
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
      readingRate: 1.3,
      pitch: 0.8,
      locale: AppLocales.english,
      documentVoice: DocumentVoice.english,
      textScale: 1.5,
      font: AppFont.lexend,
      palette: PaletteId.yellowOnBlack,
      haptics: false,
      verbosity: Verbosity.brief,
      autoCapture: false,
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
      textScale: 5,
    );
    expect(s.readingRate, ReadingRate.max);
    expect(s.pitch, ReadingRate.min);
    expect(s.textScale, ThemeSettings.maxTextScale);
  });

  test(
    'update saves only what changed, and derived providers follow',
    () async {
      await settings().update(
        (s) => s.copyWith(
          readingRate: 1.2,
          palette: PaletteId.highContrast,
          locale: AppLocales.english,
          navMode: NavMode.gestures,
        ),
      );
      final stored = await prefs().getAll();
      expect(stored[PrefKeys.readingRate], 1.2);
      expect(stored[PrefKeys.palette], 'highContrast');
      expect(stored[PrefKeys.locale], 'en');
      expect(stored[PrefKeys.navigationMode], 'gestures');
      expect(stored.containsKey(PrefKeys.font), isFalse, reason: 'unchanged');

      expect(container.read(readingRateProvider), 1.2);
      expect(
        container.read(themeSettingsProvider).palette,
        PaletteId.highContrast,
      );
      expect(container.read(appLocaleProvider), AppLocales.english);
      expect(container.read(navigationModeProvider), NavMode.gestures);
    },
  );

  test('pitch changes reach the TTS engine', () async {
    await settings().update((s) => s.copyWith(pitch: 1.2));
    expect(env.tts.pitches.last, 1.2);
  });

  test('a new profile starts from the current settings; switching back '
      'restores the device settings', () async {
    await settings().update((s) => s.copyWith(textScale: 1.4));
    await settings().switchScope('user-1');
    expect(container.read(settingsProvider).textScale, 1.4);
    expect((await prefs().getAll(userId: 'user-1'))[PrefKeys.textScale], 1.4);

    await settings().update((s) => s.copyWith(textScale: 2.0));
    expect(settings().scope, 'user-1');
    await settings().switchScope(PreferencesDao.deviceScope);
    expect(container.read(settingsProvider).textScale, 1.4);

    await settings().switchScope('user-1');
    expect(container.read(settingsProvider).textScale, 2.0);
  });
}
