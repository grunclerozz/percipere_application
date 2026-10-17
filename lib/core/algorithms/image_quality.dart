import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../config/image_quality_config.dart';

/// What is wrong with a photo, if anything.
enum ImageIssue {
  /// Few sharp edges: the phone moved or the focus missed.
  blurry,

  /// Mean brightness too low to read.
  tooDark,

  /// Mean brightness so high that detail is lost.
  tooBright,
}

/// Measured sharpness and brightness of one photo.
class ImageQuality {
  /// Creates a measurement.
  const ImageQuality({required this.sharpness, required this.brightness});

  /// Variance of the Laplacian response (higher is sharper).
  final double sharpness;

  /// Mean luminance, 0-255.
  final double brightness;

  /// The most important problem, or null when the photo is fine. Lighting
  /// comes before blur: a dark photo is blurry by nature, and the tip
  /// "find more light" is the one that helps.
  ImageIssue? get issue {
    if (brightness < ImageQualityConfig.tooDarkBelow) {
      return ImageIssue.tooDark;
    }
    if (brightness > ImageQualityConfig.tooBrightAbove) {
      return ImageIssue.tooBright;
    }
    if (sharpness < ImageQualityConfig.blurVarianceBelow) {
      return ImageIssue.blurry;
    }
    return null;
  }

  @override
  String toString() =>
      'sharpness=${sharpness.toStringAsFixed(1)} '
      'brightness=${brightness.toStringAsFixed(1)} issue=${issue?.name}';
}

/// Variance of the 3x3 Laplacian kernel (0 1 0 / 1 -4 1 / 0 1 0) over the
/// interior pixels of the grayscale image [gray] (row by row, [width] x
/// [height]). A blurry image has few edges, so the response barely varies.
double laplacianVariance(Uint8List gray, int width, int height) {
  if (width < 3 || height < 3) return 0;
  var sum = 0.0;
  var sumSquares = 0.0;
  var count = 0;
  for (var y = 1; y < height - 1; y++) {
    final row = y * width;
    for (var x = 1; x < width - 1; x++) {
      final i = row + x;
      final response =
          gray[i - width] +
          gray[i + width] +
          gray[i - 1] +
          gray[i + 1] -
          4 * gray[i];
      sum += response;
      sumSquares += response * response;
      count++;
    }
  }
  final mean = sum / count;
  return sumSquares / count - mean * mean;
}

/// Mean luminance (0-255) of [gray]; 0 for an empty image.
double meanBrightness(Uint8List gray) {
  if (gray.isEmpty) return 0;
  var sum = 0;
  for (final v in gray) {
    sum += v;
  }
  return sum / gray.length;
}

/// Luminance of every pixel of [image]: `Y = 0.299 R + 0.587 G + 0.114 B`.
Uint8List toGrayscale(img.Image image) {
  final out = Uint8List(image.width * image.height);
  var k = 0;
  for (final p in image) {
    out[k++] = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).round().clamp(0, 255);
  }
  return out;
}

/// Measures the photo in [bytes] (shrunk to
/// [ImageQualityConfig.analysisMaxSide] first). Null if it isn't an image.
/// Pure; run it off the UI isolate.
ImageQuality? measureImageQuality(Uint8List bytes) {
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } on Object {
    return null;
  }
  if (decoded == null) return null;
  var image = img.bakeOrientation(decoded);
  const side = ImageQualityConfig.analysisMaxSide;
  if (image.width > side || image.height > side) {
    image = image.width >= image.height
        ? img.copyResize(image, width: side)
        : img.copyResize(image, height: side);
  }
  final gray = toGrayscale(image);
  return ImageQuality(
    sharpness: laplacianVariance(gray, image.width, image.height),
    brightness: meanBrightness(gray),
  );
}

/// [measureImageQuality] in a background isolate.
Future<ImageQuality?> measureImageQualityAsync(Uint8List bytes) =>
    Isolate.run(() => measureImageQuality(bytes));
