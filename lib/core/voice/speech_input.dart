import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Parameters for one listening session.
@immutable
class ListenRequest {
  /// Creates a request.
  const ListenRequest({
    required this.localeId,
    required this.onDevice,
    this.phrases = const [],
    this.listenFor = const Duration(seconds: 30),
    this.pauseFor = const Duration(seconds: 4),
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

  /// Silence that ends the session.
  final Duration pauseFor;

  /// Free speech (a name, a title) rather than a short command.
  final bool dictation;
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

  /// Starts a session. [onResult] gets partial and final results.
  Future<void> listen(
    ListenRequest request, {
    required void Function(String words, bool isFinal) onResult,
  });

  /// Ends the session, keeping what was heard so far.
  Future<void> stop();

  /// Ends the session and discards it.
  Future<void> cancel();
}

/// [SpeechInput] backed by the Android recognizer via `speech_to_text`.
class SttSpeechInput implements SpeechInput {
  final SpeechToText _stt = SpeechToText();

  @override
  Future<bool> initialize({
    required void Function(String code) onError,
    required void Function(String status) onStatus,
  }) async {
    try {
      return await _stt.initialize(
        onError: (SpeechRecognitionError e) => onError(e.errorMsg),
        onStatus: onStatus,
      );
    } on Object catch (e) {
      debugPrint('Speech init failed: $e');
      return false;
    }
  }

  @override
  Future<List<String>> localeIds() async {
    final locales = await _stt.locales();
    final ids = [for (final l in locales) l.localeId];
    debugPrint('[Voice] recognizer locales (${ids.length}): $ids');
    return ids;
  }

  @override
  Future<void> listen(
    ListenRequest request, {
    required void Function(String words, bool isFinal) onResult,
  }) {
    return _stt.listen(
      onResult: (SpeechRecognitionResult r) =>
          onResult(r.recognizedWords, r.finalResult),
      listenOptions: SpeechListenOptions(
        localeId: request.localeId,
        onDevice: request.onDevice,
        listenFor: request.listenFor,
        pauseFor: request.pauseFor,
        partialResults: true,
        cancelOnError: true,
        listenMode: request.dictation
            ? ListenMode.dictation
            : ListenMode.confirmation,
        contextualPhrases: request.phrases,
      ),
    );
  }

  @override
  Future<void> stop() => _stt.stop();

  @override
  Future<void> cancel() => _stt.cancel();
}

/// The app's speech input.
final speechInputProvider = Provider<SpeechInput>((ref) => SttSpeechInput());
