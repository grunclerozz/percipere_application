import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/locale_provider.dart';
import '../../config/constants.dart';
import '../../config/voice_config.dart';
import '../../l10n/app_localizations.dart';
import '../accessibility/action_registry.dart';
import '../accessibility/announcer.dart';
import '../accessibility/command_bus.dart';
import '../accessibility/earcon.dart';
import '../accessibility/haptics.dart';
import '../accessibility/nav_intent.dart';
import '../accessibility/navigation_mode.dart';
import '../assistant/assistant_controller.dart';
import '../percy/percy_controller.dart';
import '../platform/permissions.dart';
import '../platform/system_settings.dart';
import '../settings/settings_controller.dart';
import '../tts/speech_language.dart';
import 'barge_in.dart';
import 'command_matcher.dart';
import 'reading_duck.dart';
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

/// When each step of one voice command happened, for the
/// `[VOICE TIMING]` log line.
class _Timing {
  _Timing({
    required this.text,
    required this.via,
    required this.sessionStart,
    required this.firstSound,
    required this.firstPartial,
    required this.lastChange,
    required this.decided,
  });

  final String text;
  final String via;
  final DateTime? sessionStart;
  final DateTime? firstSound;
  final DateTime? firstPartial;

  /// When the recognized words last changed: about when the user stopped
  /// talking.
  final DateTime? lastChange;

  /// When the app decided to act (partial or final result).
  final DateTime decided;
  DateTime? matched;
  String? match;
}

