import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../extraction/extraction_exception.dart';
import '../extraction/pdf_extractor.dart';
import '../ocr/ocr_service.dart';
import '../ocr/text_cleanup.dart';
import 'epub_parser.dart';
import 'library_models.dart';

/// Why a book could not be turned into text.
enum BookReadProblem {
  /// DRM-protected EPUB.
  drm,

  /// Damaged or not a real EPUB/PDF.
  invalid,

  /// Password-protected PDF.
  passwordProtected,

  /// Nothing readable (e.g. a PDF of blank pages).
  empty,
}

/// Thrown by [BookContentLoader].
class BookReadException implements Exception {
  /// Creates the exception.
  const BookReadException(this.problem, [this.detail]);

  /// What is wrong.
  final BookReadProblem problem;

  /// Technical detail, for logs.
  final String? detail;

  @override
  String toString() => 'BookReadException($problem, $detail)';
}

/// A book's text and what was learned about it while reading the file.
@immutable
class LoadedBook {
  /// Creates a loaded book.
  const LoadedBook(this.text, {this.title, this.author});

  /// Chapters and images.
  final BookText text;

  /// Title found in the file, if any.
  final String? title;

  /// Author found in the file, if any.
  final String? author;
}

/// Turns a downloaded PDF or EPUB into chapters of text.
abstract interface class BookContentLoader {
  /// Reads [path]. [chapterTitle] names chapters that have no title
  /// (1-based). Throws [BookReadException].
  Future<LoadedBook> load(
    String path,
    LibraryFormat format, {
    required String Function(int number) chapterTitle,
    void Function(int page, int pageCount)? onPage,
  });
}

/// The real loader: the EPUB parser (in a background isolate) and the
/// existing PDF pipeline — text layer first, OCR for scanned pages.
class DefaultBookContentLoader implements BookContentLoader {
  /// Creates the loader.
  const DefaultBookContentLoader(this._ocr, [this._pdf = const PdfrxReader()]);

  final OcrService _ocr;
  final PdfReader _pdf;

  @override
  Future<LoadedBook> load(
    String path,
    LibraryFormat format, {
    required String Function(int number) chapterTitle,
    void Function(int page, int pageCount)? onPage,
  }) async {
    switch (format) {
      case LibraryFormat.epub:
        final bytes = await File(path).readAsBytes();
        final prefix = chapterTitle(0)
            .replaceAll(RegExp(r'\s*0\s*$'), '')
            .trim();
        try {
          final book = await compute(_parseEpub, (bytes, prefix));
          return LoadedBook(book.text, title: book.title, author: book.author);
        } on EpubException catch (e) {
          throw BookReadException(
            e.problem == EpubProblem.drm
                ? BookReadProblem.drm
                : BookReadProblem.invalid,
            e.detail,
          );
        }
      case LibraryFormat.pdf:
        try {
          final pdf = await _pdf.read(path, _ocr, onPage: onPage);
          final chapters = await chaptersFromPdf(
            pdf,
            chapterTitle: chapterTitle,
          );
          if (chapters.isEmpty) {
            throw const BookReadException(BookReadProblem.empty);
          }
          return LoadedBook(BookText(chapters));
        } on ExtractionException catch (e) {
          throw BookReadException(
            e.failure == ExtractionFailure.passwordProtected
                ? BookReadProblem.passwordProtected
                : BookReadProblem.invalid,
            e.detail,
          );
        }
      case LibraryFormat.docx:
      case LibraryFormat.image:
        throw const BookReadException(BookReadProblem.invalid, 'format');
    }
  }
}

EpubBook _parseEpub((Uint8List, String) args) {
  final (bytes, prefix) = args;
  return EpubParser.parse(bytes, fallbackTitle: (n) => '$prefix $n'.trim());
}

/// Splits a PDF into chapters using its outline (one chapter from each
/// top-level bookmark to the next). Without an outline the whole PDF is one
/// chapter.
Future<List<ChapterText>> chaptersFromPdf(
  PdfExtraction pdf, {
  required String Function(int number) chapterTitle,
}) async {
  final pages = pdf.pageTexts.isNotEmpty ? pdf.pageTexts : [pdf.text];
  Future<String> clean(Iterable<String> parts) =>
      cleanTextAsync(parts.join('\n\n'));

  final outline = [...pdf.outline]..sort((a, b) => a.page.compareTo(b.page));
  if (outline.isEmpty || pdf.pageTexts.isEmpty) {
    final text = await clean(pages);
    return text.trim().isEmpty
        ? const []
        : [ChapterText(chapterTitle(1), text)];
  }
  final chapters = <ChapterText>[];
  // Pages before the first bookmark (cover, preface).
  final firstPage = outline.first.page.clamp(1, pages.length);
  if (firstPage > 1) {
    final front = await clean(pages.take(firstPage - 1));
    if (front.trim().isNotEmpty) {
      chapters.add(ChapterText(chapterTitle(1), front));
    }
  }
  for (var i = 0; i < outline.length; i++) {
    final start = outline[i].page.clamp(1, pages.length);
    final end = i + 1 < outline.length
        ? outline[i + 1].page.clamp(1, pages.length + 1)
        : pages.length + 1;
    if (end <= start) continue; // two bookmarks on one page
    final text = await clean(pages.sublist(start - 1, end - 1));
    if (text.trim().isNotEmpty) {
      chapters.add(ChapterText(outline[i].title, text));
    }
  }
  return chapters;
}

/// The app's book loader.
final bookContentLoaderProvider = Provider<BookContentLoader>(
  (ref) => DefaultBookContentLoader(ref.watch(ocrServiceProvider)),
);
