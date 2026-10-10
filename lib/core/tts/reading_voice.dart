import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'speech_language.dart';
import 'tts_service.dart';

/// A voice's gender, when the engine tells it.
enum VoiceGender {
  /// A female voice.
  female,

  /// A male voice.
  male,
}

/// One TTS voice installed on the phone.
@immutable
class TtsVoice {
  /// Creates a voice.
  const TtsVoice({
    required this.name,
    required this.locale,
    this.features = '',
    this.networkRequired = false,
  });

  /// Reads one entry of `FlutterTts.getVoices` (a map with `name`,
  /// `locale` and, on Android, `features` and `network_required`).
  static TtsVoice? fromEngine(Object? raw) {
    if (raw is! Map) return null;
    final name = raw['name'];
    final locale = raw['locale'];
    if (name is! String || locale is! String) return null;
    final network = raw['network_required'];
    return TtsVoice(
      name: name,
      locale: locale,
      features: '${raw['features'] ?? ''}',
      networkRequired: network == true || network == '1' || network == 1,
    );
  }

  /// Engine name, e.g. `fil-ph-x-fie-local`.
  final String name;

  /// Locale tag, e.g. `fil-PH`.
  final String locale;

  /// Engine features (Android: `notInstalled`, `networkTimeoutMs`, …).
  final String features;

  /// Needs the internet to speak.
  final bool networkRequired;

  /// The gender, if the name or features say it ("…#female_1-local").
  /// "female" is checked first, since it contains "male".
  VoiceGender? get gender {
    final text = '$name $features'.toLowerCase();
    if (text.contains('female')) return VoiceGender.female;
    if (text.contains('male')) return VoiceGender.male;
    return null;
  }

  /// Short form of the name for display: `fie` from `fil-ph-x-fie-local`.
  String get shortName {
    final m = RegExp(r'-x-([a-z0-9]+)', caseSensitive: false).firstMatch(name);
    return m?.group(1) ?? name;
  }

  /// Usable offline and actually installed.
  bool get installed => !features.contains('notInstalled');

  /// Whether this voice speaks [languageTag] (`fil-PH` matches `fil_PH`,
  /// `fil-ph`; a bare `fil` matches any Filipino voice).
  bool speaks(String languageTag) {
    String norm(String s) => s.replaceAll('_', '-').toLowerCase();
    final want = norm(languageTag);
    final have = norm(locale);
    if (have == want) return true;
    final wantLang = want.split('-').first;
    final haveLang = have.split('-').first;
    final sameLang =
        wantLang == haveLang ||
        {wantLang, haveLang}.containsAll(const {'fil', 'tl'});
    return sameLang && (!want.contains('-') || !have.contains('-'));
  }

  @override
  bool operator ==(Object other) =>
      other is TtsVoice && other.name == name && other.locale == locale;

  @override
  int get hashCode => Object.hash(name, locale);
}

/// The stored reading-voice choice (`AppSettings.readingVoice`): empty for
/// the engine default, `female` / `male`, or `name:<engine name>` when the
/// engine doesn't tell genders.
abstract final class ReadingVoicePref {
  /// The engine's default voice.
  static const String standard = '';

  /// A female voice.
  static const String female = 'female';

  /// A male voice.
  static const String male = 'male';

  /// A voice chosen by name.
  static String named(String name) => 'name:$name';

  /// The voice name in a `name:` choice, else null.
  static String? nameOf(String pref) =>
      pref.startsWith('name:') ? pref.substring(5) : null;

  /// The voice to use for [languageTag] given [pref], among [voices]; null
  /// means the engine default. A gender choice also applies to documents in
  /// another language (when that language has a voice of that gender); a
  /// voice chosen by name only to its own language.
  static TtsVoice? resolve(
    String pref,
    String languageTag,
    List<TtsVoice> voices,
  ) {
    if (pref == standard) return null;
    final candidates = usable(voices, languageTag);
    final name = nameOf(pref);
    if (name != null) {
      return candidates.where((v) => v.name == name).firstOrNull;
    }
    final gender = pref == female
        ? VoiceGender.female
        : pref == male
        ? VoiceGender.male
        : null;
    if (gender == null) return null;
    return candidates.where((v) => v.gender == gender).firstOrNull;
  }

