import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:percipere_app/core/algorithms/otsu.dart';

void main() {
  test('a two-tone histogram splits between the tones', () {
    final h = List<int>.filled(256, 0);
    h[40] = 500;
    h[200] = 500;
    final t = otsuThreshold(h);
    expect(t, inInclusiveRange(40, 199));
  });

  test('two noisy clusters split between their means', () {
    final h = List<int>.filled(256, 0);
    for (var i = 30; i <= 50; i++) {
      h[i] = 100 - (i - 40).abs() * 5;
    }
    for (var i = 190; i <= 220; i++) {
      h[i] = 80 - (i - 205).abs() * 4;
    }
    final t = otsuThreshold(h);
    expect(t, inInclusiveRange(50, 189));
  });

  test('unequal classes (dark text on a mostly white page)', () {
    final h = List<int>.filled(256, 0);
    h[30] = 100; // ink
    h[220] = 900; // paper
    expect(otsuThreshold(h), inInclusiveRange(30, 219));
  });

  test('empty and single-tone histograms do not crash', () {
    expect(otsuThreshold(List<int>.filled(256, 0)), 127);
    final h = List<int>.filled(256, 0)..[90] = 1000;
    expect(otsuThreshold(h), inInclusiveRange(0, 255));
  });

  test('histogram counts every pixel', () {
    final h = grayHistogram(Uint8List.fromList([0, 0, 5, 255]));
    expect((h[0], h[5], h[255]), (2, 1, 1));
    expect(h.fold<int>(0, (a, b) => a + b), 4);
  });

  test('binarize: above the threshold is white, the rest black', () {
    final out = binarize(Uint8List.fromList([0, 99, 100, 101, 255]), 100);
    expect(out, [0, 0, 0, 255, 255]);
  });

  test('a faint-text photo becomes pure black and white', () {
    // Light grey page (190) with darker grey strokes (120): low contrast.
    final image = img.Image(width: 100, height: 60);
    for (final p in image) {
      final stroke = p.x % 10 < 3;
      final v = stroke ? 120 : 190;
      p.setRgb(v, v, v);
    }
    final bytes = Uint8List.fromList(img.encodePng(image));
    final out = img.decodePng(otsuBinarizeToPng(bytes)!)!;
    final values = <int>{};
    for (final p in out) {
      values.add(p.r.toInt());
    }
    expect(values, {0, 255});
    expect(out.getPixel(1, 0).r, 0, reason: 'stroke is black');
    expect(out.getPixel(5, 0).r, 255, reason: 'page is white');
  });

  test('bytes that are not an image give null', () {
    expect(otsuBinarizeToPng(Uint8List.fromList([9, 9, 9])), isNull);
  });
}
