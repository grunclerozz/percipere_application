import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'filipino_numbers.dart';

/// The two bundled voices: which language each speaks and where its files
/// are.
@immutable
class OfflineVoiceFiles {
  /// Creates the file set; a null folder means that voice isn't installed.
  const OfflineVoiceFiles({this.tagalogDir, this.englishDir});

  /// Folder of the Tagalog voice (MMS-TTS `tgl`, VITS): `model.onnx`,
  /// `tokens.txt`.
  final String? tagalogDir;

  /// Folder of the English voice (Piper `en_US-ljspeech-medium`, VITS):
  /// `model.onnx`, `tokens.txt`, `espeak-ng-data/`.
  final String? englishDir;

  /// Whether the folder [dir] holds a usable voice.
  static bool usable(String? dir) =>
      dir != null &&
      File('$dir/model.onnx').existsSync() &&
      File('$dir/tokens.txt').existsSync();
}

/// Sends generated audio to the speaker (native `AudioBridge`).
abstract interface class PcmPlayer {
  /// Plays mono float [samples] at [sampleRate]; true if it finished,
  /// false if it was stopped or failed.
  Future<bool> play(Float32List samples, int sampleRate);

  /// Stops what is playing.
  Future<void> stop();
}

/// [PcmPlayer] over the `ph.bataan.percipere/audio` channel.
class ChannelPcmPlayer implements PcmPlayer {
  /// Creates the player.
  const ChannelPcmPlayer();

  static const MethodChannel _channel = MethodChannel(
    'ph.bataan.percipere/audio',
  );

  @override
  Future<bool> play(Float32List samples, int sampleRate) async {
    try {
      return await _channel.invokeMethod<bool>('play', {
            'samples': samples,
            'sampleRate': sampleRate,
          }) ??
          false;
    } on Object catch (e) {
      debugPrint('[OFFLINE VOICE] play failed: $e');
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _channel.invokeMethod<bool>('playStop');
    } on Object catch (e) {
      debugPrint('[OFFLINE VOICE] playStop failed: $e');
    }
  }
}

/// Generated speech.
@immutable
class SpeechAudio {
  /// Creates the audio.
  const SpeechAudio(this.samples, this.sampleRate);

  /// Mono samples, −1..1.
  final Float32List samples;

  /// Samples per second.
  final int sampleRate;
}

/// An offline voice the app can speak with (tests use a fake).
abstract interface class OfflineVoice {
  /// Whether it speaks the language of TTS tag [tag].
  bool speaks(String tag);

  /// Speaks [text]; true if it finished, false if stopped or failed.
  Future<bool> speak(String text, {required String tag, double rate = 1});

  /// Stops speaking.
  Future<void> stop();
}

/// The app's own offline voices (sherpa-onnx VITS: Tagalog and English),
/// generated in a background isolate and played through [PcmPlayer].
///
/// Long text is cut into short pieces: the first piece is heard while the
/// next ones are being generated. Short prompts are kept in a small cache,
/// so repeated confirmations start at once.
class OfflineSpeaker implements OfflineVoice {
  OfflineSpeaker._(this._isolate, this._commands, this._replies, this._player,
      this._languages);

  final Isolate _isolate;
  final SendPort _commands;
  final ReceivePort _replies;
  final PcmPlayer _player;
  final Set<String> _languages;
  final Map<int, Completer<SpeechAudio?>> _pending = {};
  int _request = 0;
  int _generation = 0;
  final LinkedHashMap<String, SpeechAudio> _cache = LinkedHashMap();

  /// Longest piece generated at once (characters).
  static const int pieceLength = 160;

  /// Longest first piece: short, so speech starts soon (the rest is
  /// generated while it plays).
  static const int firstPieceLength = 70;

  /// Prompts kept ready.
  static const int cacheSize = 40;

  /// Pieces up to this long are cached.
  static const int cacheTextLength = 120;

