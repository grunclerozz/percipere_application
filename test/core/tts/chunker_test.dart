import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/tts/chunker.dart';

List<String> texts(String doc) => [
  for (final s in chunkText(doc)) doc.substring(s.start, s.end),
];

void main() {
  test('splits sentences with exact offsets and paragraph numbers', () {
    const doc = 'Una ito. Ikalawa ba? Oo!\n\nBagong talata.';
    final s = chunkText(doc);
    expect(texts(doc), ['Una ito.', 'Ikalawa ba?', 'Oo!', 'Bagong talata.']);
    expect(s.map((x) => x.paragraph), [0, 0, 0, 1]);
    expect(doc.substring(s[1].start, s[1].end), 'Ikalawa ba?');
    expect(s[3].range.start, doc.indexOf('Bagong'));
  });

  test('does not break after abbreviations, initials or decimals', () {
    const doc =
        'Si Gng. Cruz at Dr. Santos ay dumating. Si J. Rizal ay bayani. '
        'Ang presyo ay P250.00 lamang. Tapos.';
    expect(texts(doc), [
      'Si Gng. Cruz at Dr. Santos ay dumating.',
      'Si J. Rizal ay bayani.',
      'Ang presyo ay P250.00 lamang.',
      'Tapos.',
    ]);
  });

  test('a lowercase next word means the break was false', () {
    expect(texts('Mga prutas, hal. mangga at saging. Tapos.'), [
      'Mga prutas, hal. mangga at saging.',
      'Tapos.',
    ]);
  });

  test('keeps closing quotes and brackets with the sentence', () {
    expect(texts('Sabi niya, "Salamat." (Tama.) Wakas.'), [
      'Sabi niya, "Salamat."',
      '(Tama.)',
      'Wakas.',
    ]);
  });

  test('text without end punctuation is one sentence per paragraph', () {
    expect(texts('Bigas 250.00\n\nAsukal 80.00'), [
      'Bigas 250.00',
      'Asukal 80.00',
    ]);
  });

  test('very long sentences are split at a comma or space', () {
    final long = List.filled(40, 'isang salita,').join(' ');
    final parts = chunkText(long, maxLength: 100);
    expect(parts.length, greaterThan(3));
    for (final p in parts) {
      expect(p.end - p.start, lessThanOrEqualTo(100));
    }
    // Nothing lost or duplicated (apart from whitespace between parts).
    expect(parts.map((p) => long.substring(p.start, p.end)).join(' '), long);
  });

  test('textIn flattens line breaks for speech', () {
    const doc = 'Isang pangungusap\nna nahati.';
    expect(chunkText(doc).single.textIn(doc), 'Isang pangungusap na nahati.');
  });

  test('paragraphStarts', () {
    final s = chunkText('A b. C d.\n\nE f.\n\nG h. I j.');
    expect(paragraphStarts(s), [0, 2, 3]);
  });

  test('empty text has no sentences', () {
    expect(chunkText(''), isEmpty);
    expect(chunkText('  \n\n  '), isEmpty);
  });

  test('titleFor uses the first line, shortened at a word boundary', () {
    expect(
      titleFor('\n  Paunawa sa Barangay\nIkalawang linya'),
      'Paunawa sa Barangay',
    );
    final t = titleFor(
      'Ito ay isang napakahabang unang linya ng dokumento na lampas sa '
      'animnapung titik ang haba',
    );
    expect(t.length, lessThanOrEqualTo(61));
    expect(t, endsWith('…'));
    expect(titleFor(''), '');
  });
}
