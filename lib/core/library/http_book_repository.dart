import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../network/api_dio.dart';
import 'admin_book_repository.dart';
import 'catalog_book.dart';

/// [AdminBookRepository] over HTTP (dio): the dashboard's REST API under
/// `{baseUrl}/api/v1/` (`docs/api-contract.md`). No sign-in is needed to read
/// the Library; the tablet only needs to reach the PC.
class HttpAdminBookRepository implements AdminBookRepository {
  /// Creates the client for the web app at [baseUrl] (the dashboard's address,
  /// without `/api/v1`).
  HttpAdminBookRepository(String baseUrl, {Dio? dio})
    : _dio = dio ?? apiDio(receive: const Duration(seconds: 30)) {
    _dio.options
      ..baseUrl = '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/api/v1/'
      ..responseType = ResponseType.json
      ..validateStatus = (_) => true;
  }

  final Dio _dio;

  /// Books per request (the server allows up to 50).
  static const int perPage = 50;

  /// Stops a runaway server from looping the app forever.
  static const int _maxPages = 200;

  /// A book file can take a while on a slow connection: the time allowed
  /// between two pieces of data.
  static const Duration _downloadPatience = Duration(seconds: 60);

  @override
  Future<List<CatalogBook>> catalog({DateTime? since}) async {
    final books = <CatalogBook>[];
    for (var page = 1; page <= _maxPages; page++) {
      final response = await _send(
        () => _dio.get<dynamic>(
          'books',
          queryParameters: {
            'page': page,
            'per_page': perPage,
            if (since != null) 'updated_since': since.toUtc().toIso8601String(),
          },
        ),
      );
      final data = response.data;
      if (response.statusCode != 200 || data is! Map || data['data'] is! List) {
        throw BookServiceException(
          BookServiceProblem.failed,
          'GET books -> HTTP ${response.statusCode}',
        );
      }
      final items = data['data'] as List;
      for (final item in items) {
        if (item is Map<String, dynamic>) books.add(CatalogBook.fromApi(item));
      }
      final total = (data['total'] as num?)?.toInt() ?? books.length;
      if (items.isEmpty || books.length >= total) return books;
    }
    return books;
  }

  @override
  Future<void> downloadFile(
    String bookId,
    String destination, {
    void Function(int received, int total)? onProgress,
  }) async {
    // The book first: it is gone (404) or switched off, and it tells us what
    // the file must look like.
    final info = await _send(() => _dio.get<dynamic>('books/$bookId'));
    final data = info.data;
    if (info.statusCode == 404) {
      throw const BookServiceException(BookServiceProblem.notFound);
    }
    if (info.statusCode != 200 || data is! Map<String, dynamic>) {
      throw BookServiceException(
        BookServiceProblem.failed,
        'GET books/$bookId -> HTTP ${info.statusCode}',
      );
    }
    final book = CatalogBook.fromApi(data);

    // Into a .part file first: a half-downloaded book is never read as a book.
    final part = File('$destination.part');
    await part.parent.create(recursive: true);
    await _remove(part);
    try {
      await _dio.download(
        'books/$bookId/file',
        part.path,
        onReceiveProgress: (received, total) =>
            onProgress?.call(received, total > 0 ? total : book.fileSize),
        options: Options(
          receiveTimeout: _downloadPatience,
          validateStatus: (status) => status == 200,
        ),
      );
    } on DioException catch (e) {
      await _remove(part);
      throw _problem(e);
    } on Object {
      await _remove(part);
      rethrow;
    }

    final size = await part.length();
    if (book.fileSize > 0 && size != book.fileSize) {
      await _remove(part);
      throw BookServiceException(
        BookServiceProblem.failed,
        'size $size, expected ${book.fileSize}',
      );
    }
    final expected = book.checksum;
    if (expected != null) {
      final actual = (await sha256.bind(part.openRead()).first).toString();
      if (actual != expected) {
        await _remove(part);
        throw const BookServiceException(
          BookServiceProblem.failed,
          'checksum does not match',
        );
      }
    }
    await _remove(File(destination));
    await part.rename(destination);
  }

  @override
  Future<Uint8List?> cover(String bookId) async {
    final response = await _send(
      () => _dio.get<List<int>>(
        'books/$bookId/cover',
        options: Options(responseType: ResponseType.bytes),
      ),
    );
    final status = response.statusCode;
    if (status == 404) return null;
    final data = response.data;
    if (status != 200 || data == null) {
      throw BookServiceException(
        BookServiceProblem.failed,
        'GET books/$bookId/cover -> HTTP $status',
      );
    }
    return Uint8List.fromList(data);
  }

  Future<Response<T>> _send<T>(Future<Response<T>> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw _problem(e);
    }
  }

  BookServiceException _problem(DioException e) {
    final problem = switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError => BookServiceProblem.offline,
      DioExceptionType.badResponse =>
        e.response?.statusCode == 404
            ? BookServiceProblem.notFound
            : BookServiceProblem.failed,
      _ =>
        e.error is SocketException
            ? BookServiceProblem.offline
            : BookServiceProblem.failed,
    };
    debugPrint('Books request failed: ${e.type.name} ${e.message}');
    return BookServiceException(problem, e.type.name);
  }

  Future<void> _remove(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on Object {
      // Already gone.
    }
  }
}
