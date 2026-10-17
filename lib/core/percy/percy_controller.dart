import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/locale_provider.dart';
import '../../config/percy_config.dart';
import '../../features/library/library_actions.dart';
import '../accessibility/announcer.dart';
import '../accessibility/command_bus.dart';
import '../accessibility/haptics.dart';
import '../accessibility/nav_intent.dart';
import '../auth/session.dart';
import '../db/daos/library_dao.dart';
import '../db/daos/percy_log_dao.dart';
import '../library/library_models.dart';
import '../settings/settings_controller.dart';
import '../tts/language_detector.dart';
import '../tts/speech_language.dart';
import '../voice/command_matcher.dart';
import '../voice/understanding.dart';
import '../voice/voice_controller.dart';
import 'dialogue_manager.dart';
import 'intent_classifier.dart';
import 'percy_analysis.dart';
import 'percy_responses.dart';

/// Percy's model and lines, loaded once.
@immutable
class PercyBrain {
  /// Creates a brain.
  const PercyBrain(this.model, this.responses);

  /// The intent classifier.
  final IntentModel model;

  /// Persona and response templates.
  final PercyResponses responses;
}

/// Loads the bundled model (parsed off the UI isolate) and the lines.
final percyBrainProvider = FutureProvider<PercyBrain>((ref) async {
  final watch = Stopwatch()..start();
  final source = await rootBundle.loadString(PercyConfig.modelAsset);
  final model = await compute(IntentClassifier.parse, source);
  final responses = PercyResponses.parse(
    await rootBundle.loadString(PercyConfig.personaAsset),
    await rootBundle.loadString(PercyConfig.responsesAsset),
  );
  debugPrint(
    '[PERCY] model ${model.version} (${model.type}) loaded in '
    '${watch.elapsedMilliseconds} ms',
  );
  return PercyBrain(model, responses);
});

/// How long Percy waits in silence: [reprompt] before asking once more,
/// then [end] before saying goodbye. Overridden with short values in tests.
@immutable
class PercySilence {
  /// Creates the timings.
  const PercySilence({
    this.reprompt = PercyConfig.silenceReprompt,
    this.end = PercyConfig.silenceEnd,
  });

  /// Silence before "Nandito pa ako. Ano ang maitutulong ko?".
  final Duration reprompt;

  /// Silence after that before the goodbye.
  final Duration end;
}

/// Percy's silence timings.
final percySilenceProvider = Provider<PercySilence>(
  (ref) => const PercySilence(),
);

/// Percy's session state.
@immutable
class PercyState {
  /// Creates a state.
  const PercyState({this.active = false, this.starting = false, this.heard});

  /// A session is running: what the user says goes to Percy.
  final bool active;

  /// The model is loading.
  final bool starting;

  /// What the user said last.
  final String? heard;
}

/// Percy, the self-built voice assistant (Phase 9): a voice session on the
/// app's own speech recognition and TTS. Each sentence goes through the
/// existing phrase matcher (exact short commands) or the [DialogueManager]
/// (intent classifier → slots → dialogue); every action runs through the
/// [CommandBus]. Started by two-finger swipe left or "Percy"; ended by
/// "paalam", by the user's own gesture or tap (except long-press, single
/// tap and two-finger double tap, which belong to the conversation), or by
/// silence: after [PercySilence.reprompt] Percy asks once more, after
/// [PercySilence.end] more it says a short goodbye.
class PercyController extends Notifier<PercyState> implements PercyEnvironment {
  DialogueManager? _manager;
  PercyBrain? _brain;
  Timer? _silence;
  bool _acting = false;

  /// Percy has already asked "Nandito pa ako…" in this silence.
  bool _reprompted = false;

  /// A sentence is being handled (not silence).
  bool _turn = false;

  /// Bumped when the user takes over (hold to listen) while a turn is being
  /// worked out, so its reply is neither spoken nor acted on.
  int _turnToken = 0;

  /// What Percy said last (a single tap repeats it).
  String? _lastLine;

