import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../voice/command_matcher.dart';

/// What kind of document a text looks like.
enum DocType {
  /// Store receipt (resibo).
  receipt,

  /// Utility or service bill / statement.
  bill,

  /// Medicine label, prescription or leaflet.
  medicine,

  /// Personal or formal letter.
  letter,

  /// A form with fields to fill in.
  form,

  /// None of the above (or not sure).
  other,
}

/// The useful facts found in a document, all optional.
@immutable
class DocumentInsights {
  /// Creates insights.
  const DocumentInsights({
    this.type = DocType.other,
    this.total,
    this.dueDate,
    this.expiry,
    this.dosage,
    this.from,
    this.summary = const [],
  });

  /// Nothing known.
  static const DocumentInsights none = DocumentInsights();

  /// Kind of document.
  final DocType type;

  /// Total / amount due, digits as printed ("1,245.50").
  final String? total;

  /// Due date as printed ("Oct 15, 2026").
  final String? dueDate;

  /// Expiry date as printed.
  final String? expiry;

  /// The dosage line ("Uminom ng 1 tableta tuwing 8 oras").
  final String? dosage;

  /// Store, company or sender (first heading line, or the letter's
  /// greeting name).
  final String? from;

  /// Up to three of the most informative sentences, in reading order.
  final List<String> summary;

  /// Whether any key fact was found (worth saying before reading).
  bool get hasKeyFacts =>
      total != null || dueDate != null || expiry != null || dosage != null;
}

/// Reads a document's text and finds what kind it is and its key facts.
///
/// Offline and rule-based (keywords and patterns in Filipino and English),
/// so it works without internet and never sends the document anywhere.
abstract final class DocumentAnalyzer {
  /// Above this length, [analyzeAsync] works in a background isolate.
  static const int isolateAbove = 20000;

  /// [analyze] off the UI isolate for long texts.
  static Future<DocumentInsights> analyzeAsync(String text) {
    if (text.length < isolateAbove) return Future.value(analyze(text));
    return Isolate.run(() => analyze(text));
  }

  /// Keywords per type, with weights. Matched on normalized words/phrases.
  static const Map<DocType, Map<String, int>> _keywords = {
    DocType.receipt: {
      'resibo': 3,
      'receipt': 3,
      'official receipt': 3,
      'sales invoice': 3,
      'subtotal': 2,
      'sub total': 2,
      'change': 1,
      'sukli': 2,
      'cash': 1,
      'vat': 1,
      'vatable': 2,
      'qty': 2,
      'cashier': 2,
      'thank you': 1,
      'salamat po': 1,
      'tin': 1,
    },
    DocType.bill: {
      'bill': 2,
      'billing': 3,
      'statement of account': 3,
      'amount due': 3,
      'total amount due': 3,
      'due date': 3,
      'account number': 2,
      'account no': 2,
      'kwh': 3,
      'meralco': 3,
      'disconnection': 3,
      'billing period': 3,
      'babayaran': 2,
      'kabuuang babayaran': 3,
      'petsa ng pagbabayad': 3,
      'water': 1,
      'electric': 1,
      'kuryente': 2,
      'tubig': 1,
    },
    DocType.medicine: {
      'mg': 2,
      'ml': 1,
      'tablet': 2,
      'tablets': 2,
      'tableta': 2,
      'capsule': 2,
      'kapsula': 2,
      'dosage': 3,
      'dose': 2,
      'inumin': 2,
      'uminom': 2,
      'take': 1,
      'every': 1,
      'tuwing': 2,
      'oras': 1,
      'hours': 1,
      'prescription': 3,
      'reseta': 3,
      'rx': 2,
      'syrup': 2,
      'sirup': 2,
      'paracetamol': 3,
      'amoxicillin': 3,
      'ibuprofen': 3,
      'side effects': 3,
      'indications': 2,
      'contraindications': 3,
      'storage': 1,
      'keep out of reach of children': 3,
      'exp': 1,
      'expiry': 1,
    },
    DocType.letter: {
      'mahal na': 3,
      'mahal kong': 3,
      'dear': 3,
      'sincerely': 3,
      'lubos na gumagalang': 3,
      'gumagalang': 2,
      'nagmamahal': 3,
      'sumasainyo': 3,
      'to whom it may concern': 3,
      'regards': 2,
      'best regards': 3,
      'yours truly': 3,
      'liham': 2,
    },
    DocType.form: {
      'pangalan': 2,
      'name': 1,
      'address': 1,
      'tirahan': 2,
      'date of birth': 3,
      'petsa ng kapanganakan': 3,
      'birthday': 1,
      'signature': 3,
      'lagda': 3,
      'kasarian': 2,
      'sex': 1,
      'civil status': 3,
      'contact number': 2,
      'application form': 3,
      'fill out': 2,
      'punan': 2,
    },
  };

