import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../config/voice_config.dart';
import '../voice/speech_input.dart';
import 'command_recognizer.dart';

/// How the app's own microphone was opened: the Android audio source and
/// which of the phone's clean-up effects are on (developer overlay, logs).
@immutable
class MicCapture {
  /// Creates the description.
  const MicCapture({
    required this.source,
    this.echoCanceller = false,
    this.noiseSuppressor = false,
    this.autoGain = false,
  });

  /// Reads the native answer (`micStart`).
  factory MicCapture.fromMap(Map<Object?, Object?> map) => MicCapture(
    source: '${map['source'] ?? 'unknown'}',
    echoCanceller: map['aec'] == true,
    noiseSuppressor: map['ns'] == true,
    autoGain: map['agc'] == true,
  );

  /// `voiceRecognition` or `voiceCommunication`.
  final String source;

  /// The phone's acoustic echo canceller is on.
  final bool echoCanceller;

  /// The phone's noise suppressor is on.
  final bool noiseSuppressor;

  /// The phone's automatic gain control is on.
  final bool autoGain;

  /// Short form for logs and the overlay, e.g. `voiceRecognition AEC NS`.
  String get summary => [
    source,
    if (echoCanceller) 'AEC',
    if (noiseSuppressor) 'NS',
    if (autoGain) 'AGC',
  ].join(' ');
}

/// The microphone as 16 kHz mono PCM16 chunks. Abstract so tests can feed
/// audio.
abstract interface class MicStream {
  /// Opens the microphone. False if it can't (no permission, busy).
  Future<bool> start();

  /// The audio while open.
  Stream<Uint8List> get audio;

  /// Closes the microphone.
  Future<void> stop();
}

/// [MicStream] over the native `AudioBridge`.
class ChannelMicStream implements MicStream {
  /// Creates the stream.
  ChannelMicStream();

  static const MethodChannel _control = MethodChannel(
    'ph.bataan.percipere/audio',
  );
  static const EventChannel _events = EventChannel('ph.bataan.percipere/mic');

  /// How the microphone was last opened (null: not yet, or the phone
  /// didn't say).
  static final ValueNotifier<MicCapture?> capture = ValueNotifier(null);

  late final Stream<Uint8List> _audio = _events
      .receiveBroadcastStream()
      .where((e) => e is Uint8List)
      .cast<Uint8List>();

  @override
  Stream<Uint8List> get audio => _audio;

  @override
  Future<bool> start() async {
    try {
      final answer = await _control.invokeMethod<Object?>('micStart', {
        'sampleRate': 16000,
        'source': VoiceConfig.micAudioSource,
        'echoCanceller': VoiceConfig.micEchoCanceller,
        'noiseSuppressor': VoiceConfig.micNoiseSuppressor,
        'autoGain': VoiceConfig.micAutoGain,
      });
      if (answer is Map) {
        final info = MicCapture.fromMap(answer);
        if (capture.value?.summary != info.summary) {
          debugPrint('[OFFLINE VOICE] microphone: ${info.summary}');
        }
        capture.value = info;
        return answer['ok'] == true;
      }
      return answer == true;
    } on Object catch (e) {
      debugPrint('[OFFLINE VOICE] mic start failed: $e');
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _control.invokeMethod<bool>('micStop');
    } on Object catch (e) {
      debugPrint('[OFFLINE VOICE] mic stop failed: $e');
    }
  }
}

/// The recognizer as the listener needs it (tests use a fake).
abstract interface class SpeechRecognizerPort {
  /// What it heard.
  Stream<RecognizerEvent> get events;

  /// Starts [session] in [language] (`tl` / `en`). With [whole]
  /// (push-to-talk), stretches of speech aren't recognized one by one: all
  /// of it is recognized at once on [flush].
  void begin(int session, String language, {bool whole = false});

  /// Audio for [session].
  void feed(int session, Uint8List pcm16);

  /// Ends the speech heard so far in [session] now.
  void flush(int session);

  /// Ends [session].
  void end(int session);
}

/// [SpeechRecognizerPort] backed by the real [CommandRecognizer].
class SherpaRecognizerPort implements SpeechRecognizerPort {
  /// Wraps [recognizer].
  SherpaRecognizerPort(this.recognizer);

  /// The sherpa-onnx recognizer.
  final CommandRecognizer recognizer;

  @override
  Stream<RecognizerEvent> get events => recognizer.events;

