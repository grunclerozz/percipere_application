import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'knowledge_base.dart';
import 'percy_responses.dart';

/// How a sentence is named in the bundled voice clips. The generation script
/// (`tool/percy_voice/generate_percy_voice.py`) uses the same rule.
abstract final class PercyClipKey {
  /// The text with whitespace runs collapsed and the ends trimmed.
  static String normalize(String text) =>
      text.replaceAll(RegExp(r'\s+'), ' ').trim();

  /// `fil` or `en` for a BCP-47 tag, null for other languages.
  static String? languageOf(String tag) {
    final lang = tag.toLowerCase().split(RegExp('[-_]')).first;
    if (lang == 'fil' || lang == 'tl' || lang == 'tgl') return 'fil';
    if (lang == 'en' || lang == 'eng') return 'en';
    return null;
  }

  /// First 16 hex characters of sha256 of `"<lang>|<normalized text>"`.
  static String hash(String lang, String text) => sha256
      .convert(utf8.encode('$lang|${normalize(text)}'))
      .toString()
      .substring(0, 16);

  /// Splits [text] into sentences like `Announcer.splitSentences` (on `.`,
  /// `!`, `?`, `…` followed by space).
  static List<String> sentences(String text) => text
      .split(RegExp(r'(?<=[.!?…])\s+'))
      .map(normalize)
      .where((s) => s.isNotEmpty)
      .toList();
}

/// The clips that ship with the app (`assets/percy/voice/manifest.json`):
/// sentence hash → file name.
@immutable
class PercyClipManifest {
  /// Creates a manifest from hash → file.
  const PercyClipManifest(this.files);

  /// No clips (the app then speaks everything with the offline voice).
  static const PercyClipManifest empty = PercyClipManifest({});

  /// Reads the manifest JSON; anything unreadable gives [empty].
  factory PercyClipManifest.parse(String source) {
    try {
      final clips = (jsonDecode(source) as Map)['clips'];
      if (clips is! Map) return empty;
      final files = <String, String>{};
      for (final e in clips.entries) {
        final file = e.value is Map ? (e.value as Map)['file'] : null;
        if (file is String && file.isNotEmpty) files['${e.key}'] = file;
      }
      return PercyClipManifest(files);
    } on Object catch (e) {
      debugPrint('[PERCY VOICE] manifest unreadable: $e');
      return empty;
    }
  }

  /// Hash → file name (inside `assets/percy/voice/`).
  final Map<String, String> files;

  /// The file for [text] in [lang] (`fil`/`en`), or null if there is no clip.
  String? fileFor(String lang, String text) =>
      files[PercyClipKey.hash(lang, text)];
}

/// How a clip ended.
enum ClipResult {
  /// There is no clip for this sentence: speak it with the offline voice.
  notFound,

  /// Played to the end.
  finished,

  /// Stopped (push-to-talk, a new prompt): do not speak it another way.
  stopped,

  /// The clip could not be loaded, decoded or played: speak the sentence
  /// with the offline voice.
  failed,
}

/// Plays clip bytes. Abstract so tests can use a fake.
abstract interface class ClipPlayer {
  /// Plays the mp3 [bytes] at [rate] × normal speed (pitch kept).
  Future<ClipResult> play(Uint8List bytes, double rate);

  /// Stops what is playing at once.
  Future<void> stop();
}

/// [ClipPlayer] over `AudioBridge.kt` (`ph.bataan.percipere/audio`): the same
/// audio track, volume and audio focus as the offline voice.
class ChannelClipPlayer implements ClipPlayer {
  /// Creates the player.
  const ChannelClipPlayer();

  static const MethodChannel _channel = MethodChannel(
    'ph.bataan.percipere/audio',
  );

  @override
  Future<ClipResult> play(Uint8List bytes, double rate) async {
    try {
      final code = await _channel.invokeMethod<int>('playClip', {
        'bytes': bytes,
        'rate': rate,
      });
      return switch (code) {
        1 => ClipResult.finished,
        0 => ClipResult.stopped,
        _ => ClipResult.failed,
      };
    } on Object catch (e) {
      debugPrint('[PERCY VOICE] play failed: $e');
      return ClipResult.failed;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _channel.invokeMethod<bool>('playStop');
    } on Object catch (e) {
      debugPrint('[PERCY VOICE] stop failed: $e');
    }
  }
}

/// Loads the bytes of a clip file; null if it is missing.
typedef ClipLoader = Future<Uint8List?> Function(String file);

/// Bundled loader: `assets/percy/voice/<file>`.
Future<Uint8List?> loadClipAsset(String file) async {
  try {
    final data = await rootBundle.load('$percyClipFolder/$file');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } on Object catch (e) {
    debugPrint('[PERCY VOICE] clip $file missing: $e');
    return null;
  }
}

