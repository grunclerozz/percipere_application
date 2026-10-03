import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ids.dart';
import '../../app/locale_provider.dart';
import '../../app/router.dart';
import '../../config/constants.dart';
import '../../l10n/app_localizations.dart';
import '../gestures/gesture_map.dart';
import '../platform/app_closer.dart';
import '../settings/app_settings.dart';
import '../settings/settings_controller.dart';
import '../tts/speech_language.dart';
import '../voice/command_matcher.dart';
import '../voice/voice_commands.dart';
import '../voice/voice_controller.dart';
import 'action_registry.dart';
import 'announcer.dart';
import 'focus_controller.dart';
import 'haptics.dart';
import 'nav_intent.dart';
import 'navigation_mode.dart';
import 'screen_registration.dart';

/// A question waiting for "oo/hindi" (or a double-tap): an ask-back
/// ("Ang ibig mo bang sabihin ay …?") or an offer ("…open Settings?").
class _Pending {
  _Pending(this.onYes)
    : expires = DateTime.now().add(AppDurations.pendingAnswer);

  final FutureOr<void> Function() onYes;
  final DateTime expires;

  bool get valid => DateTime.now().isBefore(expires);
}

/// The single entry point for user input. Gestures, voice commands and
/// visual taps all end up here, resolve against the active
/// [ScreenRegistration], and get audible (and haptic) feedback.
class CommandBus {
  /// Creates the bus.
  CommandBus(this._ref);

  final Ref _ref;
  final CommandMatcher _matcher = const CommandMatcher();
  _Pending? _pending;

  AppLocalizations get _l10n => _ref.read(speechLanguageProvider).strings;

  /// Prompt strings in the current speech language.
  AppLocalizations get strings => _l10n;
  Announcer get _announcer => _ref.read(announcerProvider.notifier);
  Haptics get _haptics => _ref.read(hapticsProvider);
  VoiceController get _voice => _ref.read(voiceControllerProvider.notifier);

  /// The active screen, if any.
  ScreenRegistration? get activeScreen => _ref.read(activeScreenProvider);

  /// Handles a recognized gesture.
  Future<void> onGesture(GestureType gesture) async {
    final intent = gestureMap[gesture];
    if (intent != null) await dispatch(intent);
  }

  /// Handles [intent] on the active screen: a pending question first (for
  /// [NavIntent.activate]), then the screen's override, then the default.
  Future<void> dispatch(NavIntent intent) async {
    _voice.noteActivity();
    final screen = activeScreen;
    if (screen == null) return;

    if (intent == NavIntent.activate) {
      final pending = _takePending();
      if (pending != null) {
        unawaited(_haptics.confirm());
        return pending.onYes();
      }
    }

    final override = screen.intentHandlers[intent];
    if (override != null) return override(this);

    switch (intent) {
      case NavIntent.next:
        return moveFocus(1);
      case NavIntent.previous:
        return moveFocus(-1);
      case NavIntent.activate:
        return activateFocused();
      case NavIntent.repeat:
        return announceScreen(screen);
      case NavIntent.back:
        return back();
      case NavIntent.stopSpeech:
        return stopSpeech();
      case NavIntent.help:
        return help(screen);
      case NavIntent.listen:
        return _voice.listenNow();
      case NavIntent.home:
        return _goHome();
      case NavIntent.camera:
      case NavIntent.capture:
        return _goAndActivate(
          AppRoutes.capture,
          Ids.capture,
          Ids.captureCamera,
        );
      case NavIntent.upload:
        return _goAndActivate(
          AppRoutes.capture,
          Ids.capture,
          Ids.captureUpload,
        );
      case NavIntent.voiceMode:
        return _setMode(NavMode.voice);
      case NavIntent.gestureMode:
        return _setMode(NavMode.gestures);
      case NavIntent.history:
        return _openScreen(AppRoutes.history, Ids.history);
      case NavIntent.settings:
        return _openScreen(AppRoutes.settings, Ids.settings);
      case NavIntent.report:
        unawaited(_haptics.error());
        return say(_l10n.featureNotReady);
      case NavIntent.faster:
      case NavIntent.slower:
      case NavIntent.textBigger:
      case NavIntent.textSmaller:
      case NavIntent.nextParagraph:
      case NavIntent.previousParagraph:
      case NavIntent.readFromStart:
      case NavIntent.read:
      case NavIntent.pause:
      case NavIntent.resume:
      case NavIntent.save:
        return notAvailable();
    }
  }

