import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/locale_provider.dart';
import '../../config/constants.dart';
import '../../l10n/app_localizations.dart';
import '../accessibility/action_registry.dart';
import '../accessibility/announcer.dart';
import '../accessibility/command_bus.dart';
import '../accessibility/haptics.dart';
import '../accessibility/navigation_mode.dart';
import '../platform/permissions.dart';
import '../platform/system_settings.dart';
import '../tts/speech_language.dart';
import 'speech_input.dart';

/// Recognizer state as the UI sees it.
enum ListenStatus {
  /// Not listening.
  idle,

  /// A session is open.
  listening,

  /// This phone can't recognize speech.
  unavailable,
}

/// What the Speaking Zone shows about voice input.
@immutable
class VoiceState {
  /// Creates a voice state.
  const VoiceState({this.status = ListenStatus.idle, this.partial, this.heard});

  /// Recognizer state.
  final ListenStatus status;

  /// Words recognized so far in the open session.
  final String? partial;

  /// The last final result, shown briefly as "Narinig: …".
  final String? heard;

  /// Whether a session is open.
  bool get listening => status == ListenStatus.listening;
}

/// Whether the microphone was already allowed at launch. Set by `bootstrap()`.
final initialMicGrantedProvider = Provider<bool>((ref) => false);

/// Voice input and listen/speak turn-taking.
///
/// - Never listens while the app is speaking: speech starting cancels the
///   session, speech ending re-arms it (after [AppDurations.autoListenDelay]).
/// - Auto-listens in voice mode, and on screens with `autoListen` (Welcome)
///   once the mic is allowed. Stops after [AppDurations.voiceIdleLimit]
///   without activity; a long-press re-arms it.
/// - Prefers on-device recognition; if the offline pack is missing it falls
///   back to online recognition, and explains when neither works.
class VoiceController extends Notifier<VoiceState> {
  bool _initialized = false;
  bool _recognizerAvailable = false;
  String? _localeId;
  bool _onDeviceUnavailable = false;
  bool _micGranted = false;
  bool _appActive = true;
  bool _budgetSpent = false;
  bool _oneShot = false;
  bool _listening = false;
  bool _gotFinal = false;
  bool _offlineNoticeGiven = false;
  int _session = 0;
  int _failures = 0;
  DateTime _lastActivity = DateTime.now();
  Timer? _restartTimer;
  Timer? _heardTimer;
  Completer<String?>? _dictation;

  late SpeechInput _stt;
  AppLocalizations get _l => ref.read(speechLanguageProvider).strings;

  @override
  VoiceState build() {
    _micGranted = ref.read(initialMicGrantedProvider);
    // Captured now: providers can't be read inside onDispose.
    _stt = ref.read(speechInputProvider);
    ref
      ..onDispose(() {
        _restartTimer?.cancel();
        _heardTimer?.cancel();
        _session++;
        if (_listening) unawaited(_stt.cancel());
      })
      ..listen(announcerProvider, _onSpeechChanged)
      ..listen(navigationModeProvider, (_, mode) {
        if (mode == NavMode.voice) {
          noteActivity();
          _scheduleAutoListen();
        } else if (!_oneShot) {
          unawaited(stopListening());
        }
      })
      ..listen(activeScreenProvider, (_, _) => noteActivity());
    return const VoiceState();
  }

  /// Whether the microphone is allowed (as last checked).
  bool get micGranted => _micGranted;

  /// Records user activity; resets the auto-listen idle budget.
  void noteActivity() {
    _lastActivity = DateTime.now();
    _budgetSpent = false;
  }

  /// Called on app pause/resume.
  void setAppActive(bool active) {
    _appActive = active;
    if (!active) {
      unawaited(stopListening());
    } else {
      noteActivity();
      unawaited(_refreshMicStatus());
    }
  }

  /// Listens once for free speech (a name, a document title) and returns the
  /// words — not treated as a command. Null if nothing was heard, listening
  /// was interrupted, or voice input isn't available.
  Future<String?> dictate() async {
    noteActivity();
    await ref.read(announcerProvider.notifier).stop();
    if (!await ensureReady(requestPermission: true)) return null;
    if (!ref.mounted) return null;
    _endDictation();
    final result = _dictation = Completer<String?>();
    _oneShot = false;
    unawaited(ref.read(hapticsProvider).tick());
    await _start();
    return result.future;
  }

  /// Ends a pending dictation with no result.
  void _endDictation() {
    final d = _dictation;
    _dictation = null;
    if (d != null && !d.isCompleted) d.complete(null);
  }

