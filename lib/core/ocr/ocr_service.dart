import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Text recognized on one image.
@immutable
class OcrPage {
  /// Creates an OCR page.
  const OcrPage({required this.text, this.confidence});

  /// Recognized text: lines of a block separated by `\n`, blocks by a blank
  /// line — ready for `cleanText`.
  final String text;

  /// Mean line confidence 0..1, if the engine reported any.
  final double? confidence;
}

/// What the camera guidance needs to know about a preview frame.
@immutable
class FrameStats {
  /// Creates frame stats.
  const FrameStats({
    required this.lineCount,
    required this.textAreaFraction,
    required this.touchesEdge,
    required this.meanLuma,
  });

  /// Lines of text found.
  final int lineCount;

  /// Share of the frame covered by text blocks (0..1).
  final double textAreaFraction;

  /// Whether text runs into the frame edge (probably cut off).
  final bool touchesEdge;

  /// Average brightness 0..255.
  final double meanLuma;
}

/// On-device text recognition. Abstract so tests can fake it.
abstract interface class OcrService {
  /// Recognizes text in the image file at [path].
  Future<OcrPage> recognizeFile(String path);

  /// Frees native resources.
  Future<void> close();
}

/// [OcrService] via Google ML Kit (Latin script: English and Filipino).
class MlKitOcrService implements OcrService {
  final TextRecognizer _recognizer = TextRecognizer();

  @override
  Future<OcrPage> recognizeFile(String path) async =>
      toOcrPage(await _recognizer.processImage(InputImage.fromFilePath(path)));

  @override
  Future<void> close() => _recognizer.close();
}

/// Converts an ML Kit result into an [OcrPage].
OcrPage toOcrPage(RecognizedText result) {
  final confidences = <double>[];
  final blocks = <String>[];
  for (final block in result.blocks) {
    blocks.add(block.lines.map((l) => l.text).join('\n'));
    for (final line in block.lines) {
      final c = line.confidence;
      if (c != null) confidences.add(c);
    }
  }
  return OcrPage(
    text: blocks.join('\n\n'),
    confidence: confidences.isEmpty
        ? null
        : confidences.reduce((a, b) => a + b) / confidences.length,
  );
}

/// Summarizes an ML Kit result on a preview frame of [imageSize] (already
/// rotated to upright) with brightness [meanLuma].
FrameStats toFrameStats(
  RecognizedText result,
  Size imageSize,
  double meanLuma,
) {
  var lines = 0;
  var area = 0.0;
  var touches = false;
  final marginX = imageSize.width * 0.03;
  final marginY = imageSize.height * 0.03;
  for (final block in result.blocks) {
    lines += block.lines.length;
    final r = block.boundingBox;
    area += r.width * r.height;
    if (r.left <= marginX ||
        r.top <= marginY ||
        r.right >= imageSize.width - marginX ||
        r.bottom >= imageSize.height - marginY) {
      touches = true;
    }
  }
  final total = imageSize.width * imageSize.height;
  return FrameStats(
    lineCount: lines,
    textAreaFraction: total <= 0 ? 0 : math.min(1, area / total),
    touchesEdge: touches,
    meanLuma: meanLuma,
  );
}

/// The app's OCR service.
final ocrServiceProvider = Provider<OcrService>((ref) {
  final service = MlKitOcrService();
  ref.onDispose(service.close);
  return service;
});
