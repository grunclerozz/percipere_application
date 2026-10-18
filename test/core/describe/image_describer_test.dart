// The ImageDescriber interface and its offline (ML Kit) implementation.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/describe/image_describer.dart';
import 'package:percipere_app/l10n/app_localizations.dart';

import '../../helpers/fakes.dart';

void main() {
  final fil = lookupAppLocalizations(const Locale('fil'));
  final en = lookupAppLocalizations(const Locale('en'));

  test('MlKitImageDescriber labels the picture and words the result', () async {
    final labeler = FakeImageLabeler();
    final describer = MlKitImageDescriber(labeler);
    final result = await describer.describe('photo.jpg', fil);
    expect(labeler.labeled, ['photo.jpg']);
    expect(
      result.text,
      'May pagkain at plato sa larawan. Mukhang may mesa din.',
    );
    expect(result.labels, labeler.results);
    expect(
      (await describer.describe('photo.jpg', en)).text,
      'There is food and plate in the picture. '
      'It also looks like there is table.',
    );
  });

  test('an unreadable image throws (the screen says so)', () async {
    final labeler = FakeImageLabeler()..fail = true;
    await expectLater(
      MlKitImageDescriber(labeler).describe('bad.jpg', fil),
      throwsA(isA<StateError>()),
    );
  });

  test('another describer can sit behind the same interface', () async {
    final ImageDescriber online = _Scripted();
    final result = await online.describe('photo.jpg', fil);
    expect(result.text, 'Isang aso sa damuhan.');
    expect(result.labels, isEmpty);
  });
}

/// Stands in for a future online describer: no labels, its own sentence.
class _Scripted implements ImageDescriber {
  @override
  Future<ImageDescription> describe(
    String path,
    AppLocalizations strings,
  ) async => const ImageDescription('Isang aso sa damuhan.');

  @override
  Future<void> close() async {}
}
