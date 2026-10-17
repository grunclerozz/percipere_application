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
      if (!await mic.start()) return false;
      if (session != _session) {
        // Cancelled while the microphone was opening.
        await mic.stop();
        return true;
      }
      return _begin(session, request, onResult, onSoundLevel, onSpeechStart);
    });
  }

  bool _begin(
    int session,
    ListenRequest request,
    SpeechResultCallback onResult,
    void Function(double level)? onSoundLevel,
    void Function()? onSpeechStart,
  ) {
    _open = true;
    _flushing = false;
    _onResult = onResult;
    _onLevel = onSoundLevel;
    _onSpeechStart = onSpeechStart;
    _hold = request.pushToTalk;
    _heldWords.clear();
    recognizer.begin(session, languageFor(request.localeId), whole: _hold);
    _audioSub = mic.audio.listen(
      (chunk) {
        if (session != _session || !_open) return;
        recognizer.feed(session, chunk);
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

  void _onEvent(RecognizerEvent event) {
    if (event.session != _session || !_open) return;
    switch (event) {
      case SpeechStarted():
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
        if (_hold) {
          // Reported together once the release has flushed everything.
          if (words.isNotEmpty) _heldWords.add(words);
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
    // The result goes out at once; the microphone closes meanwhile.
    final closing = _close(report: true);
    onResult?.call(words, true, confidence: -1);
    onStatus?.call('done');
    await closing;
  }

  /// Ends the session, reporting what was said so far.
  Future<void> stop() async => _flush();

  /// Ends the session silently.
  Future<void> cancel() => _close(report: false);

  /// Closes the session at once (no more results or statuses from it);
  /// the returned future completes once the microphone is released. With
  /// [queued], the release waits its turn behind a microphone being opened.
  /// Also cancels a session whose microphone is still opening.
  Future<void> _close({required bool report, bool queued = true}) {
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
    if (wasOpen && report) onStatus?.call('notListening');
    if (!wasOpen && sub == null) {
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
    await _close(report: false);
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
