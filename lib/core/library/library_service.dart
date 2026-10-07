import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../auth/session.dart';
import '../db/daos/library_dao.dart';
import '../platform/storage_info.dart';
import '../tts/speech_language.dart';
import 'admin_book_repository.dart';
import 'book_content.dart';
import 'catalog_book.dart';
import 'chaptered_text.dart';
import 'library_models.dart';
import 'library_paths.dart';

/// How a request to read or download a book ended.
enum BookResult {
  /// The text is ready to read.
  ready,

  /// No internet, and the book is not on the phone.
  offline,

  /// The admin removed the book.
  unavailable,

  /// The file is DRM-protected.
  drm,

  /// The file is damaged or not a valid book.
  invalid,

  /// The PDF needs a password.
  passwordProtected,

  /// The file has no readable text.
  empty,

  /// Not enough free space (nothing was downloaded; ask before going on).
  lowStorage,

  /// Any other failure.
  failed,
}

/// Brings admin books to the phone: refreshes the catalog, reads books
/// online, downloads them for offline reading, and removes downloads.
///
/// Network and parsing are slow, so everything here is asynchronous and the
/// parsing runs off the main thread (see [BookContentLoader]).
class LibraryService {
  /// Creates the service.
  LibraryService(this._ref);

  final Ref _ref;

  /// Free space to keep after a download.
  static const int storageMargin = 50 * 1024 * 1024;

  LibraryDao get _dao => _ref.read(libraryDaoProvider);
  AdminBookRepository get _repo => _ref.read(adminBookRepositoryProvider);

  String? get _userId => _ref.read(currentAccountProvider)?.id;

  /// Fetches the catalog and merges it into the user's shelves. Returns what
  /// changed, or null if the catalog could not be reached (the last cached
  /// list stays).
  Future<CatalogDiff?> refreshCatalog() async {
    final List<CatalogBook> catalog;
    try {
      catalog = await _repo.catalog();
    } on BookServiceException catch (e) {
      debugPrint('Catalog refresh failed: $e');
      return null;
    } on Object catch (e) {
      debugPrint('Catalog refresh failed: $e');
      return null;
    }
    final userId = _userId;
    final CatalogDiff diff;
    try {
      diff = await _dao.syncCatalog(userId, catalog);
    } on Object catch (e) {
      debugPrint('Saving the catalog failed: $e');
      return null;
    }
    await _fetchCovers(userId);
    return diff;
  }

  /// Saves the covers of books that have none yet.
  Future<void> _fetchCovers(String? userId) async {
    try {
      final items = await _dao.list(userId);
      final dir = await _ref.read(libraryPathsProvider).covers();
      for (final item in items) {
        final id = item.bookId;
        final existing = item.coverPath;
        if (id == null || item.coverUrl == null) continue;
        if (existing != null && await File(existing).exists()) continue;
        final bytes = await _repo.cover(id);
        if (bytes == null) continue;
        final file = File(p.join(dir.path, '$id.jpg'));
        await file.writeAsBytes(bytes, flush: true);
        await _dao.setCover(item.id, file.path);
      }
    } on Object catch (e) {
      debugPrint('Fetching covers failed: $e'); // Covers are optional.
    }
  }

  /// Makes [item]'s text ready to open in the Reader. A downloaded book is
  /// read from the phone; otherwise its file is fetched into the temporary
  /// cache first ("read online"). [onProgress] gets 0..1, or null when the
  /// size is unknown.
  Future<BookResult> prepareToRead(
    LibraryItem item, {
    void Function(double? fraction)? onProgress,
  }) async {
    if (!item.isBook) return BookResult.ready;
    if (item.unavailable && !item.downloaded) return BookResult.unavailable;
    final cached = item.textPath;
    if (cached != null && await File(cached).exists()) return BookResult.ready;
    final bookId = item.bookId;
    if (bookId == null) return BookResult.failed;

    String? file = item.filePath;
    if (file == null || !await File(file).exists()) {
      final cache = await _ref.read(libraryPathsProvider).cache();
      final target = p.join(
        cache.path,
        '$bookId-v${item.remoteVersion ?? 1}.${item.format.name}',
      );
      final fetched = await _fetch(bookId, target, onProgress);
      if (fetched != null) return fetched;
      file = target;
    }
    final cacheDir = await _ref.read(libraryPathsProvider).cache();
    return _extract(item, file, p.join(cacheDir.path, '${item.id}.json'));
  }