  /// Long-press / "listen": listen now, interrupting any speech.
  Future<void> listenNow() async {
    noteActivity();
    await ref.read(announcerProvider.notifier).stop();
    if (!await ensureReady(requestPermission: true)) return;
    if (!ref.mounted) return;
    _oneShot = !_wantsAutoListen;
    unawaited(ref.read(hapticsProvider).tick());
    await _start();
  }

  /// Makes sure the mic is allowed and the recognizer is initialized.
  ///
  /// With [requestPermission], explains and shows the Android dialog if
  /// needed, and explains a refusal.
  Future<bool> ensureReady({required bool requestPermission}) async {
    final permissions = ref.read(permissionServiceProvider);
    var access = await permissions.status(AppPermission.microphone);
    if (access == PermissionAccess.denied && requestPermission) {
      await _say(_l.micPermissionExplain);
      access = await permissions.request(AppPermission.microphone);
    }
    if (!ref.mounted) return false;
    _micGranted = access == PermissionAccess.granted;
    if (!_micGranted) {
      if (requestPermission) await _explainMicRefused(access);
      return false;
    }

    if (!_initialized) {
      _initialized = true;
      _recognizerAvailable = await _stt.initialize(
        onError: _onError,
        onStatus: _onStatus,
      );
      if (_recognizerAvailable) _localeId = await _pickLocale();
      if (!ref.mounted) return false;
    }
    if (!_recognizerAvailable) {
      state = const VoiceState(status: ListenStatus.unavailable);
      if (ref.read(navigationModeProvider) == NavMode.voice) {
        await ref.read(navigationModeProvider.notifier).set(NavMode.gestures);
      }
      await _say(_l.voiceUnavailable);
      return false;
    }
    return true;
  }