/// Voice input and listen/speak turn-taking.
///
/// - Never listens while the app speaks a prompt: speech starting cancels
///   the session, speech ending re-arms it (after
///   [VoiceConfig.afterSpeechGap]).
/// - While a document is read aloud in voice mode it keeps listening
///   (barge-in, Settings "Makinig habang nagbabasa"), ignores its own voice
///   and accepts only reading commands ([BargeIn]).
/// - Acts on a partial result as soon as it is a whole command
///   ([CommandBus.judgePartial]); the session is then closed so the final
///   result can't run it again.
/// - Results from a session that began before the last executed command are
///   discarded.
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

  /// Recognizer session the plugin hasn't reported finished (`done` / error /
  /// cancel). Starting another one meanwhile gives `error_busy`.
  bool _platformOpen = false;
  DateTime? _sessionStart;

  /// The open session listens through document reading (barge-in).
  bool _sessionBargeIn = false;

  /// When a command last ran (by voice, gesture or tap).
  DateTime? _lastCommandAt;

  /// Command the previous partial result matched (two in a row run it).
  CommandTarget? _partialTarget;

  /// Pause to switch to once the user starts speaking (null: done).
  Duration? _pauseAfterSpeech;

  /// Timing of the open session, for the logs.
  DateTime? _firstSoundAt;
  DateTime? _firstPartialAt;
  DateTime? _lastChangeAt;
  String _lastWords = '';

  /// The command on its way from the recognizer to its action.
  _Timing? _timing;

  /// Fallback ladder for a recognizer that keeps failing: on-device →
  /// online ([_onDeviceUnavailable]) → the phone's default locale.
  bool _useDefaultLocale = false;

  /// Consecutive identical failures, and sessions that ended almost at once.
  String? _lastFailure;
  int _sameFailures = 0;
  int _instantFailures = 0;
  DateTime _lastActivity = DateTime.now();
  Timer? _restartTimer;
  Timer? _heardTimer;
  Completer<String?>? _dictation;

  /// Words from a session that was cut off while the user was speaking;
  /// the next session's words are added to them ([VoiceConfig.carryFor]).
  String _carry = '';
  DateTime? _carryAt;

  /// Restarts in a row after cut-offs ([VoiceConfig.cutOffRetries]).
  int _carryRetries = 0;

  /// Play the "listening" cue when the next session opens (the app has
  /// just spoken, or the user asked to be heard).
  bool _cueNext = false;

  /// Reading is paused while the user speaks over it.
  bool _ducking = false;
  Timer? _duckTimer;
  DateTime? _noDuckUntil;

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
        _duckTimer?.cancel();
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
      ..listen(assistantActiveProvider, (_, active) {
        // Percy (the ElevenLabs assistant) has the microphone meanwhile.
        if (active) {
          _restartTimer?.cancel();
          _log('voice assistant started: listening off');
          unawaited(stopListening());
        } else {
          _log('voice assistant ended: listening on again');
          noteActivity();
          _scheduleAutoListen();
        }
      })
      ..listen(activeScreenProvider, (previous, next) {
        // A new screen never starts in password privacy.
        if (previous?.id != next?.id) sensitive = false;
        noteActivity();
        // Have the recognizer ready before the first command.
        unawaited(warmUp());
      });
    return const VoiceState();
  }

  /// While true (a password field is being filled), recognized words are
  /// never shown in the Speaking Zone: partial results show as dots and the
  /// "Narinig" line stays empty.
  bool sensitive = false;

  /// Whether the microphone is allowed (as last checked).
  bool get micGranted => _micGranted;

  /// A session that ends sooner than this without a result is a failure, not
  /// someone being quiet.
  static const Duration _instantEnd = Duration(milliseconds: 1500);

  /// Identical failures in a row before the next fallback rung / giving up.
  static const int _escalateAfter = 2;
  static const int _giveUpAfter = 3;

  /// Timestamped log line for the listening loop (`adb logcat -s flutter`).
  void _log(String message) {
    final start = _sessionStart;
    final since = start == null
        ? ''
        : ' +${DateTime.now().difference(start).inMilliseconds}ms';
    debugPrint(
      '[VOICE ${DateTime.now().toIso8601String()} s$_session$since] $message',
    );
  }

  /// Restart delay after sessions that fail at once: 0, 400 ms, 800 ms, … 5 s.
  Duration get _backoff => _instantFailures == 0
      ? Duration.zero
      : Duration(
          milliseconds: (400 << (_instantFailures - 1).clamp(0, 4)).clamp(
            400,
            5000,
          ),
        );

  /// Records a session that ended with nothing heard ([code] says why) and
  /// decides what happens next. Returns true if it handled the restart itself
  /// (fallback rung tried, or listening abandoned).
  bool _failedSession(String code) {
    final start = _sessionStart;
    final lasted = start == null
        ? Duration.zero
        : DateTime.now().difference(start);
    final instant = lasted < _instantEnd;
    final quietCode =
        code == 'error_no_match' ||
        code == 'error_speech_timeout' ||
        code == 'done_without_result' ||
        code == 'empty_final';
    _log(
      'session ended without speech: $code after ${lasted.inMilliseconds}ms '
      '(${instant ? 'INSTANT' : 'normal'})',
    );
    if (!instant && quietCode) {
      // Someone was just quiet: not a fault.
      _instantFailures = 0;
      _lastFailure = null;
      _sameFailures = 0;
      return false;
    }
    _instantFailures = instant ? _instantFailures + 1 : 0;
    _sameFailures = code == _lastFailure ? _sameFailures + 1 : 1;
    _lastFailure = code;

    // A busy recognizer only needs more time (backoff); switching to online
    // recognition wouldn't help it.
    if (_sameFailures >= _escalateAfter &&
        !_ladderExhausted &&
        code != 'error_busy') {
      if (!_onDeviceUnavailable) {
        _log('repeated $code: retrying with onDevice=false');
        _onDeviceUnavailable = true;
      } else {
        _log('repeated $code: retrying with the phone default locale');
        _useDefaultLocale = true;
      }
      _sameFailures = 0;
      _restartAfterBackoff();
      return true;
    }
    if (_sameFailures >= _giveUpAfter) {
      _giveUp(code);
      return true;
    }
    return false;
  }

  bool get _ladderExhausted => _onDeviceUnavailable && _useDefaultLocale;

  void _restartAfterBackoff() {
    _restartTimer?.cancel();
    final wait = _backoff + const Duration(milliseconds: 350);
    _log('restarting in ${wait.inMilliseconds}ms');
    _restartTimer = Timer(wait, () {
      if (ref.mounted && !_listening) unawaited(_start());
    });
  }

  /// Stops retrying and says so aloud.
  void _giveUp(String code) {
    _log('giving up after repeated "$code"');
    _restartTimer?.cancel();
    _endDictation();
    _oneShot = false;
    _budgetSpent = true;
    _listening = false;
    _sameFailures = 0;
    _instantFailures = 0;
    state = VoiceState(heard: state.heard);
    unawaited(_say(_l.voiceRepeatedError));
  }

  /// A Percy session started or ended (called by `PercyController`, which
  /// reads this controller, so this one must not listen to it). Percy
  /// talks through the app's own voice and listens after each reply, also
  /// in gesture mode.
  void percySessionChanged({required bool active}) {
    _log(active ? 'Percy started: listening on' : 'Percy ended');
    noteActivity();
    if (_wantsAutoListen) {
      _scheduleAutoListen();
    } else if (!_oneShot) {
      unawaited(stopListening());
    }
  }

  /// Percy asked again after a silence: listen for the answer, also when
  /// repeated recognizer errors had stopped listening ([_giveUp]).
  void percyListenAgain() {
    _log('Percy asked again: listening on');
    _sameFailures = _instantFailures = _failures = 0;
    noteActivity();
    if (_wantsAutoListen && !_listening) _scheduleAutoListen();
  }

  /// Records user activity; resets the auto-listen idle budget.
  void noteActivity() {
    _lastActivity = DateTime.now();
    _budgetSpent = false;
  }

  /// Called by the command bus each time a command runs (voice, gesture or
  /// tap): logs the voice command's timing, and — for a gesture or tap while
  /// a session is open — starts that session afresh, since what it heard was
  /// said before the command.
  void commandExecuted(String what) {
    final now = DateTime.now();
    _lastCommandAt = now;
    final t = _timing;
    if (t != null) {
      _timing = null;
      t.matched ??= now;
      _log('ACTION $what');
      _logTiming(t, action: now, what: what);
      return;
    }
    if (_listening && (_sessionStart?.isBefore(now) ?? false)) {
      _log('command "$what" ran while listening: restarting the session');
      _abandonSession();
    }
  }

  /// Called by the command bus once it knows what a recognized phrase is.
  /// [done]: nothing more will run (no match, a question back, a screen's
  /// own command).
  void markMatched(String what, {bool done = false}) {
    final t = _timing;
    if (t == null) return;
    t
      ..matched ??= DateTime.now()
      ..match ??= what;
    _log('MATCH $what');
    if (done) {
      _timing = null;
      _logTiming(t, action: null, what: what);
    }
  }

  void _logTiming(
    _Timing t, {
    required DateTime? action,
    required String what,
  }) {
    // Latency logs are for tuning on the tablet: debug builds only.
    if (!kDebugMode) return;
    String gap(DateTime? from, DateTime? to) => from == null || to == null
        ? '–'
        : '${to.difference(from).inMilliseconds}ms';
    final endOfSpeech = t.lastChange ?? t.firstPartial ?? t.decided;
    final speechStart = t.firstSound ?? t.firstPartial;
    debugPrint(
      '[VOICE TIMING] "${sensitive ? '•••' : t.text}" via ${t.via} → '
      '${t.match ?? what}${action == null ? ' (nothing run)' : ''} | '
      'listen→speech ${gap(t.sessionStart, t.firstSound)} | '
      'speech→1st partial ${gap(t.firstSound ?? t.sessionStart, t.firstPartial)} | '
      'last word→result ${gap(endOfSpeech, t.decided)} | '
      'result→match ${gap(t.decided, t.matched)} | '
      'match→action ${gap(t.matched, action)} | '
      'END OF SPEECH→ACTION ${gap(endOfSpeech, action)} | '
      'SPEECH START→ACTION ${gap(speechStart, action)}',
    );
  }

  /// Called on app pause/resume.
  void setAppActive(bool active) {
    _appActive = active;
    if (!active) {
      unawaited(stopListening());
    } else {
      noteActivity();
      unawaited(_refreshMicStatus().then((_) => warmUp()));
    }
  }

  /// Creates the recognizer once, ahead of the first command (screen start,
  /// app back in front), so the first session opens without the setup
  /// delay. It is reused for every session after that. Silent: problems
  /// are explained when listening is actually asked for.
  Future<void> warmUp() async {
    if (_initialized || !_micGranted || !ref.mounted) return;
    await _initRecognizer();
  }

  /// The one recognizer setup; callers that arrive while it runs wait for
  /// the same one.
  Future<void>? _initializing;
  Future<void> _initRecognizer() => _initializing ??= _createRecognizer();

  Future<void> _createRecognizer() async {
    final watch = Stopwatch()..start();
    _recognizerAvailable = await _stt.initialize(
      onError: _onError,
      onStatus: _onStatus,
    );
    // The app may have closed while the recognizer was starting.
    if (!ref.mounted) return;
    if (_recognizerAvailable) {
      _localeId = await _pickLocale();
      if (!ref.mounted) return;
      _log(
        'initialized in ${watch.elapsedMilliseconds}ms; '
        'picked locale $_localeId',
      );
    } else {
      _log('initialize() returned false: no recognizer');
    }
    _initialized = true;
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
    await _closeSession();
    if (!ref.mounted) return null;
    final result = _dictation = Completer<String?>();
    _oneShot = false;
    _sameFailures = _instantFailures = 0;
    unawaited(ref.read(hapticsProvider).tick());
    _cueNext = true;
    await _start();
    return result.future;
  }

  /// Ends a pending dictation with no result.
  void _endDictation() {
    final d = _dictation;
    _dictation = null;
    if (d != null && !d.isCompleted) d.complete(null);
  }

  /// Long-press / "listen": stops any speech (including document reading)
  /// at once and listens now. Always works, also when listening while
  /// reading is off or unreliable.
  Future<void> listenNow() async {
    noteActivity();
    await ref.read(announcerProvider.notifier).stop();
    // A session listening through the reading may still be open: close it
    // rather than wait for it to end.
    await _closeSession();
    if (!await ensureReady(requestPermission: true)) return;
    if (!ref.mounted) return;
    _oneShot = !_wantsAutoListen;
    _sameFailures = _instantFailures = 0; // an explicit retry starts fresh
    unawaited(ref.read(hapticsProvider).tick());
    _cueNext = true;
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
      await _initRecognizer();
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
    _clearCarry();
    _unduck();
    if (_listening) {
      _log('cancelled by app (stopListening)');
      _session++;
      _listening = false;
      await _stt.cancel();
      _platformOpen = false;
    }
    if (ref.mounted && state.listening) {
      state = VoiceState(heard: state.heard);
    }
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  bool get _wantsAutoListen {
    if (!_micGranted) return false;
    if (ref.read(assistantActiveProvider)) return false;
    if (ref.read(percyActiveProvider)) return true;
    if (ref.read(navigationModeProvider) == NavMode.voice) return true;
    return ref.read(activeScreenProvider)?.autoListen ?? false;
  }

  /// Voice mode with "Makinig habang nagbabasa" on.
  bool get _bargeInAllowed =>
      _micGranted &&
      !ref.read(assistantActiveProvider) &&
      (ref.read(navigationModeProvider) == NavMode.voice ||
          ref.read(percyActiveProvider)) &&
      ref.read(settingsProvider).listenWhileReading;

  /// A document is being read aloud (and no prompt is playing).
  bool get _readingNow {
    final speech = ref.read(announcerProvider);
    return speech.reading && !speech.speaking;
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
    // Read before the wait: the controller may be gone after it.
    final filipinoUi = ref.read(appLocaleProvider) == AppLocales.filipino;
    final ids = await _stt.localeIds();
    String norm(String s) => s.replaceAll('_', '-').toLowerCase();
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
    final wasBusy = previous != null && (previous.speaking || previous.reading);
    if ((previous?.reading ?? false) && !next.reading) {
      // Listening to a document counts as using the app.
      noteActivity();
    }
    if (next.speaking) {
      if (_listening) {
        // Never listen to our own prompts. What the user had already said
        // is kept and joined to what the next session hears.
        final cut = _sessionBargeIn || _dictation != null
            ? ''
            : _withCarry(_lastWords).trim();
        _log('speech started ("${next.text}"): cancelling the open session');
        unawaited(stopListening());
        if (cut.isNotEmpty) _keepCarry(cut, 'the app started talking');
      }
      return;
    }
    if (next.reading) {
      if (_listening && !_sessionBargeIn) {
        _log('reading started: closing the command session');
        unawaited(stopListening());
      }
      if (_bargeInAllowed && !(_listening && _sessionBargeIn)) {
        _scheduleAutoListen(gap: VoiceConfig.bargeInStartDelay);
      }
      return;
    }
    if (_listening && _sessionBargeIn) {
      // Reading stopped while listening through it: that session has heard
      // the app's own voice. Listen afresh for ordinary commands.
      _log('reading stopped: restarting as a command session');
      _abandonSession();
      return;
    }
    if (wasBusy) {
      _cueNext = true;
      _scheduleAutoListen();
    }
  }

  void _scheduleAutoListen({Duration? gap}) {
    _restartTimer?.cancel();
    if (!_wantsAutoListen) return;
    final wait = (gap ?? VoiceConfig.afterSpeechGap) + _backoff;
    _restartTimer = Timer(wait, () {
      if (!ref.mounted) return;
      if (!_appActive || _listening || _budgetSpent || !_wantsAutoListen) {
        return;
      }
      if (state.status == ListenStatus.unavailable) return;
      final speech = ref.read(announcerProvider);
      if (speech.speaking) return;
      if (speech.reading) {
        if (!_bargeInAllowed) return;
      } else if (DateTime.now().difference(_lastActivity) >
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

  Future<void> _start({int waited = 0}) async {
    if (_platformOpen && waited < 4) {
      // The previous session hasn't reported `done` yet: listening now would
      // give error_busy. Wait for it instead.
      _log('start deferred: previous session still open (${waited + 1}/4)');
      _restartTimer?.cancel();
      _restartTimer = Timer(const Duration(milliseconds: 300), () {
        if (ref.mounted && !_listening) unawaited(_start(waited: waited + 1));
      });
      return;
    }
    final session = ++_session;
    _sessionStart = DateTime.now();
    _gotFinal = false;
    _listening = true;
    _platformOpen = true;
    _firstSoundAt = _firstPartialAt = _lastChangeAt = null;
    _lastWords = '';
    _partialTarget = null;
    state = VoiceState(status: ListenStatus.listening, heard: state.heard);
    final dictating = _dictation != null;
    _sessionBargeIn = !dictating && _readingNow;
    final carriedAt = _carryAt;
    if (_sessionBargeIn ||
        dictating ||
        (carriedAt != null &&
            DateTime.now().difference(carriedAt) > VoiceConfig.carryFor)) {
      _clearCarry();
    }
    final carrying = _carry.isNotEmpty;
    if (carrying) {
      state = VoiceState(
        status: ListenStatus.listening,
        partial: sensitive ? '•' * _carry.length : _carry,
        heard: state.heard,
      );
    }
    if (_cueNext && !_sessionBargeIn) {
      // "Your turn": the moment the microphone opens after the app spoke.
      unawaited(ref.read(earconProvider).listening());
    }
    _cueNext = false;
    final request = ListenRequest(
      localeId: _useDefaultLocale ? null : (_localeId ?? 'fil-PH'),
      onDevice: !_onDeviceUnavailable,
      phrases: dictating
          ? const []
          : _sessionBargeIn
          ? BargeIn.phrases
          : ref.read(commandBusProvider).expectedPhrases(),
      dictation: dictating,
      // Wait for the first words, then the short pause (see onResult).
      // After a cut-off, a short wait for more: the rest of what was said
      // may already be over.
      pauseFor: dictating
          ? VoiceConfig.dictationPause
          : carrying
          ? VoiceConfig.carryWait
          : VoiceConfig.waitForSpeech,
      pauseAfterSpeech: dictating
          ? VoiceConfig.dictationPause
          : VoiceConfig.commandPause,
    );
    _pauseAfterSpeech = request.pauseFor == request.pauseAfterSpeech
        ? null
        : request.pauseAfterSpeech;
    _log(
      'listen() locale=${request.localeId ?? 'device default'} '
      'onDevice=${request.onDevice} dictation=$dictating '
      'whileReading=$_sessionBargeIn '
      'listenFor=${request.listenFor.inSeconds}s '
      'pauseFor=${request.pauseFor.inMilliseconds}ms'
      '→${request.pauseAfterSpeech.inMilliseconds}ms after speech '
      'partialResults=true '
      'phrases=${request.phrases.length}'
      '${carrying ? ' carrying="${sensitive ? '•••' : _carry}"' : ''}',
    );
    try {
      await _stt.listen(
        request,
        onResult: (words, isFinal) => _onResult(session, words, isFinal),
        onSoundLevel: (level) => _onSoundLevel(session, level),
      );
    } on Object catch (e) {
      _log('listen() threw: $e');
      _listening = false;
      _platformOpen = false;
      if (ref.mounted) state = VoiceState(heard: state.heard);
    }
  }

  void _onSoundLevel(int session, double level) {
    if (session != _session || _firstSoundAt != null) return;
    if (level < VoiceConfig.speechStartLevel) return;
    _firstSoundAt = DateTime.now();
    _log('speech started (level ${level.toStringAsFixed(1)})');
  }

  void _onResult(int session, String words, bool isFinal) {
    if (session != _session || !ref.mounted) {
      _log('ignored stale result "$words" (session $session)');
      return;
    }
    final now = DateTime.now();
    final started = _sessionStart;
    final lastCommand = _lastCommandAt;
    if (lastCommand != null &&
        started != null &&
        started.isBefore(lastCommand)) {
      _log(
        'discarded ${sensitive ? '•••' : '"$words"'}: '
        'its session began before the last command',
      );
      _abandonSession();
      return;
    }
    if (words != _lastWords) {
      _firstPartialAt ??= now;
      _lastChangeAt = now;
      _lastWords = words;
    }
    final shorter = _pauseAfterSpeech;
    if (shorter != null && !isFinal && words.trim().isNotEmpty) {
      // The user has started speaking: from now on a short silence ends it.
      _pauseAfterSpeech = null;
      _stt.changePauseFor(shorter);
      _log('words heard: pause now ${shorter.inMilliseconds}ms');
    }
    _log(
      '${isFinal ? 'FINAL' : 'partial'} result: ${sensitive ? '•••' : '"$words"'}',
    );
    if (_sessionBargeIn) return _onReadingResult(words, isFinal);
    if (words.trim().isNotEmpty) {
      // Answering a question: hold its instructions back while they talk.
      ref.read(announcerProvider.notifier).userResponding();
    }
    // After a cut-off, what was heard before counts too.
    final said = _withCarry(words);
    if (!isFinal) {
      state = VoiceState(
        status: ListenStatus.listening,
        partial: sensitive ? '•' * said.length : said,
        heard: state.heard,
      );
      if (_dictation == null && !sensitive) _tryPartial(said);
      return;
    }
    _gotFinal = true;
    _listening = false;
    final text = said.trim();
    if (text.isEmpty) {
      if (_failedSession('empty_final')) return;
      return _endEmpty();
    }
    _accept(text, via: 'final');
  }

  /// Runs a partial result that is already a whole command — at once if it
  /// matches closely, or once the same command matched twice in a row.
  void _tryPartial(String words) {
    final verdict = ref.read(commandBusProvider).judgePartial(words);
    final usable =
        verdict != null && verdict.score >= VoiceConfig.partialRepeatScore;
    final strong = usable && verdict.score >= VoiceConfig.partialAcceptScore;
    final twice = usable && verdict.target == _partialTarget;
    _partialTarget = usable ? verdict.target : null;
    if (!strong && !twice) return;
    _log(
      'acting on the partial result (${strong ? 'similarity '
                '${verdict.score.toStringAsFixed(2)}' : 'same command twice'})',
    );
    _endSessionEarly();
    _accept(words.trim(), via: strong ? 'partial' : 'partial ×2');
  }

  /// A result heard while the document was being read: only a reading
  /// command, not in the app's own voice, counts.
  void _onReadingResult(String words, bool isFinal) {
    final readAloud = ref
        .read(announcerProvider.notifier)
        .readAloudSince(_sessionStart ?? DateTime.now());
    final intent = BargeIn.command(words, readAloud);
    if (intent != null) {
      _log('reading command "${intent.name}"');
      _endSessionEarly();
      _accept(
        words.trim(),
        via: isFinal ? 'final while reading' : 'partial while reading',
        intent: intent,
      );
      return;
    }
    if (!isFinal) {
      // The user (not the app's own voice) is talking: pause the reading
      // so the rest of what they say is heard clearly.
      if (words.trim().isNotEmpty && !BargeIn.isEcho(words, readAloud)) {
        _duck();
      }
      return;
    }
    _gotFinal = true;
    _listening = false;
    _unduck(missed: true);
    if (words.trim().isEmpty) {
      if (_failedSession('empty_final')) return;
      return _endEmpty();
    }
    _log(
      BargeIn.isEcho(words, readAloud)
          ? 'ignored: the app\'s own voice'
          : 'ignored: not a reading command',
    );
    state = VoiceState(heard: state.heard);
    _scheduleAutoListen(gap: VoiceConfig.sessionGap);
  }

  /// Hands a recognized phrase on: to a pending dictation, or (with the
  /// "heard" sound and pulse first) to the command bus — or straight to
  /// [intent] for a command heard during reading.
  void _accept(String text, {required String via, NavIntent? intent}) {
    final decided = DateTime.now();
    _failures = 0;
    _instantFailures = 0;
    _sameFailures = 0;
    _lastFailure = null;
    _clearCarry();

    _oneShot = false;
    noteActivity();
    final dictation = _dictation;
    if (dictation != null) {
      // Free speech for a form field: hand it back, don't run it.
      _dictation = null;
      state = VoiceState(heard: sensitive ? null : text);
      dictation.complete(text);
      return;
    }
    // The user knows at once they were heard, before the action finishes.
    unawaited(ref.read(earconProvider).heard());
    unawaited(ref.read(hapticsProvider).heard());
    _timing = _Timing(
      text: text,
      via: via,
      sessionStart: _sessionStart,
      firstSound: _firstSoundAt,
      firstPartial: _firstPartialAt,
      lastChange: _lastChangeAt,
      decided: decided,
    );
    state = VoiceState(heard: sensitive ? null : text);
    _heardTimer?.cancel();
    _heardTimer = Timer(AppDurations.heardVisible, () {
      if (ref.mounted && state.heard == text) {
        state = VoiceState(status: state.status, partial: state.partial);
      }
    });
    if (intent != null) {
      markMatched(intent.name);
      unawaited(_handleIntent(intent));
    } else {
      unawaited(_handle(text));
    }
  }

  Future<void> _handle(String text) async {
    await ref.read(commandBusProvider).handleUtterance(text);
    if (ref.mounted) _scheduleAutoListen();
  }

  Future<void> _handleIntent(NavIntent intent) async {
    if (ref.read(percyActiveProvider)) {
      // Said to Percy over the reading: not a gesture that ends the session.
      await ref
          .read(percyControllerProvider.notifier)
          .runReadingCommand(intent);
    } else {
      await ref.read(commandBusProvider).dispatch(intent);
    }
    if (!ref.mounted) return;
    // The command decided what the Reader does now; if it left reading
    // alone, the paused sentence goes on.
    _unduck();
    _scheduleAutoListen();
  }

  /// Ends the open session now because its words were acted on: later
  /// results from it are ignored (they would run the command again).
  void _endSessionEarly() {
    _session++;
    _listening = false;
    _gotFinal = true;
    unawaited(_cancelPlatform());
  }

  /// Drops the open session and listens again shortly.
  void _abandonSession() {
    _restartTimer?.cancel();
    _clearCarry();
    _unduck(missed: true);
    if (_listening || _platformOpen) {
      _session++;
      _listening = false;
      _gotFinal = true;
      unawaited(_cancelPlatform());
    }
    if (ref.mounted && state.listening) {
      state = VoiceState(heard: state.heard);
    }
    _scheduleAutoListen(gap: VoiceConfig.sessionGap);
  }

  /// Closes the open session and waits until the recognizer is free, so a
  /// new one can start at once (long-press, dictation).
  Future<void> _closeSession() async {
    _restartTimer?.cancel();
    if (!_listening && !_platformOpen) return;
    _log('closing the open session first');
    _session++;
    _listening = false;
    try {
      await _stt.cancel();
    } on Object catch (e) {
      _log('cancel() threw: $e');
    }
    _platformOpen = false;
  }

  Future<void> _cancelPlatform() async {
    final mine = _session;
    try {
      await _stt.cancel();
    } on Object catch (e) {
      _log('cancel() threw: $e');
    }
    // Unless a new session has started meanwhile, the recognizer is free.
    if (_session == mine) _platformOpen = false;
  }

  void _onStatus(String status) {
    if (!ref.mounted) return;
    _log('status: $status (listening=$_listening, gotFinal=$_gotFinal)');
    if (status == 'done' || status == 'notListening') _platformOpen = false;
    if (status == 'done' && _listening && !_gotFinal) {
      _listening = false;
      if (_salvage('done_without_result')) return;
      if (_sessionBargeIn) _unduck(missed: true);
      if (_failedSession('done_without_result')) return;
      _endEmpty();
    }
  }

  void _onError(String code) {
    if (!ref.mounted) return;
    _log('ERROR $code (listening=$_listening)');
    _platformOpen = false;
    if (!_listening) return;
    _listening = false;
    final setupError =
        code == 'error_permission' ||
        code == 'error_insufficient_permissions' ||
        code == 'error_language_unavailable' ||
        code == 'error_language_not_supported';
    if (!setupError && _salvage(code)) return;
    if (_sessionBargeIn) _unduck(missed: true);
    if (code != 'error_permission' &&
        code != 'error_insufficient_permissions' &&
        code != 'error_language_unavailable' &&
        code != 'error_language_not_supported' &&
        _failedSession(code)) {
      return;
    }
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
        // Identical repeats are handled by _failedSession; this caps a mix
        // of different errors, and says so instead of failing silently.
        if (++_failures < 8) {
          _scheduleAutoListen();
        } else {
          _failures = 0;
          _giveUp(code);
        }
    }
  }

  void _endEmpty() {
    _listening = false;
    _unduck(missed: true);
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
    // Nothing was spoken, so there is no echo to wait for.
    _scheduleAutoListen(gap: VoiceConfig.sessionGap);
  }

  // ── Cut-off speech ──────────────────────────────────────────────────────

  /// Codes that mean the user simply stopped talking.
  static const Set<String> _quietEnds = {
    'error_no_match',
    'error_speech_timeout',
    'done_without_result',
    'empty_final',
  };

  /// A command session ended ([why]) without a final result. If words had
  /// been heard, they are not dropped: when the user had just stopped
  /// talking they are acted on now; when the session was cut off (busy,
  /// audio focus, …) listening restarts at once and keeps them, up to
  /// [VoiceConfig.cutOffRetries] times, then the user is asked to repeat.
  /// Returns true if it handled the end of the session.
  bool _salvage(String why) {
    if (_dictation != null || _sessionBargeIn) return false;
    final started = _sessionStart;
    final lastCommand = _lastCommandAt;
    if (lastCommand != null &&
        started != null &&
        started.isBefore(lastCommand)) {
      return false; // said before the last command: stale
    }
    final said = _withCarry(_lastWords).trim();
    if (said.isEmpty) return false;
    if (_quietEnds.contains(why)) {
      _log(
        'session ended ($why) without a final result: acting on '
        '${sensitive ? '•••' : '"$said"'}',
      );
      _accept(said, via: _carry.isEmpty ? 'last partial' : 'carried');
      return true;
    }
    if (_carryRetries >= VoiceConfig.cutOffRetries) {
      _log('cut off ($why) $_carryRetries times in a row: asking to repeat');
      _clearCarry();
      state = VoiceState(heard: state.heard);
      unawaited(ref.read(hapticsProvider).error());
      unawaited(_say(_l.voiceSayAgain));
      return true;
    }
    _keepCarry(said, why);
    state = VoiceState(
      status: ListenStatus.listening,
      partial: sensitive ? '•' * said.length : said,
      heard: state.heard,
    );
    _restartTimer?.cancel();
    _restartTimer = Timer(VoiceConfig.sessionGap, () {
      if (ref.mounted && !_listening) unawaited(_start());
    });
    return true;
  }

  void _keepCarry(String said, String why) {
    _carry = said;
    _carryAt = DateTime.now();
    _carryRetries++;
    _log(
      'cut off ($why) mid-speech: keeping ${sensitive ? '•••' : '"$said"'} '
      'for the next session ($_carryRetries/${VoiceConfig.cutOffRetries})',
    );
  }

  void _clearCarry() {
    _carry = '';
    _carryAt = null;
    _carryRetries = 0;
  }

  /// [words] after the words kept from a cut-off session (once: the
  /// recognizer may repeat them).
  String _withCarry(String words) {
    final carry = _carry;
    if (carry.isEmpty) return words;
    final w = words.trim();
    if (w.isEmpty) return carry;
    final lower = w.toLowerCase();
    final kept = carry.toLowerCase();
    // The user said it again from the start (whole words only: "pa" is
    // not repeated by "pause").
    if (lower == kept || lower.startsWith('$kept ')) return w;
    return '$carry $w';
  }

  // ── Pausing the reading for the user's voice ────────────────────────────

  void _duck() {
    if (_ducking) return;
    final quietUntil = _noDuckUntil;
    if (quietUntil != null && DateTime.now().isBefore(quietUntil)) return;
    _ducking = true;
    _log('user speaking over the reading: pausing it');
    ref.read(readingDuckProvider.notifier).set(on: true);
    _duckTimer?.cancel();
    _duckTimer = Timer(VoiceConfig.duckMax, () => _unduck(missed: true));
  }

  /// Lets the reading go on. [missed]: no command came of it, so don't
  /// pause for speech again for a while ([VoiceConfig.duckCooldown]).
  void _unduck({bool missed = false}) {
    if (!_ducking) return;
    _ducking = false;
    _duckTimer?.cancel();
    if (missed) {
      _noDuckUntil = DateTime.now().add(VoiceConfig.duckCooldown);
    }
    _log('reading resumes');
    if (ref.mounted) ref.read(readingDuckProvider.notifier).set(on: false);
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
