import 'package:flutter/foundation.dart';

/// Document language, as far as the TTS voice is concerned.
enum DocLanguage {
  /// Filipino (including Taglish that leans Filipino).
  filipino,

  /// English.
  english,
}

/// Result of [detectLanguage].
@immutable
class LanguageGuess {
  /// Creates a guess.
  const LanguageGuess(
    this.language, {
    required this.filipinoHits,
    required this.englishHits,
  });

  /// Chosen language.
  final DocLanguage language;

  /// Filipino function words found.
  final int filipinoHits;

  /// English function words found.
  final int englishHits;

  /// Substantial amounts of both (Taglish).
  bool get mixed => filipinoHits >= 3 && englishHits >= 3;
}

/// Common Filipino function words (very frequent, rarely English).
const Set<String> filipinoStopWords = {
  'ang',
  'ng',
  'mga',
  'sa',
  'na',
  'at',
  'ay',
  'si',
  'ni',
  'kay',
  'ko',
  'mo',
  'niya',
  'namin',
  'natin',
  'nila',
  'ito',
  'iyan',
  'iyon',
  'dito',
  'doon',
  'hindi',
  'po',
  'opo',
  'din',
  'rin',
  'lang',
  'lamang',
  'pa',
  'nang',
  'kung',
  'para',
  'ano',
  'sino',
  'saan',
  'kailan',
  'bakit',
  'paano',
  'may',
  'mayroon',
  'wala',
  'siya',
  'kami',
  'tayo',
  'sila',
  'kayo',
  'akin',
  'iyong',
  'ating',
  'kanila',
  'pero',
  'ngunit',
  'dahil',
  'kasi',
  'kaya',
  'ba',
  'naman',
  'lahat',
  'isang',
  'yung',
  'mula',
  'upang',
  'sapagkat',
  'ninyo',
};

/// Common English function words.
const Set<String> englishStopWords = {
  'the',
  'and',
  'of',
  'to',
  'in',
  'is',
  'it',
  'that',
  'for',
  'you',
  'was',
  'on',
  'are',
  'with',
  'as',
  'be',
  'this',
  'have',
  'by',
  'not',
  'or',
  'from',
  'but',
  'what',
  'all',
  'were',
  'we',
  'when',
  'your',
  'can',
  'there',
  'an',
  'which',
  'their',
  'has',
  'will',
  'if',
  'would',
  'about',
  'them',
  'been',
  'these',
  'some',
  'into',
  'they',
  'he',
  'she',
  'do',
  'does',
  'my',
  'our',
  'please',
  'should',
  'must',
  'may',
};

/// Picks the TTS language for a document from Filipino vs English function
/// words.
///
/// Taglish leans Filipino: a Filipino voice reads English words acceptably,
/// while an English voice mangles Filipino. So Filipino wins whenever it has
/// at least 40% of the function-word hits. With no hits at all, [fallback].
LanguageGuess detectLanguage(
  String text, {
  DocLanguage fallback = DocLanguage.filipino,
}) {
  var fil = 0;
  var en = 0;
  for (final raw in text.toLowerCase().split(RegExp(r'[^a-zñ\x27’]+'))) {
    if (raw.isEmpty) continue;
    // "may" is common in both; count it for neither.
    if (raw == 'may') continue;
    if (filipinoStopWords.contains(raw)) fil++;
    if (englishStopWords.contains(raw)) en++;
  }
  final DocLanguage language;
  if (fil + en == 0) {
    language = fallback;
  } else {
    language = fil / (fil + en) >= 0.4
        ? DocLanguage.filipino
        : DocLanguage.english;
  }
  return LanguageGuess(language, filipinoHits: fil, englishHits: en);
}