  static const String _monthsEn =
      'jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|'
      'jul(?:y)?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|'
      'nov(?:ember)?|dec(?:ember)?';
  static const String _monthsFil =
      'enero|pebrero|marso|abril|mayo|hunyo|hulyo|agosto|setyembre|'
      'oktubre|nobyembre|disyembre';

  /// A date as printed: "Oct 15, 2026", "15 Oktubre 2026", "10/15/2026",
  /// "2026-10-15".
  static final RegExp _date = RegExp(
    '(?:(?:$_monthsEn|$_monthsFil)\\.?\\s+\\d{1,2}(?:,\\s*|\\s+)\\d{4})|'
    '(?:\\d{1,2}\\s+(?:$_monthsEn|$_monthsFil)\\.?,?\\s+\\d{4})|'
    '(?:\\d{1,2}[/.-]\\d{1,2}[/.-]\\d{2,4})|'
    '(?:\\d{4}-\\d{1,2}-\\d{1,2})|'
    '(?:\\d{1,2}[/.-]\\d{4})|'
    '(?:(?:$_monthsEn|$_monthsFil)\\.?\\s*\\d{4})',
    caseSensitive: false,
  );

  /// An amount: "₱1,245.50", "PHP 1245", "P 99.00", or a bare "1,245.50".
  static final RegExp _amount = RegExp(
    r'(?:₱|(?<![a-z])php|(?<![a-z])p)\.?\s?(\d{1,3}(?:,\d{3})+(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?)'
    r'|(\d{1,3}(?:,\d{3})+\.\d{2}|\d+\.\d{2})',
    caseSensitive: false,
  );

  static const List<String> _totalWords = [
    'total amount due',
    'amount due',
    'kabuuang babayaran',
    'grand total',
    'total due',
    'babayaran',
    'kabuuan',
    'total',
    'amount',
    'halaga',
  ];

  static const List<String> _dueWords = [
    'due date',
    'pay before',
    'payment due',
    'petsa ng pagbabayad',
    'bayaran bago',
    'bayaran hanggang',
    'deadline',
    'hanggang',
    'due',
  ];

  static const List<String> _expiryWords = [
    'expiry date',
    'expiration date',
    'exp date',
    'gamitin bago',
    'expiry',
    'expiration',
    'expires',
    'exp',
    'best before',
  ];

  static const List<String> _dosageWords = [
    'dosage',
    'dose',
    'take',
    'inumin',
    'uminom',
    'tuwing',
    'every',
    'times a day',
    'beses',
  ];