  /// Loads the installed voices in [files]. Null if none could be loaded.
  static Future<OfflineSpeaker?> start(
    OfflineVoiceFiles files, {
    PcmPlayer player = const ChannelPcmPlayer(),
  }) async {
    final tagalog = OfflineVoiceFiles.usable(files.tagalogDir)
        ? files.tagalogDir
        : null;
    final english = OfflineVoiceFiles.usable(files.englishDir)
        ? files.englishDir
        : null;
    if (tagalog == null && english == null) return null;
    final replies = ReceivePort();
    final loaded = Completer<(SendPort, Set<String>)?>();
    OfflineSpeaker? speaker;
    replies.listen((dynamic message) {
      if (message is! List || message.isEmpty) return;
      switch (message[0]) {
        case 'loaded':
          loaded.complete((
            message[1] as SendPort,
            (message[2] as List).cast<String>().toSet(),
          ));
        case 'failed':
          debugPrint('[OFFLINE VOICE] voices failed to load: ${message[1]}');
          if (!loaded.isCompleted) loaded.complete(null);
        case 'audio':
          final waiting = speaker?._pending.remove(message[1] as int);
          if (waiting == null) return;
          final samples = message[2];
          waiting.complete(
            samples is TransferableTypedData
                ? SpeechAudio(
                    samples.materialize().asFloat32List(),
                    message[3] as int,
                  )
                : null,
          );
        case 'log':
          debugPrint('[OFFLINE VOICE] ${message[1]}');
      }
    });
    Isolate isolate;
    try {
      isolate = await Isolate.spawn(
        _voiceWorker,
        [replies.sendPort, tagalog ?? '', english ?? ''],
        debugName: 'offline-voices',
        errorsAreFatal: false,
      );
    } on Object catch (e) {
      debugPrint('[OFFLINE VOICE] voice isolate failed: $e');
      replies.close();
      return null;
    }
    final result = await loaded.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => null,
    );
    if (result == null || result.$2.isEmpty) {
      isolate.kill(priority: Isolate.immediate);
      replies.close();
      return null;
    }
    return speaker = OfflineSpeaker._(
      isolate,
      result.$1,
      replies,
      player,
      result.$2,
    );
  }

  /// The language key for a TTS tag: `fil` (Filipino/Tagalog), `en`, or
  /// null for other languages.
  static String? languageOf(String tag) {
    final lang = tag.toLowerCase().split(RegExp('[-_]')).first;
    if (lang == 'fil' || lang == 'tl' || lang == 'tgl') return 'fil';
    if (lang == 'en' || lang == 'eng') return 'en';
    return null;
  }

  /// Whether a voice for [tag] is loaded.
  @override
  bool speaks(String tag) => _languages.contains(languageOf(tag));

  /// Speaks [text] in [tag] at [rate] × normal speed. True if it finished;
  /// false if it was stopped or failed.
  @override
  Future<bool> speak(String text, {required String tag, double rate = 1}) async {
    final lang = languageOf(tag);
    if (lang == null || !_languages.contains(lang)) return false;
    final generation = ++_generation;
    final pieces = split(lang == 'fil' ? tagalogText(text) : text);
    if (pieces.isEmpty) return true;
    Future<SpeechAudio?> make(int i) => _audio(pieces[i], lang, rate);
    var next = make(0);
    for (var i = 0; i < pieces.length; i++) {
      final audio = await next;
      if (generation != _generation) return false;
      if (i + 1 < pieces.length) next = make(i + 1);
      if (audio == null) {
        debugPrint('[OFFLINE VOICE] no audio for a piece');
        return false;
      }
      if (audio.samples.isEmpty) continue;
      final finished = await _player.play(audio.samples, audio.sampleRate);
      if (!finished || generation != _generation) return false;
    }
    return true;
  }

  /// Stops speaking at once.
  @override
  Future<void> stop() async {
    _generation++;
    await _player.stop();
  }

  Future<SpeechAudio?> _audio(String text, String lang, double rate) {
    final key = '$lang|${rate.toStringAsFixed(2)}|$text';
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached; // most recently used
      return Future.value(cached);
    }
    final id = ++_request;
    final done = _pending[id] = Completer<SpeechAudio?>();
    _commands.send(['speak', id, lang, text, rate]);
    return done.future
        .timeout(
          Duration(seconds: 10 + text.length ~/ 10),
          onTimeout: () {
            _pending.remove(id);
            return null;
          },
        )
        .then((audio) {
          if (audio != null && text.length <= cacheTextLength) {
            _cache[key] = audio;
            while (_cache.length > cacheSize) {
              _cache.remove(_cache.keys.first);
            }
          }
          return audio;
        });
  }

  /// [text] as the Tagalog voice reads it: numbers spelled out, and
  /// sentences kept apart (it knows letters only, no punctuation).
  static String tagalogText(String text) => FilipinoNumbers.spell(text)
      .replaceAll(RegExp(r'[“”"()\[\]{}*_#/\|<>~^`]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Cuts [text] into pieces of at most [pieceLength] characters, at
  /// sentence ends, then commas, then spaces.
  static List<String> split(String text) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty) return const [];
    final out = <String>[];
    var rest = clean;
    while (rest.length > (out.isEmpty ? firstPieceLength : pieceLength)) {
      final limit = out.isEmpty ? firstPieceLength : pieceLength;
      var cut = -1;
      for (final marks in [
        RegExp(r'[.!?;:](\s)'),
        RegExp(r'[,—–](\s)'),
        RegExp(r'(\s)'),
      ]) {
        for (final m in marks.allMatches(rest.substring(0, limit))) {
          if (m.start > limit ~/ 3) cut = m.start + 1;
        }
        if (cut > 0) break;
      }
      if (cut <= 0) cut = limit;
      out.add(rest.substring(0, cut).trim());
      rest = rest.substring(cut).trim();
    }
    if (rest.isNotEmpty) out.add(rest);
    return [
      for (final p in out)
        if (p.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '').isNotEmpty)
          p,
    ];
  }

  /// Frees the voices.
  Future<void> dispose() async {
    _generation++;
    _commands.send(['quit']);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    _isolate.kill(priority: Isolate.immediate);
    _replies.close();
    for (final p in _pending.values) {
      if (!p.isCompleted) p.complete(null);
    }
    _pending.clear();
  }
}

