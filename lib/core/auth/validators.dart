/// Input rules and spoken-input clean-up for account forms.
abstract final class AuthRules {
  /// Shortest allowed password.
  static const int minPasswordLength = 8;

  static final RegExp _email = RegExp(
    r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}$',
  );

  /// Emails are stored and compared trimmed and lowercased.
  static String normalizeEmail(String email) => email.trim().toLowerCase();

  /// Whether [email] looks like an email address.
  static bool isValidEmail(String email) =>
      _email.hasMatch(normalizeEmail(email));

  /// Whether [password] is long enough.
  static bool isValidPassword(String password) =>
      password.length >= minPasswordLength;

  /// A dictated email made usable: "juan dela cruz at gmail dot com" →
  /// "juandelacruz@gmail.com". "at" → `@`; "dot" / "tuldok" / "punto" → `.`;
  /// "underscore" → `_`; "dash" / "gitling" → `-`.
  static String spokenEmail(String spoken) {
    var s = ' ${spoken.toLowerCase().trim()} ';
    // The recognizer may already have written "@" or "." — keep those.
    s = s
        .replaceAll(RegExp(r'\s(at|at sign)\s'), ' @ ')
        .replaceAll(RegExp(r'\s(dot|tuldok|punto)\s'), ' . ')
        .replaceAll(RegExp(r'\s(underscore)\s'), ' _ ')
        .replaceAll(RegExp(r'\s(dash|gitling|hyphen)\s'), ' - ');
    return s.replaceAll(RegExp(r'\s+'), '');
  }

  /// A dictated password: spaces removed and lowercased, because speech
  /// recognizers capitalize and space words unpredictably. (Typed passwords
  /// are kept exactly as typed.)
  static String spokenPassword(String spoken) =>
      spoken.replaceAll(RegExp(r'\s+'), '').toLowerCase();

  /// Whether [code] is an emailed 6-digit code.
  static bool isValidCode(String code) => RegExp(r'^\d{6}$').hasMatch(code);

  /// Digit words the recognizer may write out (Filipino, Spanish-derived
  /// and English): "isa dalawa tres" → "123".
  static const Map<String, String> _digitWords = {
    'sero': '0', 'zero': '0', 'oh': '0', //
    'isa': '1', 'uno': '1', 'one': '1', //
    'dalawa': '2', 'dos': '2', 'two': '2', //
    'tatlo': '3', 'tres': '3', 'three': '3', //
    'apat': '4', 'kuwatro': '4', 'kwatro': '4', 'four': '4', //
    'lima': '5', 'singko': '5', 'five': '5', //
    'anim': '6', 'sais': '6', 'six': '6', //
    'pito': '7', 'siyete': '7', 'seven': '7', //
    'walo': '8', 'otso': '8', 'eight': '8', //
    'siyam': '9', 'nuwebe': '9', 'nine': '9', //
  };

  /// A dictated code: digits kept, digit words turned into digits,
  /// everything else (spaces, dashes, filler) dropped.
  static String spokenCode(String spoken) {
    final out = StringBuffer();
    for (final word in spoken.toLowerCase().split(RegExp(r'[\s,.\-]+'))) {
      final digits = word.replaceAll(RegExp(r'\D'), '');
      out.write(digits.isNotEmpty ? digits : (_digitWords[word] ?? ''));
    }
    return out.toString();
  }

  /// A dictated name: trimmed, single spaces, each word capitalized.
  static String spokenName(String spoken) => spoken
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');

  static const Map<String, String> _plain = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', //
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', //
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', //
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', //
    'ñ': 'n', 'ç': 'c',
  };

  /// A security answer as it is hashed and compared: lowercase, no
  /// diacritics or punctuation, single spaces, trimmed — so "Sto. Niño" and
  /// "sto nino" match whether typed or spoken.
  static String normalizeAnswer(String answer) {
    final lower = answer.toLowerCase();
    final buffer = StringBuffer();
    for (final ch in lower.split('')) {
      buffer.write(_plain[ch] ?? ch);
    }
    return buffer
        .toString()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
