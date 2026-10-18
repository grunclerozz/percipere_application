import 'validators.dart';

/// What the user said to "J-U-A-N, tama ba?".
enum SpellAnswer {
  /// "tama", "oo", "yes": the spelling is right.
  yes,

  /// "mali", "hindi", "no": say or spell it again.
  no,

  /// Something else (a new name, a command).
  none,
}

/// Spelling names letter by letter, so a blind user can check what the
/// recognizer heard: "Juan" → "J-U-A-N", and a spelled "j u a n" → "Juan".
abstract final class NameSpelling {
  /// "Juan Carlos" → "J-U-A-N, C-A-R-L-O-S" (words are read apart by a
  /// pause).
  static String spell(String name) => name
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w.split('').map((c) => c.toUpperCase()).join('-'))
      .join(', ');

  /// How a recognizer may write the name of a letter.
  static const Map<String, String> _letterNames = {
    'ey': 'a', 'bi': 'b', 'bee': 'b', 'see': 'c', 'dee': 'd', 'di': 'd', //
    'ji': 'g', 'gee': 'g', 'eych': 'h', 'aitch': 'h', 'jey': 'j', //
    'jay': 'j', 'kay': 'k', 'key': 'k', 'el': 'l', 'em': 'm', 'en': 'n', //
    'enye': 'ñ', 'pi': 'p', 'pee': 'p', 'kyu': 'q', 'cue': 'q', 'ar': 'r', //
    'es': 's', 'ess': 's', 'ti': 't', 'tee': 't', 'yu': 'u', 'vi': 'v', //
    'vee': 'v', 'eks': 'x', 'ex': 'x', 'wai': 'y', 'why': 'y', 'zi': 'z', //
    'zee': 'z', 'zed': 'z', 'ef': 'f', 'dobolyu': 'w', //
  };

  /// Words that put a space between two spelled words.
  static const Set<String> _spaceWords = {
    'space',
    'espasyo',
    'pagitan',
    'gap',
  };

  static List<String> _words(String spoken) => spoken
      .toLowerCase()
      .split(RegExp(r'[^a-zñ]+'))
      .where((w) => w.isNotEmpty)
      .toList();

  /// A name spelled letter by letter ("j u a n", "J. U. A. N.", "jey yu ey
  /// en") as a capitalized name, or null when [spoken] isn't spelled: at
  /// least two words and every one a single letter, a letter's name or
  /// "space".
  static String? parseSpelled(String spoken) {
    final words = _words(spoken);
    if (words.length < 2) return null;
    final out = StringBuffer();
    for (final w in words) {
      if (_spaceWords.contains(w)) {
        out.write(' ');
      } else if (w.length == 1) {
        out.write(w);
      } else if (_letterNames.containsKey(w)) {
        out.write(_letterNames[w]);
      } else {
        return null;
      }
    }
    final name = AuthRules.spokenName(out.toString());
    return name.isEmpty ? null : name;
  }

  static const Set<String> _yes = {
    'tama', 'oo', 'opo', 'yes', 'yeah', 'yep', 'correct', 'right', 'sige',
    'okay', 'ok', //
  };

  static const Set<String> _no = {
    'mali', 'hindi', 'ayoko', 'no', 'wrong', 'ulit', 'again', 'retry', //
  };

  /// Filler that may come with a yes ("tama po", "oo tama na").
  static const Set<String> _filler = {'po', 'na', 'yan', 'iyan', 'ito', 'ay'};

  /// Whether [spoken] says the spelling is right or wrong. A no wins over a
  /// yes ("hindi tama" is a no).
  static SpellAnswer answer(String spoken) {
    final words = _words(spoken);
    if (words.isEmpty) return SpellAnswer.none;
    final known = words.every(
      (w) => _yes.contains(w) || _no.contains(w) || _filler.contains(w),
    );
    if (!known) return SpellAnswer.none;
    if (words.any(_no.contains)) return SpellAnswer.no;
    if (words.any(_yes.contains)) return SpellAnswer.yes;
    return SpellAnswer.none;
  }
}
