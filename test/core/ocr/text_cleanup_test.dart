import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/ocr/text_cleanup.dart';

void main() {
  group('cleanText', () {
    test('joins lines that were only wrapped by the page', () {
      const raw =
          'Ang Bataan ay isang lalawigan sa rehiyon ng\n'
          'Gitnang Luzon at kilala sa kasaysayan nito\n'
          'noong digmaan.';
      expect(
        cleanText(raw),
        'Ang Bataan ay isang lalawigan sa rehiyon ng Gitnang Luzon at kilala '
        'sa kasaysayan nito noong digmaan.',
      );
    });

    test('rejoins words hyphenated across a line break', () {
      const raw =
          'Mahalaga ang pagbabasa para sa lahat ng impor-\n'
          'tanteng dokumento sa ating pang-araw-araw na buhay.';
      expect(cleanText(raw), contains('importanteng dokumento'));
      expect(
        cleanText(raw),
        contains('pang-araw-araw'),
        reason: 'real hyphens',
      );
    });

    test('keeps a hyphen when the next line starts a new capitalized word', () {
      const raw =
          'Ito ang Mabuhay-\nPilipinas na programa ng bayan ngayong taon.';
      expect(cleanText(raw), contains('Mabuhay- Pilipinas'));
    });

    test('preserves paragraphs', () {
      const raw =
          'Unang talata ito na sapat ang haba.\n\n\n  Ikalawang talata.  ';
      expect(
        cleanText(raw),
        'Unang talata ito na sapat ang haba.\n\nIkalawang talata.',
      );
    });

    test('keeps short lines (headings, list items) on their own', () {
      const raw =
          'RESIBO\n'
          'Bigas 5 kilo 250.00\n'
          'Asukal 1 kilo 80.00\n'
          'Kabuuan 330.00';
      expect(cleanText(raw).split('\n\n'), [
        'RESIBO',
        'Bigas 5 kilo 250.00',
        'Asukal 1 kilo 80.00',
        'Kabuuan 330.00',
      ]);
    });

    test('collapses whitespace and removes space before punctuation', () {
      expect(
        cleanText('Kumusta   ka ,\tkaibigan  ?', joinLines: false),
        'Kumusta ka, kaibigan?',
      );
    });

    test('drops OCR garbage lines', () {
      const raw =
          'Totoong teksto dito sa pahina.\n-------\n|| ~ |\n~^~\nWakas.';
      expect(cleanText(raw), 'Totoong teksto dito sa pahina. Wakas.');
    });

    test('without joinLines, every line is its own paragraph (DOCX)', () {
      expect(cleanText('Una\nIkalawa', joinLines: false), 'Una\n\nIkalawa');
    });

    test('removes invisible characters', () {
      expect(cleanText('Sal­ita​.'), 'Salita.');
    });
  });

  group('isGarbageLine', () {
    test('flags noise, keeps real short text', () {
      for (final noise in ['-----', '||', '~ ^ ~', '•', '.....']) {
        expect(isGarbageLine(noise), isTrue, reason: noise);
      }
      for (final text in ['Oo', '12', 'P 250.00', 'Hi!', 'Ñ']) {
        expect(isGarbageLine(text), isFalse, reason: text);
      }
    });
  });

  group('assessQuality', () {
    test('empty, low and good', () {
      expect(assessQuality(''), TextQuality.empty);
      expect(assessQuality('1234 5678'), TextQuality.empty);
      expect(assessQuality('Oo po'), TextQuality.low);
      expect(assessQuality('xq7 #@ l1 !! %3 a,b ;;'), TextQuality.low);
      expect(
        assessQuality('Magandang umaga sa inyong lahat, mga kababayan.'),
        TextQuality.good,
      );
    });

    test('low OCR confidence lowers quality', () {
      const text = 'Magandang umaga sa inyong lahat, mga kababayan.';
      expect(assessQuality(text, ocrConfidence: 0.3), TextQuality.low);
      expect(assessQuality(text, ocrConfidence: 0.9), TextQuality.good);
    });
  });
}
