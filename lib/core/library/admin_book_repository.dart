import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/env.dart';
import 'catalog_book.dart';
import 'http_book_repository.dart';

/// Why a web app request failed.
enum BookServiceProblem {
  /// No internet (or the web app is off).
  offline,

  /// The book no longer exists on the server.
  notFound,

  /// Any other server or network failure.
  failed,
}

/// Thrown by [AdminBookRepository].
class BookServiceException implements Exception {
  /// Creates the exception.
  const BookServiceException(this.problem, [this.detail]);

  /// What went wrong.
  final BookServiceProblem problem;

  /// Technical detail, for logs.
  final String? detail;

  @override
  String toString() => 'BookServiceException($problem, $detail)';
}

/// The books the admins manage in the web app (`docs/api-contract.md`,
/// section Library). Only books the admins switched on are listed; one that
/// is switched off simply disappears from the catalog.
abstract interface class AdminBookRepository {
  /// The whole catalog (every page of `GET /api/v1/books`). With [since],
  /// only books added or changed after it. Throws [BookServiceException].
  Future<List<CatalogBook>> catalog({DateTime? since});

  /// Downloads the book file (`GET /api/v1/books/{id}/file`) to [destination],
  /// checks it against the server's size and SHA-256, and reports bytes
  /// received and the total. Nothing is left at [destination] if it fails.
  /// Throws [BookServiceException].
  Future<void> downloadFile(
    String bookId,
    String destination, {
    void Function(int received, int total)? onProgress,
  });

  /// The cover image (`GET /api/v1/books/{id}/cover`), or null if it has none.
  Future<Uint8List?> cover(String bookId);
}

/// Used when the app was built without a web app (no `API_BASE_URL`): there is
/// no catalog to show, so every call behaves like having no internet. Own
/// documents still work; only the admin books are missing.
class UnconfiguredBookRepository implements AdminBookRepository {
  /// Creates it.
  const UnconfiguredBookRepository();

  @override
  Future<List<CatalogBook>> catalog({DateTime? since}) =>
      Future.error(const BookServiceException(BookServiceProblem.offline));

  @override
  Future<void> downloadFile(
    String bookId,
    String destination, {
    void Function(int received, int total)? onProgress,
  }) => Future.error(const BookServiceException(BookServiceProblem.offline));

  @override
  Future<Uint8List?> cover(String bookId) async => null;
}

/// The web app's books: over HTTP when the app is built with `API_BASE_URL`,
/// otherwise an empty, offline catalog.
final adminBookRepositoryProvider = Provider<AdminBookRepository>(
  (ref) => Env.apiBaseUrl == Env.noServer
      ? const UnconfiguredBookRepository()
      : HttpAdminBookRepository(Env.apiBaseUrl),
);
