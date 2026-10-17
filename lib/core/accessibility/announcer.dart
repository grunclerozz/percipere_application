import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/voice_config.dart';
import '../assistant/assistant_controller.dart';
import '../percy/percy_clips.dart';
import '../tts/reading_rate.dart';
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
    this.rate, {
    this.clip = false,
  });

  final String text;
  final String? screenId;
  final String languageTag;
  final bool protect;
  final double rate;

  /// Played from Percy's bundled clip ([PercyClips]).
  final bool clip;
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
/// - [ask] speaks a question and then **stops**, so the user can answer.
///   What would have followed (how to answer, the mode hint, queued
///   notices) is spoken only if no answer comes within
///   [VoiceConfig.answerWait]; any answer or command drops it ([answered]).
class Announcer extends Notifier<SpeechState> {
  final Queue<_Utterance> _queue = Queue<_Utterance>();
  _Utterance? _current;
  bool _draining = false;

  /// Speech held back until the open question is answered or times out.
  final List<_Utterance> _afterAnswer = [];

  /// A question was asked and its follow-up is being held back.
  bool _holding = false;

  /// Screen the open question belongs to.
  String? _holdScreen;

  /// Bumped whenever a hold ends, so a late callback can tell it is stale.
  int _holdToken = 0;
  Timer? _answerTimer;

  @override
  SpeechState build() {
    ref.onDispose(() {
      for (final u in _queue) {
        u.complete();
      }
      _queue.clear();
      _current?.complete();
      _endHold(speak: false);
    });
    return const SpeechState();
  }

  /// Whether a question is waiting for the user's answer.
  bool get awaitingAnswer => _holding;

  /// Asks [question] and waits for the answer before saying anything else.
  ///
  /// [question] is spoken whole (it may carry context after the question
  /// mark, e.g. "Delete it? Its items stay."); [then] — how to answer, side
  /// notes — is held back. With [split], [question] is cut after its last
  /// question instead and the rest is held back too (for fixed texts like
  /// "Did you mean …? Say yes or no."). If the user hasn't answered (or
  /// done anything) within [VoiceConfig.answerWait] after the question
  /// ends, the held-back part is spoken. Speech queued meanwhile with
  /// `interrupt: false` waits too. Completes when the question itself has
  /// been spoken.
  Future<void> ask(
    String question, {
    String? then,
    bool split = false,
    bool interrupt = true,
    bool protect = false,
    String? screenId,
    String? languageTag,
  }) {
    final (asked, rest) = split ? splitAtQuestion(question) : (question, null);
    final follow = [?rest, ?then].where((s) => s.trim().isNotEmpty).join(' ');
    // A new question replaces an older one that is still open.
    _endHold(speak: false);
    final done = say(
      asked,
      interrupt: interrupt,
      protect: protect,
      screenId: screenId,
      languageTag: languageTag,
    );
    if (follow.isEmpty) return done;

    final sid = screenId ?? ref.read(activeScreenProvider)?.id;
    final tag = languageTag ?? ref.read(speechLanguageProvider).ttsTag;
    _holding = true;
    _holdScreen = sid;
    final token = ++_holdToken;
    _afterAnswer.addAll([
      for (final s in splitSentences(follow))
        _Utterance(s, sid, tag, false, ref.read(readingRateProvider)),
    ]);
    unawaited(
      done.then((_) {
        if (ref.mounted && token == _holdToken && _holding) _startAnswerWait();
      }),
    );
    return done;
  }

  /// The user answered or did something (command, gesture, tap): what was
  /// held back after the question is dropped.
  void answered() => _endHold(speak: false);

  /// The user has started speaking: give them the full wait again before
  /// any held-back instructions are spoken over them.
  void userResponding() {
    if (_answerTimer != null) _startAnswerWait();
  }

  void _startAnswerWait() {
    _answerTimer?.cancel();
    _answerTimer = Timer(VoiceConfig.answerWait, () {
      _answerTimer = null;
      if (!ref.mounted || !_holding) return;
      final stillHere =
          _holdScreen == null ||
          ref.read(activeScreenProvider)?.id == _holdScreen;
      _endHold(speak: stillHere);
    });
  }

  /// Ends the current hold: queues what was held back ([speak]) or drops it.
  void _endHold({required bool speak}) {
    _answerTimer?.cancel();
    _answerTimer = null;
    final held = List.of(_afterAnswer);
    _afterAnswer.clear();
    final wasHolding = _holding;
    _holding = false;
    _holdScreen = null;
    if (wasHolding) _holdToken++;
    if (speak && held.isNotEmpty) {
      _queue.addAll(held);
      unawaited(_drain());
    } else {
      for (final u in held) {
        u.complete();
      }
    }
  }

