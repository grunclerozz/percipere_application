import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'reading_voice.dart';

export 'reading_voice.dart' show TtsVoice;

/// Which TTS voices this phone can use offline.
@immutable
class VoiceStatus {
  /// Creates a voice status.
  const VoiceStatus({
    required this.filipinoReady,
    this.filipinoTag = 'fil-PH',
    this.englishTag = 'en-US',
  });

  /// True when a Filipino voice is available AND its data is installed, so
  /// Filipino prompts can be spoken offline.
  final bool filipinoReady;

  /// BCP-47 tag used for Filipino speech.
  final String filipinoTag;

  /// BCP-47 tag used for English speech (`en-PH` when the engine has it).
  final String englishTag;

  @override
  bool operator ==(Object other) =>
      other is VoiceStatus &&
      other.filipinoReady == filipinoReady &&
      other.filipinoTag == filipinoTag &&
      other.englishTag == englishTag;

  @override
  int get hashCode => Object.hash(filipinoReady, filipinoTag, englishTag);
}

/// Text-to-speech output. Abstract so tests can use a fake.
abstract interface class TtsService {
  /// Speaks [text] in [languageTag] at [rate] × normal speed. Completes when
  /// the utterance ends: true if it finished, false if it was stopped or
  /// failed (the reading loop uses this to tell "done" from "interrupted").
  Future<bool> speak(
    String text, {
    required String languageTag,
    double rate = 1.0,
  });

  /// Stops speaking immediately.
  Future<void> stop();

  /// Checks which voices are usable.
  Future<VoiceStatus> checkVoices();

  /// Sets pitch (1.0 is normal).
  Future<void> setPitch(double pitch);

  /// The voices installed on the phone (all languages).
  Future<List<TtsVoice>> listVoices();

  /// Sets the reading voice ([ReadingVoicePref]); used from the next
  /// utterance on, for documents and prompts alike.
  Future<void> setVoicePreference(String preference);
}

/// [TtsService] backed by the Android TTS engine via `flutter_tts`.
///
/// Uses `awaitSpeakCompletion(true)`: the plugin resolves each `speak()` call
/// itself when the utterance finishes or is stopped, so a late "cancelled"
/// event can never end the *next* utterance early.
class FlutterTtsService implements TtsService {
  FlutterTtsService._(this._tts);

  /// Google's engine, which ships Filipino voices.
  static const String googleEngine = 'com.google.android.tts';

  final FlutterTts _tts;
  String? _currentLanguage;
  double? _currentRate;
  String _voicePreference = ReadingVoicePref.standard;
  List<TtsVoice>? _voices;

  /// Creates and configures the service. Prefers the Google TTS engine when
  /// installed.
  static Future<FlutterTtsService> create() async {
    final service = FlutterTtsService._(FlutterTts());
    await service._init();
    return service;
  }

  Future<void> _init() async {
    await _tts.awaitSpeakCompletion(true);
    try {
      final engines = await _tts.getEngines;
      if (engines is List && engines.contains(googleEngine)) {
        await _tts.setEngine(googleEngine);
      }
    } on Object catch (e) {
      debugPrint('TTS engine selection failed: $e');
    }
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
  }

  @override
  Future<bool> speak(
    String text, {
    required String languageTag,
    double rate = 1.0,
  }) async {
    if (_currentLanguage != languageTag) {
      // Also resets the engine to the language's default voice.
      await _tts.setLanguage(languageTag);
      _currentLanguage = languageTag;
      await _applyVoice(languageTag);
    }
    if (_currentRate != rate) {
      // Android engine scale: 0.5 is normal speed.
      await _tts.setSpeechRate(0.5 * rate);
      _currentRate = rate;
    }
    // The engine's error path never resolves the call; cap the wait at a
    // generous estimate of the utterance length.
    final limit = Duration(milliseconds: 5000 + text.length * 150);
    final result = await _tts
        .speak(text, focus: true)
        .timeout(limit, onTimeout: () => null);
    return result == 1;
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }

  @override
  Future<VoiceStatus> checkVoices() async {
    Future<bool> check(Future<dynamic> Function() probe) async {
      try {
        return await probe() == true;
      } on Object {
        return false;
      }
    }

    final filAvailable = await check(() => _tts.isLanguageAvailable('fil-PH'));
    final filInstalled = await check(() => _tts.isLanguageInstalled('fil-PH'));
    final enPh = await check(() => _tts.isLanguageAvailable('en-PH'));
    return VoiceStatus(
      filipinoReady: filAvailable && filInstalled,
      englishTag: enPh ? 'en-PH' : 'en-US',
    );
  }

  @override
  Future<void> setPitch(double pitch) async => _tts.setPitch(pitch);

  @override
  Future<List<TtsVoice>> listVoices() async {
    final cached = _voices;
    if (cached != null) return cached;
    try {
      final raw = await _tts.getVoices;
      return _voices = [
        if (raw is List)
          for (final v in raw) ?TtsVoice.fromEngine(v),
      ];
    } on Object catch (e) {
      debugPrint('[TTS] getVoices failed: $e');
      return const [];
    }
  }

  @override
  Future<void> setVoicePreference(String preference) async {
    if (preference == _voicePreference) return;
    _voicePreference = preference;
    // Voices installed since launch (TTS settings) count too.
    _voices = null;
    // The next utterance sets its language again, which resets the voice
    // to the default and then applies this choice.
    _currentLanguage = null;
  }

  /// Switches to the chosen voice for [languageTag], if one fits.
  Future<void> _applyVoice(String languageTag) async {
    if (_voicePreference == ReadingVoicePref.standard) return;
    final voice = ReadingVoicePref.resolve(
      _voicePreference,
      languageTag,
      await listVoices(),
    );
    if (voice == null) return;
    try {
      await _tts.setVoice({'name': voice.name, 'locale': voice.locale});
    } on Object catch (e) {
      debugPrint('[TTS] setVoice ${voice.name} failed: $e');
    }
  }
}

/// The app's TTS service. Overridden at startup by `bootstrap()`.
final ttsServiceProvider = Provider<TtsService>(
  (ref) => throw UnimplementedError('ttsServiceProvider is set in bootstrap'),
);

/// Current voice availability; refreshed when the app resumes (the user may
/// have just installed the Filipino voice).
class VoiceStatusNotifier extends Notifier<VoiceStatus> {
  /// Creates the notifier with the status found at startup.
  VoiceStatusNotifier([this._initial = const VoiceStatus(filipinoReady: true)]);

  final VoiceStatus _initial;

  @override
  VoiceStatus build() => _initial;

  /// Re-checks the engine. Returns true if Filipino just became ready.
  Future<bool> refresh() async {
    final before = state.filipinoReady;
    final next = await ref.read(ttsServiceProvider).checkVoices();
    if (!ref.mounted) return false;
    state = next;
    return !before && next.filipinoReady;
  }
}

/// Voice availability.
final voiceStatusProvider = NotifierProvider<VoiceStatusNotifier, VoiceStatus>(
  VoiceStatusNotifier.new,
);
