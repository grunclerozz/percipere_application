/// Preprocessing and feature analyzers of Percy's intent classifier.
///
/// An exact copy of `scripts/percy/percy_text.py`; the model is trained on
/// what the Python version produces, so any change must be made in both
/// (the test vectors check that they agree).
abstract final class PercyText {
  /// Accented letters folded to plain ones.
  static const Map<String, String> fold = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', //
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', //
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', //
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', //
    'ñ': 'n', 'ç': 'c',
  };

  /// Removed only as the wake word ("Percy, …", "hey Percy …").
  static const Set<String> wakeWords = {'percy', 'persi', 'percey'};

  /// Common automatic-speech-recognition spellings mapped token by token.
  static const Map<String, String> corrections = {
    'aklatann': 'aklatan', 'aklatam': 'aklatan', 'libary': 'library',
    'seting': 'settings', 'setings': 'settings', 'settngs': 'settings',
    'maglarawn': 'maglarawan', 'maglarwan': 'maglarawan',
    'ilarawn': 'ilarawan', 'deskribe': 'describe', 'describ': 'describe',
    'tutoryal': 'tutorial', 'tutoriyal': 'tutorial',
  };

  /// Polite words and speech disfluencies that do not change an intent.
  static const Set<String> fillers = {
    'po', 'opo', 'pakisuyo', 'pakiusap', 'please', 'nga', 'naman',
  };

  /// Word n-gram lengths.
  static const (int, int) wordNgrams = (1, 2);

  /// Character n-gram lengths (inside each padded word).
  static const (int, int) charNgrams = (3, 5);

  static final RegExp _drop = RegExp(r"[-'’]");
  static final RegExp _other = RegExp(r'[^a-z0-9 ]');
  static final RegExp _spaces = RegExp(r'\s+');

  /// Lowercase, fold accents, correct common STT spellings, and drop fillers.
  /// Negation words (hindi, huwag, wag, ayoko, no, not) are always kept.
  static String preprocess(String text) {
    final lower = text.toLowerCase();
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final ch = String.fromCharCode(rune);
      buffer.write(fold[ch] ?? ch);
    }
    final cleaned = buffer
        .toString()
        .replaceAll(_drop, '')
        .replaceAll(_other, ' ');
    final words = cleaned.split(_spaces).where((w) => w.isNotEmpty).toList();
    final corrected = [for (final w in words) corrections[w] ?? w];
    final kept = <String>[];
    for (var i = 0; i < corrected.length; i++) {
      final w = corrected[i];
      if (wakeWords.contains(w)) continue;
      if (w == 'hey' &&
          i + 1 < corrected.length &&
          wakeWords.contains(corrected[i + 1])) {
        continue;
      }
      if (fillers.contains(w)) continue;
      if (w == 'ano' &&
          i + 1 < corrected.length &&
          !const {'ang', 'itong', 'iyan', 'yun'}.contains(corrected[i + 1])) {
        continue;
      }
      kept.add(w);
    }
    return kept.isEmpty ? corrected.join(' ') : kept.join(' ');
  }

  /// Word unigrams and bigrams of preprocessed text.
  static List<String> wordFeatures(String clean) {
    final words = clean.split(' ').where((w) => w.isNotEmpty).toList();
    final out = <String>[];
    for (var n = wordNgrams.$1; n <= wordNgrams.$2; n++) {
      for (var i = 0; i + n <= words.length; i++) {
        out.add(words.sublist(i, i + n).join(' '));
      }
    }
    return out;
  }

  /// Character 3–5-grams inside each word padded with spaces (" word ").
  static List<String> charFeatures(String clean) {
    final out = <String>[];
    for (final w in clean.split(' ').where((w) => w.isNotEmpty)) {
      final padded = ' $w ';
      for (var n = charNgrams.$1; n <= charNgrams.$2; n++) {
        for (var i = 0; i + n <= padded.length; i++) {
          out.add(padded.substring(i, i + n));
        }
      }
    }
    return out;
  }
}