  @override
  PercyState build() {
    ref
      ..onDispose(() => _silence?.cancel())
      ..listen(announcerProvider, (previous, next) {
        if (!state.active) return;
        if (next.speaking || next.reading) {
          // Talking or reading aloud is not silence.
          _silence?.cancel();
        } else if ((previous?.speaking ?? false) ||
            (previous?.reading ?? false)) {
          // Silence is counted from when the app stops talking.
          _armSilence();
        }
      });
    return const PercyState();
  }

  CommandBus get _bus => ref.read(commandBusProvider);

  /// Whether Percy itself is running an action right now (its commands
  /// must not end the session the way a user's gesture or tap does).
  bool get acting => _acting;

  /// The current speaking style (language, politeness, talkativeness).
  PercyStyle get style {
    final settings = ref.read(settingsProvider);
    final english =
        ref.read(speechLanguageProvider).locale == AppLocales.english;
    return PercyStyle(
      lang: english ? 'en' : 'fil',
      politeness: settings.percyPoliteness,
      talk: settings.percyTalk,
    );
  }

  /// Starts a session, or ends the running one.
  Future<void> toggle() => state.active ? stop() : start();

  /// Starts a session: greets, or handles [firstUtterance] at once
  /// ("Percy, buksan ang library").
  Future<void> start({String? firstUtterance}) async {
    if (state.active || state.starting) return;
    final l = ref.read(speechLanguageProvider).strings;
    state = const PercyState(starting: true);
    final voice = ref.read(voiceControllerProvider.notifier);
    var micReady = voice.micGranted;
    if (!micReady) {
      try {
        micReady = await voice.ensureReady(requestPermission: true);
      } on Object catch (e) {
        debugPrint('[PERCY] microphone: $e');
      }
    }
    if (!ref.mounted) return;
    if (!micReady) {
      state = const PercyState();
      unawaited(ref.read(hapticsProvider).error());
      return _bus.say(l.percyMicNeeded);
    }
    try {
      _brain = await ref.read(percyBrainProvider.future);
    } on Object catch (e, stack) {
      debugPrint('[PERCY] model failed to load: $e\n$stack');
      if (!ref.mounted) return;
      // Try loading again next time instead of keeping the error.
      ref.invalidate(percyBrainProvider);
      state = const PercyState();
      unawaited(ref.read(hapticsProvider).error());
      return _bus.say(l.percyUnavailable);
    }
    if (!ref.mounted) return;
    final brain = _brain!;
    _manager = DialogueManager(model: brain.model, responses: brain.responses);
    state = const PercyState(active: true);
    _reprompted = false;
    _lastLine = null;
    debugPrint('[PERCY] session started');
    voice.percySessionChanged(active: true);
    unawaited(ref.read(hapticsProvider).confirm());
    _armSilence();
    if (firstUtterance != null && firstUtterance.trim().isNotEmpty) {
      return handle(firstUtterance);
    }
    final s = style;
    await _say(brain.responses.greeting(s.lang, s.politeness));
  }

  /// The user held the gesture area to speak: whatever Percy was still
  /// working out for the last sentence is dropped.
  void interruptTurn() {
    if (!_turn || _acting) return;
    _turnToken++;
  }

  /// Ends the session, saying [line] (default: a short goodbye).
  Future<void> stop({String? line}) async {
    if (!state.active && !state.starting) return;
    _silence?.cancel();
    _reprompted = false;
    _turn = false;
    state = const PercyState();
    _manager?.reset();
    debugPrint('[PERCY] session ended');
    ref
        .read(voiceControllerProvider.notifier)
        .percySessionChanged(active: false);
    final brain = _brain;
    if (line != null && line.isEmpty) return;
    final s = style;
    await _bus.say(
      line ?? brain?.responses.dialogue('ended', s.lang, s.politeness) ?? '',
    );
  }

  /// Handles one sentence the user said during the session.
  Future<void> handle(String heard) async {
    final manager = _manager;
    if (!state.active || manager == null) return;
    final text = heard.trim();
    if (text.isEmpty) return;
    _silence?.cancel();
    _reprompted = false;
    _turn = true;
    final token = _turnToken;
    state = PercyState(active: true, heard: text);
    try {
      await _handleTurn(manager, text, token);
    } finally {
      _turn = false;
      if (ref.mounted && state.active) _armSilence();
    }
  }

