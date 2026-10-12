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
import '../tts/speech_language.dart';
import '../voice/understanding.dart';
import '../voice/voice_controller.dart';
import 'dialogue_manager.dart';
import 'intent_classifier.dart';
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
/// "paalam", any gesture or tap, or [PercyConfig.idleEnd] of silence.
class PercyController extends Notifier<PercyState> implements PercyEnvironment {
  DialogueManager? _manager;
  PercyBrain? _brain;
  Timer? _idle;
  bool _acting = false;

  @override
  PercyState build() {
    ref.onDispose(() => _idle?.cancel());
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
    debugPrint('[PERCY] session started');
    voice.percySessionChanged(active: true);
    unawaited(ref.read(hapticsProvider).confirm());
    _armIdle();
    if (firstUtterance != null && firstUtterance.trim().isNotEmpty) {
      return handle(firstUtterance);
    }
    final s = style;
    await _bus.say(brain.responses.greeting(s.lang, s.politeness));
  }

  /// Ends the session, saying [line] (default "tapos na ang usapan").
  Future<void> stop({String? line}) async {
    if (!state.active && !state.starting) return;
    _idle?.cancel();
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
    _armIdle();
    state = PercyState(active: true, heard: text);

    // Exact short commands keep using the app's phrase matcher.
    if (!manager.awaitingAnswer && !_bus.hasPendingQuestion) {
      final exact = _bus.exactCommand(text);
      if (exact != null) {
        debugPrint('[PERCY] "$text" → exact command');
        manager.remember(text, null);
        unawaited(_log(text, null, null, TurnOutcome.matcher));
        return _run(() => _bus.runTarget(exact));
      }
    }

    final s = style;
    final reply = await manager.handle(text, this, s);
    if (!ref.mounted || !state.active) return;
    unawaited(_log(text, reply.intent?.label, reply.confidence, reply.outcome));
    if (reply.say.isNotEmpty) await _bus.say(reply.say);
    // A gesture while Percy was speaking ended the session: do nothing more.
    if (!ref.mounted || !state.active) return;
    switch (reply.action) {
      case RunIntent(:final intent):
        await _run(() => _bus.dispatch(intent));
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
      await _bus.say(_brain!.responses.dialogue('more', s.lang, s.politeness));
    }
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

  void _armIdle() {
    _idle?.cancel();
    _idle = Timer(PercyConfig.idleEnd, () {
      if (!ref.mounted || !state.active) return;
      // Listening to a document read aloud is not silence.
      if (ref.read(announcerProvider).reading) return _armIdle();
      final s = style;
      unawaited(
        stop(
          line: _brain?.responses.dialogue('idle_end', s.lang, s.politeness),
        ),
      );
    });
  }

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
