import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../../app/ids.dart';
import '../../app/locale_provider.dart';
import '../../app/router.dart';
import '../../config/constants.dart';
import '../../config/percy_config.dart';
import '../../config/voice_config.dart';
import '../../features/library/library_actions.dart';
import '../../l10n/app_localizations.dart';
import '../assistant/assistant_config.dart';
import '../assistant/assistant_controller.dart';
import '../auth/session.dart';
import '../db/daos/library_dao.dart';
import '../gestures/gesture_map.dart';
import '../library/library_models.dart';
import '../library/library_view.dart';
import '../percy/percy_controller.dart';
import '../percy/percy_text.dart';
import '../platform/app_closer.dart';
import '../settings/app_settings.dart';
import '../settings/settings_controller.dart';
import '../tts/reading_rate.dart';
import '../tts/speech_language.dart';
import '../voice/command_matcher.dart';
import '../voice/understanding.dart';
import '../voice/voice_commands.dart';
import '../voice/voice_controller.dart';
import 'action_registry.dart';
import 'announcer.dart';
import 'familiarity.dart';
import 'focus_controller.dart';
import 'haptics.dart';
import 'nav_intent.dart';
import 'navigation_mode.dart';
import 'screen_registration.dart';

/// A question waiting for "oo/hindi" (or a double-tap): an ask-back
/// ("Ang ibig mo bang sabihin ay …?") or an offer ("…open Settings?").
class _Pending {
  _Pending(this.onYes, [this.onNo])
    // The instructions after the question come only after the answer wait,
    // so that wait doesn't eat into the time to answer.
    : expires = DateTime.now().add(
        AppDurations.pendingAnswer + VoiceConfig.answerWait,
      );

  final FutureOr<void> Function() onYes;
  final FutureOr<void> Function()? onNo;
  final DateTime expires;

  bool get valid => DateTime.now().isBefore(expires);
}

/// "Alin sa dalawa: A, o B?" — waiting for the user to name one.
class _Choices {
  _Choices(this.options) : expires = DateTime.now().add(VoiceConfig.choiceWait);

  final List<({String label, Future<void> Function() run})> options;
  final DateTime expires;

  bool get valid => DateTime.now().isBefore(expires);
}

/// A partial speech result that already reads as a whole command.
class PartialMatch {
  /// Creates a partial match.
  const PartialMatch(this.target, this.score);

  /// What it would run.
  final CommandTarget target;

  /// Similarity of the whole partial result to the command, 0..1.
  final double score;
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
  _Choices? _choices;

  /// Voice commands misunderstood in a row (reset by any understood one).
  int _misses = 0;

  /// The user seems stuck: announcements give full help again.
  bool get struggling => _misses >= 2;

  AppLocalizations get _l10n => _ref.read(speechLanguageProvider).strings;

  /// Prompt strings in the current speech language.
  AppLocalizations get strings => _l10n;
  Announcer get _announcer => _ref.read(announcerProvider.notifier);
  Haptics get _haptics => _ref.read(hapticsProvider);
  VoiceController get _voice => _ref.read(voiceControllerProvider.notifier);
  AssistantController get _assistant =>
      _ref.read(assistantControllerProvider.notifier);

  /// While Percy is talking with the user, any gesture, tap or command of
  /// the user's own ends the conversation (and does nothing else), so the
  /// user can always take back control. Percy's own tools don't count.
  Future<bool> _userEndsAssistant() async {
    if (!_ref.read(assistantActiveProvider) || _assistant.runningTool) {
      return false;
    }
    await _assistant.stop();
    return true;
  }

  PercyController get _percy => _ref.read(percyControllerProvider.notifier);

  /// While a Percy session runs, a gesture or tap of the user's own ends it
  /// (and does nothing else); Percy's own actions don't count.
  Future<bool> _userEndsPercy() async {
    if (!_ref.read(percyActiveProvider) || _percy.acting) return false;
    await _percy.stop();
    return true;
  }

  /// During a Percy session, the gestures that belong to talking with Percy
  /// keep it going instead of ending it (2026-10-13: long-press to speak
  /// used to end the session at once): long-press listens now, a single
  /// tap repeats Percy's last line, two-finger double tap stops the speech.
  Future<bool> _keepsPercy(NavIntent intent) async {
    if (!_ref.read(percyActiveProvider) || _percy.acting) return false;
    switch (intent) {
      case NavIntent.listen:
        await _voice.listenNow();
        return true;
      case NavIntent.repeat:
        await _percy.repeatLast();
        return true;
      case NavIntent.stopSpeech:
        await stopSpeech();
        return true;
      default:
        return false;
    }
  }

