import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Something a phrase can trigger.
@immutable
sealed class CommandTarget {
  const CommandTarget();
}

/// Triggers an action registered by the active screen.
final class ActionTarget extends CommandTarget {
  /// Targets [actionId].
  const ActionTarget(this.actionId);

  /// Action id.
  final String actionId;

  @override
  bool operator ==(Object other) =>
      other is ActionTarget && other.actionId == actionId;

  @override
  int get hashCode => actionId.hashCode;

  @override
  String toString() => 'ActionTarget($actionId)';
}

/// Triggers a value from outside (a NavIntent, a yes/no answer, a number…).
final class ValueTarget<T extends Object> extends CommandTarget {
  /// Targets [value].
  const ValueTarget(this.value);

  /// The value.
  final T value;

  @override
  bool operator ==(Object other) =>
      other is ValueTarget && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'ValueTarget($value)';
}

/// A phrase that triggers [target].
@immutable
class CommandPhrase {
  /// Creates a phrase.
  const CommandPhrase(this.phrase, this.target);

  /// What the user says, as written (e.g. "i-pause").
  final String phrase;

  /// What it triggers.
  final CommandTarget target;
}

/// Outcome of matching an utterance.
@immutable
sealed class MatchResult {
  const MatchResult();
}

/// Confident match.
final class Matched extends MatchResult {
  /// Creates a match; [at] is the word position of a phrase found word for
  /// word, -1 for a fuzzy match.
  const Matched(this.target, this.phrase, this.score, {this.at = -1});

  /// Word position of the phrase in the utterance (-1: fuzzy match).
  final int at;

  /// What to run.
  final CommandTarget target;

  /// The phrase that matched (as written).
  final String phrase;

  /// Similarity, 0..1.
  final double score;
}

/// Close but unsure: ask "Ang ibig mo bang sabihin ay …?".
final class Ambiguous extends MatchResult {
  /// Creates an ambiguous result.
  const Ambiguous(this.target, this.phrase, this.score);

  /// Best guess.
  final CommandTarget target;

  /// The phrase to ask back with.
  final String phrase;

  /// Similarity, 0..1.
  final double score;
}

/// Nothing close enough.
final class NoMatch extends MatchResult {
  /// The no-match result.
  const NoMatch();
}

/// Fuzzy matcher for short bilingual voice commands.
///
/// Both sides are normalized (lowercase, no diacritics or punctuation,
/// hyphens optional). A phrase scores 1.0 if its words appear in order inside
/// the utterance ("basahin mo nga" → "basahin"); otherwise the best
/// Levenshtein similarity between the phrase and any same-length run of
/// words in the utterance.
class CommandMatcher {
  /// Creates a matcher.
  const CommandMatcher({this.acceptThreshold = 0.8, this.askThreshold = 0.6});

  /// At or above: run the command.
  final double acceptThreshold;

  /// At or above (but below [acceptThreshold]): ask back.
  final double askThreshold;

  /// Matches [utterance] against [phrases].
  ///
  /// When the utterance contains several phrases word for word ("itigil,
  /// bumalik"), the one said **first** wins; at the same position the longer
  /// one ("susunod na talata" over "susunod"). One phrase runs one command.
  MatchResult match(String utterance, List<CommandPhrase> phrases) {
    final input = tokens(utterance);
    if (input.isEmpty || phrases.isEmpty) return const NoMatch();

    final contained = _firstContained(input, phrases);
    if (contained != null) return contained;

    // Best phrase per target, in first-seen order (earlier = higher priority).
    final perTarget = <CommandTarget, (double, String)>{};
    for (final p in phrases) {
      final s = score(input, p.phrase);
      final current = perTarget[p.target];
      if (current == null || s > current.$1) {
        perTarget[p.target] = (s, p.phrase);
      }
    }
    MapEntry<CommandTarget, (double, String)>? best;
    for (final e in perTarget.entries) {
      if (best == null || e.value.$1 > best.value.$1) best = e;
    }
    final (bestScore, bestPhrase) = best!.value;
    var runnerUpScore = 0.0;
    for (final e in perTarget.entries) {
      if (e.key != best.key) {
        runnerUpScore = math.max(runnerUpScore, e.value.$1);
      }
    }

    // Two different commands that both fit equally well: ask, don't guess.
    final tied = runnerUpScore >= bestScore - 0.005;
    if (bestScore >= acceptThreshold && !tied) {
      return Matched(best.key, bestPhrase, bestScore);
    }
    if (bestScore >= askThreshold) {
      return Ambiguous(best.key, bestPhrase, bestScore);
    }
    return const NoMatch();
  }

