import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../ocr/ocr_service.dart';
import 'extraction_exception.dart';

/// Raw text of a PDF plus how it was obtained.
@immutable
class PdfExtraction {
  /// Creates a PDF extraction.
  const PdfExtraction({
    required this.text,
    required this.pageCount,
    required this.ocrPageCount,
    this.ocrConfidence,
    this.pageTexts = const [],
    this.outline = const [],
  });

  /// Raw text, pages separated by a blank line.
  final String text;

  /// Pages in the document.
  final int pageCount;

  /// Pages that had no text layer and were OCR'd.
  final int ocrPageCount;

  /// Mean OCR confidence over OCR'd pages, if any.
  final double? ocrConfidence;

  /// Raw text of each page, in order.
  final List<String> pageTexts;

  /// Top-level outline entries (title, 1-based page), for chapters.
  final List<({String title, int page})> outline;
}

/// Reads PDFs. Abstract so tests don't need the native PDF engine.
abstract interface class PdfReader {
  /// Extracts text from the PDF at [path], OCR'ing pages with no text layer.
  /// [onPage] is called with (page number, page count) before each page.
  Future<PdfExtraction> read(
    String path,
    OcrService ocr, {
    void Function(int page, int pageCount)? onPage,
  });
}

/// [PdfReader] via pdfrx (PDFium).
class PdfrxReader implements PdfReader {
  /// Creates the reader.
  const PdfrxReader();

  /// A page with fewer characters than this in its text layer is treated as
  /// scanned and OCR'd.
  static const int minTextLayerChars = 20;

  /// Render scale for OCR (2× = 144 dpi, plenty for body text).
  static const double ocrScale = 2;

  @override
  Future<PdfExtraction> read(
    String path,
    OcrService ocr, {
    void Function(int page, int pageCount)? onPage,
  }) async {
    await pdfrxFlutterInitialize();
    final PdfDocument doc;
    try {
      doc = await PdfDocument.openFile(path);
    } on PdfPasswordException {
      throw const ExtractionException(ExtractionFailure.passwordProtected);
    } on Object catch (e) {
      throw ExtractionException(ExtractionFailure.unreadable, '$e');
    }

    try {
      final parts = <String>[];
      final confidences = <double>[];
      var ocrPages = 0;
      final pages = doc.pages;
      for (var i = 0; i < pages.length; i++) {
        onPage?.call(i + 1, pages.length);
        final page = pages[i];
        final layer = (await page.loadText())?.fullText ?? '';
        if (layer.trim().length >= minTextLayerChars) {
          parts.add(layer);
          continue;
        }
        final scanned = await _ocrPage(page, ocr);
        ocrPages++;
        parts.add(scanned.text);
        if (scanned.confidence != null) confidences.add(scanned.confidence!);
      }
      final outline = <({String title, int page})>[];
      try {
        for (final node in await doc.loadOutline()) {
          final page = node.dest?.pageNumber;
          if (page != null && node.title.trim().isNotEmpty) {
            outline.add((title: node.title.trim(), page: page));
          }
        }
      } on Object catch (e) {
        debugPrint('PDF outline failed: $e');
      }
      return PdfExtraction(
        pageTexts: parts,
        outline: outline,
        text: parts.join('\n\n'),
        pageCount: pages.length,
        ocrPageCount: ocrPages,
        ocrConfidence: confidences.isEmpty
            ? null
            : confidences.reduce((a, b) => a + b) / confidences.length,
      );
    } finally {
      await doc.dispose();
    }
  }

  /// Renders [page] to a temporary PNG and OCRs it.
  static Future<OcrPage> _ocrPage(PdfPage page, OcrService ocr) async {
    final w = (page.width * ocrScale).round();
    final h = (page.height * ocrScale).round();
    final rendered = await page.render(
      width: w,
      height: h,
      fullWidth: w.toDouble(),
      fullHeight: h.toDouble(),
      backgroundColor: 0xFFFFFFFF,
    );
    if (rendered == null) return const OcrPage(text: '');

    ui.Image? image;
    File? file;
    try {
      image = await rendered.createImage();
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) return const OcrPage(text: '');
      final dir = await getTemporaryDirectory();
      file = File(
        p.join(
          dir.path,
          'pdf_page_${DateTime.now().microsecondsSinceEpoch}.png',
        ),
      );
      await file.writeAsBytes(png.buffer.asUint8List(), flush: true);
      return await recognizeOrThrow(ocr, file.path);
    } finally {
      image?.dispose();
      rendered.dispose();
      if (file != null && await file.exists()) await file.delete();
    }
  }
}
