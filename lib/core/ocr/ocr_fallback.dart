import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../config/image_quality_config.dart';
import '../algorithms/otsu.dart';
import '../extraction/extraction_exception.dart';
import 'ocr_service.dart';

/// Writes a grayscale + Otsu binarized copy of the image at the path and
/// returns its file path; null if the image can't be read. Replaced in
/// tests.
typedef Binarizer = Future<String?> Function(String path);

/// Whether the first OCR result is weak enough to try again: too few
/// letters or digits, or low engine confidence.
bool isWeakOcr(OcrPage page) {
  final chars = RegExp(r'[\p{L}\p{N}]', unicode: true).allMatches(page.text);
  if (chars.length < OcrFallbackConfig.weakBelowChars) return true;
  final c = page.confidence;
  return c != null && c < OcrFallbackConfig.weakBelowConfidence;
}

/// Words that look real: two or more letters (apostrophes and hyphens
/// allowed inside) with at least one vowel. A cheap filter for OCR noise
/// like "xqzt" or "|||".
int validWordCount(String text) {
  final word = RegExp(r"^\p{L}[\p{L}'’-]*\p{L}$", unicode: true);
  final vowel = RegExp('[aeiouáéíóúAEIOUÁÉÍÓÚ]');
  var n = 0;
  for (final w in text.split(RegExp(r'\s+'))) {
    final trimmed = w.replaceAll(
      RegExp(r'^[^\p{L}]+|[^\p{L}]+$', unicode: true),
      '',
    );
    if (trimmed.length >= 2 &&
        word.hasMatch(trimmed) &&
        vowel.hasMatch(trimmed)) {
      n++;
    }
  }
  return n;
}

/// The default [Binarizer]: decodes, binarizes with Otsu's method in a
/// background isolate and saves a PNG in the temporary folder.
Future<String?> binarizeToTempFile(String path) async {
  final bytes = await File(path).readAsBytes();
  final png = await otsuBinarizeToPngAsync(bytes);
  if (png == null) return null;
  final dir = await getTemporaryDirectory();
  final file = File(
    p.join(dir.path, 'otsu_${DateTime.now().microsecondsSinceEpoch}.png'),
  );
  await file.writeAsBytes(png, flush: true);
  return file.path;
}

/// OCR on the image at [path]; if the result is weak ([isWeakOcr]), OCR the
/// Otsu-binarized image too and keep the result with more valid words (the
/// original on a tie). Failures of the retry never lose the first result.
/// Engine failures of the first read throw like [recognizeOrThrow].
Future<OcrPage> recognizeWithOtsuFallback(
  OcrService ocr,
  String path, {
  Binarizer binarizer = binarizeToTempFile,
}) async {
  final first = await recognizeOrThrow(ocr, path);
  if (!isWeakOcr(first)) return first;
  final started = DateTime.now();
  String? binarized;
  try {
    binarized = await binarizer(path);
    if (binarized == null) return first;
    final second = await ocr.recognizeFile(binarized);
    final firstWords = validWordCount(first.text);
    final secondWords = validWordCount(second.text);
    final useSecond = secondWords > firstWords;
    debugPrint(
      '[OCR FALLBACK] weak first read (${first.text.length} chars, '
      'confidence=${first.confidence?.toStringAsFixed(2)}, '
      '$firstWords valid words); Otsu read: ${second.text.length} chars, '
      '$secondWords valid words; kept ${useSecond ? 'Otsu' : 'original'} '
      '(${DateTime.now().difference(started).inMilliseconds} ms)',
    );
    return useSecond ? second : first;
  } on Object catch (e) {
    debugPrint('[OCR FALLBACK] retry failed, keeping the first read: $e');
    return first;
  } finally {
    if (binarized != null) {
      try {
        await File(binarized).delete();
      } on Object {
        // Already gone.
      }
    }
  }
}