/// Asset folder of the clips and their manifest.
const String percyClipFolder = 'assets/percy/voice';

/// Plays Percy's bundled ElevenLabs clips for fixed sentences. The caller
/// speaks a sentence with the offline voice when [play] says [ClipResult.notFound]
/// or [ClipResult.failed], so a sentence is never silent.
class PercyClips {
  /// Creates the service.
  PercyClips({
    required this.manifest,
    required ClipPlayer this.player,
    this.load = loadClipAsset,
  });

  /// No clips; never plays anything.
  PercyClips.none()
    : manifest = PercyClipManifest.empty,
      player = null,
      load = loadClipAsset;

  /// The bundled clips.
  final PercyClipManifest manifest;

  /// Plays the bytes; null when there are no clips.
  final ClipPlayer? player;

  /// Loads a clip file.
  final ClipLoader load;

  /// Counts [stop] calls, so a stop that lands while a clip is loading keeps
  /// it from starting afterwards.
  int _stops = 0;
  bool _busy = false;

  /// Whether a clip is loading or playing.
  bool get busy => _busy;

  /// Whether [text] ([languageTag] like `fil-PH`) has a clip that can play.
  bool hasClip(String text, String languageTag) {
    if (player == null) return false;
    final lang = PercyClipKey.languageOf(languageTag);
    return lang != null && manifest.fileFor(lang, text) != null;
  }

  /// Plays the clip for [text] ([languageTag] like `fil-PH`) at [rate] × normal
  /// speed. Does nothing (and answers [ClipResult.notFound]) when there is no
  /// clip.
  Future<ClipResult> play(String text, String languageTag, double rate) async {
    final player = this.player;
    final lang = PercyClipKey.languageOf(languageTag);
    final file = lang == null ? null : manifest.fileFor(lang, text);
    if (player == null || file == null) return ClipResult.notFound;
    final stops = _stops;
    _busy = true;
    try {
      final bytes = await load(file);
      if (stops != _stops) return ClipResult.stopped;
      if (bytes == null || bytes.isEmpty) return ClipResult.failed;
      final result = await player.play(bytes, rate);
      if (result == ClipResult.failed) {
        debugPrint('[PERCY VOICE] clip $file failed: offline voice instead');
      }
      return result;
    } on Object catch (e) {
      debugPrint('[PERCY VOICE] clip $file failed: $e');
      return ClipResult.failed;
    } finally {
      if (stops == _stops) _busy = false;
    }
  }

  /// Stops the clip at once (push-to-talk, a new prompt).
  Future<void> stop() async {
    _stops++;
    final wasBusy = _busy;
    _busy = false;
    // Only when a clip is playing: the audio track is shared with the
    // offline voice, which stops itself.
    if (wasBusy) await player?.stop();
  }

  /// How many of [sentences] (language, text) have a clip.
  int countWithClips(Iterable<(String, String)> sentences) =>
      sentences.where((s) => manifest.fileFor(s.$1, s.$2) != null).length;
}

/// The bundled clips; no clips until [bootstrap] loads the manifest, so the
/// app works with an empty folder.
final percyClipsProvider = Provider<PercyClips>((ref) => PercyClips.none());

/// Reads the manifest from the assets (empty if it is missing or broken).
Future<PercyClipManifest> loadPercyClipManifest() async {
  try {
    return PercyClipManifest.parse(
      await rootBundle.loadString('$percyClipFolder/manifest.json'),
    );
  } on Object catch (e) {
    debugPrint('[PERCY VOICE] no manifest: $e');
    return PercyClipManifest.empty;
  }
}

/// "N of M": how many of Percy's fixed sentences have a clip.
@immutable
class PercyClipStats {
  /// Creates the numbers.
  const PercyClipStats(this.withClips, this.total);

  /// Fixed sentences with a clip.
  final int withClips;

  /// All fixed sentences (the ones without `{placeholders}`).
  final int total;
}

/// Counts the fixed sentences of `responses.json` + `persona.json` and how
/// many have a clip.
final percyClipStatsProvider = FutureProvider<PercyClipStats>((ref) async {
  final clips = ref.watch(percyClipsProvider);
  final responses = PercyResponses.parse(
    await rootBundle.loadString('assets/percy/persona.json'),
    await rootBundle.loadString('assets/percy/responses.json'),
  );
  final fixed = {
    ...responses.fixedSentences(),
    ...KnowledgeBase.parse(
      await rootBundle.loadString('assets/percy/knowledge.json'),
    ).fixedSentences(),
  };
  return PercyClipStats(clips.countWithClips(fixed), fixed.length);
});