  /// Speaks [text]. Completes when its last sentence finishes (or is dropped).
  ///
  /// Everything is spoken with the app's one voice (the Reader's), except
  /// a line of Percy's ([percyVoice]) whose every sentence has a bundled
  /// clip: that line is played from the clips. A line is never mixed (some
  /// sentences in Percy's clip voice, others in the app's voice), and app
  /// prompts never use the clips (2026-10-17: the voice kept changing).
  Future<void> say(
    String text, {
    bool interrupt = true,
    bool protect = false,
    String? screenId,
    String? languageTag,
    double? rate,
    bool percyVoice = false,
  }) {
    final sentences = splitSentences(text);
    if (sentences.isEmpty) return Future.value();

    final sid = screenId ?? ref.read(activeScreenProvider)?.id;
    final tag = languageTag ?? ref.read(speechLanguageProvider).ttsTag;
    // Prompts and Percy follow the user's speech speed, like the reader.
    final double speed = rate ?? ref.read(readingRateProvider);
    final clips = ref.read(percyClipsProvider);
    final clip = percyVoice && sentences.every((s) => clips.hasClip(s, tag));
    // A prompt always takes over from document reading: the engine would
    // drop it while a document sentence is playing.
    if (state.reading) {
      state = state.withReading(false);
      unawaited(_stopSpeech());
    }
    if (interrupt) _interrupt();

    final group = [
      for (final s in sentences)
        _Utterance(s, sid, tag, protect, speed, clip: clip),
    ];
    if (!interrupt && _holding) {
      // A question is waiting for its answer: queued notices come after.
      _afterAnswer.addAll(group);
      return group.last.done.future;
    }
    _queue.addAll(group);
    unawaited(_drain());
    return group.last.done.future;
  }

  /// Shows [text] as the live subtitle without speaking it (what Percy, the
  /// voice assistant, and the user say).
  void showSubtitle(String text) {
    if (!ref.mounted) return;
    state = SpeechState(
      text: text,
      screenId: ref.read(activeScreenProvider)?.id,
      reading: state.reading,
    );
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
    _endHold(speak: false);
    _clearQueue();
    final reading = state.reading;
    if (reading) state = state.withReading(false);
    if (_current != null || reading) {
      await _stopSpeech();
    }
  }

  /// Stops all speech like [stop], then waits until the voice has really
  /// finished (the sentence being spoken has returned, at most [max]) and
  /// Android has released its audio focus ([focusGap]), so the microphone
  /// opened next hears the user and not the end of a prompt. Returns at
  /// once when nothing was speaking.
  Future<void> stopAndWait({
    Duration max = VoiceConfig.speechStopWait,
    Duration focusGap = VoiceConfig.audioFocusRelease,
  }) async {
    final wasSpeaking = _draining || _current != null || state.reading;
    await stop();
    if (!wasSpeaking || !ref.mounted) return;
    // TalkBack speaks prompts itself; only its pacing pause would be waited
    // for here.
    final talkBack = ref.read(talkBackProvider);
    final watch = Stopwatch()..start();
    while (ref.mounted && !talkBack && _draining && watch.elapsed < max) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    if (_draining && !talkBack) {
      debugPrint(
        '[VOICE] speech still finishing after ${watch.elapsedMilliseconds}ms: '
        'listening anyway',
      );
    }
    if (focusGap > Duration.zero) await Future<void>.delayed(focusGap);
  }

  /// Stops the voice and the Percy clip that is playing.
  Future<void> _stopSpeech() => Future.wait([
    ref.read(ttsServiceProvider).stop(),
    ref.read(percyClipsProvider).stop(),
  ]);

  void _interrupt() {
    _endHold(speak: false);
    _clearQueue();
    final current = _current;
    if (current != null && !current.protect) {
      unawaited(_stopSpeech());
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
        if (ref.read(assistantActiveProvider)) {
          // Percy is talking with the user: show the prompt, don't speak it
          // over Percy's voice.
          state = SpeechState(text: u.text, screenId: u.screenId);
          u.complete();
          _current = null;
          continue;
        }
        state = SpeechState(text: u.text, screenId: u.screenId, speaking: true);
        try {
          if (ref.read(talkBackProvider)) {
            await _announceToScreenReader(u.text);
          } else {
            // Percy's bundled clip for his lines that have one; otherwise
            // (or if the clip cannot play) the app's voice, so it is never
            // silent. Nothing of the clip carries over: the app's voice
            // sets its own speed and pitch for every utterance.
            final clip = u.clip
                ? await ref
                      .read(percyClipsProvider)
                      .play(u.text, u.languageTag, u.rate)
                : ClipResult.notFound;
            if (clip == ClipResult.notFound || clip == ClipResult.failed) {
              await ref
                  .read(ttsServiceProvider)
                  .speak(u.text, languageTag: u.languageTag, rate: u.rate);
            }
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

  /// Splits [text] after its last sentence that is a question: (the text up
  /// to and including that question, the rest or null). Text with no
  /// question, or ending in one, comes back whole.
  static (String, String?) splitAtQuestion(String text) {
    final sentences = splitSentences(text);
    final isQuestion = RegExp(r'\?["”’)\]]*$');
    final last = sentences.lastIndexWhere(isQuestion.hasMatch);
    if (last < 0 || last == sentences.length - 1) return (text, null);
    return (
      sentences.take(last + 1).join(' '),
      sentences.skip(last + 1).join(' '),
    );
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