  Future<void> _handleTurn(
    DialogueManager manager,
    String text,
    int token,
  ) async {
    // Exact short commands keep using the app's phrase matcher.
    if (!manager.awaitingAnswer && !_bus.hasPendingQuestion) {
      final exact = _bus.exactCommand(text);
      if (exact != null) {
        debugPrint('[PERCY] "$text" → exact command');
        manager.remember(text, null);
        unawaited(_log(text, null, null, TurnOutcome.matcher));
        _analyze(text, null, 'exact:${_targetName(exact)}');
        return _run(() => _bus.runTarget(exact));
      }
    }

    final s = style;
    final reply = await manager.handle(text, this, s);
    if (!ref.mounted || !state.active || token != _turnToken) return;
    unawaited(_log(text, reply.intent?.label, reply.confidence, reply.outcome));
    _analyze(
      text,
      manager.lastPrediction,
      _actionName(reply),
      intent: reply.intent?.label,
      confidence: reply.confidence,
    );
    if (reply.say.isNotEmpty) await _say(reply.say);
    // A gesture while Percy was speaking ended the session, or a hold to
    // listen took over: do nothing more.
    if (!ref.mounted || !state.active || token != _turnToken) return;
    switch (reply.action) {
      case RunIntent(:final intent):
        await _run(() => _bus.dispatch(intent));
      case RunAction(:final actionId):
        await _run(() => _bus.activate(actionId));
      case SetSpeed(:final speed):
        await _run(() => _bus.setReadingSpeed(speed));
      case OpenDocument(:final item, :final play):
        await _run(
          () => ref.read(libraryActionsProvider).open(item, play: play),
        );
      case AnswerApp(:final yes):
        await _run(() => _bus.answerPending(yes: yes));
      case TellWhereAmI():
        await _run(() => _bus.answer(Question.whereAmI));
      case EndSession():
        return stop(line: '');
      case null:
        break;
    }
    if (s.talk == PercyTalk.chatty &&
        reply.outcome == TurnOutcome.chat &&
        state.active) {
      await _say(_brain!.responses.dialogue('more', s.lang, s.politeness));
    }
  }

  /// A reading command heard while a document is read aloud during the
  /// session (barge-in): it runs as Percy's own, so it doesn't end the
  /// session the way the user's gesture does.
  Future<void> runReadingCommand(NavIntent intent) async {
    if (!state.active) return _bus.dispatch(intent);
    // "Percy" heard over the reading: the session is already running.
    if (intent == NavIntent.assistant) return;
    _reprompted = false;
    await _run(() => _bus.dispatch(intent));
    if (ref.mounted && state.active) _armSilence();
  }

  /// Single tap during the session: Percy says its last line again.
  Future<void> repeatLast() async {
    if (!state.active) return;
    _reprompted = false;
    final s = style;
    final line =
        _lastLine ?? _brain?.responses.greeting(s.lang, s.politeness) ?? '';
    if (line.isNotEmpty) await _say(line);
  }

  Future<void> _say(String line) {
    _lastLine = line;
    return _bus.say(line);
  }

  Future<void> _run(Future<void> Function() action) async {
    _acting = true;
    try {
      await action();
    } on Object catch (e, stack) {
      debugPrint('[PERCY] action failed: $e\n$stack');
    } finally {
      _acting = false;
    }
  }

  /// Starts counting silence afresh: [PercySilence.reprompt] before the
  /// reminder, or [PercySilence.end] once it has been said.
  void _armSilence() {
    _silence?.cancel();
    if (!state.active) return;
    final timing = ref.read(percySilenceProvider);
    _silence = Timer(
      _reprompted ? timing.end : timing.reprompt,
      () => unawaited(
        _onSilence().catchError((Object e, StackTrace stack) {
          debugPrint('[PERCY] silence handling failed: $e\n$stack');
        }),
      ),
    );
  }