  // ── Voice ────────────────────────────────────────────────────────────────

  /// Handles a final speech recognition result.
  Future<void> handleUtterance(String heard) async {
    final text = _stripWakeWord(heard);
    if (text.isEmpty) return say(_l10n.voiceWakeReply);

    final pending = _takePending();
    if (pending != null) {
      final answer = _matcher.match(text, _yesNoPhrases);
      if (answer is Matched) {
        if (answer.target == const ValueTarget(true)) {
          unawaited(_haptics.confirm());
          return pending.onYes();
        }
        return say(_l10n.voiceCancelled);
      }
      // Not a yes/no: treat it as a new command.
    }

    final screen = activeScreen;
    final custom = screen?.onUtterance;
    if (custom != null && await custom(text, this)) return;
    switch (_matchCommand(text, screen)) {
      case Matched(:final target):
        return _run(target);
      case Ambiguous(:final target, :final phrase):
        _pending = _Pending(() => _run(target));
        return say(_l10n.voiceDidYouMean(phrase));
      case NoMatch():
        unawaited(_haptics.error());
        return say(_l10n.voiceUnknown(_commandSummary(screen)));
    }
  }

  /// Phrases the recognizer should expect on the active screen.
  List<String> expectedPhrases() => [
    for (final p in _screenPhrases(activeScreen)) p.phrase,
    for (final list in globalVoiceCommands.values) ...list,
    ...yesWords,
    ...noWords,
  ];

  /// Speaks [prompt] and lets the user accept with a double-tap or "oo"
  /// within [AppDurations.pendingAnswer].
  Future<void> offer(String prompt, FutureOr<void> Function() onAccept) {
    _pending = _Pending(onAccept);
    return say('$prompt ${_l10n.offerConfirmHint}');
  }

  _Pending? _takePending() {
    final p = _pending;
    _pending = null;
    return (p != null && p.valid) ? p : null;
  }

  MatchResult _matchCommand(String text, ScreenRegistration? screen) {
    // The screen's own actions win over app-wide commands.
    final local = _matcher.match(text, _screenPhrases(screen));
    if (local is Matched) return local;
    final global = _matcher.match(text, _globalPhrases);
    if (global is Matched) return global;
    if (local is Ambiguous) return local;
    return global;
  }

  Future<void> _run(CommandTarget target) async {
    switch (target) {
      case ActionTarget(:final actionId):
        return activate(actionId);
      case ValueTarget(:final value) when value is NavIntent:
        return dispatch(value);
      case ValueTarget():
        return;
    }
  }

  /// Action labels in both languages ("Pa-boses (Voice)" also yields
  /// "Pa-boses" and "Voice") plus each action's synonyms.
  List<CommandPhrase> _screenPhrases(ScreenRegistration? screen) {
    if (screen == null) return const [];
    final fil = lookupAppLocalizations(AppLocales.filipino);
    final en = lookupAppLocalizations(AppLocales.english);
    return [
      for (final a in screen.actions) ...[
        for (final label in {a.label(fil), a.label(en)})
          for (final part in _labelParts(label))
            CommandPhrase(part, ActionTarget(a.id)),
        for (final s in a.voiceSynonyms) CommandPhrase(s, ActionTarget(a.id)),
      ],
    ];
  }

