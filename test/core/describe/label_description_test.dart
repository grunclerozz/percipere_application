import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/config/image_labels_fil.dart';
import 'package:percipere_app/core/describe/image_labeler.dart';
import 'package:percipere_app/core/describe/label_description.dart';
import 'package:percipere_app/l10n/app_localizations.dart';

void main() {
  final fil = lookupAppLocalizations(const Locale('fil'));
  final en = lookupAppLocalizations(const Locale('en'));

  group('pickLabels', () {
    test('keeps only confidence of at least 0.7, best first, at most 3', () {
      final picked = pickLabels(const [
        LabelResult('Spoon', 0.55),
        LabelResult('Table', 0.81),
        LabelResult('Food', 0.93),
        LabelResult('Cup', 0.7),
        LabelResult('Plate', 0.88),
        LabelResult('Bowl', 0.75),
      ]);
      expect(picked.map((l) => l.label), ['Food', 'Plate', 'Table']);
    });

    test('0.7 passes, just below does not', () {
      expect(pickLabels(const [LabelResult('Cup', 0.7)]), hasLength(1));
      expect(pickLabels(const [LabelResult('Cup', 0.699)]), isEmpty);
    });

    test('nothing confident enough gives an empty list', () {
      expect(pickLabels(const [LabelResult('Cup', 0.5)]), isEmpty);
      expect(pickLabels(const []), isEmpty);
    });
  });

  group('translation', () {
    test('known labels are in Filipino, any capitalization', () {
      expect(translateLabel('Plate', filipino: true), 'plato');
      expect(translateLabel(' FOOD ', filipino: true), 'pagkain');
    });

    test('labels missing from the map fall back to English', () {
      expect(imageLabelsFil.containsKey('quokka'), isFalse);
      expect(translateLabel('Quokka', filipino: true), 'quokka');
    });

    test('English speech keeps the English label', () {
      expect(translateLabel('Plate', filipino: false), 'plate');
    });
  });

  group('joining', () {
    test('one, two and three items', () {
      expect(joinLabels(['a'], fil), 'a');
      expect(joinLabels(['a', 'b'], fil), 'a at b');
      expect(joinLabels(['a', 'b', 'c'], fil), 'a, b, at c');
      expect(joinLabels(['a', 'b', 'c'], en), 'a, b, and c');
    });
  });

  group('offlineDescription', () {
    const food = [
      LabelResult('Food', 0.93),
      LabelResult('Plate', 0.88),
      LabelResult('Table', 0.81),
    ];

    test('starts with "Mukhang" and uses Filipino labels', () {
      expect(
        offlineDescription(food, fil),
        'Mukhang may pagkain, plato, at mesa sa larawan.',
      );
    });

    test('English starts with "It looks like"', () {
      expect(
        offlineDescription(food, en),
        'It looks like there is food, plate, and table in the picture.',
      );
    });

    test('no confident label: asks to try again with brighter light', () {
      expect(
        offlineDescription(const [LabelResult('Cup', 0.4)], fil),
        'Hindi ko matiyak kung ano ang nasa larawan. '
        'Subukan ulit na may mas maliwanag na ilaw.',
      );
    });

    test('medicine or money adds the reminder', () {
      for (final label in ['Medicine', 'Pill', 'Money', 'Coin']) {
        final text = offlineDescription([LabelResult(label, 0.9)], fil);
        expect(text, startsWith('Mukhang'));
        expect(
          text,
          endsWith(
            'Paalala: kumpirmahin ito sa taong pinagkakatiwalaan mo bago '
            'gamitin.',
          ),
          reason: label,
        );
      }
      expect(offlineDescription(food, fil), isNot(contains('Paalala')));
    });

    test('a reminder label below the threshold adds nothing', () {
      final text = offlineDescription(const [
        LabelResult('Plate', 0.9),
        LabelResult('Pill', 0.5),
      ], fil);
      expect(text, isNot(contains('Paalala')));
    });
  });
}
