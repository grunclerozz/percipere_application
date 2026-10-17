import '../voice/command_matcher.dart';

/// Word Error Rate of one recognized sentence.
class WerResult {
  /// Creates a result.
  const WerResult({
    required this.substitutions,
    required this.deletions,
    required this.insertions,
    required this.referenceWords,
  });

  /// Reference words replaced by a different word.
  final int substitutions;

  /// Reference words missing from the recognized text.
  final int deletions;

  /// Extra words in the recognized text.
  final int insertions;

  /// Number of words in the reference (N).
  final int referenceWords;

  /// Total errors (S + D + I).
  int get errors => substitutions + deletions + insertions;

  /// `(S + D + I) / N`. An empty reference gives 0 if nothing was
  /// recognized, otherwise 1.
  double get wer =>
      referenceWords == 0 ? (insertions == 0 ? 0 : 1) : errors / referenceWords;
}

/// Word-level Levenshtein over [reference] and [hypothesis], with
/// backtracking through the table to count substitutions, deletions and
/// insertions. Both texts are normalized first (lowercase, no diacritics or
/// punctuation), like the voice-command matcher.
WerResult wordErrorRate(String reference, String hypothesis) {
  final ref = CommandMatcher.tokens(reference);
  final hyp = CommandMatcher.tokens(hypothesis);
  final n = ref.length;
  final m = hyp.length;

  // d[i][j]: fewest edits turning the first i reference words into the
  // first j recognized words.
  final d = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  for (var i = 0; i <= n; i++) {
    d[i][0] = i;
  }
  for (var j = 0; j <= m; j++) {
    d[0][j] = j;
  }
  for (var i = 1; i <= n; i++) {
    for (var j = 1; j <= m; j++) {
      final cost = ref[i - 1] == hyp[j - 1] ? 0 : 1;
      var best = d[i - 1][j - 1] + cost;
      if (d[i - 1][j] + 1 < best) best = d[i - 1][j] + 1;
      if (d[i][j - 1] + 1 < best) best = d[i][j - 1] + 1;
      d[i][j] = best;
    }
  }

  // Walk back from the corner, preferring a match, then a substitution.
  var s = 0;
  var del = 0;
  var ins = 0;
  var i = n;
  var j = m;
  while (i > 0 || j > 0) {
    if (i > 0 && j > 0) {
      final same = ref[i - 1] == hyp[j - 1];
      if (d[i][j] == d[i - 1][j - 1] + (same ? 0 : 1)) {
        if (!same) s++;
        i--;
        j--;
        continue;
      }
    }
    if (i > 0 && d[i][j] == d[i - 1][j] + 1) {
      del++;
      i--;
    } else {
      ins++;
      j--;
    }
  }
  return WerResult(
    substitutions: s,
    deletions: del,
    insertions: ins,
    referenceWords: n,
  );
}
