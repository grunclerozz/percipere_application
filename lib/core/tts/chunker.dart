import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// One sentence of a document: a character range plus its paragraph.
@immutable
class Sentence {
  /// Creates a sentence.
  const Sentence(this.start, this.end, this.paragraph);

  /// Start offset in the document text (inclusive).
  final int start;

  /// End offset in the document text (exclusive).
  final int end;

  /// Index of the paragraph it belongs to.
  final int paragraph;

  /// Character range, for highlighting.
  TextRange get range => TextRange(start: start, end: end);

  /// The sentence as it should be spoken (line breaks flattened).
  String textIn(String document) =>
      document.substring(start, end).replaceAll(RegExp(r'\s+'), ' ').trim();

  @override
  bool operator ==(Object other) =>
      other is Sentence &&
      other.start == start &&
      other.end == end &&
      other.paragraph == paragraph;

  @override
  int get hashCode => Object.hash(start, end, paragraph);

  @override
  String toString() => 'Sentence($start–$end, ¶$paragraph)';
}

/// Words that end with a period without ending the sentence (Filipino and
/// English abbreviations common in letters, forms and receipts).
const Set<String> _abbreviations = {
  'g',
  'gng',
  'bb',
  'dr',
  'dra',
  'engr',
  'atty',
  'hon',
  'kgg',
  'sto',
  'sta',
  'st',
  'mr',
  'mrs',
  'ms',
  'jr',
  'sr',
  'atbp',
  'hal',
  'blg',
  'pp',
  'vol',
  'no',
  'etc',
  'vs',
  'e.g',
  'i.e',
  'brgy',
  'pres',
  'gov',
  'sen',
  'rep',
};

/// Splits [text] into sentences for chunked TTS, keeping exact character
/// offsets so the Reader can highlight what is being spoken.
///
/// Paragraphs are separated by a blank line. Sentences end at `.`, `!`, `?`
/// or `…` followed by whitespace — except after abbreviations ("Gng."),
/// single-letter initials ("J. Rizal"), or when the next word starts in
/// lowercase (a false break). Sentences longer than [maxLength] are split at
/// a comma/semicolon or a space, so skipping and highlighting stay precise.
List<Sentence> chunkText(String text, {int maxLength = 220}) {
  final sentences = <Sentence>[];
  var paragraph = 0;
  for (final para in RegExp(r'[^\n]+(?:\n(?!\s*\n)[^\n]*)*').allMatches(text)) {
    final pStart = para.start;
    final pText = para.group(0)!;
    if (pText.trim().isEmpty) continue;

    var sStart = 0;
    for (final m in RegExp(
      r'[.!?…]+["\x27”’)\]]*(?=\s+|$)',
    ).allMatches(pText)) {
      final end = m.end;
      if (!_isSentenceEnd(pText, m.start, end)) continue;
      _add(sentences, pText, pStart, sStart, end, paragraph, maxLength);
      sStart = end;
    }
    _add(sentences, pText, pStart, sStart, pText.length, paragraph, maxLength);
    paragraph++;
  }
  return sentences;
}

bool _isSentenceEnd(String p, int punctStart, int end) {
  // Word right before the punctuation.
  final before = RegExp(
    r'([\p{L}.]+)$',
    unicode: true,
  ).firstMatch(p.substring(0, punctStart));
  final word = before?.group(1)?.toLowerCase() ?? '';
  if (p[punctStart] == '.') {
    if (_abbreviations.contains(word)) return false;
    if (word.length == 1 &&
        RegExp(
          r'\p{Lu}',
          unicode: true,
        ).hasMatch(p.substring(punctStart - 1, punctStart))) {
      return false; // initial: "J. Rizal"
    }
  }
  // A lowercase continuation means the break was false ("hal. ang").
  final after = RegExp(r'^\s+(\S)').firstMatch(p.substring(end));
  if (after != null &&
      RegExp(r'\p{Ll}', unicode: true).hasMatch(after.group(1)!)) {
    return false;
  }
  return true;
}

void _add(
  List<Sentence> out,
  String p,
  int pStart,
  int from,
  int to,
  int paragraph,
  int maxLength,
) {
  // Trim surrounding whitespace, keeping offsets exact.
  while (from < to && p[from].trim().isEmpty) {
    from++;
  }
  while (to > from && p[to - 1].trim().isEmpty) {
    to--;
  }
  if (from >= to) return;

  while (to - from > maxLength) {
    final window = p.substring(from, from + maxLength);
    var cut = window.lastIndexOf(RegExp(r'[,;:—–]\s'));
    cut = cut > maxLength ~/ 3 ? cut + 1 : window.lastIndexOf(' ');
    if (cut <= 0) cut = maxLength;
    out.add(Sentence(pStart + from, pStart + from + cut, paragraph));
    from += cut;
    while (from < to && p[from].trim().isEmpty) {
      from++;
    }
  }
  if (from < to) out.add(Sentence(pStart + from, pStart + to, paragraph));
}

/// Index of the first sentence of each paragraph.
List<int> paragraphStarts(List<Sentence> sentences) => [
  for (var i = 0; i < sentences.length; i++)
    if (i == 0 || sentences[i].paragraph != sentences[i - 1].paragraph) i,
];

/// A title for history: the first line, shortened to about [max] characters
/// at a word boundary.
String titleFor(String text, {int max = 60}) {
  final first = text
      .split('\n')
      .map((l) => l.trim())
      .firstWhere((l) => l.isNotEmpty, orElse: () => '');
  if (first.length <= max) return first;
  final cut = first.lastIndexOf(' ', max);
  return '${first.substring(0, cut > max ~/ 2 ? cut : max).trimRight()}…';
}