  /// Saves the book for offline reading.
  Future<BookResult> download(
    LibraryItem item, {
    bool ignoreLowStorage = false,
    void Function(double? fraction)? onProgress,
  }) async {
    final bookId = item.bookId;
    if (!item.isBook || bookId == null) return BookResult.failed;
    if (item.unavailable) return BookResult.unavailable;
    if (!ignoreLowStorage && await isLowOnSpace(item.fileSize ?? 0)) {
      return BookResult.lowStorage;
    }
    final books = await _ref.read(libraryPathsProvider).books();
    final version = item.remoteVersion ?? item.bookVersion ?? 1;
    final target = p.join(books.path, '$bookId-v$version.${item.format.name}');
    final fetched = await _fetch(bookId, target, onProgress);
    if (fetched != null) return fetched;
    final texts = await _ref.read(libraryPathsProvider).texts();
    final result = await _extract(
      item,
      target,
      p.join(texts.path, '${item.id}.json'),
      downloadedAs: (path: target, version: version),
    );
    if (result == BookResult.ready) {
      // An older downloaded version is no longer needed.
      final old = item.filePath;
      if (old != null && old != target) await _delete(old);
    } else {
      await _delete(target);
    }
    return result;
  }

  /// Whether [bytes] would leave less than [storageMargin] free.
  Future<bool> isLowOnSpace(int bytes) async {
    final free = await _ref.read(storageInfoProvider).freeBytes();
    if (free == null) return false;
    return free < bytes * 3 + storageMargin;
  }

  /// Deletes the downloaded file and text, keeping progress and favorites.
  Future<void> removeDownload(LibraryItem item) async {
    final files = await _dao.clearDownload(item.id);
    for (final f in files) {
      await _delete(f);
    }
  }

  /// Deletes an own document with everything that belongs to it.
  Future<void> deleteItem(LibraryItem item) async {
    final files = await _dao.delete(item.id);
    for (final f in files) {
      await _delete(f);
    }
  }

  Future<BookResult?> _fetch(
    String bookId,
    String target,
    void Function(double? fraction)? onProgress,
  ) async {
    try {
      await _repo.downloadFile(
        bookId,
        target,
        onProgress: (received, total) =>
            onProgress?.call(total > 0 ? received / total : null),
      );
      return null;
    } on BookServiceException catch (e) {
      debugPrint('Book download failed: $e');
      return switch (e.problem) {
        BookServiceProblem.offline => BookResult.offline,
        BookServiceProblem.notFound => BookResult.unavailable,
        BookServiceProblem.failed => BookResult.failed,
      };
    } on Object catch (e) {
      debugPrint('Book download failed: $e');
      return BookResult.failed;
    }
  }

  Future<BookResult> _extract(
    LibraryItem item,
    String file,
    String textPath, {
    ({String path, int version})? downloadedAs,
  }) async {
    try {
      final loaded = await _ref
          .read(bookContentLoaderProvider)
          .load(
            file,
            item.format,
            chapterTitle: _ref
                .read(speechLanguageProvider)
                .strings
                .chapterFallback,
          );
      final layout = await ChapteredText.buildAsync(loaded.text.chapters);
      await File(textPath).parent.create(recursive: true);
      await File(textPath)
          .writeAsString(loaded.text.toJsonString(), flush: true);
      if (downloadedAs != null) {
        await _dao.setDownloaded(
          item.id,
          filePath: downloadedAs.path,
          version: downloadedAs.version,
          textPath: textPath,
          chapters: layout.info,
          totalSentences: layout.sentences.length,
          wordCount: layout.wordCount,
        );
      } else {
        await _dao.setTextCache(
          item.id,
          textPath: textPath,
          chapters: layout.info,
          totalSentences: layout.sentences.length,
          wordCount: layout.wordCount,
        );
      }
      return BookResult.ready;
    } on BookReadException catch (e) {
      debugPrint('Reading book failed: $e');
      return switch (e.problem) {
        BookReadProblem.drm => BookResult.drm,
        BookReadProblem.invalid => BookResult.invalid,
        BookReadProblem.passwordProtected => BookResult.passwordProtected,
        BookReadProblem.empty => BookResult.empty,
      };
    } on Object catch (e) {
      debugPrint('Reading book failed: $e');
      return BookResult.failed;
    }
  }

  Future<void> _delete(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } on Object {
      // Already gone.
    }
  }
}

/// The Library's book service.
final libraryServiceProvider = Provider<LibraryService>(LibraryService.new);
