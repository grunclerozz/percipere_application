// Reading voice (female / male): built from the phone's voices for the
// current language, gender from the voice's name or features, by name when
// the engine doesn't say, nothing to choose with one voice.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/settings/app_settings.dart';
import 'package:percipere_app/core/settings/settings_controller.dart';
import 'package:percipere_app/core/tts/reading_voice.dart';
import 'package:percipere_app/features/settings/setting_items.dart';
import 'package:percipere_app/l10n/app_localizations.dart';

import '../../helpers/fakes.dart';

const _filFemale = TtsVoice(
  name: 'fil-ph-x-fie#female_1-local',
  locale: 'fil-PH',
);
const _filMale = TtsVoice(name: 'fil-ph-x-fic#male_1-local', locale: 'fil-PH');
const _enFemale = TtsVoice(name: 'en-us-x-sfg#female_2-local', locale: 'en-US');
const _enMale = TtsVoice(name: 'en-us-x-iom#male_3-local', locale: 'en-US');

void main() {
  final fil = lookupAppLocalizations(const Locale('fil'));
  final en = lookupAppLocalizations(const Locale('en'));

  test('gender comes from the name or the features ("female" first)', () {
    expect(_filFemale.gender, VoiceGender.female);
    expect(_filMale.gender, VoiceGender.male);
    expect(
      const TtsVoice(
        name: 'x',
        locale: 'fil-PH',
        features: 'gender=male',
      ).gender,
      VoiceGender.male,
    );
    expect(
      const TtsVoice(name: 'fil-ph-x-fid-local', locale: 'fil-PH').gender,
      isNull,
    );
    expect(
      const TtsVoice(name: 'fil-ph-x-fid-local', locale: 'fil_PH').shortName,
      'fid',
    );
  });

  test('reads the engine\'s voice maps', () {
    final v = TtsVoice.fromEngine({
      'name': 'fil-ph-x-fie-network',
      'locale': 'fil-PH',
      'network_required': '1',
      'features': 'networkTimeoutMs',
    });
    expect(v!.networkRequired, isTrue);
    expect(TtsVoice.fromEngine('nope'), isNull);
    expect(TtsVoice.fromEngine({'name': 'x'}), isNull);
  });

  test('both genders → Female / Male for the current language only', () {
    final o = ReadingVoiceOptions.forLanguage([
      _filFemale,
      _filMale,
      _enFemale,
      _enMale,
    ], 'fil-PH');
    expect(o.byGender, isTrue);
    expect(o.choices, [ReadingVoicePref.female, ReadingVoicePref.male]);
    expect(o.voices, [_filFemale, _filMale]);
    expect(o.fixed, isFalse);
  });

  test('unknown genders → voices by name; offline and installed first', () {
    const a = TtsVoice(name: 'fil-ph-x-fid-local', locale: 'fil-PH');
    const b = TtsVoice(name: 'fil-ph-x-cfc-local', locale: 'fil-PH');
    const online = TtsVoice(
      name: 'fil-ph-x-fie-network',
      locale: 'fil-PH',
      networkRequired: true,
    );
    const missing = TtsVoice(
      name: 'fil-ph-x-fic-local',
      locale: 'fil-PH',
      features: 'notInstalled',
    );
    final o = ReadingVoiceOptions.forLanguage([
      a,
      online,
      b,
      missing,
      a,
    ], 'fil-PH');
    expect(o.byGender, isFalse);
    expect(o.choices, [
      ReadingVoicePref.named(a.name),
      ReadingVoicePref.named(b.name),
    ]);
    expect(readingVoiceName(o.choices.last, o, fil), 'Boses 2 (cfc)');
    expect(readingVoiceName(o.choices.first, o, en), 'Voice 1 (fid)');
  });

  test('one voice (or none): nothing to choose', () {
    expect(ReadingVoiceOptions.forLanguage([_filFemale], 'fil-PH').fixed, true);
    expect(ReadingVoiceOptions.forLanguage(const [], 'fil-PH').fixed, true);
    expect(
      ReadingVoiceOptions.forLanguage([_enFemale, _enMale], 'fil-PH').fixed,
      isTrue,
      reason: 'no Filipino voice at all',
    );
  });

  test('cycling: default → Female → Male → Female', () {
    final o = ReadingVoiceOptions.forLanguage([_filFemale, _filMale], 'fil');
    expect(o.next('', 1), ReadingVoicePref.female);
    expect(o.next('', -1), ReadingVoicePref.male);
    expect(o.next(ReadingVoicePref.female, 1), ReadingVoicePref.male);
    expect(o.next(ReadingVoicePref.male, 1), ReadingVoicePref.female);
  });

  test(
    'which voice speaks: a gender follows the language, a name does not',
    () {
      final all = [_filFemale, _filMale, _enFemale, _enMale];
      expect(ReadingVoicePref.resolve('', 'fil-PH', all), isNull);
      expect(
        ReadingVoicePref.resolve(ReadingVoicePref.male, 'fil-PH', all),
        _filMale,
      );
      expect(
        ReadingVoicePref.resolve(ReadingVoicePref.female, 'en-US', all),
        _enFemale,
        reason: 'an English document keeps the chosen gender',
      );
      final named = ReadingVoicePref.named(_filMale.name);
      expect(ReadingVoicePref.resolve(named, 'fil-PH', all), _filMale);
      expect(ReadingVoicePref.resolve(named, 'en-US', all), isNull);
    },
  );

  test('labels', () {
    expect(readingVoiceName('', null, fil), 'Karaniwan');
    expect(readingVoiceName(ReadingVoicePref.female, null, fil), 'Babae');
    expect(readingVoiceName(ReadingVoicePref.male, null, en), 'Male');
    expect(fil.voiceChanged('babae'), 'Napalitan na ang boses: babae.');
    expect(en.voiceChanged('female'), 'Voice changed to female.');
  });

  test('the choice is saved, read back and given to the TTS engine', () async {
    final env = await TestEnv.create();
    final container = ProviderContainer(overrides: env.overrides);
    addTearDown(container.dispose);
    await container
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(readingVoice: ReadingVoicePref.male));
    expect(env.tts.voicePreferences, [ReadingVoicePref.male]);
    final s = container.read(settingsProvider);
    expect(AppSettings.fromPrefs(s.toPrefs()).readingVoice, 'male');
    expect(const AppSettings().readingVoice, ReadingVoicePref.standard);
  });

  test('Settings: Female/Male row with a Preview row after it; one voice '
      'makes it a row that only explains', () {
    final o = ReadingVoiceOptions.forLanguage([_filFemale, _filMale], 'fil');
    final items = settingItemsFor(null, voices: o);
    final i = items.indexWhere((e) => e.id == 'settings.readingVoice');
    expect(items[i].kind, SettingKind.choice);
    expect(items[i + 1].id, 'settings.voicePreview');
    expect(
      items[i].adjust!(const AppSettings(), 1).readingVoice,
      ReadingVoicePref.female,
    );

    final single = settingItemsFor(
      null,
      voices: ReadingVoiceOptions.forLanguage([_filFemale], 'fil'),
    ).firstWhere((e) => e.id == 'settings.readingVoice');
    expect(single.kind, SettingKind.link);
    expect(single.adjust, isNull);
  });
}