  /// The command said first among the phrases found word for word in
  /// [input], or null if none is. Two different commands at the same position
  /// and length are a tie: asked back, not guessed.
  MatchResult? _firstContained(
    List<String> input,
    List<CommandPhrase> phrases,
  ) {
    // Earliest (start, score, phrase) per target.
    final found = <CommandTarget, (int, double, String)>{};
    for (final p in phrases) {
      for (final variant in _variants(p.phrase)) {
        final words = tokens(variant);
        if (words.isEmpty) continue;
        final at = _indexOfRun(input, words);
        if (at < 0) continue;
        final s = 1.0 + 0.01 * words.length;
        final current = found[p.target];
        if (current == null ||
            at < current.$1 ||
            (at == current.$1 && s > current.$2)) {
          found[p.target] = (at, s, p.phrase);
        }
      }
    }
    if (found.isEmpty) return null;
    final ranked = found.entries.toList()
      ..sort((a, b) {
        final byStart = a.value.$1.compareTo(b.value.$1);
        return byStart != 0 ? byStart : b.value.$2.compareTo(a.value.$2);
      });
    final best = ranked.first;
    final (start, s, phrase) = best.value;
    if (ranked.length > 1) {
      final (nextStart, nextScore, _) = ranked[1].value;
      if (nextStart == start && (nextScore - s).abs() < 0.005) {
        return Ambiguous(best.key, phrase, s);
      }
    }
    return Matched(best.key, phrase, s, at: start);
  }

  /// Similarity of the **whole** utterance to [phrase] (0..1), ignoring word
  /// breaks: "i pause" and "ipause" both score 1 against "i-pause". Unlike
  /// [score], extra words lower it, so a partial result only counts as a
  /// command when it is nothing but the command.
  static double wholeScore(List<String> input, String phrase) {
    if (input.isEmpty) return 0;
    final said = input.join();
    var best = 0.0;
    for (final variant in _variants(phrase)) {
      final p = tokens(variant).join();
      if (p.isEmpty) continue;
      best = math.max(best, similarity(said, p));
    }
    return best;
  }

  /// Whether [phrase] continues the words said so far ([input]), so the
  /// user may still be saying it: "susunod" → "susunod na talata",
  /// "susunod na tala" → "susunod na talata".
  static bool extendedBy(List<String> input, String phrase) {
    if (input.isEmpty) return false;
    final said = input.join();
    for (final variant in _variants(phrase)) {
      final p = tokens(variant).join();
      if (p.length > said.length && p.startsWith(said)) return true;
    }
    return false;
  }

  /// Similarity of [phrase] to the utterance [input] tokens: 0..1, or just
  /// above 1 when the phrase occurs verbatim (1 + 0.01 per word).
  static double score(List<String> input, String phrase) {
    var best = 0.0;
    for (final variant in _variants(phrase)) {
      final p = tokens(variant);
      if (p.isEmpty) continue;
      // Contained phrases win, longer ones more ("susunod na talata" beats
      // "susunod" in "susunod na talata po").
      if (_containsRun(input, p)) return 1.0 + 0.01 * p.length;
      final target = p.join();
      // Compare against every run of words of about the phrase's length.
      for (var len = math.max(1, p.length - 1); len <= p.length + 1; len++) {
        for (var i = 0; i + len <= input.length; i++) {
          final window = input.sublist(i, i + len).join();
          best = math.max(best, similarity(window, target));
        }
      }
      best = math.max(best, similarity(input.join(), target));
    }
    return best;
  }

  /// Hyphenated phrases may be heard joined or split ("i-pause" → "ipause",
  /// "i pause").
  static Iterable<String> _variants(String phrase) sync* {
    yield phrase.replaceAll('-', '');
    if (phrase.contains('-')) yield phrase.replaceAll('-', ' ');
  }

  static bool _containsRun(List<String> haystack, List<String> needle) =>
      _indexOfRun(haystack, needle) >= 0;

  /// Where [needle] first occurs as a run of words in [haystack], or -1.
  static int _indexOfRun(List<String> haystack, List<String> needle) {
    for (var i = 0; i + needle.length <= haystack.length; i++) {
      var all = true;
      for (var j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) {
          all = false;
          break;
        }
      }
      if (all) return i;
    }
    return -1;
  }

  /// Normalized words of [text]: lowercase, diacritics removed, hyphens
  /// dropped, other punctuation treated as spaces.
  static List<String> tokens(String text) =>
      normalize(text)
          .split(' ')
          .where((t) => t.isNotEmpty)
          .toList(growable: false);

  /// Normalizes [text] for comparison.
  static String normalize(String text) {
    final lower = text.toLowerCase();
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final ch = String.fromCharCode(rune);
      buffer.write(_fold[ch] ?? ch);
    }
    return buffer
        .toString()
        .replaceAll('-', '')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// 1 − (edit distance / longer length).
  static double similarity(String a, String b) {
    if (a == b) return 1;
    final longest = math.max(a.length, b.length);
    if (longest == 0) return 1;
    return 1 - levenshtein(a, b) / longest;
  }

  /// Character edit distance.
  static int levenshtein(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    var curr = List<int>.filled(b.length + 1, 0);
    for (var i = 1; i <= a.length; i++) {
      curr[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        curr[j] = math.min(
          math.min(curr[j - 1] + 1, prev[j] + 1),
          prev[j - 1] + cost,
        );
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[b.length];
  }

  static const Map<String, String> _fold = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', //
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', //
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', //
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', //
    'ñ': 'n', 'ç': 'c', '’': ' ', '‘': ' ', '“': ' ', '”': ' ',
  };
}
