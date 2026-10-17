/// Spells numbers as Filipino words for the offline Tagalog voice, which
/// reads letters only ("Pahina 12" → "Pahina labindalawa").
abstract final class FilipinoNumbers {
  static const List<String> _ones = [
    'sero',
    'isa',
    'dalawa',
    'tatlo',
    'apat',
    'lima',
    'anim',
    'pito',
    'walo',
    'siyam',
  ];

  /// Numbers above this are read digit by digit.
  static const int max = 999999;

  /// [text] with every whole number (and percentages) spelled out.
  static String spell(String text) => text
      .replaceAllMapped(RegExp(r'(\d+)\s*%'), (m) {
        final n = int.tryParse(m.group(1)!);
        return n == null ? m.group(0)! : '${words(n)} porsiyento';
      })
      .replaceAllMapped(RegExp(r'\d+'), (m) {
        final digits = m.group(0)!;
        final n = int.tryParse(digits);
        if (n == null || n > max || (digits.length > 1 && digits[0] == '0')) {
          return digits.split('').map((d) => _ones[int.parse(d)]).join(' ');
        }
        return words(n);
      });

  /// [n] (0..[max]) in Filipino words.
  static String words(int n) {
    if (n < 10) return _ones[n];
    if (n == 10) return 'sampu';
    if (n < 20) return 'labing${_ones[n - 10]}';
    if (n < 100) {
      final tens = _tens(n ~/ 10);
      final rest = n % 10;
      return rest == 0 ? tens : '$tens\'t ${_ones[rest]}';
    }
    if (n < 1000) {
      final hundreds = _group(n ~/ 100, 'daan');
      final rest = n % 100;
      return rest == 0 ? hundreds : '$hundreds at ${words(rest)}';
    }
    final thousands = _group(n ~/ 1000, 'libo');
    final rest = n % 1000;
    return rest == 0 ? thousands : '$thousands ${words(rest)}';
  }

  /// "dalawampu", "tatlumpu" …
  static String _tens(int t) => switch (t) {
    2 => 'dalawampu',
    3 => 'tatlumpu',
    4 => 'apatnapu',
    5 => 'limampu',
    6 => 'animnapu',
    7 => 'pitumpu',
    8 => 'walumpu',
    _ => 'siyamnapu',
  };

  /// "isang daan", "dalawang daan", "tatlong libo", "apat na raan" …
  static String _group(int count, String unit) {
    final number = words(count);
    final last = number[number.length - 1];
    final vowelEnd = 'aeiou'.contains(last);
    // After a vowel the linker is "-ng" and "daan" stays; after a
    // consonant it is "na" and "daan" becomes "raan".
    if (vowelEnd) return '${number}ng $unit';
    return '$number na ${unit == 'daan' ? 'raan' : unit}';
  }
}