  /// Two-finger swipe left / "Percy": the self-built Percy, or the online
  /// ElevenLabs one when the developer setting is on.
  Future<void> _toggleAssistant() => _ref.read(elevenLabsActiveProvider)
      ? _assistant.toggle()
      : _percy.toggle();

  // ── For Percy ────────────────────────────────────────────────────────────

  /// Whether the app asked a yes/no question that is still open.
  bool get hasPendingQuestion => _pending?.valid ?? false;

  /// Answers the app's open yes/no question (Percy heard the answer).
  Future<void> answerPending({required bool yes}) async {
    final pending = _takePending();
    if (pending == null) return;
    if (yes) {
      unawaited(_haptics.confirm());
      return pending.onYes();
    }
    final onNo = pending.onNo;
    if (onNo != null) return onNo();
    return say(_l10n.voiceCancelled);
  }

  /// The command [heard] names exactly ("bilisan", "i-pause", "home"), if
  /// it is a short known command (at most [PercyConfig.exactCommandWords]
  /// words): Percy runs these with the phrase matcher, not the classifier.
  CommandTarget? exactCommand(String heard) {
    final text = Understanding.clean(_stripWakeWord(heard));
    final words = CommandMatcher.tokens(text);
    if (words.isEmpty || words.length > PercyConfig.exactCommandWords) {
      return null;
    }
    final result = _matchCommand(text, activeScreen);
    if (result is! Matched || result.score < 1) return null;
    if (CommandMatcher.tokens(result.phrase).length != words.length) {
      return null;
    }
    // "Percy" during a session is not a command to end it.
    if (result.target == const ValueTarget(NavIntent.assistant)) return null;
    return result.target;
  }

  /// Runs a matched command (as if it had been said).
  Future<void> runTarget(CommandTarget target) => _run(target);

