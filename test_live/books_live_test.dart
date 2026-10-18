// The Library's real web app: HttpAdminBookRepository against a running
// dashboard (the one in the dashboard repo's docs/testing/README.md, with test
// books). Skipped unless PERCIPERE_LIVE_API is set, so the normal test run
// (and tool/test_each.sh) never needs a server:
//
//   PERCIPERE_LIVE_API=http://localhost/website/percipere_dashboard \
//   PERCIPERE_LIVE_HIDDEN_ID=12 flutter test test_live/books_live_test.dart
//
// It expects the dashboard's own test data: 11 active books ("Book number 1"
// .. "Book number 11", the first with a cover) and one hidden book.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/library/admin_book_repository.dart';
import 'package:percipere_app/core/library/http_book_repository.dart';
import 'package:percipere_app/core/library/library_models.dart';

void main() {
  final api = Platform.environment['PERCIPERE_LIVE_API'];
  final hiddenId = Platform.environment['PERCIPERE_LIVE_HIDDEN_ID'] ?? '12';
  final skip = api == null ? 'set PERCIPERE_LIVE_API to run this' : false;

  group('against the real dashboard', skip: skip, () {
    late HttpAdminBookRepository repo;
    late Directory tmp;
    setUp(() {
      repo = HttpAdminBookRepository(api!);
      tmp = Directory.systemTemp.createTempSync('live_books');
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    test('the catalog lists only the active books', () async {
      final books = await repo.catalog();
      expect(books, hasLength(11), reason: 'the hidden one is not listed');
      expect(books.where((b) => b.id == hiddenId), isEmpty);
      final first = books.firstWhere((b) => b.title == 'Book number 1');
      expect(first.category, 'Fiction');
      expect(first.format, LibraryFormat.pdf);
      expect(first.version, 1);
      expect(first.fileSize, 193);
      expect(first.checksum, hasLength(64));
      expect(first.coverUrl, isNotNull);
      expect(books.map((b) => b.language).toSet(), {'fil', 'en'});
    });

    test('updated_since: nothing newer than the future, everything since 2020',
        () async {
      expect(await repo.catalog(since: DateTime.utc(2030)), isEmpty);
      expect(await repo.catalog(since: DateTime.utc(2020)), hasLength(11));
    });

    test('a book downloads, matches its checksum, and is a real PDF', () async {
      final book = (await repo.catalog()).firstWhere(
        (b) => b.title == 'Book number 1',
      );
      final target = '${tmp.path}/${book.id}.pdf';
      var last = 0;
      await repo.downloadFile(book.id, target, onProgress: (r, t) => last = r);
      final bytes = File(target).readAsBytesSync();
      expect(bytes.length, book.fileSize);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(last, book.fileSize);
      expect(File('$target.part').existsSync(), isFalse);
    });

    test('the cover is an image; a book without one is null', () async {
      final books = await repo.catalog();
      final withCover = books.firstWhere((b) => b.coverUrl != null);
      final bytes = await repo.cover(withCover.id);
      expect(bytes, isNotNull);
      expect(bytes!.take(4), [0x89, 0x50, 0x4E, 0x47], reason: 'a PNG');
      final without = books.firstWhere((b) => b.coverUrl == null);
      expect(await repo.cover(without.id), isNull);
    });

    test('a hidden or missing book is notFound', () async {
      for (final id in [hiddenId, '99999']) {
        await expectLater(
          repo.downloadFile(id, '${tmp.path}/x.pdf'),
          throwsA(
            isA<BookServiceException>().having(
              (e) => e.problem,
              'problem',
              BookServiceProblem.notFound,
            ),
          ),
          reason: id,
        );
      }
      expect(File('${tmp.path}/x.pdf').existsSync(), isFalse);
    });

    test('a server that is not there is offline', () async {
      final nobody = HttpAdminBookRepository('http://127.0.0.1:9');
      await expectLater(
        nobody.catalog(),
        throwsA(
          isA<BookServiceException>().having(
            (e) => e.problem,
            'problem',
            BookServiceProblem.offline,
          ),
        ),
      );
    });
  });
}