  /// Finds the type and key facts of [text].
  static DocumentInsights analyze(String text) {
    final lines = text
        .split(RegExp(r'\n+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return DocumentInsights.none;
    final norm = ' ${CommandMatcher.normalize(text)} ';
    final type = _type(norm, text);
    final total = type == DocType.receipt || type == DocType.bill
        ? _total(lines)
        : null;
    final due = type == DocType.bill ? _dateAfter(lines, _dueWords) : null;
    final expiry = type == DocType.medicine
        ? _dateAfter(lines, _expiryWords)
        : null;
    final dosage = type == DocType.medicine ? _dosage(lines) : null;
    return DocumentInsights(
      type: type,
      total: total,
      dueDate: due,
      expiry: expiry,
      dosage: dosage,
      from: _from(lines, type),
      summary: summarize(text),
    );
  }

  static DocType _type(String norm, String text) {
    var best = DocType.other;
    var bestScore = 0;
    // "500mg", "5 mL" written together with the number.
    final strengths = RegExp(
      r'\d\s?(?:mg|ml|mcg)\b',
      caseSensitive: false,
    ).allMatches(text).length;
    for (final entry in _keywords.entries) {
      var score = entry.key == DocType.medicine ? 2 * strengths : 0;
      for (final k in entry.value.entries) {
        if (norm.contains(' ${k.key} ')) score += k.value;
      }
      if (score > bestScore) {
        best = entry.key;
        bestScore = score;
      }
    }
    // One weak hint is not enough to call it anything.
    return bestScore >= 4 ? best : DocType.other;
  }

  static bool _lineHas(String line, List<String> words) {
    final n = ' ${CommandMatcher.normalize(line)} ';
    return words.any((w) => n.contains(' $w '));
  }

  static String? _amountIn(String line) {
    final m = _amount.firstMatch(line);
    if (m == null) return null;
    return m.group(1) ?? m.group(2);
  }

  static double _value(String amount) =>
      double.tryParse(amount.replaceAll(',', '')) ?? 0;

  /// The amount on (or right after) the strongest "total" line; else the
  /// largest amount in the document.
  static String? _total(List<String> lines) {
    for (final word in _totalWords) {
      for (var i = lines.length - 1; i >= 0; i--) {
        final line = lines[i];
        if (!_lineHas(line, [word])) continue;
        // "Subtotal" is not the total.
        if (word == 'total' && _lineHas(line, ['subtotal', 'sub total'])) {
          continue;
        }
        final here = _amountIn(line);
        if (here != null) return here;
        if (i + 1 < lines.length) {
          final next = _amountIn(lines[i + 1]);
          if (next != null) return next;
        }
      }
    }
    String? best;
    for (final line in lines) {
      for (final m in _amount.allMatches(line)) {
        final a = m.group(1) ?? m.group(2)!;
        if (best == null || _value(a) > _value(best)) best = a;
      }
    }
    return best;
  }

  static String? _dateAfter(List<String> lines, List<String> words) {
    for (final word in words) {
      for (var i = 0; i < lines.length; i++) {
        if (!_lineHas(lines[i], [word])) continue;
        final here = _date.firstMatch(lines[i]);
        if (here != null) return here.group(0)!.trim();
        if (i + 1 < lines.length) {
          final next = _date.firstMatch(lines[i + 1]);
          if (next != null) return next.group(0)!.trim();
        }
      }
    }
    return null;
  }

  static String? _dosage(List<String> lines) {
    for (final line in lines) {
      if (_lineHas(line, _dosageWords) &&
          RegExp(
            r'\d|isa|dalawa|tatlo|once|twice',
            caseSensitive: false,
          ).hasMatch(line)) {
        return line.length > 160 ? '${line.substring(0, 157)}…' : line;
      }
    }
    return null;
  }

  static String? _from(List<String> lines, DocType type) {
    if (type == DocType.letter) {
      final greeting = RegExp(
        r'^(?:mahal\s+(?:na|kong)|dear)\s+(.+?)[,:]?$',
        caseSensitive: false,
      );
      for (final line in lines.take(6)) {
        final m = greeting.firstMatch(line);
        if (m != null) return m.group(1)!.trim();
      }
      return null;
    }
    if (type == DocType.receipt || type == DocType.bill) {
      final first = lines.first;
      final letters = RegExp(r'\p{L}', unicode: true).allMatches(first).length;
      if (letters >= 3 && first.length <= 60) return first;
    }
    return null;
  }

  // ── Summary ──────────────────────────────────────────────────────────────

  static const Set<String> _stopwords = {
    // Filipino
    'ang', 'ng', 'sa', 'na', 'at', 'ay', 'mga', 'si', 'ni', 'kay', 'ko', 'mo',
    'ka', 'ako', 'ikaw', 'siya', 'kami', 'tayo', 'kayo', 'sila', 'ito', 'iyan',
    'iyon', 'po', 'din', 'rin', 'lang', 'naman', 'pa', 'ba', 'kung', 'para',
    'nang', 'may', 'mayroon', 'wala', 'hindi', 'oo', 'yung', 'nito', 'niya',
    'kanila', 'amin', 'atin', 'inyo', 'dahil', 'pero', 'kasi', 'upang',
    // English
    'the', 'a', 'an', 'and', 'or', 'of', 'to', 'in', 'on', 'for', 'is', 'are',
    'was', 'were', 'be', 'been', 'it', 'this', 'that', 'with', 'as',
    'by', 'from', 'you', 'your', 'we', 'our', 'i', 'my', 'he', 'she', 'they',
    'his', 'her', 'their', 'not', 'no', 'yes', 'will', 'can', 'have', 'has',
    'had', 'do', 'does', 'did', 'but', 'if', 'so', 'than', 'then', 'there',
  };

  /// Up to [count] of the most informative sentences of [text], in their
  /// original order (word-frequency scoring, offline).
  static List<String> summarize(String text, {int count = 3}) {
    final sentences = text
        .replaceAll('\n', ' ')
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => CommandMatcher.tokens(s).length >= 4)
        .toList();
    if (sentences.length <= count) return sentences;
    final freq = <String, int>{};
    for (final s in sentences) {
      for (final w in CommandMatcher.tokens(s)) {
        if (w.length < 3 || _stopwords.contains(w)) continue;
        freq[w] = (freq[w] ?? 0) + 1;
      }
    }
    double score(String s) {
      final words = CommandMatcher.tokens(s)
          .where((w) => w.length >= 3 && !_stopwords.contains(w))
          .toList();
      if (words.isEmpty) return 0;
      final sum = words.fold<int>(0, (a, w) => a + (freq[w] ?? 0));
      // Favour full sentences over very long ones.
      return sum / math.sqrt(words.length);
    }

    final ranked = [for (var i = 0; i < sentences.length; i++) i]
      ..sort((a, b) {
        final byScore = score(sentences[b]).compareTo(score(sentences[a]));
        // The opening sentence wins ties: it usually says what it is about.
        return byScore != 0 ? byScore : a.compareTo(b);
      });
    final picked = ranked.take(count).toList()..sort();
    return [for (final i in picked) sentences[i]];
  }
}
