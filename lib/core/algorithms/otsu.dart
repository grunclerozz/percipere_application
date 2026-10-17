import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../config/image_quality_config.dart';
import 'image_quality.dart';

/// 256-bin histogram of [gray].
List<int> grayHistogram(Uint8List gray) {
  final h = List<int>.filled(256, 0);
  for (final v in gray) {
    h[v]++;
  }
  return h;
}

/// Otsu's threshold for a 256-bin [histogram]: the level `t` that
/// maximizes the between-class variance
/// `w0(t) * w1(t) * (mean0(t) - mean1(t))^2`. Pixels `<= t` are the dark
/// class. Returns 127 for an empty histogram; the first best `t` wins on
/// ties.
int otsuThreshold(List<int> histogram) {
  final total = histogram.fold<int>(0, (a, b) => a + b);
  if (total == 0) return 127;
  var sumAll = 0.0;
  for (var i = 0; i < 256; i++) {
    sumAll += i * histogram[i];
  }
  var weightDark = 0;
  var sumDark = 0.0;
  var bestVariance = -1.0;
  var best = 127;
  for (var t = 0; t < 256; t++) {
    weightDark += histogram[t];
    if (weightDark == 0) continue;
    final weightLight = total - weightDark;
    if (weightLight == 0) break;
    sumDark += t * histogram[t];
    final meanDark = sumDark / weightDark;
    final meanLight = (sumAll - sumDark) / weightLight;
    final diff = meanDark - meanLight;
    final variance = weightDark.toDouble() * weightLight * diff * diff;
    if (variance > bestVariance) {
      bestVariance = variance;
      best = t;
    }
  }
  return best;
}

/// Black (0) and white (255) copy of [gray]: pixel `> threshold` is white.
Uint8List binarize(Uint8List gray, int threshold) {
  final out = Uint8List(gray.length);
  for (var i = 0; i < gray.length; i++) {
    out[i] = gray[i] > threshold ? 255 : 0;
  }
  return out;
}

/// Grayscale + Otsu binarization of the photo in [bytes], encoded as PNG.
/// Null if it isn't an image. Pure; run it off the UI isolate.
Uint8List? otsuBinarizeToPng(Uint8List bytes) {
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } on Object {
    return null;
  }
  if (decoded == null) return null;
  var image = img.bakeOrientation(decoded);
  const side = OcrFallbackConfig.maxSide;
  if (image.width > side || image.height > side) {
    image = image.width >= image.height
        ? img.copyResize(image, width: side)
        : img.copyResize(image, height: side);
  }
  final gray = toGrayscale(image);
  final bw = binarize(gray, otsuThreshold(grayHistogram(gray)));
  final out = img.Image(width: image.width, height: image.height);
  var k = 0;
  for (final p in out) {
    final v = bw[k++];
    p.setRgb(v, v, v);
  }
  return Uint8List.fromList(img.encodePng(out));
}

/// [otsuBinarizeToPng] in a background isolate.
Future<Uint8List?> otsuBinarizeToPngAsync(Uint8List bytes) =>
    Isolate.run(() => otsuBinarizeToPng(bytes));
