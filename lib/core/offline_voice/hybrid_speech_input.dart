import 'package:flutter/foundation.dart';

import '../voice/speech_input.dart';
import 'offline_engines.dart';

/// Speech input that listens for **commands** with the app's own offline
/// recognizer once its model is installed (works without internet, needs
/// nothing from Google), and uses the Android recognizer for everything
/// else (dictation, Percy) and for commands while the model isn't there.
///
/// Which one a session uses is decided by the voice controller's plan
/// ([ListenRequest.offline]); if the offline recognizer can't open the
/// microphone, the session falls back to Android's.
class HybridSpeechInput implements SpeechInput {
  /// Creates the input over Android's recognizer [android] and the app's
  /// [engines].
  HybridSpeechInput(this.android, this.engines);

  /// The Android recognizer (speech_to_text).
  final SpeechInput android;

  /// The app's own offline engines.
  final OfflineEngines engines;

  void Function(String status)? _onStatus;
  bool _offlineSession = false;

  @override
  Future<bool> initialize({
    required void Function(String code) onError,
    required void Function(String status) onStatus,
  }) async {
    _onStatus = onStatus;
    final androidReady = await android.initialize(
      // Like the statuses below: an error of an Android session that was
      // cancelled earlier can arrive after our own session has started.
      // Counted as this session's failure, it made the app give up
      // ("Hindi gumagana ang pakikinig...") while the offline recognizer
      // went on to hear the command a moment later.
      onError: (code) {
        if (!_offlineSession) onError(code);
      },
      onStatus: (status) {
        // Statuses of an Android session while ours is open are stale.
        if (!_offlineSession) onStatus(status);
      },
    );
    // Without a recognizer on the phone, commands still work offline.
    return androidReady || engines.commandsReady;
  }

  @override
  Future<List<String>> localeIds() => android.localeIds();

  @override
  Future<RecognizerInfo> recognizerInfo() => android.recognizerInfo();

  @override
  Future<bool> downloadOffline(String languageTag) =>
      android.downloadOffline(languageTag);

  @override
  Future<void> listen(
    ListenRequest request, {
    required SpeechResultCallback onResult,
    void Function(double level)? onSoundLevel,
  }) async {
    final listener = engines.listener;
    if (request.offline && listener != null) {
      listener.onStatus = (status) {
        if (_offlineSession) _onStatus?.call(status);
      };
      _offlineSession = true;
      if (await listener.listen(
        request,
        onResult: onResult,
        onSoundLevel: onSoundLevel,
      )) {
        return;
      }
      debugPrint('[OFFLINE VOICE] microphone busy: Android recognizer instead');
    }
    _offlineSession = false;
    return android.listen(
      request,
      onResult: onResult,
      onSoundLevel: onSoundLevel,
    );
  }

  @override
  void changePauseFor(Duration pauseFor) {
    // The offline recognizer times its own silences.
    if (!_offlineSession) android.changePauseFor(pauseFor);
  }

  @override
  Future<void> stop() async {
    final listener = engines.listener;
    if (_offlineSession && listener != null) return listener.stop();
    return android.stop();
  }

  @override
  Future<void> cancel() async {
    final listener = engines.listener;
    if (_offlineSession && listener != null) {
      await listener.cancel();
      return;
    }
    return android.cancel();
  }
}
