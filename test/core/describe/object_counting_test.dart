// Offline object counting: the phrase builder and its place in the ML Kit
// describer.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/config/count_words.dart';
import 'package:percipere_app/core/describe/image_describer.dart';
import 'package:percipere_app/core/describe/image_labeler.dart';
import 'package:percipere_app/core/describe/object_counting.dart';
import 'package:percipere_app/core/describe/object_detector.dart';
import 'package:percipere_app/l10n/app_localizations.dart';

import '../../helpers/fakes.dart';

void main() {
  final fil = lookupAppLocalizations(const Locale('fil'));
  final en = lookupAppLocalizations(const Locale('en'));

  List<FoundObject> at(List<double> xs) => [for (final x in xs) FoundObject(x)];

  group('FoundObject.side', () {
    test('thirds of the picture', () {
      expect(const FoundObject(0).side, ObjectSide.left);
      expect(const FoundObject(0.33).side, ObjectSide.left);
      expect(const FoundObject(0.34).side, ObjectSide.middle);
      expect(const FoundObject(0.66).side, ObjectSide.middle);
      expect(const FoundObject(0.67).side, ObjectSide.right);
      expect(const FoundObject(1).side, ObjectSide.right);
    });
  });

  group('number words', () {
    test('Filipino words and links before a noun', () {
      expect(countWordBeforeNoun(1, filipino: true), 'isang');
      expect(countWordBeforeNoun(3, filipino: true), 'tatlong');
      expect(countWordBeforeNoun(4, filipino: true), 'apat na');
      expect(countWordBeforeNoun(11, filipino: true), '11 na');
      expect(countWord(2, filipino: true), 'dalawa');
      expect(countWord(2, filipino: false), 'two');
      expect(countWord(12, filipino: true), '12');
    });
  });

  group('countingPhrase', () {
    const sureLabels = [
      LabelResult('Cup', 0.95),
      LabelResult('Book', 0.92),
      LabelResult('Bottle', 0.9),
    ];

    test('nothing found says nothing', () {
      expect(countingPhrase(const [], sureLabels, fil), isNull);
    });

    test('every object named and sure: stated plainly, with positions', () {
      final objects = at([0.1, 0.5, 0.9]);
      expect(
        countingPhrase(objects, sureLabels, fil),
        'May tatlong bagay: isang tasa, isang libro, at isang bote. '
        'Isa sa kaliwa, isa sa gitna, at isa sa kanan.',
      );
      expect(
        countingPhrase(objects, sureLabels, en),
        'There are 3 objects: a cup, a book, and a bottle. '
        'One on the left, one in the middle, and one on the right.',
      );
    });

    test('fewer names than objects: "mukhang" and "mga"', () {
      final objects = at([0.1, 0.2]);
      expect(
        countingPhrase(objects, const [LabelResult('Cup', 0.95)], fil),
        'Mukhang may dalawang bagay, mga tasa. Dalawa sa kaliwa.',
      );
      expect(
        countingPhrase(objects, const [LabelResult('Cup', 0.95)], en),
        'It looks like there are 2 objects, such as a cup. Two on the left.',
      );
    });

    test('a name that is not confident enough is unsure too', () {
      expect(
        countingPhrase(at([0.5]), const [LabelResult('Cup', 0.75)], fil),
        'Mukhang may isang bagay, mga tasa. Isa sa gitna.',
      );
    });

    test('no usable names: only the count and the places', () {
      expect(
        countingPhrase(at([0.5]), const [], fil),
        'May isang bagay sa larawan. Isa sa gitna.',
      );
      expect(
        countingPhrase(at([0.5]), const [], en),
        'There is 1 object in the picture. One in the middle.',
      );
      // Scenery is not an object.
      expect(
        countingPhrase(at([0.5, 0.9]), const [LabelResult('Sky', 0.97)], fil),
        'May dalawang bagay sa larawan. Isa sa gitna at isa sa kanan.',
      );
    });

    test('more objects than names: only as many names as objects', () {
      expect(
        countingPhrase(at([0.5]), sureLabels, fil),
        'May isang bagay: isang tasa. Isa sa gitna.',
      );
    });

    test('big numbers are said with digits', () {
      expect(
        countingPhrase(at([for (var i = 0; i < 12; i++) 0.1]), const [], fil),
        'May 12 na bagay sa larawan. 12 sa kaliwa.',
      );
      expect(
        countingPhrase(at([0.1, 0.1, 0.1, 0.1]), const [], fil),
        'May apat na bagay sa larawan. Apat sa kaliwa.',
      );
    });
  });

  group('MlKitImageDescriber with counting', () {
    test('the counting sentence follows the label sentence', () async {
      final detector = FakeObjectDetector()..results = at([0.2, 0.8]);
      final describer = MlKitImageDescriber(
        FakeImageLabeler(),
        objectDetector: detector,
      );
      final text = (await describer.describe('photo.jpg', fil)).text;
      expect(
        text,
        startsWith('May pagkain at plato sa larawan. Mukhang may mesa din. '),
      );
      expect(text, contains('dalawang bagay'));
      expect(text, endsWith('Isa sa kaliwa at isa sa kanan.'));
    });

    test('a failing detector leaves the label sentence alone', () async {
      final detector = FakeObjectDetector()..fail = true;
      final describer = MlKitImageDescriber(
        FakeImageLabeler(),
        objectDetector: detector,
      );
      expect(
        (await describer.describe('photo.jpg', fil)).text,
        'May pagkain at plato sa larawan. Mukhang may mesa din.',
      );
    });

    test('nothing detected: the label sentence alone', () async {
      final describer = MlKitImageDescriber(
        FakeImageLabeler(),
        objectDetector: FakeObjectDetector(),
      );
      expect(
        (await describer.describe('photo.jpg', fil)).text,
        'May pagkain at plato sa larawan. Mukhang may mesa din.',
      );
    });
  });
}