  /// Sets one of the three named reading-speed presets used during setup.
  ///
  /// The value is saved in the existing profile setting and the confirmation
  /// is spoken at the newly selected speed.
  Future<void> setReadingSpeed(SpeechSpeed speed) async {
    await _ref
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(readingRate: speed.rate));
    final l = _l10n;
    final name = switch (speed) {
      SpeechSpeed.slow => l.speedSlow,
      SpeechSpeed.medium => l.speedMedium,
      SpeechSpeed.fast => l.speedFast,
    };
    unawaited(_haptics.confirm());
    await say(l.setupSpeedChosen(name), protect: true);
  }

  /// App commands that do something only where a screen handles them.
  static const Set<NavIntent> _screenOnly = {
    NavIntent.faster,
    NavIntent.slower,
    NavIntent.textBigger,
    NavIntent.textSmaller,
    NavIntent.nextParagraph,
    NavIntent.previousParagraph,
    NavIntent.readFromStart,
    NavIntent.read,
    NavIntent.pause,
    NavIntent.resume,
    NavIntent.save,
    NavIntent.nextChapter,
    NavIntent.previousChapter,
    NavIntent.favorite,
    NavIntent.favorites,
  };

  /// Whether [intent] does something on the active screen.
  bool supports(NavIntent intent) {
    final screen = activeScreen;
    if (screen == null) return false;
    if (screen.intentHandlers.containsKey(intent)) return true;
    return !_screenOnly.contains(intent);
  }

  /// "Percy, buksan ang library" said while Percy is off: the rest after
  /// the wake word, or null.
  static String? _percyRequest(String heard) {
    final words = heard.trim().split(RegExp(r'\s+'));
    var i = 0;
    if (words.length > 1 && PercyText.preprocess(words[0]) == 'hey') i = 1;
    if (i >= words.length) return null;
    final first = words[i].toLowerCase().replaceAll(RegExp('[^a-z]'), '');
    if (!PercyText.wakeWords.contains(first)) return null;
    final rest = words.skip(i + 1).join(' ').trim();
    return rest.isEmpty ? null : rest;
  }

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
    final claimsAssistant =
        activeScreen?.intentHandlers.containsKey(NavIntent.assistant) ?? false;
    if (intent == NavIntent.assistant && !claimsAssistant) {
      _announcer.answered();
      return _toggleAssistant();
    }
    if (await _userEndsAssistant()) return;
    if (await _keepsPercy(intent)) return;
    if (await _userEndsPercy()) return;
    _announcer.answered();
    _voice
      ..noteActivity()
      ..commandExecuted(intent.name);
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
        return announceScreen(screen, full: true);
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
      case NavIntent.library:
        return _openLibrary();
      case NavIntent.settings:
        return _openScreen(AppRoutes.settings, Ids.settings);
      case NavIntent.report:
        return _openReport();
      case NavIntent.describe:
        return _goAndActivate(
          AppRoutes.capture,
          Ids.capture,
          Ids.captureDescribe,
        );
      case NavIntent.tutorial:
        return answer(Question.tutorial);
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
      case NavIntent.nextChapter:
      case NavIntent.previousChapter:
      case NavIntent.favorite:
      case NavIntent.favorites:
        return notAvailable();
      case NavIntent.assistant:
        return _toggleAssistant();
    }
  }

  // ── Voice ────────────────────────────────────────────────────────────────

  /// Handles a final speech recognition result.
  ///
  /// Order: a pending choice or yes/no answer, the screen's own free-text
  /// commands, questions the app answers from its state ("nasaan ako?"),
  /// documents named from anywhere ("basahin ang Liham"), then the phrase
  /// matcher. Everyday phrasing is cleaned first ([Understanding.clean]).
  Future<void> handleUtterance(String heard) async {
    if (await _userEndsAssistant()) return;
    _announcer.answered();
    // A Percy session gets everything that is said.
    if (_ref.read(percyActiveProvider)) return _percy.handle(heard);
    final request = _percyRequest(heard);
    if (request != null && !_ref.read(elevenLabsActiveProvider)) {
      _voice.markMatched('Percy + request', done: true);
      return _percy.start(firstUtterance: request);
    }
    final text = _stripWakeWord(heard);
    if (text.isEmpty) return say(_l10n.voiceWakeReply);
    final cleaned = Understanding.clean(text);

    final choices = _takeChoices();
    if (choices != null) {
      final picked = _pickChoice(text, choices);
      if (picked != null) {
        _understood('choice "${picked.label}"');
        unawaited(_haptics.confirm());
        return picked.run();
      }
      // Not one of them: treat it as a new command.
    }

    final pending = _takePending();
    if (pending != null) {
      final answer = _matcher.match(cleaned, _yesNoPhrases);
      if (answer is Matched) {
        _misses = 0;
        _voice.markMatched(answer.phrase);
        if (answer.target == const ValueTarget(true)) {
          unawaited(_haptics.confirm());
          return pending.onYes();
        }
        final onNo = pending.onNo;
        if (onNo != null) return onNo();
        return say(_l10n.voiceCancelled);
      }
      // Not a yes/no: treat it as a new command.
    }

    final screen = activeScreen;
    final custom = screen?.onUtterance;
    if (custom != null) {
      final handled =
          await custom(text, this) ||
          (cleaned != CommandMatcher.normalize(text) &&
              await custom(cleaned, this));
      if (handled) {
        _understood('screen command');
        return;
      }
    }

    final question = Understanding.question(text);
    if (question != null) {
      _understood('question ${question.name}');
      return answer(question);
    }

    if (await _openByTitle(text, cleaned, screen)) return;

    switch (_matchCommand(cleaned, screen)) {
      case Matched(:final target, :final phrase):
        _misses = 0;
        _voice.markMatched(phrase);
        return _run(target);
      case Ambiguous(:final target, :final phrase):
        _misses = 0;
        _voice.markMatched('unsure: "$phrase"', done: true);
        _pending = _Pending(() => _run(target));
        return ask(_l10n.voiceDidYouMean(phrase), split: true);
      case NoMatch():
        if (Understanding.documentQuestion(text) != null) {
          _understood('document question outside the Reader');
          return say(_l10n.docNeedsOpenDoc);
        }
        _voice.markMatched('no command', done: true);
        return _notUnderstood(cleaned, screen);
    }
  }

  void _understood(String what) {
    _misses = 0;
    _voice.markMatched(what, done: true);
  }

  /// No command fits: suggest the closest ones on this screen; after a few
  /// misses in a row, offer the tutorial.
  Future<void> _notUnderstood(String cleaned, ScreenRegistration? screen) {
    _misses++;
    unawaited(_haptics.error());
    final l = _l10n;
    final options = _closestActions(cleaned, screen);
    var message = options.isEmpty
        ? l.voiceNotUnderstood
        : l.voiceSuggest(_joinOr(options, l));
    if (_misses >= VoiceConfig.missesBeforeHelp) {
      message = '$message ${l.voiceOfferHelp}';
    }
    return say(message);
  }

  /// Labels of up to three screen actions that sound most like [cleaned].
  List<String> _closestActions(String cleaned, ScreenRegistration? screen) {
    if (screen == null) return const [];
    final input = CommandMatcher.tokens(cleaned);
    if (input.isEmpty) return const [];
    final fil = lookupAppLocalizations(AppLocales.filipino);
    final en = lookupAppLocalizations(AppLocales.english);
    final scored = <(double, String)>[];
    for (final a in screen.focusables) {
      var best = 0.0;
      for (final phrase in {a.label(fil), a.label(en), ...a.voiceSynonyms}) {
        for (final part in _labelParts(phrase)) {
          final sc = CommandMatcher.score(input, part);
          if (sc > best) best = sc;
        }
      }
      if (best >= 0.4) {
        scored.add((best, a.label(_l10n).split('(').first.trim()));
      }
    }
    scored.sort((a, b) => b.$1.compareTo(a.$1));
    return [for (final s in scored.take(3)) s.$2];
  }

  // ── Questions ─────────────────────────────────────────────────────────────

  /// Answers [question] from what the app knows right now.
  Future<void> answer(Question question) async {
    final l = _l10n;
    final screen = activeScreen;
    switch (question) {
      case Question.whereAmI:
        final parts = <String>[];
        final name =
            screen?.title?.call(l) ??
            (screen == null
                ? null
                : Announcer.splitSentences(screen.prompt(l)).firstOrNull);
        if (name != null && name.isNotEmpty) {
          parts.add(l.whereAmIScreen(name.replaceAll(RegExp(r'[.!?]+$'), '')));
        }
        final focused = _ref.read(focusControllerProvider);
        final action = focused == null ? null : screen?.action(focused);
        if (action != null) parts.add(l.whereAmIFocused(action.label(l)));
        final extra = screen?.whereAmI?.call(l) ?? '';
        if (extra.isNotEmpty) parts.add(extra);
        return say(parts.join(' '));
      case Question.whatCanIDo:
        return say('${l.whatCanIDo(_commandSummary(screen))} ${l.askMeHint}');
      case Question.time:
        return say(l.timeNow(await _formatNow(l, (tag) => DateFormat.jm(tag))));
      case Question.date:
        return say(
          l.dateToday(await _formatNow(l, (tag) => DateFormat.yMMMMEEEEd(tag))),
        );
      case Question.tutorial:
        if (screen?.id == Ids.tutorial) return announceScreen(screen!);
        unawaited(_haptics.confirm());
        unawaited(
          _ref.read(routerProvider).push(AppRoutes.tutorial, extra: true),
        );
        return;
      case Question.docType:
      case Question.total:
      case Question.due:
      case Question.expiry:
      case Question.dosage:
      case Question.summary:
      case Question.progress:
        return say(l.docNeedsOpenDoc);
    }
  }

  /// Now, formatted for the prompt language.
  static Future<String> _formatNow(
    AppLocalizations l,
    DateFormat Function(String tag) format,
  ) async {
    final now = DateTime.now();
    try {
      await initializeDateFormatting(l.localeName);
      return format(l.localeName).format(now);
    } on Object catch (e) {
      debugPrint('Date format for ${l.localeName} failed: $e');
      return format('en').format(now);
    }
  }

  // ── Documents by name ─────────────────────────────────────────────────────

  /// "Basahin ang Liham kay Nanay", "ituloy ang huli": opens a Library
  /// document from any screen. Returns false when it isn't such a command
  /// (or the screen handles it), so the phrase matcher gets it.
  Future<bool> _openByTitle(
    String text,
    String cleaned,
    ScreenRegistration? screen,
  ) async {
    final cmd = Understanding.titleCommand(text);
    if (cmd == null || screen?.id == Ids.library) return false;
    final local = _matcher.match(cleaned, _screenPhrases(screen));
    if (cmd.last) {
      // "Basahin ito" on a screen with its own "Basahin", or on the Reader.
      if (screen?.id == Ids.reader) return false;
      if (local is Matched && local.score >= 1) return false;
      if (local is Ambiguous && local.score >= 1) return false;
    } else {
      // "Buksan ang camera", "basahin mula sa simula": a command, not a title.
      if (_namesCommand(Understanding.clean(cmd.title), screen)) return false;
    }
    final account = _ref.read(currentAccountProvider);
    if (account == null) return false; // no Library before logging in
    final List<LibraryItem> items;
    try {
      items = await _ref.read(libraryDaoProvider).list(account.id);
    } on Object catch (e) {
      debugPrint('Library lookup failed: $e');
      return false;
    }
    _understood('document "${cmd.title}"');
    if (cmd.last) {
      if (items.isEmpty) {
        unawaited(_haptics.error());
        await say(_l10n.libraryNotFound(cmd.title));
        return true;
      }
      await _openItem(items.first, cmd.verb);
      return true;
    }
    final ranked = LibraryView.rankByTitle(items, cmd.title, floor: 0.6);
    if (ranked.isEmpty) {
      unawaited(_haptics.error());
      await say(_l10n.libraryNotFound(cmd.title));
      return true;
    }
    final best = ranked.first;
    final second = ranked.length > 1 ? ranked[1] : null;
    final clear =
        best.score >= 0.75 &&
        (second == null || second.score < best.score - 0.15);
    if (clear) {
      await _openItem(best.item, cmd.verb);
      return true;
    }
    if (second != null) {
      _choices = _Choices([
        (label: best.item.title, run: () => _openItem(best.item, cmd.verb)),
        (label: second.item.title, run: () => _openItem(second.item, cmd.verb)),
      ]);
      await ask(
        _l10n.voiceWhichOne(best.item.title, second.item.title),
        split: true,
      );
      return true;
    }
    _pending = _Pending(() => _openItem(best.item, cmd.verb));
    await ask(_l10n.voiceDidYouMean(best.item.title), split: true);
    return true;
  }

  /// Whether [text] contains a command word for word (screen or app-wide).
  bool _namesCommand(String text, ScreenRegistration? screen) {
    bool contained(MatchResult r) => switch (r) {
      Matched(:final score) || Ambiguous(:final score) => score >= 1,
      NoMatch() => false,
    };
    return contained(_matcher.match(text, _screenPhrases(screen))) ||
        contained(_matcher.match(text, _globalPhrases));
  }

  Future<void> _openItem(LibraryItem item, TitleVerb verb) async {
    unawaited(_haptics.confirm());
    await say(_l10n.libraryOpening(item.title), protect: true);
    await _ref
        .read(libraryActionsProvider)
        .open(item, play: verb == TitleVerb.read);
  }

  _Choices? _takeChoices() {
    final c = _choices;
    _choices = null;
    return (c != null && c.valid) ? c : null;
  }

  static const List<List<String>> _ordinals = [
    ['una', 'unang', 'yung una', 'first', 'the first', 'first one'],
    ['pangalawa', 'ikalawa', 'yung pangalawa', 'second', 'the second'],
  ];

  /// The option of [choices] named in [text] (by title or "una/pangalawa").
  ({String label, Future<void> Function() run})? _pickChoice(
    String text,
    _Choices choices,
  ) {
    final said = Understanding.clean(text);
    for (var i = 0; i < choices.options.length && i < _ordinals.length; i++) {
      if (_ordinals[i].any((o) => CommandMatcher.normalize(o) == said)) {
        return choices.options[i];
      }
    }
    ({String label, Future<void> Function() run})? best;
    var bestScore = 0.0;
    for (final o in choices.options) {
      final sc = LibraryView.titleScore(o.label, text, floor: 0.6);
      if (sc > bestScore) {
        best = o;
        bestScore = sc;
      }
    }
    return best;
  }

  /// Whether the partial result [partial] is already a whole command, so it
  /// can run before the recognizer's final result. Null while the user may
  /// still be talking: a longer command or a free-text command starts this
  /// way ("susunod" → "susunod na talata", "ituloy" → "ituloy ang Liham"),
  /// or the screen reads free text without saying how it begins.
  ///
  /// Compares the whole partial result with each phrase (extra words lower
  /// the score), in the same order as [handleUtterance]: a pending yes/no
  /// question, then the screen's own actions, then app-wide commands. What
  /// runs is still decided by [handleUtterance].
  PartialMatch? judgePartial(String partial) {
    // Percy needs the whole sentence.
    if (_ref.read(percyActiveProvider)) return null;
    final input = CommandMatcher.tokens(
      Understanding.clean(_stripWakeWord(partial)),
    );
    final screen = activeScreen;
    if (input.isEmpty || screen == null) return null;
    if (_choices != null) return null; // a title is on its way
    final prefixes = screen.freeTextPrefixes;
    if (screen.onUtterance != null && prefixes == null) return null;
    for (final prefix in [
      ...?prefixes,
      // "basahin ang …" (a title follows) and questions ("nasaan ako").
      ...Understanding.titlePrefixes,
      ..._questionPhrases,
    ]) {
      final words = CommandMatcher.tokens(prefix);
      final startsWithIt =
          input.length >= words.length &&
          CommandMatcher.wholeScore(input.sublist(0, words.length), prefix) ==
              1;
      if (startsWithIt || CommandMatcher.extendedBy(input, prefix)) {
        return null;
      }
    }

    final pending = _pending;
    final groups = [
      if (pending != null && pending.valid) _yesNoPhrases,
      _screenPhrases(screen),
      _globalPhrases,
    ];
    PartialMatch? found;
    for (final group in groups) {
      final best = _bestWhole(input, group);
      if (best == null) return null; // two commands fit equally: wait
      if (best.score >= VoiceConfig.partialRepeatScore) {
        found = best;
        break;
      }
    }
    // In a noisy room the recognizer often hears other words first ("…
    // ingay susunod"): a command said word for word at the very end counts
    // too, but only once it shows in two partial results in a row.
    found ??= _commandAtEnd(input, groups);
    if (found == null) return null;
    // A different, longer command may still be on its way.
    for (final group in groups) {
      for (final p in group) {
        if (p.target != found.target &&
            CommandMatcher.extendedBy(input, p.phrase)) {
          return null;
        }
      }
    }
    return found;
  }

  /// The phrase in [phrases] most similar to the whole of [input]; null for
  /// a tie between two different commands.
  /// Words that turn the command after them around ("hindi susunod").
  static const Set<String> _negations = {
    'hindi',
    'huwag',
    'wag',
    'di',
    'dont',
    'not',
    'no',
  };

  /// The command whose words end [input] exactly, after other words (not a
  /// negation), scored [VoiceConfig.partialRepeatScore]; null if none or
  /// if two different commands fit.
  static PartialMatch? _commandAtEnd(
    List<String> input,
    List<List<CommandPhrase>> groups,
  ) {
    if (input.length < 2) return null;
    for (final group in groups) {
      CommandTarget? found;
      var foundLength = 0;
      for (final p in group) {
        final words = CommandMatcher.tokens(p.phrase);
        if (words.isEmpty || words.length >= input.length) continue;
        // "oo", "go": too easy to mishear in noise.
        if (words.join().length < 4) continue;
        final tail = input.sublist(input.length - words.length);
        if (tail.join(' ') != words.join(' ')) continue;
        if (_negations.contains(input[input.length - words.length - 1])) {
          continue;
        }
        if (found != null && found != p.target && words.length == foundLength) {
          return null; // two commands fit equally: wait
        }
        if (words.length > foundLength) {
          found = p.target;
          foundLength = words.length;
        }
      }
      if (found != null) {
        return PartialMatch(found, VoiceConfig.partialRepeatScore);
      }
    }
    return null;
  }

  /// What [heard] would run, without running it (the Voice check screen).
  MatchResult matchOnly(String heard) =>
      _matchCommand(Understanding.clean(_stripWakeWord(heard)), activeScreen);

  /// Picks among the recognizer's guesses: [best] when it names a command
  /// (or is not a plain command at all: a title, a free-text answer, Percy),
  /// else the first of [alternates] that names one word for word. In noise
  /// the right words are often the recognizer's second or third guess.
  String preferAlternate(String best, List<String> alternates) {
    if (alternates.isEmpty) return best;
    if (_ref.read(percyActiveProvider) || _choices != null) return best;
    final screen = activeScreen;
    if (screen == null || screen.onUtterance != null) return best;
    final cleaned = Understanding.clean(_stripWakeWord(best));
    if (_matchCommand(cleaned, screen) is Matched) return best;
    if (_percyRequest(best) != null) return best;
    final input = CommandMatcher.tokens(cleaned);
    for (final prefix in Understanding.titlePrefixes) {
      final words = CommandMatcher.tokens(prefix);
      if (input.length >= words.length &&
          CommandMatcher.wholeScore(input.sublist(0, words.length), prefix) ==
              1) {
        return best; // "basahin ang …": a title follows
      }
    }
    for (final alternate in alternates.take(4)) {
      final result = _matchCommand(
        Understanding.clean(_stripWakeWord(alternate)),
        screen,
      );
      if (result is Matched && result.score >= 1) return alternate;
    }
    return best;
  }

  static PartialMatch? _bestWhole(
    List<String> input,
    List<CommandPhrase> phrases,
  ) {
    CommandTarget? best;
    var bestScore = 0.0;
    var tied = false;
    for (final p in phrases) {
      final s = CommandMatcher.wholeScore(input, p.phrase);
      if (s > bestScore + 0.005) {
        best = p.target;
        bestScore = s;
        tied = false;
      } else if (s >= bestScore - 0.005 && best != null && p.target != best) {
        tied = true;
      }
    }
    if (best == null) return const PartialMatch(ValueTarget(false), 0);
    if (tied && bestScore >= VoiceConfig.partialRepeatScore) return null;
    return PartialMatch(best, bestScore);
  }

  /// Phrases the recognizer should expect on the active screen.
  List<String> expectedPhrases() => [
    for (final p in _screenPhrases(activeScreen)) p.phrase,
    for (final list in globalVoiceCommands.values) ...list,
    ...yesWords,
    ...noWords,
  ];

  /// Asks [prompt] and lets the user accept with a double-tap or "oo"
  /// within [AppDurations.pendingAnswer]. Speech stops after the question;
  /// how to answer is said only if no answer comes ([Announcer.ask]).
  Future<void> offer(
    String prompt,
    FutureOr<void> Function() onAccept, {
    FutureOr<void> Function()? onDecline,
  }) {
    _pending = _Pending(onAccept, onDecline);
    return ask(prompt, then: _l10n.offerConfirmHint);
  }

  _Pending? _takePending() {
    final p = _pending;
    _pending = null;
    return (p != null && p.valid) ? p : null;
  }

  MatchResult _matchCommand(String text, ScreenRegistration? screen) {
    // The screen's own actions win over app-wide commands.
    final local = _matcher.match(text, _screenPhrases(screen));
    final global = _matcher.match(text, _globalPhrases);
    if (local is Matched) {
      // Two commands in one phrase: the first one said runs — except
      // "buksan / open / piliin" followed by what to open ("open the
      // camera"): then the thing named runs.
      if (global is Matched &&
          global.at >= 0 &&
          global.at < local.at &&
          global.target != const ValueTarget(NavIntent.activate)) {
        return global;
      }
      return local;
    }
    if (global is Matched) return _whatToOpen(global, text) ?? global;
    if (local is Ambiguous) return local;
    return global;
  }

  /// "buksan ang Aklatan" on a screen without its own "Aklatan": "buksan"
  /// (activate) is said first, but the app-wide command named after it is
  /// meant. Null when nothing follows.
  MatchResult? _whatToOpen(Matched global, String text) {
    if (global.target != const ValueTarget(NavIntent.activate)) return null;
    final rest = _globalPhrases
        .where((p) => p.target != const ValueTarget(NavIntent.activate))
        .toList();
    final named = _matcher.match(text, rest);
    if (named is Matched && named.at > global.at && named.score >= 1) {
      return named;
    }
    return null;
  }

  Future<void> _run(CommandTarget target) async {
    switch (target) {
      case ActionTarget(:final actionId):
        return activate(actionId);
      case ValueTarget(:final value) when value is NavIntent:
        return dispatch(value);
      case ValueTarget(:final value) when value is SpeechSpeed:
        return setReadingSpeed(value);
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
    for (final e in namedSpeedCommands.entries)
      for (final phrase in e.value) CommandPhrase(phrase, ValueTarget(e.key)),
  ];

  static final List<String> _questionPhrases = [
    for (final list in Understanding.questionPhrases.values) ...list,
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
    if (await _userEndsAssistant()) return;
    if (await _userEndsPercy()) return;
    _announcer.answered();
    _voice
      ..noteActivity()
      ..commandExecuted(actionId);
    final action = activeScreen?.action(actionId);
    if (action == null) return notAvailable();
    _ref.read(focusControllerProvider.notifier).focus(actionId);
    unawaited(_haptics.confirm());
    unawaited(say((action.confirmation ?? action.label)(_l10n), protect: true));
    await action.onActivate(this);
  }

  /// Speaks the entry announcement of [screen]. With [interrupt] false it
  /// queues behind whatever is being said. When the screen asks a question,
  /// speech stops after the question and its options; the rest waits for
  /// the answer ([entryParts], [Announcer.ask]).
  ///
  /// With [full] (the user asked to hear it again) a familiar screen is
  /// still announced in full.
  Future<void> announceScreen(
    ScreenRegistration screen, {
    bool interrupt = true,
    bool full = false,
  }) {
    final (:asked, :then) = entryParts(
      screen,
      returning: _consumeReturning(),
      full: full,
    );
    return _announcer.ask(
      asked,
      then: then,
      screenId: screen.id,
      interrupt: interrupt,
    );
  }

  /// Builds "Title. Prompt. Options: A or B. Follow-up. Mode hint." as one
  /// text.
  String entryAnnouncement(
    ScreenRegistration screen, {
    bool returning = false,
  }) {
    final (:asked, :then) = entryParts(screen, returning: returning);
    return [asked, ?then].join(' ');
  }

  /// The entry announcement split where the app waits for an answer:
  /// [asked] is "Title. Prompt? Options: A or B." and [then] is the screen's
  /// follow-up (how to answer) plus the mode hint, and help when detailed.
  /// A prompt with no question is said whole, without waiting ([then]
  /// null).
  ///
  /// "Awtomatiko" ([Verbosity.auto]): a screen opened
  /// [VoiceConfig.familiarAfter] times or more leaves out the navigation
  /// hint (unless [full]); when the user seems stuck ([struggling]) the
  /// screen's help is added.
  ({String asked, String? then}) entryParts(
    ScreenRegistration screen, {
    bool returning = false,
    bool full = false,
  }) {
    final l = _l10n;
    final title = screen.title;
    final prompt = screen.prompt(l);
    final asked = <String>[
      if (title != null)
        returning ? l.backReturnedTo(title(l)) : _asSentence(title(l)),
      if (prompt.isNotEmpty) prompt,
    ];
    final items = screen.focusables;
    if (screen.listOptions && items.isNotEmpty) {
      asked.add(l.optionsList(_joinOr([for (final a in items) a.label(l)], l)));
    }
    final followUp = screen.followUp?.call(l) ?? '';
    final later = <String>[if (followUp.isNotEmpty) followUp];
    final verbosity = _ref.read(settingsProvider).verbosity;
    final auto = verbosity == Verbosity.auto;
    final stuck = auto && struggling;
    final familiar = auto && !full && !stuck && isFamiliar(screen.id);
    if (verbosity == Verbosity.brief) {
      // Name and question only (plus how to answer, if no answer comes).
      final keep = screen.title == null ? 1 : 2;
      if (asked.length > keep) asked.removeRange(keep, asked.length);
    } else {
      if (screen.includeModeHint && !familiar) later.add(modeHint(l));
      if (verbosity == Verbosity.detailed || stuck) {
        later.add((screen.help ?? (l) => l.helpGesturesMenu)(l));
      }
    }
    if (later.isEmpty) return (asked: asked.join(' '), then: null);
    if (!asksQuestion(prompt)) {
      // Nothing to answer: say it all at once.
      return (asked: [...asked, ...later].join(' '), then: null);
    }
    return (asked: asked.join(' '), then: later.join(' '));
  }

  /// Whether [text] contains a question (a sentence ending in "?").
  static bool asksQuestion(String text) =>
      Announcer.splitSentences(text).any(RegExp(r'\?["”’)\]]*$').hasMatch);

  /// Whether the user has opened [screenId] often enough to know it.
  bool isFamiliar(String screenId) =>
      _ref.read(familiarityProvider.notifier).visits(screenId) >=
      VoiceConfig.familiarAfter;

  /// Counts a visit to [screenId] (for "Awtomatiko" announcements).
  void noteVisit(String screenId) =>
      _ref.read(familiarityProvider.notifier).noteVisit(screenId);

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
      if (_ref.read(assistantConfigProvider).isSetUp) l.assistantHowToCall,
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

  /// Asks the question in [text] and waits for the answer before saying
  /// [then] (and, with [split], what follows the question in [text]); see
  /// [Announcer.ask].
  Future<void> ask(String text, {String? then, bool split = false}) =>
      _announcer.ask(text, then: then, split: split);

  /// Opens a top-level screen (pushed, so "back" returns here).
  Future<void> _openScreen(String route, String screenId) async {
    if (activeScreen?.id == screenId) return announceScreen(activeScreen!);
    unawaited(_haptics.confirm());
    unawaited(_ref.read(routerProvider).push(route));
  }

  /// Opens "Mag-report ng problema" on top of the current screen (whose id
  /// goes with the report); Back or "Tapos na" returns there.
  Future<void> _openReport() async {
    final id = activeScreen?.id ?? '';
    if (id.startsWith('${Ids.reportIssue}.')) {
      return announceScreen(activeScreen!);
    }
    unawaited(_haptics.confirm());
    unawaited(_ref.read(routerProvider).push(AppRoutes.reportIssue, extra: id));
  }

  Future<void> _goHome() async {
    if (activeScreen?.id == Ids.home) return announceScreen(activeScreen!);
    unawaited(_haptics.confirm());
    _ref.read(routerProvider).go(AppRoutes.home);
  }

  /// Opens the Library on top of Home, so Back always returns to Home. From
  /// the Reader or a description it is pushed instead, so Back returns there.
  Future<void> _openLibrary() async {
    final id = activeScreen?.id;
    if (id == Ids.library) return announceScreen(activeScreen!);
    unawaited(_haptics.confirm());
    final router = _ref.read(routerProvider);
    if (id == Ids.reader || id == Ids.describe) {
      unawaited(router.push(AppRoutes.library));
      return;
    }
    router.go(AppRoutes.home);
    unawaited(router.push(AppRoutes.library));
  }

  /// Runs [actionId] on screen [screenId], navigating to [route] first if
  /// that screen isn't active.
  Future<void> _goAndActivate(
    String route,
    String screenId,
    String actionId,
  ) async {
    if (activeScreen?.id != screenId) {
      final router = _ref.read(routerProvider);
      // Capture sits on top of Home, so Back returns to Home.
      router.go(AppRoutes.home);
      unawaited(router.push(route));
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
