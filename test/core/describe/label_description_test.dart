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

  group('grouping', () {
    test('a broad label goes when a specific one of its group is there', () {
      final picked = pickLabels(const [
        LabelResult('Food', 0.95),
        LabelResult('Rice', 0.9),
        LabelResult('Tableware', 0.9),
        LabelResult('Plate', 0.88),
      ]);
      expect(picked.map((l) => l.label), ['Rice', 'Plate']);
    });

    test('a broad label stays when it stands alone in its group', () {
      final picked = pickLabels(const [
        LabelResult('Food', 0.95),
        LabelResult('Plate', 0.88),
      ]);
      expect(picked.map((l) => l.label), ['Food', 'Plate']);
    });

    test('groups are spoken together: people, animals, then objects', () {
      final text = offlineDescription(const [
        LabelResult('Table', 0.97),
        LabelResult('Dog', 0.96),
        LabelResult('Person', 0.9),
      ], fil);
      expect(text, 'May tao, aso, at mesa sa larawan.');
    });

    test('labels that share a word are said once ("cup" and "mug")', () {
      final text = offlineDescription(const [
        LabelResult('Cup', 0.95),
        LabelResult('Mug', 0.9),
        LabelResult('Table', 0.88),
      ], fil);
      expect(text, 'May tasa at mesa sa larawan.');
    });

    test('the same label seen twice is one label with a count', () {
      final picked = pickLabels(const [
        LabelResult('Cup', 0.8),
        LabelResult('Cup', 0.9),
        LabelResult('Plate', 0.75),
      ]);
      expect(picked.first.label, 'Cup');
      expect(picked.first.confidence, 0.9);
      expect(picked.first.count, 2);
    });
  });

  group('counts', () {
    test('a count above one is said as a number', () {
      expect(
        offlineDescription(const [LabelResult('Cup', 0.95, count: 2)], fil),
        'May 2 tasa sa larawan.',
      );
      expect(
        offlineDescription(const [LabelResult('Cup', 0.95, count: 3)], en),
        'There is 3 cups in the picture.',
      );
      expect(
        offlineDescription(const [LabelResult('Glass', 0.95, count: 2)], en),
        'There is 2 glasses in the picture.',
      );
    });

    test('a count of one (or unknown) says nothing', () {
      expect(
        offlineDescription(const [LabelResult('Cup', 0.95)], fil),
        'May tasa sa larawan.',
      );
    });
  });

  group('offlineDescription', () {
    const food = [
      LabelResult('Food', 0.93),
      LabelResult('Plate', 0.88),
      LabelResult('Table', 0.81),
    ];

    test('sure labels are plain, the unsure one is "mukhang"', () {
      expect(
        offlineDescription(food, fil),
        'May pagkain at plato sa larawan. Mukhang may mesa din.',
      );
    });

    test('English: plain for sure, "it also looks like" for unsure', () {
      expect(
        offlineDescription(food, en),
        'There is food and plate in the picture. '
        'It also looks like there is table.',
      );
    });

    test('all unsure: the whole sentence is "mukhang"', () {
      expect(
        offlineDescription(const [
          LabelResult('Food', 0.8),
          LabelResult('Plate', 0.75),
        ], fil),
        'Mukhang may pagkain at plato sa larawan.',
      );
      expect(
        offlineDescription(const [LabelResult('Dog', 0.72)], en),
        'It looks like there is dog in the picture.',
      );
    });

    test('all sure: no "mukhang" at all', () {
      final text = offlineDescription(const [
        LabelResult('Dog', 0.95),
        LabelResult('Grass', 0.9),
      ], fil);
      expect(text, 'May aso at damo sa larawan.');
      expect(text, isNot(contains('Mukhang')));
    });

    test('85 % is sure, just below is not', () {
      expect(
        offlineDescription(const [LabelResult('Dog', 0.85)], fil),
        'May aso sa larawan.',
      );
      expect(
        offlineDescription(const [LabelResult('Dog', 0.849)], fil),
        'Mukhang may aso sa larawan.',
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
        expect(text, startsWith('May '));
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