  @override
  void begin(int session, String language, {bool whole = false}) =>
      recognizer.begin(session, language, whole: whole);

  @override
  void feed(int session, Uint8List pcm16) => recognizer.feed(session, pcm16);

  @override
  void flush(int session) => recognizer.flush(session);

  @override
  void end(int session) => recognizer.end(session);
}

/// Listens for one command with the app's own offline recognizer and
/// reports it like the Android recognizer does (a final result, then the
/// `done` status), so the voice controller and the command matcher work
/// unchanged.
///
/// Timing: the session waits [ListenRequest.pauseFor] for speech to start;
/// the recognizer's voice detector ends the speech after
/// [VoiceConfig.offlineEndOfSpeech] of silence and the words are reported
/// at once. Speech longer than [VoiceConfig.commandSpeechMax] (a noisy
/// room) is cut and judged; [ListenRequest.listenFor] caps the session.
///
/// Push-to-talk ([ListenRequest.pushToTalk]): pauses don't end the session
/// and there is no speech cap; [stop] (the release) ends it, and everything
/// said while held is recognized at once and reported as one result
/// (2026-10-17: the first pause used to end the command).
class OfflineCommandListener {
  /// Creates a listener over [recognizer] and [mic].
  OfflineCommandListener(this.recognizer, this.mic, {this.onStatus}) {
    _eventSub = recognizer.events.listen(_onEvent);
  }

  /// The recognizer.
  final SpeechRecognizerPort recognizer;

  /// The microphone.
  final MicStream mic;

  /// Gets `listening`, `notListening` and `done`, like the Android
  /// recognizer's status callback.
  void Function(String status)? onStatus;

  late final StreamSubscription<RecognizerEvent> _eventSub;
  StreamSubscription<Uint8List>? _audioSub;
  int _session = 0;
  bool _open = false;
  bool _flushing = false;
  SpeechResultCallback? _onResult;
  void Function(double level)? _onLevel;
  void Function()? _onSpeechStart;

  /// The open session is a push-to-talk one, and the words it has heard.
  bool _hold = false;
  final List<String> _heldWords = [];
  Timer? _wait;
  Timer? _cap;
  Timer? _speechCap;

  // ── 2026-10-18: mic kept open between sessions, tone mute, threshold ──

  /// The microphone is still open after a session that heard nothing
  /// ([VoiceConfig.micLinger]): what it hears is kept for the next one.
  StreamSubscription<Uint8List>? _lingerSub;
  Timer? _linger;
  final List<Uint8List> _kept = [];
  int _keptBytes = 0;

  /// Audio is dropped until then (one of the app's tones).
  DateTime? _mutedUntil;

  /// The open session's speech threshold ([ListenRequest.speechThreshold]),
  /// recent chunk levels, and the loudest level of the speech being heard
  /// (null: no speech yet).
  double? _threshold;
  final List<(DateTime, double)> _recent = [];
  double? _loudest;

  /// Whether a session is open.
  bool get listening => _open;

  /// The recognizer language for a locale (`tl` for Filipino, else `en`).
  static String languageFor(String? localeId) {
    final lang = (localeId ?? 'fil').toLowerCase().split(RegExp('[-_]')).first;
    return lang == 'en' ? 'en' : 'tl';
  }

  /// Opening and closing the microphone, one after the other: a session
  /// opened while the previous one was still closing got a microphone that
  /// the old close then stopped (2026-10-17: commands said into a dead
  /// microphone, "say it twice").
  Future<void> _micQueue = Future.value();

