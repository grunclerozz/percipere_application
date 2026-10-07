import 'package:flutter/foundation.dart';

import '../ocr/ocr_service.dart';

/// Why a document couldn't be read.
enum ExtractionFailure {
  /// The file is damaged or not what its extension says.
  unreadable,

  /// Not an image, PDF or DOCX.
  unsupported,

  /// Password-protected PDF.
  passwordProtected,

  /// The file disappeared before it could be read (or was never copied).
  missing,

  /// The file is fine but the text reader (OCR) failed on this phone.
  ocrUnavailable,
}

/// Thrown by extractors; carries a [failure] the Reader can explain aloud.
class ExtractionException implements Exception {
  /// Creates the exception.
  const ExtractionException(this.failure, [this.detail]);

  /// What went wrong.
  final ExtractionFailure failure;

  /// Technical detail for logs.
  final String? detail;

  @override
  String toString() => 'ExtractionException($failure, $detail)';
}

/// Runs OCR on [path]; an engine failure (the file itself is fine) becomes
/// [ExtractionFailure.ocrUnavailable] instead of "the file is damaged".
Future<OcrPage> recognizeOrThrow(OcrService ocr, String path) async {
  try {
    return await ocr.recognizeFile(path);
  } on ExtractionException {
    rethrow;
  } on Object catch (e, stack) {
    debugPrint('[CAPTURE] OCR engine failed: $e');
    debugPrint('[CAPTURE] $stack');
    throw ExtractionException(ExtractionFailure.ocrUnavailable, '$e');
  }
}
