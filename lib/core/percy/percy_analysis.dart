import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_controller.dart';
import '../tts/language_detector.dart';
import 'intent_classifier.dart';

/// One utterance as Percy understood it, for the "Percy analysis" panel
/// (developer setting; testing and the Intelligent Systems demonstration).
/// Kept in memory only: no audio, nothing written to the database.
@immutable
class PercyAnalysisEntry {
  /// Creates an entry.
  const PercyAnalysisEntry({
    required this.heard,
    required this.language,
    required this.top,
    required this.action,
    required this.at,
    this.intent,
    this.confidence,
  });

  /// What speech recognition heard (dots for a password field).
  final String heard;

  /// The language the words look like (Filipino / English function words).
  final LanguageGuess language;

  /// The intent Percy went with (null: an exact command or none).
  final String? intent;

  /// The classifier's confidence in [intent], 0–1.
  final double? confidence;

  /// The classifier's three most likely intents.
  final List<IntentScore> top;

  /// What Percy did (`run:library`, `exact:home`, `asked`, …).
  final String action;

  /// When it was heard.
  final DateTime at;
}

/// The last utterances, newest first.
class PercyAnalysisLog extends Notifier<List<PercyAnalysisEntry>> {
  /// Entries kept.
  static const int keep = 20;

  @override
  List<PercyAnalysisEntry> build() => const [];

  /// Adds [entry] at the top.
  void add(PercyAnalysisEntry entry) {
    state = [entry, ...state.take(keep - 1)];
  }

  /// Forgets everything.
  void clear() => state = const [];
}

/// What Percy heard and decided, for the analysis panel.
final percyAnalysisProvider =
    NotifierProvider<PercyAnalysisLog, List<PercyAnalysisEntry>>(
      PercyAnalysisLog.new,
    );

/// Whether the analysis panel is on: the developer setting, in a developer
/// build only (`PERCIPERE_DEV=true`). Overridden in tests.
final percyAnalysisOnProvider = Provider<bool>(
  (ref) =>
      ref.watch(devBuildProvider) &&
      ref.watch(settingsProvider.select((s) => s.percyAnalysis)),
);
