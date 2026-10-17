import 'dart:async';

import 'package:flutter/foundation.dart';

import '../tts/tts_service.dart';
import 'offline_engines.dart';
import 'offline_speaker.dart';

/// Which voice speaks a language.
enum TtsRoute {
  /// A voice installed on the phone (Android TTS, works offline).
  androidLocal,

  /// The app's own downloaded voice (sherpa-onnx, works offline).
  bundled,

  /// Whatever Android has — possibly a network voice (only useful online).
  androidAny,
}

/// The app's voice: an offline voice first — one installed on the phone, else
/// the app's own downloaded voice — and a network voice only as a last
/// resort. If the Android voice fails mid-way (a network voice going
/// offline), the same text is spoken by the app's own voice.
class HybridTtsService implements TtsService {
  /// Creates the service over Android's TTS [android] and the app's
  /// [engines].
  HybridTtsService(this.android, this.engines);

  /// Android TTS (flutter_tts).
  final TtsService android;

  /// The app's offline engines.
  final OfflineEngines engines;

  TtsRoute? _speaking;

  /// The voice each language speaks with, kept for the whole run: prompts,
  /// Percy and the Reader always sound the same. It changes only when that
  /// voice fails, or from the network last resort once an offline voice is
  /// there; every change is logged (`[TTS] engine switch`). (2026-10-17:
  /// a failed Android voice used the offline voice for one sentence and
  /// went back for the next — the voice kept changing.)
  final Map<String, TtsRoute> _routes = {};

  /// Counts [stop] calls: a stop that lands while [speak] is still picking
  /// a voice must keep that text from being spoken afterwards (it used to
  /// start talking over a hold-to-listen session).
  int _stops = 0;

  /// Completes on the next [stop], so a [speak] still waiting for the
  /// offline voices to load (seconds at startup) returns at once.
  Completer<void> _stopped = Completer<void>();

  @override
  bool lastFailed = false;

  /// Which voice will speak [languageTag] now: the one it has spoken with
  /// so far ([_routes]), else the best one there is.
  Future<TtsRoute> routeFor(String languageTag) async {
    final kept = _routes[languageTag];
    if (kept != null && kept != TtsRoute.androidAny) return kept;
    final route = await _bestRoute(languageTag);
    _setRoute(
      languageTag,
      route,
      kept == null ? 'first use' : 'offline voice ready',
    );
    return route;
  }

  Future<TtsRoute> _bestRoute(String languageTag) async {
    if (await _androidHasLocal(languageTag)) return TtsRoute.androidLocal;
    final lang = OfflineSpeaker.languageOf(languageTag);
    if (lang != null && engines.voiceLanguages.contains(lang)) {
      return TtsRoute.bundled;
    }
    return TtsRoute.androidAny;
  }

  void _setRoute(String languageTag, TtsRoute route, String why) {
    final before = _routes[languageTag];
    if (before == route) return;
    _routes[languageTag] = route;
    debugPrint(
      before == null
          ? '[TTS] $languageTag speaks with: ${route.name}'
          : '[TTS] engine switch for $languageTag: ${before.name} → '
                '${route.name} ($why)',
    );
  }

  Future<bool> _androidHasLocal(String languageTag) async {
    try {
      final voices = await android.listVoices();
      return voices.any(
        (v) => v.installed && !v.networkRequired && v.speaks(languageTag),
      );
    } on Object catch (e) {
      debugPrint('[TTS] voice list failed: $e');
      return false;
    }
  }

  Future<OfflineVoice?> _bundledFor(String languageTag) async {
    await Future.any([engines.voicesLoaded, _stopped.future]);
    final speaker = engines.speaker;
    return speaker != null && speaker.speaks(languageTag) ? speaker : null;
  }

  @override
  Future<bool> speak(
    String text, {
    required String languageTag,
    double rate = 1.0,
  }) async {
    final stops = _stops;
    final route = await routeFor(languageTag);
    if (stops != _stops) return false;
    if (route == TtsRoute.bundled) {
      final speaker = await _bundledFor(languageTag);
      if (stops != _stops) return false;
      if (speaker != null) {
        _speaking = TtsRoute.bundled;
        final done = await speaker.speak(text, tag: languageTag, rate: rate);
        lastFailed = false;
        return done;
      }
    }
    _speaking = route;
    final done = await android.speak(
      text,
      languageTag: languageTag,
      rate: rate,
    );
    lastFailed = android.lastFailed;
    if (!done && android.lastFailed && stops == _stops) {
      // A network voice without network (or a broken voice): the app's own
      // voice says it instead.
      final speaker = await _bundledFor(languageTag);
      if (speaker != null && stops == _stops) {
        // From now on, not just for this sentence.
        _setRoute(languageTag, TtsRoute.bundled, 'Android voice failed');
        _speaking = TtsRoute.bundled;
        final again = await speaker.speak(text, tag: languageTag, rate: rate);
        lastFailed = false;
        return again;
      }
    }
    return done;
  }

  @override
  Future<void> stop() async {
    _stops++;
    final stopped = _stopped;
    _stopped = Completer<void>();
    stopped.complete();
    final speaker = engines.speaker;
    // Both: a stop may race with the start of either.
    await Future.wait([android.stop(), if (speaker != null) speaker.stop()]);
    _speaking = null;
  }

  @override
  Future<VoiceStatus> checkVoices() async {
    final status = await android.checkVoices();
    final bundled = engines.voiceLanguages;
    return VoiceStatus(
      filipinoReady: status.filipinoReady || bundled.contains('fil'),
      filipinoTag: status.filipinoTag,
      englishTag: status.englishTag,
      englishReady: status.englishReady || bundled.contains('en'),
      filipinoAvailable: status.filipinoAvailable || bundled.contains('fil'),
    );
  }

  @override
  Future<void> setPitch(double pitch) => android.setPitch(pitch);

  @override
  Future<List<TtsVoice>> listVoices() => android.listVoices();

  @override
  Future<void> setVoicePreference(String preference) {
    // The user chose another voice: pick the voices afresh.
    _routes.clear();
    return android.setVoicePreference(preference);
  }

  @override
  Future<TtsReport> report(String languageTag) async {
    final route = await routeFor(languageTag);
    if (route == TtsRoute.bundled) {
      final lang = OfflineSpeaker.languageOf(languageTag);
      return TtsReport(
        engine: bundledEngine,
        voiceName: lang == 'fil' ? 'MMS Tagalog' : 'Piper LJSpeech',
        local: true,
      );
    }
    return android.report(languageTag);
  }

  /// The engine name the Voice check shows for the app's own voices.
  static const String bundledEngine = 'percipere-offline';

  /// The voice used for the last utterance (for logs and tests).
  TtsRoute? get lastRoute => _speaking;
}