  Future<void> _onSilence() async {
    if (!ref.mounted || !state.active) return;
    // Not silence: the app is talking or reading, Percy is busy, or the
    // user has started a sentence. Count again from now.
    final speech = ref.read(announcerProvider);
    final partial = ref.read(voiceControllerProvider).partial;
    if (speech.speaking ||
        speech.reading ||
        _acting ||
        _turn ||
        (partial != null && partial.trim().isNotEmpty)) {
      return _armSilence();
    }
    final s = style;
    final responses = _brain?.responses;
    if (!_reprompted) {
      _reprompted = true;
      debugPrint('[PERCY] silence: asking once more');
      await _say(responses?.dialogue('reprompt', s.lang, s.politeness) ?? '');
      if (!ref.mounted || !state.active) return;
      // Listening may have stopped meanwhile (repeated recognizer errors):
      // open it again for the answer.
      ref.read(voiceControllerProvider.notifier).percyListenAgain();
      _armSilence();
      return;
    }
    debugPrint('[PERCY] silence after the reminder: ending the session');
    await stop(line: responses?.dialogue('idle_end', s.lang, s.politeness));
  }

  /// Records [text] for the analysis panel (developer setting).
  void _analyze(
    String text,
    IntentPrediction? prediction,
    String action, {
    String? intent,
    double? confidence,
  }) {
    if (!ref.read(percyAnalysisOnProvider)) return;
    try {
      final p = prediction ?? _brain?.model.predict(text);
      final hidden = ref.read(voiceControllerProvider.notifier).sensitive;
      ref
          .read(percyAnalysisProvider.notifier)
          .add(
            PercyAnalysisEntry(
              heard: hidden ? '•••' : text,
              language: detectLanguage(hidden ? '' : text),
              intent: intent,
              confidence: confidence,
              top: p?.topN(3) ?? const [],
              action: action,
              at: DateTime.now(),
            ),
          );
    } on Object catch (e) {
      debugPrint('[PERCY] analysis failed: $e');
    }
  }

  static String _targetName(CommandTarget target) => switch (target) {
    ActionTarget(:final actionId) => actionId,
    ValueTarget(:final value) => value is NavIntent ? value.name : '$value',
  };

  static String _actionName(PercyReply reply) => switch (reply.action) {
    RunIntent(:final intent) => 'run:${intent.name}',
    RunAction(:final actionId) => 'action:$actionId',
    SetSpeed(:final speed) => 'speed:${speed.name}',
    OpenDocument(:final item, :final play) =>
      '${play ? 'play' : 'open'}:${item.title}',
    AnswerApp(:final yes) => 'answer:${yes ? 'yes' : 'no'}',
    TellWhereAmI() => 'where_am_i',
    EndSession() => 'end_session',
    null => reply.outcome.name,
  };

  Future<void> _log(
    String text,
    String? intent,
    double? confidence,
    TurnOutcome outcome,
  ) async {
    if (!ref.read(settingsProvider).percyLogging) return;
    try {
      await ref
          .read(percyLogDaoProvider)
          .insert(
            PercyLogEntry(
              userId: ref.read(currentAccountProvider)?.id,
              text: text,
              intent: intent,
              confidence: confidence,
              outcome: outcome.name,
              screen: screenId,
              modelVersion: _brain?.model.version,
              at: DateTime.now(),
            ),
          );
    } on Object catch (e) {
      debugPrint('[PERCY] log failed: $e');
    }
  }

  // ── PercyEnvironment ───────────────────────────────────────────────────

  @override
  String? get screenId => _bus.activeScreen?.id;

  @override
  bool get appQuestionPending => _bus.hasPendingQuestion;

  @override
  bool supports(NavIntent intent) => _bus.supports(intent);

  @override
  bool supportsAction(String actionId) => _bus.activeScreen?.action(actionId) != null;

  @override
  Future<List<LibraryItem>> libraryItems() async {
    final account = ref.read(currentAccountProvider);
    if (account == null) return const [];
    try {
      return await ref.read(libraryDaoProvider).list(account.id);
    } on Object catch (e) {
      debugPrint('[PERCY] library lookup failed: $e');
      return const [];
    }
  }
}

/// Percy, the self-built voice assistant.
final percyControllerProvider = NotifierProvider<PercyController, PercyState>(
  PercyController.new,
);

/// Whether a Percy session is running.
final percyActiveProvider = Provider<bool>(
  (ref) => ref.watch(percyControllerProvider.select((s) => s.active)),
);
