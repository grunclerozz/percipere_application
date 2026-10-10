import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../l10n/app_localizations.dart';
import 'command_bus.dart';
import 'nav_intent.dart';

/// Builds a localized string. Using the generated [AppLocalizations] keeps
/// both the Filipino and English labels in the ARB files.
typedef L10nText = String Function(AppLocalizations l10n);

/// Handler for an action or an intent override.
typedef BusHandler = FutureOr<void> Function(CommandBus bus);

/// One thing the user can do on a screen, reachable by focus + double-tap,
/// by a visual tap, and (Phase 3) by voice.
@immutable
class A11yAction {
  /// Creates an action.
  const A11yAction({
    required this.id,
    required this.label,
    required this.onActivate,
    this.voiceSynonyms = const [],
    this.confirmation,
    this.focusable = true,
  });

  /// Stable id, e.g. `capture.upload`. Used by voice matching and usage logs.
  final String id;

  /// Spoken and visible label.
  final L10nText label;

  /// Extra Filipino/English words that trigger this action by voice.
  final List<String> voiceSynonyms;

  /// Spoken before [onActivate] runs; defaults to [label].
  final L10nText? confirmation;

  /// Whether swipe navigation stops on this action.
  final bool focusable;

  /// Runs the action.
  final BusHandler onActivate;
}

/// Everything the accessibility core needs to know about one screen.
///
/// Screens register one of these through `AccessibleScreen`; gestures and
/// voice both resolve against the topmost registration.
@immutable
class ScreenRegistration {
  /// Creates a registration.
  const ScreenRegistration({
    required this.id,
    required this.prompt,
    this.followUp,
    this.whereAmI,
    this.title,
    this.actions = const [],
    this.intentHandlers = const {},
    this.help,
    this.listOptions = true,
    this.includeModeHint = true,
    this.autoListen = false,
    this.onUtterance,
    this.freeTextPrefixes,
    this.hasUnsavedInput,
    this.beforeBack,
  });

  /// Whether leaving now would lose what the user entered. Back then asks
  /// "May hindi pa naka-save. Sigurado ka bang babalik?" first.
  final bool Function()? hasUnsavedInput;

  /// Runs before back leaves the screen (Reader: stop and save position).
  final Future<void> Function()? beforeBack;

  /// Stable screen id, e.g. `capture`.
  final String id;

  /// Screen name spoken first on entry (omit when [prompt] already says it).
  final L10nText? title;

  /// The screen's main question or status.
  final L10nText prompt;

  /// What follows a question in [prompt]: how to answer it, or a side note.
  /// The app stops after the question (and its options) and says this only
  /// if no answer comes within `VoiceConfig.answerWait`; any answer drops
  /// it. Without a question in [prompt] it is said straight after.
  final L10nText? followUp;

  /// Extra detail for "nasaan ako?" (e.g. the Reader's progress).
  final L10nText? whereAmI;

  /// Actions in focus order.
  final List<A11yAction> actions;

  /// Screen-specific behavior for intents, overriding the defaults
  /// (e.g. Reader maps [NavIntent.repeat] to play/pause).
  final Map<NavIntent, BusHandler> intentHandlers;

  /// Help text; defaults to the generic menu gestures.
  final L10nText? help;

  /// Whether the entry announcement lists the focusable options.
  final bool listOptions;

  /// Whether the entry announcement ends with a hint for the current mode.
  final bool includeModeHint;

  /// Listen for commands after speaking even in gesture mode (once the mic
  /// is allowed). Used by Welcome so "boses" / "galaw" work before a mode
  /// is chosen.
  final bool autoListen;

  /// Sees every recognized utterance first (after pending yes/no answers).
  /// Return true if handled — for free-form commands like
  /// "hanapin resibo" that the phrase matcher can't express.
  final FutureOr<bool> Function(String text, CommandBus bus)? onUtterance;

  /// How the free-text commands that [onUtterance] reads begin ("hanapin",
  /// "ituloy ang"), so a partial result that is only their start doesn't run
  /// as a command before the user finishes ("ituloy" → "ituloy ang Liham").
  ///
  /// A screen with [onUtterance] but no list waits for the final result for
  /// every command; an empty list says [onUtterance] reads no free text.
  final List<String>? freeTextPrefixes;

  /// Focusable actions, in order.
  List<A11yAction> get focusables =>
      actions.where((a) => a.focusable).toList(growable: false);

  /// Finds an action by id.
  A11yAction? action(String actionId) {
    for (final a in actions) {
      if (a.id == actionId) return a;
    }
    return null;
  }
}
