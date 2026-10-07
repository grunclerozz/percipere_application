import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What a signed-in account would send to the web app so its Library follows
/// it to another device (Phase 7). Only admin-book data: the user's own
/// scanned and uploaded documents never leave the device.
@immutable
class LibrarySyncBatch {
  /// Creates a batch.
  const LibrarySyncBatch({
    this.books = const [],
    this.progress = const [],
    this.favorites = const [],
    this.collections = const [],
  });

  /// Admin books the user added or downloaded (`{bookId, downloaded}`).
  final List<Map<String, Object?>> books;

  /// Reading progress per book (`{bookId, chapter, sentence, percent, finished}`).
  final List<Map<String, Object?>> progress;

  /// Favorites inside books.
  final List<Map<String, Object?>> favorites;

  /// Collections and their book links.
  final List<Map<String, Object?>> collections;

  /// Nothing to send.
  bool get isEmpty =>
      books.isEmpty &&
      progress.isEmpty &&
      favorites.isEmpty &&
      collections.isEmpty;
}

/// Library sync with the web app (`docs/api-contract.md`). No real
/// implementation until Phase 7.
abstract interface class LibrarySyncRepository {
  /// Sends local changes of [userId]. Returns how many records were accepted.
  Future<int> push(String userId, LibrarySyncBatch batch);

  /// Fetches what [userId] saved on other devices, changed after [since].
  Future<LibrarySyncBatch> pull(String userId, {DateTime? since});
}

/// Accepts everything and returns nothing; remembers what it was sent so
/// tests can check what would be uploaded.
class MockLibrarySyncRepository implements LibrarySyncRepository {
  /// Batches received by [push], per user.
  final Map<String, List<LibrarySyncBatch>> pushed = {};

  @override
  Future<int> push(String userId, LibrarySyncBatch batch) async {
    pushed.putIfAbsent(userId, () => []).add(batch);
    return batch.books.length +
        batch.progress.length +
        batch.favorites.length +
        batch.collections.length;
  }

  @override
  Future<LibrarySyncBatch> pull(String userId, {DateTime? since}) async =>
      const LibrarySyncBatch();
}

/// Library sync. The mock until Phase 7.
final librarySyncRepositoryProvider = Provider<LibrarySyncRepository>(
  (ref) => MockLibrarySyncRepository(),
);
