import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../../config/voice_config.dart';

/// The files of the offline command recognizer, in [dir]: Whisper (tiny,
/// multilingual — knows Filipino/Tagalog and English) and the Silero voice
/// activity detector that finds where speech starts and ends.
@immutable
class RecognizerFiles {
  /// Creates the file set for the model folder [dir].
  const RecognizerFiles(this.dir);

  /// The installed model's folder.
  final String dir;

  /// Whisper encoder.
  String get encoder => '$dir/encoder.onnx';

  /// Whisper decoder.
  String get decoder => '$dir/decoder.onnx';

  /// Whisper tokens.
  String get tokens => '$dir/tokens.txt';

  /// Silero VAD.
  String get vad => '$dir/silero_vad.onnx';

  /// All files the recognizer needs.
  List<String> get all => [encoder, decoder, tokens, vad];

  /// Whether every file is there.
  bool get complete => all.every((p) => File(p).existsSync());
}

/// What the recognizer isolate reports for a listening session.
sealed class RecognizerEvent {
  const RecognizerEvent(this.session);

  /// The session it belongs to.
  final int session;
}

/// Speech has started.
final class SpeechStarted extends RecognizerEvent {
  /// Creates the event.
  const SpeechStarted(super.session);
}

/// A stretch of speech ended and was recognized.
final class SpeechRecognized extends RecognizerEvent {
  /// Creates the event.
  const SpeechRecognized(super.session, this.text, this.millis);

  /// What was said (may be empty).
  final String text;

  /// How long recognition took.
  final int millis;
}

/// A [CommandRecognizer.flush] is done: everything heard was reported.
final class RecognizerFlushed extends RecognizerEvent {
  /// Creates the event.
  const RecognizerFlushed(super.session);
}

/// The offline recognizer (sherpa-onnx Whisper + Silero VAD) in its own
/// isolate: give it a session ([begin]) and the microphone's audio
/// ([feed]); it reports when speech starts and, at the end of each stretch
/// of speech, what was said ([events]).
class CommandRecognizer {
  CommandRecognizer._(this._isolate, this._commands, this._replies);

  final Isolate _isolate;
  final SendPort _commands;
  final ReceivePort _replies;
  final StreamController<RecognizerEvent> _events =
      StreamController.broadcast();

  /// What the recognizer heard.
  Stream<RecognizerEvent> get events => _events.stream;