  /// Installed voices for [languageTag], offline ones first (Percipere is
  /// offline-first; online voices are kept only if there is no offline one).
  static List<TtsVoice> usable(List<TtsVoice> voices, String languageTag) {
    final mine = [
      for (final v in voices)
        if (v.installed && v.speaks(languageTag)) v,
    ];
    final offline = [
      for (final v in mine)
        if (!v.networkRequired) v,
    ];
    final list = offline.isNotEmpty ? offline : mine;
    // One entry per name (engines can list a voice twice).
    final seen = <String>{};
    return [
      for (final v in list)
        if (seen.add(v.name)) v,
    ];
  }
}

/// What the "Reading voice" setting offers on this phone.
@immutable
class ReadingVoiceOptions {
  /// Creates the options.
  const ReadingVoiceOptions({
    this.choices = const [],
    this.byGender = false,
    this.voices = const [],
  });

  /// Nothing loaded yet (or no voices).
  static const ReadingVoiceOptions none = ReadingVoiceOptions();

  /// Builds the options for [languageTag] from the phone's [all] voices:
  /// Female / Male when the engine tells both genders, else every voice by
  /// name; nothing to choose with one voice or none.
  factory ReadingVoiceOptions.forLanguage(
    List<TtsVoice> all,
    String languageTag,
  ) {
    final voices = ReadingVoicePref.usable(all, languageTag);
    if (voices.length < 2) return ReadingVoiceOptions(voices: voices);
    final genders = {for (final v in voices) ?v.gender};
    if (genders.length == VoiceGender.values.length) {
      return ReadingVoiceOptions(
        choices: const [ReadingVoicePref.female, ReadingVoicePref.male],
        byGender: true,
        voices: voices,
      );
    }
    return ReadingVoiceOptions(
      choices: [for (final v in voices) ReadingVoicePref.named(v.name)],
      voices: voices,
    );
  }

  /// Stored values to cycle through.
  final List<String> choices;

  /// The choices are Female / Male (not names).
  final bool byGender;

  /// The usable voices for the current language.
  final List<TtsVoice> voices;

  /// Fewer than two voices: nothing to choose.
  bool get fixed => choices.length < 2;

  /// The next choice after [current] in [direction] (+1 / −1). The default
  /// (or a choice not offered here) moves to the first or last one.
  String next(String current, int direction) {
    if (fixed) return current;
    final i = choices.indexOf(current);
    if (i < 0) return direction > 0 ? choices.first : choices.last;
    return choices[(i + direction) % choices.length];
  }

  /// 1-based position of the voice named in [pref] (for "Voice 2 (fie)").
  int numberOf(String pref) {
    final name = ReadingVoicePref.nameOf(pref);
    final i = voices.indexWhere((v) => v.name == name);
    return i < 0 ? 0 : i + 1;
  }

  @override
  bool operator ==(Object other) =>
      other is ReadingVoiceOptions &&
      listEquals(other.choices, choices) &&
      other.byGender == byGender;

  @override
  int get hashCode => Object.hash(Object.hashAll(choices), byGender);
}

/// The reading-voice choices for the user's current language, from the
/// voices installed on the phone.
final readingVoiceOptionsProvider = FutureProvider<ReadingVoiceOptions>((
  ref,
) async {
  final tag = ref.watch(speechLanguageProvider).ttsTag;
  try {
    final voices = await ref.read(ttsServiceProvider).listVoices();
    final options = ReadingVoiceOptions.forLanguage(voices, tag);
    debugPrint(
      '[TTS] ${options.voices.length} voices for $tag; '
      '${options.byGender ? 'by gender' : 'by name'}',
    );
    return options;
  } on Object catch (e) {
    debugPrint('[TTS] voice list failed: $e');
    return ReadingVoiceOptions.none;
  }
});
