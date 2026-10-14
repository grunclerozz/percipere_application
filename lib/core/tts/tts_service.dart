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
    this.englishReady = true,
  });

  /// True when a Filipino voice is available AND its data is installed, so
  /// Filipino prompts can be spoken offline.
  final bool filipinoReady;

  /// BCP-47 tag used for Filipino speech.
  final String filipinoTag;

  /// BCP-47 tag used for English speech (`en-PH` when its voice is
  /// installed on the phone, else `en-US`).
  final String englishTag;

  /// True when the English voice ([englishTag]) is installed on the phone,
  /// so English works offline.
  final bool englishReady;

  @override
  bool operator ==(Object other) =>
      other is VoiceStatus &&
      other.filipinoReady == filipinoReady &&
      other.filipinoTag == filipinoTag &&
      other.englishTag == englishTag &&
      other.englishReady == englishReady;

  @override
  int get hashCode =>
      Object.hash(filipinoReady, filipinoTag, englishTag, englishReady);
}

/// Which engine and voice speak a language (Voice check screen).
@immutable
class TtsReport {
  /// Creates a report.
  const TtsReport({this.engine, this.voiceName, this.local});

  /// Engine package (`com.google.android.tts`, `com.samsung.SMT`, …).
  final String? engine;

  /// The voice used, if known.
  final String? voiceName;

  /// True: installed on the phone (works offline); false: needs the
  /// internet; null: unknown (the engine doesn't list its voices).
  final bool? local;
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

  /// Whether the last [speak] ended because the engine failed (an error or
  /// no answer), not because it finished or was stopped.
  bool get lastFailed;

  /// Checks which voices are usable.
  Future<VoiceStatus> checkVoices();

  /// Sets pitch (1.0 is normal).
  Future<void> setPitch(double pitch);

  /// The voices installed on the phone (all languages).
  Future<List<TtsVoice>> listVoices();

  /// Sets the reading voice ([ReadingVoicePref]); used from the next
  /// utterance on, for documents and prompts alike.
  Future<void> setVoicePreference(String preference);

  /// The engine and voice that speak [languageTag].
  Future<TtsReport> report(String languageTag);
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
  String? _engine;
  String? _currentLanguage;
  TtsVoice? _currentVoice;

  /// Ends the wait for the utterance in progress when the engine reports
  /// an error (the plugin never answers the speak call then).
  Completer<void>? _failed;

  /// Voices that failed to speak since launch.
  final Set<String> _failedVoices = {};

  @override
  bool lastFailed = false;
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
    _tts.setErrorHandler((dynamic message) {
      debugPrint('[TTS] engine error: $message');
      final failed = _failed;
      if (failed != null && !failed.isCompleted) failed.complete();
    });
    try {
      final engines = await _tts.getEngines;
      if (engines is List && engines.contains(googleEngine)) {
        await _tts.setEngine(googleEngine);
        _engine = googleEngine;
      } else {
        final fallback = await _tts.getDefaultEngine;
        _engine = fallback is String ? fallback : null;
      }
    } on Object catch (e) {
      debugPrint('TTS engine selection failed: $e');
    }
    debugPrint('[TTS] engine: $_engine');
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
    // The engine's error path never resolves the call: an error ends the
    // wait at once (a network voice offline used to mean seconds of
    // silence per sentence); a generous estimate of the utterance length
    // caps it otherwise.
    final failed = _failed = Completer<void>();
    final limit = Duration(milliseconds: 5000 + text.length * 150);
    final result = await Future.any<dynamic>([
      _tts.speak(text, focus: true),
      failed.future.then((_) => 0),
    ]).timeout(limit, onTimeout: () => null);
    if (identical(_failed, failed)) _failed = null;
    lastFailed = result == null || (result != 1 && failed.isCompleted);
    if (result != 1 && failed.isCompleted) {
      // The voice failed (e.g. a network voice while offline): another one
      // from the next utterance on.
      final voice = _currentVoice;
      if (voice != null) _failedVoices.add(voice.name);
      _currentLanguage = null;
    }
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
    // `isLanguageInstalled` is true only for a voice on the phone (not a
    // network one): en-PH only when it works offline, else en-US.
    final enPh =
        await check(() => _tts.isLanguageAvailable('en-PH')) &&
        await check(() => _tts.isLanguageInstalled('en-PH'));
    final enUs = await check(() => _tts.isLanguageInstalled('en-US'));
    return VoiceStatus(
      filipinoReady: filAvailable && filInstalled,
      englishTag: enPh ? 'en-PH' : 'en-US',
      englishReady: enPh || enUs,
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

  /// The voice for [languageTag]: the user's choice if one fits, else a
  /// voice installed on the phone (the engine's default can be a network
  /// voice, which is silent offline). Null leaves the engine's default.
  Future<TtsVoice?> _voiceFor(String languageTag) async {
    final voices = await listVoices();
    final chosen = ReadingVoicePref.resolve(
      _voicePreference,
      languageTag,
      voices,
    );
    if (chosen != null && !_failedVoices.contains(chosen.name)) return chosen;
    final local = [
      for (final v in ReadingVoicePref.usable(voices, languageTag))
        if (!v.networkRequired && !_failedVoices.contains(v.name)) v,
    ];
    if (local.isEmpty) return null;
    // The language's own local voice ("…-local") first.
    return local.firstWhere(
      (v) => v.name.endsWith('-local'),
      orElse: () => local.first,
    );
  }

  /// Switches to the voice for [languageTag] ([_voiceFor]).
  Future<void> _applyVoice(String languageTag) async {
    final voice = await _voiceFor(languageTag);
    _currentVoice = voice;
    if (voice == null) return;
    try {
      await _tts.setVoice({'name': voice.name, 'locale': voice.locale});
    } on Object catch (e) {
      debugPrint('[TTS] setVoice ${voice.name} failed: $e');
    }
  }

  @override
  Future<TtsReport> report(String languageTag) async {
    final voices = await listVoices();
    if (voices.isEmpty) return TtsReport(engine: _engine);
    final voice = await _voiceFor(languageTag);
    if (voice != null) {
      return TtsReport(
        engine: _engine,
        voiceName: voice.name,
        local: !voice.networkRequired && voice.installed,
      );
    }
    // No voice on the phone: the engine speaks with a network one, if any.
    final network = ReadingVoicePref.usable(voices, languageTag);
    return TtsReport(
      engine: _engine,
      voiceName: network.isEmpty ? null : network.first.name,
      local: false,
    );
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