  /// Loads the model in [files] in a new isolate. Null if it can't be
  /// loaded (missing or broken files, no native library).
  static Future<CommandRecognizer?> start(RecognizerFiles files) async {
    if (!files.complete) return null;
    final replies = ReceivePort();
    final ready = Completer<SendPort?>();
    CommandRecognizer? recognizer;
    replies.listen((dynamic message) {
      if (message is! List || message.isEmpty) return;
      final events = recognizer?._events;
      switch (message[0]) {
        case 'loaded':
          ready.complete(message[1] as SendPort);
        case 'failed':
          debugPrint('[OFFLINE VOICE] recognizer failed to load: ${message[1]}');
          if (!ready.isCompleted) ready.complete(null);
        case 'speech':
          events?.add(SpeechStarted(message[1] as int));
        case 'text':
          events?.add(
            SpeechRecognized(
              message[1] as int,
              message[2] as String,
              message[3] as int,
            ),
          );
        case 'flushed':
          events?.add(RecognizerFlushed(message[1] as int));
        case 'log':
          debugPrint('[OFFLINE VOICE] ${message[1]}');
      }
    });
    Isolate isolate;
    try {
      isolate = await Isolate.spawn(
        _recognizerWorker,
        [replies.sendPort, files.dir],
        debugName: 'command-recognizer',
        errorsAreFatal: false,
      );
    } on Object catch (e) {
      debugPrint('[OFFLINE VOICE] recognizer isolate failed: $e');
      replies.close();
      return null;
    }
    final commands = await ready.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => null,
    );
    if (commands == null) {
      isolate.kill(priority: Isolate.immediate);
      replies.close();
      return null;
    }
    return recognizer = CommandRecognizer._(isolate, commands, replies);
  }

  /// Starts [session], recognizing [language] (`tl` or `en`).
  void begin(int session, String language) =>
      _commands.send(['begin', session, language]);

  /// Hands over 16 kHz mono PCM16 audio for [session].
  void feed(int session, Uint8List pcm16) => _commands.send([
    'audio',
    session,
    TransferableTypedData.fromList([pcm16]),
  ]);

  /// Ends the speech heard so far in [session] now (as if the user had
  /// stopped talking); a [RecognizerFlushed] follows the results.
  void flush(int session) => _commands.send(['flush', session]);

  /// Stops [session]: its audio is ignored from now on.
  void end(int session) => _commands.send(['end', session]);

  /// Frees the model and the isolate.
  Future<void> dispose() async {
    _commands.send(['quit']);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    _isolate.kill(priority: Isolate.immediate);
    _replies.close();
    await _events.close();
  }

  /// Whisper's transcript cleaned for the command matcher: sound notes
  /// ("[Music]", "(tawa)") and stray symbols dropped.
  static String clean(String text) => text
      .replaceAll(RegExp(r'\[[^\]]*\]|\([^)]*\)|\*[^*]*\*'), ' ')
      .replaceAll(RegExp(r'[♪♫"“”]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// The recognizer isolate: loads Whisper and the VAD, then answers
/// `begin` / `audio` / `flush` / `end` / `quit`.
Future<void> _recognizerWorker(List<Object> args) async {
  final out = args[0] as SendPort;
  final files = RecognizerFiles(args[1] as String);
  final inbox = ReceivePort();
  late final sherpa.OfflineRecognizer recognizer;
  late final sherpa.VoiceActivityDetector vad;
  var language = 'tl';

  sherpa.OfflineRecognizerConfig config(String lang) =>
      sherpa.OfflineRecognizerConfig(
        model: sherpa.OfflineModelConfig(
          whisper: sherpa.OfflineWhisperModelConfig(
            encoder: files.encoder,
            decoder: files.decoder,
            language: lang,
            task: 'transcribe',
          ),
          tokens: files.tokens,
          numThreads: 4,
          debug: false,
        ),
      );

  try {
    sherpa.initBindings();
    recognizer = sherpa.OfflineRecognizer(config(language));
    vad = sherpa.VoiceActivityDetector(
      config: sherpa.VadModelConfig(
        sileroVad: sherpa.SileroVadModelConfig(
          model: files.vad,
          threshold: 0.5,
          minSilenceDuration:
              VoiceConfig.offlineEndOfSpeech.inMilliseconds / 1000,
          minSpeechDuration: 0.2,
          maxSpeechDuration:
              VoiceConfig.commandSpeechMax.inMilliseconds / 1000,
        ),
        numThreads: 1,
        debug: false,
      ),
      bufferSizeInSeconds: 30,
    );
  } on Object catch (e) {
    out.send(['failed', '$e']);
    return;
  }
  out.send(['log', 'recognizer loaded (Whisper + Silero VAD)']);
  out.send(['loaded', inbox.sendPort]);

  var session = -1;
  var speechReported = false;
  // The session's audio, so each stretch of speech is recognized with a
  // little of what came before it: the voice detector starts a segment
  // only once speech is certain, which cuts the first syllable
  // ("basahin" → "hina").
  final heard = <Float32List>[];
  var heardLength = 0;

  Float32List audioFor(sherpa.SpeechSegment segment) {
    const preRoll = 16000 * 4 ~/ 10; // 0.4 s
    const tail = 16000 * 2 ~/ 10; // 0.2 s
    final from = (segment.start - preRoll).clamp(0, heardLength);
    final to = (segment.start + segment.samples.length + tail).clamp(
      from,
      heardLength,
    );
    if (to - from < segment.samples.length) return segment.samples;
    final out = Float32List(to - from);
    var offset = 0;
    for (final chunk in heard) {
      final start = offset;
      final end = offset + chunk.length;
      offset = end;
      if (end <= from || start >= to) continue;
      final a = from > start ? from - start : 0;
      final b = to < end ? to - start : chunk.length;
      out.setRange(start + a - from, start + b - from, chunk, a);
    }
    return out;
  }

  void recognizeSegments() {
    while (!vad.isEmpty()) {
      final segment = vad.front();
      vad.pop();
      final watch = Stopwatch()..start();
      final stream = recognizer.createStream();
      try {
        stream.acceptWaveform(samples: audioFor(segment), sampleRate: 16000);
        recognizer.decode(stream);
        final text = recognizer.getResult(stream).text;
        out.send(['text', session, text, watch.elapsedMilliseconds]);
      } on Object catch (e) {
        out.send(['log', 'recognition failed: $e']);
        out.send(['text', session, '', watch.elapsedMilliseconds]);
      } finally {
        stream.free();
      }
    }
  }

  await for (final dynamic message in inbox) {
    if (message is! List || message.isEmpty) continue;
    switch (message[0]) {
      case 'begin':
        session = message[1] as int;
        final lang = message[2] as String;
        vad.reset();
        speechReported = false;
        heard.clear();
        heardLength = 0;
        if (lang != language) {
          try {
            recognizer.setConfig(config(lang));
            language = lang;
          } on Object catch (e) {
            out.send(['log', 'language switch to $lang failed: $e']);
          }
        }
      case 'audio':
        if (message[1] != session) continue;
        final bytes = Uint8List.fromList(
          (message[2] as TransferableTypedData).materialize().asUint8List(),
        );
        final pcm = bytes.buffer.asInt16List(0, bytes.lengthInBytes ~/ 2);
        final samples = Float32List(pcm.length);
        for (var i = 0; i < pcm.length; i++) {
          samples[i] = pcm[i] / 32768.0;
        }
        heard.add(samples);
        heardLength += samples.length;
        vad.acceptWaveform(samples);
        if (!speechReported && vad.isDetected()) {
          speechReported = true;
          out.send(['speech', session]);
        }
        recognizeSegments();
      case 'flush':
        if (message[1] != session) continue;
        vad.flush();
        recognizeSegments();
        out.send(['flushed', session]);
      case 'end':
        if (message[1] == session) {
          session = -1;
          vad.reset();
          heard.clear();
          heardLength = 0;
        }
      case 'quit':
        vad.free();
        recognizer.free();
        inbox.close();
        return;
    }
  }
}
