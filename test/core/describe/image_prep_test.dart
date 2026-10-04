import 'dart:io';

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:percipere_app/core/describe/image_prep.dart';

Uint8List _png(int width, int height) =>
    Uint8List.fromList(img.encodePng(img.Image(width: width, height: height)));

void main() {
  test('a large image is shrunk to 1600 on its longest side, as JPEG', () {
    final out = resizeToJpeg(_png(3200, 1200), uploadMaxSide)!;
    final decoded = img.decodeJpg(out)!;
    expect(decoded.width, 1600);
    expect(decoded.height, 600);
  });

  test('a tall image is limited by its height', () {
    final decoded = img.decodeJpg(resizeToJpeg(_png(900, 2400), 1600)!)!;
    expect(decoded.height, 1600);
    expect(decoded.width, 600);
  });

  test('a small image is never enlarged', () {
    final decoded = img.decodeJpg(resizeToJpeg(_png(400, 300), 1600)!)!;
    expect([decoded.width, decoded.height], [400, 300]);
  });

  test('bytes that are not an image give null', () {
    expect(resizeToJpeg(Uint8List.fromList([1, 2, 3]), 1600), isNull);
  });

  group('deleteThumbnail', () {
    test('removes the file', () async {
      final dir = Directory.systemTemp.createTempSync('thumb_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/t.jpg')..writeAsBytesSync([1, 2, 3]);
      await deleteThumbnail(file.path);
      expect(file.existsSync(), isFalse);
    });

    test('a missing file or no path is fine', () async {
      await deleteThumbnail('/does/not/exist.jpg');
      await deleteThumbnail(null);
    });
  });
}
