import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/offline_voice/filipino_numbers.dart';
import 'package:percipere_app/core/offline_voice/offline_speaker.dart';

void main() {
  group('Filipino numbers for the Tagalog voice', () {
    test('words', () {
      expect(FilipinoNumbers.words(0), 'sero');
      expect(FilipinoNumbers.words(7), 'pito');
      expect(FilipinoNumbers.words(10), 'sampu');
      expect(FilipinoNumbers.words(12), 'labingdalawa');
      expect(FilipinoNumbers.words(21), "dalawampu't isa");
      expect(FilipinoNumbers.words(100), 'isang daan');
      expect(FilipinoNumbers.words(400), 'apat na raan');
      expect(FilipinoNumbers.words(345), "tatlong daan at apatnapu't lima");
      expect(FilipinoNumbers.words(2000), 'dalawang libo');
    });

    test('in text, with percent', () {
      expect(
        FilipinoNumbers.spell('Pahina 5 sa 20. 40% na.'),
        'Pahina lima sa dalawampu. apatnapu porsiyento na.',
      );
      expect(FilipinoNumbers.spell('PRC 0915'), 'PRC sero siyam isa lima');
    });
  });

  group('offline voice', () {
    test('language of a TTS tag', () {
      expect(OfflineSpeaker.languageOf('fil-PH'), 'fil');
      expect(OfflineSpeaker.languageOf('tl_PH'), 'fil');
      expect(OfflineSpeaker.languageOf('en-US'), 'en');
      expect(OfflineSpeaker.languageOf('es-ES'), isNull);
    });

    test('long text is cut at sentence ends, short enough to start soon', () {
      final text = List.filled(12, 'Ito ay isang pangungusap na mahaba.').join(' ');
      final pieces = OfflineSpeaker.split(text);
      expect(pieces.length, greaterThan(1));
      expect(
        pieces.first.length,
        lessThanOrEqualTo(OfflineSpeaker.firstPieceLength),
        reason: 'the first piece is short, so speech starts soon',
      );
      for (final p in pieces) {
        expect(p.length, lessThanOrEqualTo(OfflineSpeaker.pieceLength));
        expect(p.endsWith('.'), isTrue);
      }
      expect(pieces.join(' '), text);
    });

    test('pieces without letters are dropped', () {
      expect(OfflineSpeaker.split(' … '), isEmpty);
      expect(OfflineSpeaker.split('Handa na.'), ['Handa na.']);
    });
  });
}