  Future<T> _serial<T>(Future<T> Function() task) {
    final result = _micQueue.then((_) => task());
    _micQueue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  /// Starts a session for [request]. False if the microphone can't be
  /// opened (the caller then uses another recognizer).
  Future<bool> listen(
    ListenRequest request, {
    required SpeechResultCallback onResult,
    void Function(double level)? onSoundLevel,
    void Function()? onSpeechStart,
  }) {
    // Claimed now, so a cancel() arriving while the microphone opens
    // cancels this session.
    final releasing = _close(report: false, queued: false);
    final session = ++_session;
    return _serial(() async {
      await releasing;
      if (session != _session) return true; // cancelled or replaced
      // Still open from the session before: no gap, and what it heard
      // meanwhile (the start of the command) goes to this session.
      final kept = _takeLinger();
      if (kept == null) {
        if (!await mic.start()) return false;
        if (session != _session) {
          // Cancelled while the microphone was opening.
          await mic.stop();
          return true;
        }
      }
      final begun = _begin(
        session,
        request,
        onResult,
        onSoundLevel,
        onSpeechStart,
        kept?.$1 ?? const [],
      );
      // Only now: the audio stream always keeps a listener (the native
      // side stops sending when the last one goes).
      unawaited(kept?.$2.cancel());
      return begun;
    });
  }

  bool _begin(
    int session,
    ListenRequest request,
    SpeechResultCallback onResult,
    void Function(double level)? onSoundLevel,
    void Function()? onSpeechStart,
    List<Uint8List> preRoll,
  ) {
    _open = true;
    _flushing = false;
    _onResult = onResult;
    _onLevel = onSoundLevel;
    _onSpeechStart = onSpeechStart;
    _hold = request.pushToTalk;
    _heldWords.clear();
    _mutedUntil = null;
    _threshold = request.speechThreshold;
    _recent.clear();
    _loudest = null;
    recognizer.begin(session, languageFor(request.localeId), whole: _hold);
    if (preRoll.isNotEmpty) {
      debugPrint(
        '[OFFLINE VOICE] microphone kept open: '
        '${preRoll.fold<int>(0, (n, c) => n + c.length) ~/ 32}ms before the '
        'session',
      );
    }
    for (final chunk in preRoll) {
      recognizer.feed(session, chunk);
      _track(chunk);
    }
    _audioSub = mic.audio.listen(
      (chunk) {
        if (session != _session || !_open) return;
        final until = _mutedUntil;
        if (until != null && DateTime.now().isBefore(until)) {
          // The app's own tone: never heard as speech (half-duplex). Its
          // level is still reported; the noise monitor ignores it.
          _reportLevel(chunk);
          return;
        }
        recognizer.feed(session, chunk);
        _track(chunk);
        _reportLevel(chunk);
      },
      onError: (Object e) {
        debugPrint('[OFFLINE VOICE] mic error: $e');
        if (session == _session) _flush();
      },
    );
    _wait = Timer(request.pauseFor, () {
      if (session != _session) return;
      // Nobody spoke (push-to-talk: held too long; what was said counts).
      _hold ? _flush() : unawaited(_finish(''));
    });
    _cap = Timer(request.listenFor, () {
      if (session == _session) _flush();
    });
    onStatus?.call('listening');
    return true;
  }

  void _reportLevel(Uint8List chunk) {
    final level = _onLevel;
    if (level == null) return;
    // About Android's rms dB scale (−2 silent .. 10 loud), measured from a
    // quiet room (−60 dBFS), so a steady noise shows as loud: the voice
    // controller judges the room by it ([VoiceConfig.noisyLevel]).
    level(soundLevel(levelOf(chunk)));
  }

  /// A chunk's loudness [dbfs] on about Android's rms dB scale.
  static double soundLevel(double dbfs) =>
      ((dbfs + 60) / 3).clamp(-2, 10).toDouble();

  /// Keeps the recent levels and, while speech is heard, its loudest one.
  void _track(Uint8List chunk) {
    final level = soundLevel(levelOf(chunk));
    final now = DateTime.now();
    _recent.add((now, level));
    final old = now.subtract(const Duration(seconds: 1));
    while (_recent.isNotEmpty && _recent.first.$1.isBefore(old)) {
      _recent.removeAt(0);
    }
    final loudest = _loudest;
    if (loudest != null && level > loudest) _loudest = level;
  }

  /// The loudest level of the last half second (the voice detector is
  /// sure of speech only a moment after it began).
  double _recentLoudest() {
    final from = DateTime.now().subtract(const Duration(milliseconds: 500));
    var loudest = -2.0;
    for (final (at, level) in _recent) {
      if (!at.isBefore(from) && level > loudest) loudest = level;
    }
    return loudest;
  }

  void _onEvent(RecognizerEvent event) {
    if (event.session != _session || !_open) return;
    switch (event) {
      case SpeechStarted():
        _loudest = _recentLoudest();
        _onSpeechStart?.call();
        // Speech has begun: no more "nobody spoke".
        _wait?.cancel();
        // Push-to-talk: only the release (or the session cap) ends it.
        if (_hold) return;
        // A long stretch of words is cut and judged.
        _speechCap ??= Timer(VoiceConfig.commandSpeechMax, _flush);
      case SpeechRecognized(:final text, :final millis):
        final words = CommandRecognizer.clean(text);
        debugPrint(
          '[OFFLINE VOICE] heard "${words.isEmpty ? '' : words}" '
          '(recognized in ${millis}ms)',
        );
        final threshold = _threshold;
        final loudest = _loudest;
        // The next stretch of speech is measured afresh.
        _loudest = _recentLoudest();
        if (_hold) {
          // Reported together once the release has flushed everything.
          if (words.isNotEmpty) _heldWords.add(words);
        } else if (words.isNotEmpty &&
            threshold != null &&
            loudest != null &&
            loudest < threshold) {
          // About as loud as the room (the TV, people further away): not
          // the user's command.
          debugPrint(
            '[OFFLINE VOICE] ignored: level ${loudest.toStringAsFixed(1)} '
            'below the speech threshold ${threshold.toStringAsFixed(1)}',
          );
          if (_flushing) {
            unawaited(_finish(''));
          } else {
            _speechCap?.cancel();
            _speechCap = null;
          }
        } else if (words.isNotEmpty) {
          unawaited(_finish(words));
        } else if (!_flushing) {
          // A cough or a click: keep listening for the command.
          _speechCap?.cancel();
          _speechCap = null;
        }
      case RecognizerFlushed():
        unawaited(_finish(_hold ? _heldWords.join(' ') : ''));
    }
  }

  /// Ends the speech now and reports what it was.
  void _flush() {
    if (!_open || _flushing) return;
    _flushing = true;
    recognizer.flush(_session);
  }

  /// Ends the session with [words] as its final result (empty: nothing
  /// heard), then reports `done`.
  Future<void> _finish(String words) async {
    if (!_open) return;
    final onResult = _onResult;
    // The result goes out at once; the microphone closes meanwhile. After
    // a session that heard nothing the next one usually follows at once:
    // the microphone stays open for it ([VoiceConfig.micLinger]).
    final closing = _close(report: true, keepMic: words.isEmpty);
    onResult?.call(words, true, confidence: -1);
    onStatus?.call('done');
    await closing;
  }

  /// Ends the session, reporting what was said so far.
  Future<void> stop() async => _flush();

  /// Ends the session silently (and closes the microphone).
  Future<void> cancel() async {
    final closing = _close(report: false);
    // Queued: a room measurement still running lingers when it ends.
    await _serial(_stopLinger);
    await closing;
  }

  /// Drops the microphone's audio from now for [duration] (one of the app's
  /// tones). Ends with the session.
  void muteAudio(Duration duration) {
    _mutedUntil = duration <= Duration.zero
        ? null
        : DateTime.now().add(duration);
  }

  /// Closes the microphone now if it is still open between sessions (the
  /// app is about to speak: half-duplex).
  Future<void> releaseMic() async {
    if (!_open) _session++; // ends a room measurement
    await _serial(_stopLinger);
  }

  /// Keeps the open microphone running for the next session, keeping what
  /// it hears (at most [VoiceConfig.micLinger]), and closes it after that.
  void _startLinger() {
    _linger?.cancel();
    _kept.clear();
    _keptBytes = 0;
    // 16 kHz, 2 bytes per sample.
    final maxBytes = VoiceConfig.micLinger.inMilliseconds * 32;
    final old = _lingerSub;
    late final StreamSubscription<Uint8List> sub;
    sub = mic.audio.listen((chunk) {
      if (!identical(_lingerSub, sub)) return;
      _kept.add(chunk);
      _keptBytes += chunk.length;
      while (_keptBytes > maxBytes && _kept.length > 1) {
        _keptBytes -= _kept.removeAt(0).length;
      }
    }, onError: (Object _) {});
    _lingerSub = sub;
    // The new listener first, then the old one goes (see [listen]).
    unawaited(old?.cancel());
    _linger = Timer(VoiceConfig.micLinger, () {
      if (_lingerSub != null) unawaited(_serial(_stopLinger));
    });
  }

  /// Ends the linger with the microphone still open: the audio kept
  /// meanwhile and the linger's listener, which the caller cancels once it
  /// listens itself. Null if the microphone isn't lingering.
  (List<Uint8List>, StreamSubscription<Uint8List>)? _takeLinger() {
    final sub = _lingerSub;
    if (sub == null) return null;
    _linger?.cancel();
    _linger = null;
    _lingerSub = null;
    final kept = List.of(_kept);
    _kept.clear();
    _keptBytes = 0;
    return (kept, sub);
  }

  Future<void> _stopLinger() async {
    final taken = _takeLinger();
    if (taken == null) return;
    await taken.$2.cancel();
    await mic.stop();
  }

  /// Measures the room for [duration] while no session is open (the
  /// warm-up and noisy screens): the levels in order. Ends early, empty or
  /// short, when a session opens or [cancel] / [releaseMic] is called. The
  /// microphone then lingers for the next session.
  Future<List<double>> measure(Duration duration) {
    final mine = ++_session;
    return _serial(() async {
      if (_open || mine != _session) return const <double>[];
      if (_lingerSub == null && !await mic.start()) return const <double>[];
      // Lingers throughout: a session asked for meanwhile takes it over.
      _startLinger();
      if (mine != _session) return const <double>[];
      final levels = await _collect(mic.audio, duration, () => mine != _session);
      // The microphone stays open a little longer for the first session.
      if (_lingerSub != null) _startLinger();
      return levels;
    });
  }

  /// Sound levels from [audio] for [duration] (until [stop] says so).
  static Future<List<double>> _collect(
    Stream<Uint8List> audio,
    Duration duration,
    bool Function() stop,
  ) async {
    final levels = <double>[];
    final done = Completer<void>();
    final sub = audio.listen((chunk) {
      if (stop()) {
        if (!done.isCompleted) done.complete();
        return;
      }
      levels.add(soundLevel(levelOf(chunk)));
    }, onError: (Object _) {});
    await Future.any([done.future, Future<void>.delayed(duration)]);
    await sub.cancel();
    return levels;
  }

  /// Measures the room with [mic] alone (no offline recognizer loaded):
  /// opens it, takes the levels for [duration] and closes it.
  static Future<List<double>> measureWith(
    MicStream mic,
    Duration duration,
  ) async {
    if (!await mic.start()) return const [];
    try {
      return await _collect(mic.audio, duration, () => false);
    } finally {
      await mic.stop();
    }
  }

  /// Closes the session at once (no more results or statuses from it);
  /// the returned future completes once the microphone is released. With
  /// [queued], the release waits its turn behind a microphone being opened.
  /// Also cancels a session whose microphone is still opening. With
  /// [keepMic] the microphone stays open for the next session.
  Future<void> _close({
    required bool report,
    bool queued = true,
    bool keepMic = false,
  }) {
    final wasOpen = _open;
    _open = false;
    _flushing = false;
    _wait?.cancel();
    _cap?.cancel();
    _speechCap?.cancel();
    _wait = _cap = _speechCap = null;
    final sub = _audioSub;
    _audioSub = null;
    if (wasOpen) recognizer.end(_session);
    _session++;
    _onResult = null;
    _onLevel = null;
    _onSpeechStart = null;
    _hold = false;
    _heldWords.clear();
    _mutedUntil = null;
    _threshold = null;
    _loudest = null;
    if (wasOpen && report) onStatus?.call('notListening');
    if (!wasOpen && sub == null) {
      return queued ? _serial(() async {}) : Future.value();
    }
    if (wasOpen && keepMic) {
      _startLinger();
      unawaited(sub?.cancel());
      return queued ? _serial(() async {}) : Future.value();
    }
    Future<void> release() async {
      await sub?.cancel();
      if (wasOpen) await mic.stop();
    }

    return queued ? _serial(release) : release();
  }

  /// Stops listening for good.
  Future<void> dispose() async {
    await cancel();
    await _eventSub.cancel();
  }

  /// Loudness of a PCM16 chunk in dB relative to full scale (−100 for
  /// silence).
  static double levelOf(Uint8List pcm16) {
    // Int16 views need an even offset.
    final bytes = pcm16.offsetInBytes.isEven
        ? pcm16
        : Uint8List.fromList(pcm16);
    final samples = bytes.buffer.asInt16List(
      bytes.offsetInBytes,
      bytes.lengthInBytes ~/ 2,
    );
    if (samples.isEmpty) return -100;
    var sum = 0.0;
    for (final s in samples) {
      sum += s * s;
    }
    final rms = math.sqrt(sum / samples.length) / 32768;
    return rms <= 0 ? -100 : 20 * math.log(rms) / math.ln10;
  }
}