  /// Closes any open session.
  Future<void> stopListening() async {
    _restartTimer?.cancel();
    _endDictation();
    if (_listening) {
      _session++;
      _listening = false;
      await _stt.cancel();
    }
    if (ref.mounted && state.listening) {
      state = VoiceState(heard: state.heard);
    }
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  bool get _wantsAutoListen {
    if (!_micGranted) return false;
    if (ref.read(navigationModeProvider) == NavMode.voice) return true;
    return ref.read(activeScreenProvider)?.autoListen ?? false;
  }

  Future<void> _refreshMicStatus() async {
    final access = await ref
        .read(permissionServiceProvider)
        .status(AppPermission.microphone);
    if (!ref.mounted) return;
    _micGranted = access == PermissionAccess.granted;
    _scheduleAutoListen();
  }

  Future<String> _pickLocale() async {
    final ids = await _stt.localeIds();
    String norm(String s) => s.replaceAll('_', '-').toLowerCase();
    final filipinoUi = ref.read(appLocaleProvider) == AppLocales.filipino;
    final preferred = filipinoUi
        ? ['fil-ph', 'fil', 'tl-ph', 'en-ph', 'en-us']
        : ['en-ph', 'en-us', 'fil-ph'];
    for (final p in preferred) {
      for (final id in ids) {
        final n = norm(id);
        if (n == p || n.startsWith('$p-')) return id;
      }
    }
    if (ids.isNotEmpty) return ids.first;
    return filipinoUi ? 'fil-PH' : 'en-US';
  }

  void _onSpeechChanged(SpeechState? previous, SpeechState next) {
    final busy = next.speaking || next.reading;
    final wasBusy = previous != null && (previous.speaking || previous.reading);
    if (busy && _listening) {
      // Never listen to ourselves.
      unawaited(stopListening());
    } else if (wasBusy && !busy) {
      _scheduleAutoListen();
    }
  }

  void _scheduleAutoListen() {
    _restartTimer?.cancel();
    if (!_wantsAutoListen) return;
    _restartTimer = Timer(AppDurations.autoListenDelay, () {
      if (!ref.mounted) return;
      if (!_appActive || _listening || _budgetSpent || !_wantsAutoListen) {
        return;
      }
      if (state.status == ListenStatus.unavailable) return;
      final speech = ref.read(announcerProvider);
      if (speech.speaking || speech.reading) return;
      if (DateTime.now().difference(_lastActivity) >
          AppDurations.voiceIdleLimit) {
        _budgetSpent = true;
        unawaited(_say(_l.voiceListeningPaused));
        return;
      }
      unawaited(_startAuto());
    });
  }

  Future<void> _startAuto() async {
    if (!await ensureReady(requestPermission: false)) return;
    if (!ref.mounted || _listening) return;
    _oneShot = false;
    await _start();
  }

  Future<void> _start() async {
    final session = ++_session;
    _gotFinal = false;
    _listening = true;
    state = VoiceState(status: ListenStatus.listening, heard: state.heard);
    final dictating = _dictation != null;
    try {
      await _stt.listen(
        ListenRequest(
          localeId: _localeId ?? 'fil-PH',
          onDevice: !_onDeviceUnavailable,
          phrases: dictating
              ? const []
              : ref.read(commandBusProvider).expectedPhrases(),
          dictation: dictating,
          pauseFor: dictating
              ? const Duration(seconds: 4)
              : const Duration(seconds: 3),
        ),
        onResult: (words, isFinal) => _onResult(session, words, isFinal),
      );
    } on Object catch (e) {
      debugPrint('Listen failed: $e');
      _listening = false;
      if (ref.mounted) state = VoiceState(heard: state.heard);
    }
  }

  void _onResult(int session, String words, bool isFinal) {
    if (session != _session || !ref.mounted) return;
    if (!isFinal) {
      state = VoiceState(
        status: ListenStatus.listening,
        partial: words,
        heard: state.heard,
      );
      return;
    }
    _gotFinal = true;
    _listening = false;
    _failures = 0;
    final text = words.trim();
    if (text.isEmpty) return _endEmpty();

    _oneShot = false;
    noteActivity();
    final dictation = _dictation;
    if (dictation != null) {
      // Free speech for a form field: hand it back, don't run it.
      _dictation = null;
      state = VoiceState(heard: text);
      dictation.complete(text);
      return;
    }
    state = VoiceState(heard: text);
    _heardTimer?.cancel();
    _heardTimer = Timer(AppDurations.heardVisible, () {
      if (ref.mounted && state.heard == text) {
        state = VoiceState(status: state.status, partial: state.partial);
      }
    });
    unawaited(_handle(text));
  }

  Future<void> _handle(String text) async {
    await ref.read(commandBusProvider).handleUtterance(text);
    if (ref.mounted) _scheduleAutoListen();
  }

  void _onStatus(String status) {
    if (!ref.mounted) return;
    if (status == 'done' && _listening && !_gotFinal) _endEmpty();
  }

  void _onError(String code) {
    if (!ref.mounted || !_listening) return;
    _listening = false;
    final retryingOnline =
        (code == 'error_language_unavailable' ||
            code == 'error_language_not_supported') &&
        !_onDeviceUnavailable;
    if (!retryingOnline) _endDictation();
    switch (code) {
      case 'error_language_unavailable' || 'error_language_not_supported'
          when !_onDeviceUnavailable:
        // No offline pack for this language: retry with online recognition,
        // after the failed session's trailing "done" status has arrived.
        _onDeviceUnavailable = true;
        _restartTimer?.cancel();
        _restartTimer = Timer(const Duration(milliseconds: 250), () {
          if (ref.mounted && !_listening) unawaited(_start());
        });
      case 'error_no_match' || 'error_speech_timeout':
        _endEmpty();
      case 'error_network' ||
              'error_network_timeout' ||
              'error_server' ||
              'error_server_disconnected'
          when _onDeviceUnavailable:
        // Online recognition needed, but there's no connection.
        state = VoiceState(heard: state.heard);
        _budgetSpent = true;
        if (!_offlineNoticeGiven) {
          _offlineNoticeGiven = true;
          unawaited(
            ref
                .read(commandBusProvider)
                .offer(
                  _l.voiceOfflineMissing,
                  () =>
                      ref.read(systemSettingsProvider).openVoiceInputSettings(),
                ),
          );
        }
      case 'error_permission' || 'error_insufficient_permissions':
        _micGranted = false;
        state = VoiceState(heard: state.heard);
      default:
        debugPrint('Speech error: $code');
        state = VoiceState(heard: state.heard);
        if (++_failures < 3) _scheduleAutoListen();
    }
  }

  void _endEmpty() {
    _listening = false;
    state = VoiceState(heard: state.heard);
    if (_dictation != null) {
      _endDictation();
      return;
    }
    if (_oneShot) {
      _oneShot = false;
      unawaited(_say(_l.voiceNothingHeard));
      return;
    }
    _scheduleAutoListen();
  }

  Future<void> _explainMicRefused(PermissionAccess access) async {
    final bus = ref.read(commandBusProvider);
    if (access == PermissionAccess.permanentlyDenied) {
      await bus.offer(
        _l.micDeniedPermanent,
        () => ref.read(permissionServiceProvider).openAppSettings(),
      );
    } else {
      await _say(_l.micDenied);
    }
  }

  Future<void> _say(String text) =>
      ref.read(announcerProvider.notifier).say(text, interrupt: false);
}

/// Voice input controller.
final voiceControllerProvider = NotifierProvider<VoiceController, VoiceState>(
  VoiceController.new,
);