/// The voice isolate: loads the voices, then answers `speak` / `quit`.
Future<void> _voiceWorker(List<Object> args) async {
  final out = args[0] as SendPort;
  final tagalogDir = args[1] as String;
  final englishDir = args[2] as String;
  final inbox = ReceivePort();
  final voices = <String, sherpa.OfflineTts>{};
  try {
    sherpa.initBindings();
    sherpa.OfflineTts load(String dir, {String dataDir = ''}) =>
        sherpa.OfflineTts(
          sherpa.OfflineTtsConfig(
            model: sherpa.OfflineTtsModelConfig(
              vits: sherpa.OfflineTtsVitsModelConfig(
                model: '$dir/model.onnx',
                tokens: '$dir/tokens.txt',
                dataDir: dataDir,
              ),
              numThreads: 4,
              debug: false,
            ),
          ),
        );
    if (tagalogDir.isNotEmpty) {
      try {
        voices['fil'] = load(tagalogDir);
      } on Object catch (e) {
        out.send(['log', 'Tagalog voice failed: $e']);
      }
    }
    if (englishDir.isNotEmpty) {
      try {
        voices['en'] = load(
          englishDir,
          dataDir: Directory('$englishDir/espeak-ng-data').existsSync()
              ? '$englishDir/espeak-ng-data'
              : '',
        );
      } on Object catch (e) {
        out.send(['log', 'English voice failed: $e']);
      }
    }
  } on Object catch (e) {
    out.send(['failed', '$e']);
    return;
  }
  // The first generation is slow (the runtime prepares itself): done now,
  // not on the first prompt.
  for (final v in voices.values) {
    try {
      v.generate(text: 'a', sid: 0, speed: 1);
    } on Object catch (_) {
      // Only a warm-up.
    }
  }
  out.send(['log', 'voices loaded: ${voices.keys.join(', ')}']);
  out.send(['loaded', inbox.sendPort, voices.keys.toList()]);

  await for (final dynamic message in inbox) {
    if (message is! List || message.isEmpty) continue;
    if (message[0] == 'quit') {
      for (final v in voices.values) {
        v.free();
      }
      inbox.close();
      return;
    }
    if (message[0] != 'speak') continue;
    final id = message[1] as int;
    final voice = voices[message[2] as String];
    if (voice == null) {
      out.send(['audio', id, null, 0]);
      continue;
    }
    try {
      final audio = voice.generate(
        text: message[3] as String,
        sid: 0,
        speed: (message[4] as double).clamp(0.5, 2.5),
      );
      out.send([
        'audio',
        id,
        TransferableTypedData.fromList([audio.samples]),
        audio.sampleRate,
      ]);
    } on Object catch (e) {
      out.send(['log', 'generate failed: $e']);
      out.send(['audio', id, null, 0]);
    }
  }
}
