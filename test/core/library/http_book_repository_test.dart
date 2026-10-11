// HttpAdminBookRepository: the Library's books from the dashboard's REST API
// (`GET {base}/api/v1/books`, `/books/{id}`, `/books/{id}/file`, `/cover`).
// Pages are read until the total is reached; a download is checked against the
// server's size and SHA-256 and leaves no half file; no connection = offline.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/library/admin_book_repository.dart';
import 'package:percipere_app/core/library/http_book_repository.dart';
import 'package:percipere_app/core/library/library_models.dart';

/// Answers each request from [reply]: a Map/List becomes JSON, bytes stay
/// bytes. Remembers what was asked.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.reply);

  final (int, Object?) Function(RequestOptions) reply;
  final List<RequestOptions> sent = [];
  Object? throwError;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    sent.add(options);
    final error = throwError;
    if (error != null) throw error;
    final (status, body) = reply(options);
    if (body is Uint8List) {
      return ResponseBody.fromBytes(
        body,
        status,
        headers: {
          Headers.contentTypeHeader: ['application/octet-stream'],
          Headers.contentLengthHeader: ['${body.length}'],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _book(
  int id, {
  String title = 'Noli Me Tangere',
  String format = 'pdf',
  Map<String, dynamic>? language = const {
    'id': 1,
    'name': 'Filipino',
    'code': 'fil',
  },
  int size = 5,
  String? checksum,
  String? coverUrl,
}) => {
  'id': id,
  'title': title,
  'author': 'Jose Rizal',
  'description': 'Isang nobela.',
  'category': {'id': 2, 'name': 'Fiction'},
  'language': language,
  'format': format,
  'file_size': size,
  'checksum': checksum,
  'version': 3,
  'cover_url': coverUrl,
  'created_at': '2026-10-11T12:28:57+08:00',
  'updated_at': '2026-10-11T12:28:59+08:00',
};

String _sum(List<int> bytes) => 'sha256:${sha256.convert(bytes)}';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('books_test'));
  tearDown(() => tmp.deleteSync(recursive: true));

  HttpAdminBookRepository repo(_Adapter adapter, {String base = 'http://pc'}) =>
      HttpAdminBookRepository(base, dio: Dio()..httpClientAdapter = adapter);

  group('catalog', () {
    test('reads every page until the total, and maps the books', () async {
      final adapter = _Adapter((o) {
        final page = o.queryParameters['page'];
        return (
          200,
          {
            'data': page == 1
                ? [
                    _book(
                      7,
                      checksum: _sum([1, 2]),
                      coverUrl: 'http://pc/api/v1/books/7/cover',
                    ),
                    _book(
                      8,
                      title: 'The Tortoise',
                      format: 'epub',
                      language: {'id': 2, 'name': 'English', 'code': 'en'},
                    ),
                  ]
                : [
                    _book(
                      9,
                      language: {'id': 3, 'name': 'Cebuano', 'code': 'ceb'},
                    ),
                  ],
            'page': page,
            'per_page': 2,
            'total': 3,
          },
        );
      });
      final books = await repo(adapter).catalog();

      expect(books.map((b) => b.id), ['7', '8', '9']);
      expect(adapter.sent.map((o) => o.queryParameters['page']), [1, 2]);
      expect(adapter.sent.first.uri.path, '/api/v1/books');
      expect(adapter.sent.first.queryParameters['per_page'], 50);

      final a = books[0];
      expect(a.title, 'Noli Me Tangere');
      expect(a.author, 'Jose Rizal');
      expect(a.category, 'Fiction');
      expect(a.language, 'fil');
      expect(a.format, LibraryFormat.pdf);
      expect(a.version, 3);
      expect(a.fileSize, 5);
      expect(a.checksum, _sum([1, 2]).substring(7));
      expect(a.coverUrl, 'http://pc/api/v1/books/7/cover');
      expect(a.updatedAt.toUtc(), DateTime.utc(2026, 10, 11, 4, 28, 59));
      expect(a.active, isTrue);

      expect(books[1].language, 'en', reason: 'English voice');
      expect(books[1].format, LibraryFormat.epub);
      expect(books[1].coverUrl, isNull);
      expect(books[1].checksum, isNull);
      expect(books[2].language, 'fil', reason: 'other languages use Filipino');
    });

    test('a trailing slash on the address is fine', () async {
      final adapter = _Adapter(
        (_) => (200, {'data': <Object>[], 'total': 0}),
      );
      await repo(adapter, base: 'http://192.168.1.23/dash/').catalog();
      expect(adapter.sent.single.uri.toString(),
          startsWith('http://192.168.1.23/dash/api/v1/books?'));
    });

    test('an empty library is an empty list', () async {
      final adapter = _Adapter(
        (_) => (200, {'data': <Object>[], 'page': 1, 'total': 0}),
      );
      expect(await repo(adapter).catalog(), isEmpty);
      expect(adapter.sent, hasLength(1));
    });

    test('since is sent as updated_since in UTC', () async {
      final adapter = _Adapter(
        (_) => (200, {'data': <Object>[], 'total': 0}),
      );
      await repo(adapter).catalog(since: DateTime.utc(2026, 10, 1, 8));
      expect(
        adapter.sent.single.queryParameters['updated_since'],
        '2026-10-01T08:00:00.000Z',
      );
    });

    test('no connection is offline; a server error or junk is failed', () async {
      final down = _Adapter((_) => (200, {}))
        ..throwError = DioException.connectionError(
          requestOptions: RequestOptions(path: ''),
          reason: 'no route',
        );
      await expectLater(
        repo(down).catalog(),
        throwsA(
          isA<BookServiceException>().having(
            (e) => e.problem,
            'problem',
            BookServiceProblem.offline,
          ),
        ),
      );
      final timeout = _Adapter((_) => (200, {}))
        ..throwError = DioException.connectionTimeout(
          timeout: const Duration(seconds: 10),
          requestOptions: RequestOptions(path: ''),
        );
      await expectLater(
        repo(timeout).catalog(),
        throwsA(
          isA<BookServiceException>().having(
            (e) => e.problem,
            'problem',
            BookServiceProblem.offline,
          ),
        ),
      );
      for (final reply in <(int, Object?)>[
        (500, {'error': {'code': 'server_error', 'message': 'x'}}),
        (200, {'unexpected': true}),
        (404, {'error': {'code': 'not_found', 'message': 'x'}}),
      ]) {
        await expectLater(
          repo(_Adapter((_) => reply)).catalog(),
          throwsA(
            isA<BookServiceException>().having(
              (e) => e.problem,
              'problem',
              BookServiceProblem.failed,
            ),
          ),
          reason: '$reply',
        );
      }
    });
  });

  group('downloadFile', () {
    final bytes = Uint8List.fromList(utf8.encode('12345'));

    (int, Object?) Function(RequestOptions) server({
      String? checksum,
      int size = 5,
      Uint8List? file,
      int infoStatus = 200,
      int fileStatus = 200,
    }) => (o) {
      if (o.uri.path.endsWith('/file')) {
        return (fileStatus, fileStatus == 200 ? (file ?? bytes) : {'error': {}});
      }
      return (
        infoStatus,
        infoStatus == 200
            ? _book(5, size: size, checksum: checksum ?? _sum(bytes))
            : {'error': {'code': 'not_found'}},
      );
    };

    test('saves the file, reports progress, leaves nothing else', () async {
      final adapter = _Adapter(server());
      final target = '${tmp.path}/books/5-v3.pdf';
      final progress = <int>[];
      await repo(adapter).downloadFile(
        '5',
        target,
        onProgress: (received, total) {
          progress.add(received);
          expect(total, 5);
        },
      );
      expect(File(target).readAsBytesSync(), bytes);
      expect(File('$target.part').existsSync(), isFalse);
      expect(progress, isNotEmpty);
      expect(progress.last, 5);
      expect(adapter.sent.map((o) => o.uri.path), [
        '/api/v1/books/5',
        '/api/v1/books/5/file',
      ]);
    });

    test('a newer download replaces an older file', () async {
      final target = '${tmp.path}/5.pdf';
      File(target).writeAsStringSync('old');
      await repo(_Adapter(server())).downloadFile('5', target);
      expect(File(target).readAsBytesSync(), bytes);
    });

    test('a file that does not match the checksum is thrown away', () async {
      final target = '${tmp.path}/5.pdf';
      final adapter = _Adapter(server(checksum: _sum([9, 9, 9])));
      await expectLater(
        repo(adapter).downloadFile('5', target),
        throwsA(
          isA<BookServiceException>().having(
            (e) => e.problem,
            'problem',
            BookServiceProblem.failed,
          ),
        ),
      );
      expect(File(target).existsSync(), isFalse);
      expect(File('$target.part').existsSync(), isFalse);
    });

    test('a file of the wrong size is thrown away', () async {
      final target = '${tmp.path}/5.pdf';
      await expectLater(
        repo(_Adapter(server(size: 99))).downloadFile('5', target),
        throwsA(isA<BookServiceException>()),
      );
      expect(File(target).existsSync(), isFalse);
      expect(File('$target.part').existsSync(), isFalse);
    });

    test('without a checksum the size is still checked', () async {
      // The server did not give a checksum: only the size can be checked.
      final adapter = _Adapter((o) {
        if (o.uri.path.endsWith('/file')) return (200, bytes);
        final book = _book(5)..['checksum'] = null;
        return (200, book);
      });
      final target = '${tmp.path}/5.pdf';
      await repo(adapter).downloadFile('5', target);
      expect(File(target).existsSync(), isTrue);
    });

    test('a book the admins removed is notFound, before any file request',
        () async {
      final adapter = _Adapter(server(infoStatus: 404));
      await expectLater(
        repo(adapter).downloadFile('5', '${tmp.path}/5.pdf'),
        throwsA(
          isA<BookServiceException>().having(
            (e) => e.problem,
            'problem',
            BookServiceProblem.notFound,
          ),
        ),
      );
      expect(adapter.sent, hasLength(1));
    });

    test('a file that vanishes between the two requests is notFound', () async {
      final target = '${tmp.path}/5.pdf';
      await expectLater(
        repo(_Adapter(server(fileStatus: 404))).downloadFile('5', target),
        throwsA(
          isA<BookServiceException>().having(
            (e) => e.problem,
            'problem',
            BookServiceProblem.notFound,
          ),
        ),
      );
      expect(File('$target.part').existsSync(), isFalse);
    });

    test('a server error is failed; no connection is offline', () async {
      await expectLater(
        repo(_Adapter(server(fileStatus: 500)))
            .downloadFile('5', '${tmp.path}/5.pdf'),
        throwsA(
          isA<BookServiceException>().having(
            (e) => e.problem,
            'problem',
            BookServiceProblem.failed,
          ),
        ),
      );
      final down = _Adapter(server())
        ..throwError = DioException.connectionError(
          requestOptions: RequestOptions(path: ''),
          reason: 'no route',
        );
      await expectLater(
        repo(down).downloadFile('5', '${tmp.path}/5.pdf'),
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

  group('cover', () {
    test('returns the image bytes', () async {
      final image = Uint8List.fromList([0xFF, 0xD8, 1, 2, 3]);
      final adapter = _Adapter((_) => (200, image));
      expect(await repo(adapter).cover('7'), image);
      expect(adapter.sent.single.uri.path, '/api/v1/books/7/cover');
    });

    test('a book with no cover gives null', () async {
      final adapter = _Adapter(
        (_) => (404, {'error': {'code': 'no_cover'}}),
      );
      expect(await repo(adapter).cover('7'), isNull);
    });

    test('a server error is failed', () async {
      await expectLater(
        repo(_Adapter((_) => (500, {'error': {}}))).cover('7'),
        throwsA(isA<BookServiceException>()),
      );
    });
  });

  test('built without a web app, the catalog is offline and covers are null',
      () async {
    const repo = UnconfiguredBookRepository();
    await expectLater(
      repo.catalog(),
      throwsA(
        isA<BookServiceException>().having(
          (e) => e.problem,
          'problem',
          BookServiceProblem.offline,
        ),
      ),
    );
    expect(await repo.cover('1'), isNull);
  });
}