  static Iterable<String> _labelParts(String label) sync* {
    yield label;
    final parts = label
        .split(RegExp('[()]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.length > 1) yield* parts;
  }

  static final List<CommandPhrase> _globalPhrases = [
    for (final e in globalVoiceCommands.entries)
      for (final phrase in e.value) CommandPhrase(phrase, ValueTarget(e.key)),
  ];

  static final List<CommandPhrase> _yesNoPhrases = [
    for (final w in yesWords) CommandPhrase(w, const ValueTarget(true)),
    for (final w in noWords) CommandPhrase(w, const ValueTarget(false)),
  ];

  static String _stripWakeWord(String heard) {
    final words = heard.trim().split(RegExp(r'\s+'));
    if (words.isEmpty) return '';
    final first = CommandMatcher.normalize(words.first);
    final isWake = wakeWords.any(
      (w) => CommandMatcher.similarity(first, w) >= 0.75,
    );
    return (isWake ? words.skip(1) : words).join(' ').trim();
  }

  /// "Mag-upload, Gamit ang Camera, susunod, nakaraan, …" for the unknown-
  /// command and help messages.
  String _commandSummary(ScreenRegistration? screen) {
    final l = _l10n;
    final labels = [
      // "Pa-boses (Voice)" is said as "Pa-boses".
      for (final a in screen?.focusables ?? const <A11yAction>[])
        a.label(l).split('(').first.trim(),
    ];
    return [...labels, l.voiceCommonCommands].join(', ');
  }

  // ── Default behaviors ────────────────────────────────────────────────────

  /// Moves focus and speaks the newly focused option ("Mag-upload, 1 sa 2").
  Future<void> moveFocus(int delta) async {
    final index = _ref.read(focusControllerProvider.notifier).move(delta);
    final screen = activeScreen;
    if (index == null || screen == null) return notAvailable();
    final items = screen.focusables;
    final l = _l10n;
    unawaited(_haptics.tick());
    await say(l.focusedItem(items[index].label(l), index + 1, items.length));
  }

  /// Activates the focused option, or explains how to pick one.
  Future<void> activateFocused() async {
    final id = _ref.read(focusControllerProvider);
    if (id == null) {
      unawaited(_haptics.error());
      return say(_l10n.nothingFocused);
    }
    return activate(id);
  }

  /// Runs [actionId] on the active screen with a confirmation pulse and a
  /// short, protected spoken confirmation. Visual taps call this too, so
  /// every path gives the same feedback.
  Future<void> activate(String actionId) async {
    _voice.noteActivity();
    final action = activeScreen?.action(actionId);
    if (action == null) return notAvailable();
    _ref.read(focusControllerProvider.notifier).focus(actionId);
    unawaited(_haptics.confirm());
    unawaited(say((action.confirmation ?? action.label)(_l10n), protect: true));
    await action.onActivate(this);
  }

  /// Speaks the entry announcement of [screen]. With [interrupt] false it
  /// queues behind whatever is being said.
  Future<void> announceScreen(
    ScreenRegistration screen, {
    bool interrupt = true,
  }) => _announcer.say(
    entryAnnouncement(screen, returning: _consumeReturning()),
    screenId: screen.id,
    interrupt: interrupt,
  );

  /// Builds "Title. Prompt. Options: A or B. Mode hint."
  String entryAnnouncement(
    ScreenRegistration screen, {
    bool returning = false,
  }) {
    final l = _l10n;
    final title = screen.title;
    final parts = <String>[
      if (title != null)
        returning ? l.backReturnedTo(title(l)) : _asSentence(title(l)),
      screen.prompt(l),
    ];
    final items = screen.focusables;
    if (screen.listOptions && items.isNotEmpty) {
      parts.add(l.optionsList(_joinOr([for (final a in items) a.label(l)], l)));
    }
    final verbosity = _ref.read(settingsProvider).verbosity;
    if (verbosity == Verbosity.brief) {
      // Name and question only.
      return parts.take(screen.title == null ? 1 : 2).join(' ');
    }
    if (screen.includeModeHint) parts.add(modeHint(l));
    if (verbosity == Verbosity.detailed) {
      parts.add((screen.help ?? (l) => l.helpGesturesMenu)(l));
    }
    return parts.join(' ');
  }

  /// The how-to-navigate hint for the current mode.
  String modeHint(AppLocalizations l) {
    if (_ref.read(talkBackProvider)) return l.modeHintTalkBack;
    return _ref.read(navigationModeProvider) == NavMode.voice
        ? l.modeHintVoice
        : l.modeHintGestures;
  }

  /// Goes back one screen (gesture, voice and Android back all land here).
  ///
  /// Unsaved input is confirmed first; the screen's `beforeBack` runs (the
  /// Reader stops and saves); the destination is announced as "Bumalik sa
  /// …". With nowhere to go back to, offers to close the app.
  Future<void> back() async {
    final screen = activeScreen;
    if (screen?.hasUnsavedInput?.call() ?? false) {
      unawaited(_haptics.error());
      return offer(_l10n.backUnsavedConfirm, () => _leave(screen));
    }
    return _leave(screen);
  }

  Future<void> _leave(ScreenRegistration? screen) async {
    await screen?.beforeBack?.call();
    final router = _ref.read(routerProvider);
    if (router.canPop()) {
      unawaited(_haptics.confirm());
      _returningAt = DateTime.now();
      router.pop();
    } else {
      unawaited(_haptics.error());
      await offer(
        '${_l10n.alreadyAtStart} ${_l10n.closeAppQuestion}',
        () => _ref.read(appCloserProvider)(),
      );
    }
  }

  /// Set when back pops a screen, so the next entry announcement says
  /// "Bumalik sa …" instead of just the screen name.
  DateTime? _returningAt;

  bool _consumeReturning() {
    final at = _returningAt;
    _returningAt = null;
    return at != null &&
        DateTime.now().difference(at) < const Duration(seconds: 3);
  }

  /// Silences all speech.
  Future<void> stopSpeech() => _announcer.stop();

  /// Speaks the help for [screen]; in voice mode also lists voice commands.
  Future<void> help(ScreenRegistration screen) {
    final l = _l10n;
    final title = screen.title;
    final parts = [
      if (title != null) l.helpTitle(title(l)),
      (screen.help ?? (l) => l.helpGesturesMenu)(l),
      if (_ref.read(navigationModeProvider) == NavMode.voice)
        l.helpVoiceCommands(_commandSummary(screen)),
    ];
    return say(parts.join(' '));
  }

  /// Error feedback for a command the screen doesn't support.
  Future<void> notAvailable() async {
    unawaited(_haptics.error());
    await say(_l10n.commandNotAvailable);
  }

  /// Speaks [text] in the prompt language.
  Future<void> say(String text, {bool protect = false, String? screenId}) =>
      _announcer.say(text, protect: protect, screenId: screenId);

  /// Opens a top-level screen (pushed, so "back" returns here).
  Future<void> _openScreen(String route, String screenId) async {
    if (activeScreen?.id == screenId) return announceScreen(activeScreen!);
    unawaited(_haptics.confirm());
    unawaited(_ref.read(routerProvider).push(route));
  }

  Future<void> _goHome() async {
    if (activeScreen?.id == Ids.capture) return announceScreen(activeScreen!);
    unawaited(_haptics.confirm());
    _ref.read(routerProvider).go(AppRoutes.capture);
  }

  /// Runs [actionId] on screen [screenId], navigating to [route] first if
  /// that screen isn't active.
  Future<void> _goAndActivate(
    String route,
    String screenId,
    String actionId,
  ) async {
    if (activeScreen?.id != screenId) {
      _ref.read(routerProvider).go(route);
      if (!await _awaitScreen(screenId)) return;
    }
    await activate(actionId);
  }

  Future<bool> _awaitScreen(String id) {
    if (activeScreen?.id == id) return Future.value(true);
    final done = Completer<bool>();
    final sub = _ref.listen(activeScreenProvider, (_, next) {
      if (next?.id == id && !done.isCompleted) done.complete(true);
    });
    return done.future
        .timeout(const Duration(seconds: 3), onTimeout: () => false)
        .whenComplete(sub.close);
  }

  Future<void> _setMode(NavMode mode) async {
    await _ref.read(navigationModeProvider.notifier).set(mode);
    unawaited(_haptics.confirm());
    if (mode == NavMode.voice) {
      await say(_l10n.modeChosenVoice, protect: true);
      await _voice.ensureReady(requestPermission: true);
    } else {
      await _voice.stopListening();
      await say(_l10n.modeChosenGestures, protect: true);
    }
  }

  static String _asSentence(String s) =>
      RegExp(r'[.!?…]$').hasMatch(s) ? s : '$s.';

  static String _joinOr(List<String> items, AppLocalizations l) {
    if (items.length <= 1) return items.join();
    final head = items.sublist(0, items.length - 1).join(', ');
    return '$head ${l.wordOr} ${items.last}';
  }
}

/// The app's command bus.
final commandBusProvider = Provider<CommandBus>((ref) => CommandBus(ref));
