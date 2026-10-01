import 'dart:isolate';
import 'dart:math' as math;

/// Turns raw extracted text (OCR, PDF, DOCX) into clean, readable
/// paragraphs separated by a blank line.
///
/// With [joinLines] (OCR and PDF text, where line breaks are just where the
/// page wrapped):
/// - words split by a hyphen at a line end are rejoined ("impor-\ntante");
/// - wrapped lines are joined into one paragraph;
/// - short lines without end punctuation (headings, list items, receipt rows)
///   stay on their own.
///
/// Always: whitespace is collapsed, spaces before punctuation removed, and
/// obvious OCR garbage lines ("-----", "|||", "~ ^ ~") dropped.
String cleanText(String raw, {bool joinLines = true}) {
  final text = raw
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll(RegExp('[​-‍﻿­]'), '')
      .replaceAll('\t', ' ')
      .replaceAll(' ', ' ');

  final paragraphs = <String>[];
  for (final block in text.split(RegExp(r'\n\s*\n'))) {
    final lines = block
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r' {2,}'), ' ').trim())
        .where((l) => l.isNotEmpty && !isGarbageLine(l))
        .toList();
    if (lines.isEmpty) continue;
    if (!joinLines) {
      paragraphs.addAll(lines.map(_tidy));
      continue;
    }
    paragraphs.addAll(_joinWrapped(lines).map(_tidy));
  }
  return paragraphs.where((p) => p.isNotEmpty).join('\n\n');
}

/// Runs [cleanText] in a background isolate for large texts (so the UI and
/// speech never stutter); small texts are cleaned inline.
Future<String> cleanTextAsync(String raw, {bool joinLines = true}) {
  if (raw.length < 20000) {
    return Future.value(cleanText(raw, joinLines: joinLines));
  }
  return Isolate.run(() => cleanText(raw, joinLines: joinLines));
}

List<String> _joinWrapped(List<String> lines) {
  final sorted = [...lines.map((l) => l.length)]..sort();
  final typical = sorted[sorted.length ~/ 2];
  final out = <String>[];
  var current = '';

  bool isShortStandalone(String line) =>
      lines.length > 1 &&
      line.length < math.max(12, typical * 0.6) &&
      !RegExp(r'[-,;:]$').hasMatch(line);

  final startsUpper = RegExp(r'^\p{Lu}', unicode: true);
  bool isHeading(String line) =>
      RegExp(r'\p{Lu}', unicode: true).hasMatch(line) &&
      !RegExp(r'\p{Ll}', unicode: true).hasMatch(line);

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final next = i + 1 < lines.length ? lines[i + 1] : null;
    if (current.isEmpty) {
      current = line;
    } else if (RegExp(r'\p{L}-$', unicode: true).hasMatch(current) &&
        RegExp(r'^\p{Ll}', unicode: true).hasMatch(line)) {
      // "impor-" + "tante" → "importante"
      current = current.substring(0, current.length - 1) + line;
    } else {
      current = '$current $line';
    }
    // End the paragraph after: a short line (heading, list item, or the
    // last line of a wrapped paragraph); an all-caps heading; or a row that
    // ends in a number when the next starts a new item (receipts, price
    // lists).
    final endsRow =
        RegExp(r'\d$').hasMatch(line) &&
        next != null &&
        startsUpper.hasMatch(next);
    if (isShortStandalone(line) || isHeading(line) || endsRow) {
      out.add(current);
      current = '';
    }
  }
  if (current.isNotEmpty) out.add(current);
  return out;
}

String _tidy(String s) => s
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAllMapped(RegExp(r'\s+([,.;:!?)\]])'), (m) => m[1]!)
    .replaceAllMapped(RegExp(r'([(\[])\s+'), (m) => m[1]!)
    .trim();

/// Whether [line] is OCR noise rather than text: mostly symbols, a run of
/// one repeated character, or a lone non-alphanumeric character.
bool isGarbageLine(String line) {
  final compact = line.replaceAll(' ', '');
  if (compact.isEmpty) return true;
  if (RegExp(r'^(.)\1{3,}$').hasMatch(compact)) return true;
  final letters = RegExp(
    r'[\p{L}\p{N}]',
    unicode: true,
  ).allMatches(compact).length;
  if (letters == 0) return true;
  return compact.length >= 3 && letters / compact.length < 0.5;
}

/// How usable extracted text is.
enum TextQuality {
  /// Nothing readable.
  empty,

  /// Some text, but probably misread (few real words, low OCR confidence).
  low,

  /// Looks like normal text.
  good,
}

/// Rates [text]. [ocrConfidence] (0..1) is the mean OCR confidence, when
/// known.
TextQuality assessQuality(String text, {double? ocrConfidence}) {
  final tokens = text
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList(growable: false);
  if (tokens.isEmpty) return TextQuality.empty;

  final wordLike = RegExp(r"^[\p{L}][\p{L}'’\-]*[\p{L}]$", unicode: true);
  final words = tokens
      .map(
        (t) =>
            t.replaceAll(RegExp(r'^[^\p{L}]+|[^\p{L}]+$', unicode: true), ''),
      )
      .where(wordLike.hasMatch)
      .length;
  if (words == 0) return TextQuality.empty;
  if (words < 3 || words / tokens.length < 0.5) return TextQuality.low;
  if (ocrConfidence != null && ocrConfidence < 0.5) return TextQuality.low;
  return TextQuality.good;
}
