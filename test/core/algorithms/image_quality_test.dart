import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:percipere_app/core/algorithms/image_quality.dart';

/// A black-and-white checkerboard of [cell]-pixel squares, [size] square.
img.Image checkerboard({int size = 240, int cell = 8}) {
  final image = img.Image(width: size, height: size);
  for (final p in image) {
    final on = ((p.x ~/ cell) + (p.y ~/ cell)).isEven;
    final v = on ? 235 : 20;
    p.setRgb(v, v, v);
  }
  return image;
}

Uint8List png(img.Image image) => Uint8List.fromList(img.encodePng(image));

img.Image flat(int value, {int size = 120}) {
  final image = img.Image(width: size, height: size);
  for (final p in image) {
    p.setRgb(value, value, value);
  }
  return image;
}

void main() {
  test('a sharp image scores far higher than its blurred copy', () {
    final sharp = checkerboard();
    final blurred = img.gaussianBlur(checkerboard(), radius: 6);
    final a = measureImageQuality(png(sharp))!;
    final b = measureImageQuality(png(blurred))!;
    expect(a.sharpness, greaterThan(b.sharpness * 5));
    expect(a.issue, isNull);
    expect(b.issue, ImageIssue.blurry);
  });

  test('laplacianVariance is 0 for a flat image', () {
    final gray = Uint8List.fromList(List.filled(100, 128));
    expect(laplacianVariance(gray, 10, 10), 0);
  });

  test('laplacianVariance of a single bright pixel is known', () {
    // 5x5, all 0 except the centre = 100. Response: centre -400, its four
    // neighbours +100, the rest of the 3x3 interior 0 (9 pixels).
    final gray = Uint8List(25)..[12] = 100;
    // mean = (−400 + 4·100) / 9 = 0; E[x²] = (160000 + 4·10000) / 9
    expect(laplacianVariance(gray, 5, 5), closeTo(200000 / 9, 1e-9));
  });

  test('images smaller than the kernel give 0', () {
    expect(laplacianVariance(Uint8List(4), 2, 2), 0);
  });

  test('brightness is the mean luminance', () {
    expect(meanBrightness(Uint8List.fromList([0, 100, 200, 100])), 100);
    expect(meanBrightness(Uint8List(0)), 0);
  });

  test('dark and bright photos are flagged before blur', () {
    expect(measureImageQuality(png(flat(10)))!.issue, ImageIssue.tooDark);
    expect(measureImageQuality(png(flat(250)))!.issue, ImageIssue.tooBright);
    // A mid-grey flat image is only blurry.
    expect(measureImageQuality(png(flat(128)))!.issue, ImageIssue.blurry);
  });

  test('grayscale uses 0.299 R + 0.587 G + 0.114 B', () {
    final image = img.Image(width: 1, height: 1)
      ..setPixelRgb(0, 0, 100, 200, 50);
    expect(
      toGrayscale(image).single,
      (0.299 * 100 + 0.587 * 200 + 0.114 * 50).round(),
    );
  });

  test('bytes that are not an image give null', () {
    expect(measureImageQuality(Uint8List.fromList([1, 2, 3, 4])), isNull);
  });

  test('big photos are shrunk before measuring', () {
    final big = checkerboard(size: 1000, cell: 20);
    expect(measureImageQuality(png(big))!.brightness, closeTo(127, 10));
  });
}
