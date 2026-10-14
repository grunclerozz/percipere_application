import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../config/voice_config.dart';

/// Parameters for one listening session.
@immutable
class ListenRequest {
  /// Creates a request.
  const ListenRequest({
    required this.localeId,
    required this.onDevice,
    this.phrases = const [],
    this.listenFor = VoiceConfig.listenFor,
    this.pauseFor = VoiceConfig.waitForSpeech,
    this.pauseAfterSpeech = VoiceConfig.commandPause,
    this.dictation = false,
  });

  /// Recognizer locale, e.g. `fil-PH`. Null uses the device's default.
  final String? localeId;

  /// Recognize on the device only (offline pack required).
  final bool onDevice;

  /// Expected phrases, used to bias recognition where supported.
  final List<String> phrases;

  /// Longest session.
  final Duration listenFor;

  /// Silence that ends the session before any words are heard (the wait
  /// for the user to start speaking).
  final Duration pauseFor;

  /// Silence that ends the session once words have been heard; the
  /// controller switches to it with [SpeechInput.changePauseFor].
  final Duration pauseAfterSpeech;

  /// Free speech (a name, a title) rather than a short command.
  final bool dictation;
}

/// Called with each recognition result: the best [words], whether the
/// result is final, the recognizer's other guesses ([alternates], final
/// results only) and its [confidence] (0..1; −1 when it doesn't say, as
/// on-device recognizers and partial results usually don't).
typedef SpeechResultCallback = void Function(
  String words,
  bool isFinal, {
  List<String> alternates,
  double confidence,
});

/// What the phone's speech recognition can do (Voice check screen and the
/// offline listening plan).
@immutable
class RecognizerInfo {
  /// Creates the info.
  const RecognizerInfo({
    this.sdk = 0,
    this.service,
    this.available = true,
    this.onDevice = false,
    this.installed,
    this.pending = const [],
    this.supported = const [],
    this.error,
  });

  /// Nothing known (the query failed or isn't possible).
  static const RecognizerInfo unknown = RecognizerInfo(onDevice: true);

  /// Android SDK level.
  final int sdk;

  /// Package of the default recognition service (e.g.
  /// `com.google.android.googlequicksearchbox`, `com.samsung.android…`).
  final String? service;

  /// A recognition service exists.
  final bool available;

  /// On-device (offline) recognition exists on this phone.
  final bool onDevice;

  /// Languages installed for on-device recognition (BCP-47); null when the
  /// phone can't say (Android 12 and older, or the query failed).
  final List<String>? installed;

  /// Languages being downloaded.
  final List<String> pending;

  /// Languages the on-device recognizer can download.
  final List<String> supported;

  /// Why the language lists are missing, if they are.
  final String? error;

  /// Reads the native answer.
  factory RecognizerInfo.fromMap(Map<Object?, Object?> map) {
    List<String>? list(Object? v) =>
        v is List ? [for (final e in v) '$e'] : null;
    return RecognizerInfo(
      sdk: map['sdk'] is int ? map['sdk']! as int : 0,
      service: map['service'] as String?,
      available: map['available'] != false,
      onDevice: map['onDevice'] == true,
      installed: list(map['installed']),
      pending: list(map['pending']) ?? const [],
      supported: list(map['supported']) ?? const [],
      error: map['error'] as String?,
    );
  }

  /// The first of [wanted] (`fil-PH`, `en`, …) installed on the device, as
  /// the installed tag; matches by language when [wanted] has no region.
  /// Null if none is, or the list is unknown.
  String? installedOf(List<String> wanted) {
    final have = installed;
    if (have == null || !onDevice) return null;
    String norm(String s) => s.replaceAll('_', '-').toLowerCase();
    for (final w in wanted) {
      final want = norm(w);
      for (final h in have) {
        final n = norm(h);
        final sameLang =
            n.split('-').first == want.split('-').first ||
            {
              n.split('-').first,
              want.split('-').first,
            }.containsAll(const {'fil', 'tl'});
        if (n == want || (!want.contains('-') && sameLang)) return h;
      }
    }
    return null;
  }

  /// Whether Filipino (or Tagalog) recognition works offline.
  bool get filipinoOffline =>
      installedOf(const ['fil-PH', 'tl-PH', 'fil']) != null;

  /// The installed English tag for offline recognition, if any.
  String? get englishOffline => installedOf(const ['en-PH', 'en-US', 'en']);
}

/// Speech recognition. Abstract so tests can script what is "heard".
abstract interface class SpeechInput {
  /// Prepares the recognizer. Returns false if the phone has none.
  /// [onError] gets Android codes such as `error_no_match`.
  Future<bool> initialize({
    required void Function(String code) onError,
    required void Function(String status) onStatus,
  });

  /// Recognizer locale ids available on this phone.
  Future<List<String>> localeIds();

  /// What recognition can do on this phone (service, offline languages).
  Future<RecognizerInfo> recognizerInfo();

  /// Asks the phone to download offline recognition for [languageTag].
  /// False if the phone can't (Android 12 and older).
  Future<bool> downloadOffline(String languageTag);

