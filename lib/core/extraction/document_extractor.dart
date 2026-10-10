import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../ocr/ocr_service.dart';
import '../ocr/text_cleanup.dart';
import 'docx_extractor.dart';
import 'extraction_exception.dart';
import 'pdf_extractor.dart';

/// Kinds of documents the app can read.
enum DocumentKind {
  /// JPG or PNG (uploaded or from the camera).
  image,

  /// PDF (text layer, or OCR for scanned pages).
  pdf,

  /// Word .docx.
  docx;

  /// Kind for a file name, or null if unsupported.
  static DocumentKind? forPath(String path) =>
      switch (p.extension(path).toLowerCase()) {
        '.jpg' || '.jpeg' || '.png' => DocumentKind.image,
        '.pdf' => DocumentKind.pdf,
        '.docx' => DocumentKind.docx,
        _ => null,
      };
}

/// A document file waiting to be read.
@immutable
class DocumentFile {
  /// Creates a document file.
  const DocumentFile({
    required this.path,
    required this.kind,
    this.fromCamera = false,
  });

  /// Local path.
  final String path;

  /// What it is.
  final DocumentKind kind;

  /// Taken with the in-app camera (deleted after reading).
  final bool fromCamera;

  /// History `source_type`: `camera`, `image`, `pdf` or `docx`.
  String get sourceType => fromCamera ? 'camera' : kind.name;

  @override
  bool operator ==(Object other) =>
      other is DocumentFile &&
      other.path == path &&
      other.kind == kind &&
      other.fromCamera == fromCamera;

  @override
  int get hashCode => Object.hash(path, kind, fromCamera);
}

/// Clean text plus how it was obtained.
@immutable
class ExtractionResult {
  /// Creates a result.
  const ExtractionResult({
    required this.text,
    required this.quality,
    required this.pageCount,
    required this.usedOcr,
  });

  /// Clean text; paragraphs separated by a blank line.
  final String text;

  /// How usable the text looks.
  final TextQuality quality;

  /// Pages (1 for images and DOCX).
  final int pageCount;

  /// Whether any of it came from OCR.
  final bool usedOcr;
}

/// Reads any supported document into clean text. Abstract so the Reader can
/// be tested without native OCR/PDF engines.
abstract interface class DocumentExtractor {
  /// Extracts [file]. [onPage] reports (page, pageCount) for multi-page PDFs.
  /// Throws [ExtractionException].
  Future<ExtractionResult> extract(
    DocumentFile file, {
    void Function(int page, int pageCount)? onPage,
  });
}

/// The real extractor: ML Kit for images, pdfrx (+ OCR) for PDFs, and
/// archive/xml for DOCX; then [cleanText] and [assessQuality].
class DefaultDocumentExtractor implements DocumentExtractor {
  /// Creates the extractor.
  const DefaultDocumentExtractor(this._ocr, [this._pdf = const PdfrxReader()]);

  final OcrService _ocr;
  final PdfReader _pdf;

  @override
  Future<ExtractionResult> extract(
    DocumentFile file, {
    void Function(int page, int pageCount)? onPage,
  }) async {
    if (!await File(file.path).exists()) {
      throw const ExtractionException(ExtractionFailure.missing, 'missing');
    }
    try {
      switch (file.kind) {
        case DocumentKind.image:
          final page = await recognizeOrThrow(_ocr, file.path);
          final text = await cleanTextAsync(page.text);
          return ExtractionResult(
            text: text,
            quality: assessQuality(text, ocrConfidence: page.confidence),
            pageCount: 1,
            usedOcr: true,
          );
        case DocumentKind.docx:
          final raw = await extractDocxTextAsync(
            await File(file.path).readAsBytes(),
          );
          final text = await cleanTextAsync(raw, joinLines: false);
          return ExtractionResult(
            text: text,
            quality: assessQuality(text),
            pageCount: 1,
            usedOcr: false,
          );
        case DocumentKind.pdf:
          final pdf = await _pdf.read(file.path, _ocr, onPage: onPage);
          final text = await cleanTextAsync(pdf.text);
          return ExtractionResult(
            text: text,
            quality: assessQuality(text, ocrConfidence: pdf.ocrConfidence),
            pageCount: pdf.pageCount,
            usedOcr: pdf.ocrPageCount > 0,
          );
      }
    } on ExtractionException catch (e, stack) {
      debugPrint('[CAPTURE] extraction failed (${file.kind.name}): $e');
      debugPrint('[CAPTURE] $stack');
      rethrow;
    } on FileSystemException catch (e, stack) {
      // The file vanished or can't be read from storage.
      debugPrint('[CAPTURE] reading ${file.kind.name} from storage failed: $e');
      debugPrint('[CAPTURE] $stack');
      final gone = !await File(file.path).exists();
      throw ExtractionException(
        gone ? ExtractionFailure.missing : ExtractionFailure.unreadable,
        '$e',
      );
    } on Object catch (e, stack) {
      // Not the file's fault: say so, and keep the real error in the log.
      debugPrint(
        '[CAPTURE] extraction failed (${file.kind.name}) '
        '${e.runtimeType}: $e',
      );
      debugPrint('[CAPTURE] $stack');
      throw ExtractionException(
        ExtractionFailure.failed,
        '${e.runtimeType}: $e',
      );
    }
  }
}

/// The app's document extractor.
final documentExtractorProvider = Provider<DocumentExtractor>(
  (ref) => DefaultDocumentExtractor(ref.watch(ocrServiceProvider)),
);
