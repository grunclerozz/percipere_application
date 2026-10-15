import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../config/voice_config.dart';
import '../voice/speech_input.dart';
import 'command_recognizer.dart';

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

  late final Stream<Uint8List> _audio = _events
      .receiveBroadcastStream()
      .where((e) => e is Uint8List)
      .cast<Uint8List>();

  @override
  Stream<Uint8List> get audio => _audio;

  @override
  Future<bool> start() async {
    try {
      return await _control.invokeMethod<bool>('micStart', {
            'sampleRate': 16000,
          }) ??
          false;
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

  /// Starts [session] in [language] (`tl` / `en`).
  void begin(int session, String language);

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
  void begin(int session, String language) =>
      recognizer.begin(session, language);

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
  Timer? _wait;
  Timer? _cap;
  Timer? _speechCap;
  double _noiseFloor = -1;

  /// Whether a session is open.
  bool get listening => _open;

  /// The recognizer language for a locale (`tl` for Filipino, else `en`).
  static String languageFor(String? localeId) {
    final lang = (localeId ?? 'fil').toLowerCase().split(RegExp('[-_]')).first;
    return lang == 'en' ? 'en' : 'tl';
  }

  /// Starts a session for [request]. False if the microphone can't be
  /// opened (the caller then uses another recognizer).
  Future<bool> listen(
    ListenRequest request, {
    required SpeechResultCallback onResult,
    void Function(double level)? onSoundLevel,
  }) async {
    await _close(report: false);
    final session = ++_session;
    if (!await mic.start()) return false;
    if (session != _session) return true; // replaced meanwhile
    _open = true;
    _flushing = false;
    _onResult = onResult;
    _onLevel = onSoundLevel;
    _noiseFloor = -1;
    recognizer.begin(session, languageFor(request.localeId));
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
      // Nobody spoke.
      if (session == _session) unawaited(_finish(''));
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
    final db = levelOf(chunk);
    // The room's noise: follows quiet moments quickly, loud ones slowly.
    _noiseFloor = _noiseFloor < 0 || db < _noiseFloor
        ? db
        : _noiseFloor + 0.05;
    // Android's rms dB scale (about −2 silent .. 10 loud), for the logs.
    level(((db - _noiseFloor) / 3).clamp(-2, 10).toDouble());
  }

  void _onEvent(RecognizerEvent event) {
    if (event.session != _session || !_open) return;
    switch (event) {
      case SpeechStarted():
        // Speech has begun: no more "nobody spoke"; a long stretch of
        // words is cut and judged.
        _wait?.cancel();
        _speechCap ??= Timer(VoiceConfig.commandSpeechMax, _flush);
      case SpeechRecognized(:final text, :final millis):
        final words = CommandRecognizer.clean(text);
        debugPrint(
          '[OFFLINE VOICE] heard "${words.isEmpty ? '' : words}" '
          '(recognized in ${millis}ms)',
        );
        if (words.isNotEmpty) {
          unawaited(_finish(words));
        } else if (!_flushing) {
          // A cough or a click: keep listening for the command.
          _speechCap?.cancel();
          _speechCap = null;
        }
      case RecognizerFlushed():
        unawaited(_finish(''));
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

  Future<void> _close({required bool report}) async {
    final wasOpen = _open;
    _open = false;
    _flushing = false;
    _wait?.cancel();
    _cap?.cancel();
    _speechCap?.cancel();
    _wait = _cap = _speechCap = null;
    final sub = _audioSub;
    _audioSub = null;
    if (wasOpen) {
      recognizer.end(_session);
      _session++;
    }
    _onResult = null;
    _onLevel = null;
    if (wasOpen && report) onStatus?.call('notListening');
    await sub?.cancel();
    if (wasOpen) await mic.stop();
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