  /// Starts a session. [onResult] gets partial and final results;
  /// [onSoundLevel] the microphone level (for timing logs only).
  Future<void> listen(
    ListenRequest request, {
    required SpeechResultCallback onResult,
    void Function(double level)? onSoundLevel,
  });

  /// Changes the silence that ends the open session, counted from now.
  void changePauseFor(Duration pauseFor);

  /// Ends the session, keeping what was heard so far.
  Future<void> stop();

  /// Ends the session and discards it.
  Future<void> cancel();
}

/// [SpeechInput] backed by the Android recognizer via `speech_to_text`.
///
/// The silence that ends a session is timed here, not by the plugin: the
/// plugin would also hand its pause to Android as "silence that completes
/// the input" (`EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS`), so the
/// long wait for the user to *start* speaking (4 s) also became the wait
/// after they *stopped* — the recognizer then held its final result back
/// for seconds (decision log 2026-10-14).
class SttSpeechInput implements SpeechInput {
  final SpeechToText _stt = SpeechToText();
  static const MethodChannel _native = MethodChannel(
    'ph.bataan.percipere/speech',
  );

  Timer? _silence;
  Duration? _window;
  int _generation = 0;
  String _lastWords = '';

  @override
  Future<bool> initialize({
    required void Function(String code) onError,
    required void Function(String status) onStatus,
  }) async {
    try {
      return await _stt.initialize(
        onError: (SpeechRecognitionError e) => onError(e.errorMsg),
        onStatus: onStatus,
        finalTimeout: VoiceConfig.finalTimeout,
      );
    } on Object catch (e) {
      debugPrint('Speech init failed: $e');
      return false;
    }
  }

  @override
  Future<List<String>> localeIds() async {
    try {
      // On Android 13+ without on-device recognition the plugin never
      // answers: don't let voice setup wait for it.
      final locales = await _stt.locales().timeout(
        const Duration(seconds: 3),
        onTimeout: () => const [],
      );
      final ids = [for (final l in locales) l.localeId];
      debugPrint('[VOICE] recognizer locales (${ids.length}): $ids');
      return ids;
    } on Object catch (e) {
      debugPrint('[VOICE] locales failed: $e');
      return const [];
    }
  }

  @override
  Future<RecognizerInfo> recognizerInfo() async {
    try {
      final raw = await _native
          .invokeMapMethod<Object?, Object?>('info')
          .timeout(const Duration(seconds: 5));
      if (raw == null) return RecognizerInfo.unknown;
      final info = RecognizerInfo.fromMap(raw);
      debugPrint(
        '[VOICE] recognizer: service=${info.service} onDevice=${info.onDevice} '
        'installed=${info.installed} pending=${info.pending} '
        '${info.error == null ? '' : 'error=${info.error}'}',
      );
      return info;
    } on Object catch (e) {
      debugPrint('[VOICE] recognizer info failed: $e');
      return RecognizerInfo.unknown;
    }
  }

  @override
  Future<bool> downloadOffline(String languageTag) async {
    try {
      return await _native.invokeMethod<bool>('download', {
            'language': languageTag,
          }) ??
          false;
    } on Object catch (e) {
      debugPrint('[VOICE] offline download failed: $e');
      return false;
    }
  }

  @override
  Future<void> listen(
    ListenRequest request, {
    required SpeechResultCallback onResult,
    void Function(double level)? onSoundLevel,
  }) {
    final generation = ++_generation;
    _lastWords = '';
    _window = request.pauseFor;
    _arm(generation);
    return _stt.listen(
      onResult: (SpeechRecognitionResult r) {
        if (generation == _generation && r.recognizedWords != _lastWords) {
          // New words: the silence counts from now.
          _lastWords = r.recognizedWords;
          _arm(generation);
        }
        onResult(
          r.recognizedWords,
          r.finalResult,
          alternates: [
            for (final a in r.alternates.skip(1))
              if (a.recognizedWords.trim().isNotEmpty) a.recognizedWords,
          ],
          confidence: r.hasConfidenceRating ? r.confidence : -1,
        );
      },
      onSoundLevelChange: onSoundLevel,
      listenOptions: SpeechListenOptions(
        localeId: request.localeId,
        onDevice: request.onDevice,
        listenFor: request.listenFor,
        // No pauseFor: see the class comment.
        partialResults: true,
        cancelOnError: true,
        listenMode: request.dictation
            ? ListenMode.dictation
            : ListenMode.confirmation,
        contextualPhrases: request.phrases,
      ),
    );
  }

  void _arm(int generation) {
    _silence?.cancel();
    final window = _window;
    if (window == null) return;
    _silence = Timer(window, () {
      if (generation != _generation || !_stt.isListening) return;
      unawaited(
        _stt.stop().catchError((Object e) {
          debugPrint('[VOICE] stop after silence failed: $e');
        }),
      );
    });
  }

  @override
  void changePauseFor(Duration pauseFor) {
    _window = pauseFor;
    _arm(_generation);
  }

  @override
  Future<void> stop() {
    _silence?.cancel();
    _generation++;
    return _stt.stop();
  }

  @override
  Future<void> cancel() {
    _silence?.cancel();
    _generation++;
    return _stt.cancel();
  }
}

/// The app's speech input.
final speechInputProvider = Provider<SpeechInput>((ref) => SttSpeechInput());
