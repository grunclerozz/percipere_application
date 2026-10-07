import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/voice_config.dart';
import '../tts/speech_language.dart';
import '../tts/tts_service.dart';
import 'action_registry.dart';
import 'navigation_mode.dart';

/// What the Speaking Zone shows: the sentence being spoken and whether
/// speech (or, from Phase 3, listening) is in progress.
@immutable
class SpeechState {
  /// Creates a speech state.
  const SpeechState({
    this.text,
    this.screenId,
    this.speaking = false,
    this.reading = false,
  });

  /// Sentence currently (or last) spoken.
  final String? text;

  /// Screen that was active when [text] was queued.
  final String? screenId;

  /// True while TTS is speaking.
  final bool speaking;

  /// True while the Reader is reading a document aloud (not a prompt). Voice
  /// input stays off meanwhile, so the app never hears itself.
  final bool reading;

  /// Returns a copy with [speaking] replaced.
  SpeechState withSpeaking(bool speaking) => SpeechState(
    text: text,
    screenId: screenId,
    speaking: speaking,
    reading: reading,
  );

  /// Returns a copy with [reading] replaced.
  SpeechState withReading(bool reading) => SpeechState(
    text: text,
    screenId: screenId,
    speaking: speaking,
    reading: reading,
  );
}

class _Utterance {
  _Utterance(
    this.text,
    this.screenId,
    this.languageTag,
    this.protect,
    this.rate,
  );

  final String text;
  final String? screenId;
  final String languageTag;
  final bool protect;
  final double rate;
  final Completer<void> done = Completer<void>();

  void complete() {
    if (!done.isCompleted) done.complete();
  }
}

/// Speaks prompts one sentence at a time and publishes each sentence as the
/// live subtitle.
///
/// - `interrupt: true` (default) drops anything queued and cuts off the
///   current sentence — unless it is `protect`ed (short confirmations), in
///   which case the new text waits for it.
/// - With TalkBack on, text goes to TalkBack as an announcement instead of
///   our own TTS, so the two never talk over each other.
class Announcer extends Notifier<SpeechState> {
  final Queue<_Utterance> _queue = Queue<_Utterance>();
  _Utterance? _current;
  bool _draining = false;

  @override
  SpeechState build() {
    ref.onDispose(() {
      for (final u in _queue) {
        u.complete();
      }
      _queue.clear();
      _current?.complete();
    });
    return const SpeechState();
  }

  /// Speaks [text]. Completes when its last sentence finishes (or is dropped).
  Future<void> say(
    String text, {
    bool interrupt = true,
    bool protect = false,
    String? screenId,
    String? languageTag,
    double rate = 1.0,
  }) {
    final sentences = splitSentences(text);
    if (sentences.isEmpty) return Future.value();

    final sid = screenId ?? ref.read(activeScreenProvider)?.id;
    final tag = languageTag ?? ref.read(speechLanguageProvider).ttsTag;
    // A prompt always takes over from document reading: the engine would
    // drop it while a document sentence is playing.
    if (state.reading) {
      state = state.withReading(false);
      unawaited(ref.read(ttsServiceProvider).stop());
    }
    if (interrupt) _interrupt();

    final group = [
      for (final s in sentences) _Utterance(s, sid, tag, protect, rate),
    ];
    _queue.addAll(group);
    unawaited(_drain());
    return group.last.done.future;
  }

  /// Marks document reading on/off (set by the Reader around its own TTS
  /// calls, which bypass this queue for sentence-level control).
  void setReading(bool reading) {
    if (ref.mounted && state.reading != reading) {
      state = state.withReading(reading);
    }
  }

  final List<(DateTime, String)> _readAloud = [];

  /// Records a document sentence the Reader is about to read aloud, so voice
  /// input can recognize the app's own voice (barge-in).
  void noteReadAloud(String sentence) {
    _readAloud.add((DateTime.now(), sentence));
    while (_readAloud.length > VoiceConfig.echoSentences) {
      _readAloud.removeAt(0);
    }
  }

  /// Sentences read aloud since [since], plus the one before it (it may
  /// still have been playing then).
  List<String> readAloudSince(DateTime since) {
    final start = _readAloud.indexWhere((e) => !e.$1.isBefore(since));
    final from = start < 0 ? _readAloud.length - 1 : math.max(0, start - 1);
    if (from < 0) return const [];
    return [for (final e in _readAloud.skip(from)) e.$2];
  }

  /// Completes once no prompt is being spoken or queued.
  Future<void> idle() async {
    while (ref.mounted && (_draining || _queue.isNotEmpty)) {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
  }

  /// Stops all speech, including protected sentences.
  Future<void> stop() async {
    _clearQueue();
    final reading = state.reading;
    if (reading) state = state.withReading(false);
    if (_current != null || reading) {
      await ref.read(ttsServiceProvider).stop();
    }
  }

  void _interrupt() {
    _clearQueue();
    final current = _current;
    if (current != null && !current.protect) {
      unawaited(ref.read(ttsServiceProvider).stop());
    }
  }

  void _clearQueue() {
    for (final u in _queue) {
      u.complete();
    }
    _queue.clear();
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_queue.isNotEmpty) {
        final u = _current = _queue.removeFirst();
        if (!ref.mounted) {
          u.complete();
          continue;
        }
        state = SpeechState(text: u.text, screenId: u.screenId, speaking: true);
        try {
          if (ref.read(talkBackProvider)) {
            await _announceToScreenReader(u.text);
          } else {
            await ref
                .read(ttsServiceProvider)
                .speak(u.text, languageTag: u.languageTag, rate: u.rate);
          }
        } on Object catch (e) {
          debugPrint('Speech failed: $e');
        }
        u.complete();
        _current = null;
      }
    } finally {
      _draining = false;
      if (ref.mounted) state = state.withSpeaking(false);
    }
  }

  Future<void> _announceToScreenReader(String text) async {
    final view = PlatformDispatcher.instance.implicitView;
    if (view == null) return;
    await SemanticsService.sendAnnouncement(view, text, TextDirection.ltr);
    // TalkBack gives no completion signal; pace the queue roughly.
    await Future<void>.delayed(Duration(milliseconds: 400 + text.length * 55));
  }

  /// Splits [text] into sentences (on `.`, `!`, `?`, `…` followed by space),
  /// keeping the punctuation.
  static List<String> splitSentences(String text) => text
      .split(RegExp(r'(?<=[.!?…])\s+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList(growable: false);
}

/// Speech output + live subtitle state.
final announcerProvider = NotifierProvider<Announcer, SpeechState>(
  Announcer.new,
);
