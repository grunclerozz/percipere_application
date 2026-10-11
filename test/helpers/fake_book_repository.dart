import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:percipere_app/core/library/admin_book_repository.dart';
import 'package:percipere_app/core/library/catalog_book.dart';
import 'package:percipere_app/core/library/library_models.dart';

import 'sample_books.dart';

/// A stand-in for the web app's books, for tests only: public-domain sample
/// books built in memory. The app itself uses [HttpAdminBookRepository].
///
/// [simulateNewBook], [simulateUpdate] and [simulateRemoval] change the
/// catalog the way an admin would; [offline] makes every call fail as if
/// there were no internet.
class FakeAdminBookRepository implements AdminBookRepository {
  /// Creates the mock. [latency] slows each call, to show progress in the app.
  FakeAdminBookRepository({this.latency = Duration.zero}) {
    final t = DateTime(2026, 9, 1);
    _books = [
      CatalogBook(
        id: 'bk-fables',
        title: "Aesop's Fables, Selected",
        author: 'Aesop',
        language: 'en',
        category: 'Fables',
        description:
            'Three classic fables with illustrations: the tortoise and the '
            'hare, the ant and the grasshopper, and the lion and the mouse.',
        format: LibraryFormat.epub,
        fileSize: 0,
        version: 1,
        createdAt: t,
        updatedAt: t,
        coverUrl: 'mock://cover/bk-fables',
      ),
      CatalogBook(
        id: 'bk-hare',
        title: 'The Tortoise and the Hare',
        author: 'Aesop',
        language: 'en',
        category: 'Fables',
        description: 'The famous race, as a short PDF with two chapters.',
        format: LibraryFormat.pdf,
        fileSize: 0,
        version: 1,
        createdAt: t,
        updatedAt: t,
        coverUrl: 'mock://cover/bk-hare',
      ),
      CatalogBook(
        id: 'bk-kindness',
        title: 'Short Tales of Kindness',
        author: 'Folk tales',
        language: 'en',
        category: 'Short Stories',
        description:
            'Two short tales about honesty and patience: the woodcutter and '
            'the crow with the pitcher.',
        format: LibraryFormat.epub,
        fileSize: 0,
        version: 1,
        createdAt: t,
        updatedAt: t,
        coverUrl: 'mock://cover/bk-kindness',
      ),
    ];
    _books = [for (final b in _books) _withSize(b)];
  }

  /// Pause added to each call.
  final Duration latency;

  /// Pretend there is no internet.
  bool offline = false;

  late List<CatalogBook> _books;

  CatalogBook _withSize(CatalogBook b) => CatalogBook(
    id: b.id,
    title: b.title,
    author: b.author,
    language: b.language,
    category: b.category,
    description: b.description,
    format: b.format,
    fileSize: _bytes(b).length,
    version: b.version,
    createdAt: b.createdAt,
    updatedAt: b.updatedAt,
    coverUrl: b.coverUrl,
    active: b.active,
  );

  Uint8List _bytes(CatalogBook b) {
    switch (b.id) {
      case 'bk-fables':
        return SampleBooks.epub(
          title: b.title,
          author: b.author,
          chapters: SampleBooks.fables,
          illustrated: true,
        );
      case 'bk-hare':
        return SampleBooks.pdf(title: b.title, chapters: SampleBooks.hare);
      case 'bk-crow':
        return SampleBooks.pdf(
          title: b.title,
          chapters: [SampleBooks.kindness[1]],
          outline: false,
        );
      default:
        return SampleBooks.epub(
          title: b.title,
          author: b.author,
          chapters: SampleBooks.kindness,
        );
    }
  }

  Future<void> _pause() async {
    if (offline) throw const BookServiceException(BookServiceProblem.offline);
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  /// Adds a book the way an admin would; the next refresh sees it as new.
  void simulateNewBook() {
    if (_books.any((b) => b.id == 'bk-crow')) return;
    final now = DateTime.now();
    _books = [
      ..._books,
      _withSize(
        CatalogBook(
          id: 'bk-crow',
          title: 'The Crow and the Pitcher',
          author: 'Aesop',
          language: 'en',
          category: 'Fables',
          description: 'A thirsty crow solves a clever puzzle.',
          format: LibraryFormat.pdf,
          fileSize: 0,
          version: 1,
          createdAt: now,
          updatedAt: now,
          coverUrl: 'mock://cover/bk-crow',
        ),
      ),
    ];
  }

  /// Publishes a new version of [bookId] (downloads can then be updated).
  void simulateUpdate(String bookId) {
    _books = [
      for (final b in _books)
        if (b.id == bookId)
          CatalogBook(
            id: b.id,
            title: b.title,
            author: b.author,
            language: b.language,
            category: b.category,
            description: b.description,
            format: b.format,
            fileSize: b.fileSize,
            version: b.version + 1,
            createdAt: b.createdAt,
            updatedAt: DateTime.now(),
            coverUrl: b.coverUrl,
          )
        else
          b,
    ];
  }

  /// Takes [bookId] off the shelves.
  void simulateRemoval(String bookId) {
    _books = [
      for (final b in _books)
        if (b.id != bookId) b,
    ];
  }

  @override
  Future<List<CatalogBook>> catalog({DateTime? since}) async {
    await _pause();
    return [
      for (final b in _books)
        if (since == null || b.updatedAt.isAfter(since)) b,
    ];
  }

  @override
  Future<void> downloadFile(
    String bookId,
    String destination, {
    void Function(int received, int total)? onProgress,
  }) async {
    await _pause();
    final book = _books.where((b) => b.id == bookId).firstOrNull;
    if (book == null) {
      throw const BookServiceException(BookServiceProblem.notFound);
    }
    final bytes = _bytes(book);
    final file = File(destination);
    await file.parent.create(recursive: true);
    final sink = file.openWrite();
    const chunk = 16 * 1024;
    var sent = 0;
    while (sent < bytes.length) {
      final end = (sent + chunk).clamp(0, bytes.length);
      sink.add(bytes.sublist(sent, end));
      sent = end;
      onProgress?.call(sent, bytes.length);
    }
    await sink.close();
  }

  @override
  Future<Uint8List?> cover(String bookId) async {
    await _pause();
    final book = _books.where((b) => b.id == bookId).firstOrNull;
    if (book == null) return null;
    final image = img.Image(width: 200, height: 280);
    const colors = [
      [27, 94, 32],
      [13, 71, 161],
      [136, 14, 79],
      [230, 81, 0],
    ];
    final c = colors[bookId.hashCode.abs() % colors.length];
    img.fill(image, color: img.ColorRgb8(c[0], c[1], c[2]));
    return Uint8List.fromList(img.encodeJpg(image, quality: 70));
  }
}
