import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session.dart';
import '../../core/db/daos/library_dao.dart';
import '../../core/library/catalog_book.dart';
import '../../core/library/chaptered_text.dart';
import '../../core/library/library_models.dart';
import '../../core/library/library_service.dart';
import '../../core/library/library_view.dart';

/// What the Library screen shows.
@immutable
class LibraryState {
  /// Creates a state.
  const LibraryState({
    this.loaded = false,
    this.items = const [],
    this.collections = const [],
    this.favoriteIds = const {},
    this.collectionItemIds = const {},
    this.filter = LibraryFilter.all,
    this.query = '',
  });

  /// Whether the first load finished.
  final bool loaded;

  /// All of the user's items.
  final List<LibraryItem> items;

  /// The user's collections.
  final List<LibraryCollection> collections;

  /// Ids of items that have a favorite.
  final Set<String> favoriteIds;

  /// Ids of the items in the filtered collection.
  final Set<String> collectionItemIds;

  /// The active filter.
  final LibraryFilter filter;

  /// The active search words.
  final String query;

  /// Shelves for the current view.
  List<Shelf> get shelves => LibraryView.shelves(
    items: items,
    collections: collections,
    filter: filter,
    query: query,
    favoriteIds: favoriteIds,
    collectionItemIds: collectionItemIds,
  );

  /// Items passing the current filter and search.
  List<LibraryItem> get visibleItems => LibraryView.search(
    LibraryView.applyFilter(
      items,
      filter,
      favoriteIds: favoriteIds,
      collectionItemIds: collectionItemIds,
    ),
    query,
  );

  /// Copy with changes.
  LibraryState copyWith({
    bool? loaded,
    List<LibraryItem>? items,
    List<LibraryCollection>? collections,
    Set<String>? favoriteIds,
    Set<String>? collectionItemIds,
    LibraryFilter? filter,
    String? query,
  }) => LibraryState(
    loaded: loaded ?? this.loaded,
    items: items ?? this.items,
    collections: collections ?? this.collections,
    favoriteIds: favoriteIds ?? this.favoriteIds,
    collectionItemIds: collectionItemIds ?? this.collectionItemIds,
    filter: filter ?? this.filter,
    query: query ?? this.query,
  );
}

/// Loads and changes the user's Library.
class LibraryController extends Notifier<LibraryState> {
  LibraryDao get _dao => ref.read(libraryDaoProvider);
  String? get _userId => ref.read(currentAccountProvider)?.id;

  @override
  LibraryState build() => const LibraryState();

  /// Fills in sentence totals of migrated history, then loads the lists.
  Future<void> load() async {
    try {
      await _backfillTotals();
    } on Object catch (e) {
      debugPrint(
        'Backfilling totals failed: $e',
      ); // Not fatal: shown as started.
    }
    try {
      await reload();
    } on Object catch (e) {
      debugPrint('Loading the Library failed: $e');
      // An empty Library is better than a blank screen.
      if (ref.mounted) state = state.copyWith(loaded: true);
    }
  }

  /// Reads items, collections and favorites again.
  Future<void> reload() async {
    final userId = _userId;
    final items = await _dao.list(userId);
    final collections = await _dao.collections(userId);
    final favorites = await _dao.itemsWithFavorites(userId);
    final filter = state.filter;
    // The filtered collection may have been renamed or deleted.
    LibraryFilter active = filter;
    var inCollection = const <String>{};
    if (filter.kind == LibraryFilterKind.collection) {
      final current = collections
          .where((c) => c.id == filter.collection?.id)
          .firstOrNull;
      if (current == null) {
        active = LibraryFilter.all;
      } else {
        active = LibraryFilter(
          LibraryFilterKind.collection,
          collection: current,
        );
        inCollection = await _dao.collectionItemIds(current.id);
      }
    }
    if (!ref.mounted) return;
    state = state.copyWith(
      loaded: true,
      items: items,
      collections: collections,
      favoriteIds: favorites,
      collectionItemIds: inCollection,
      filter: active,
    );
  }

  Future<void> _backfillTotals() async {
    for (final item in await _dao.itemsNeedingTotals()) {
      final layout = await ChapteredText.buildAsync([
        ChapterText('', item.text),
      ]);
      await _dao.setTotals(
        item.id,
        totalSentences: layout.sentences.length,
        wordCount: layout.wordCount,
      );
    }
  }

  /// Asks the web app for the catalog and merges it. Null when offline.
  Future<CatalogDiff?> refreshCatalog() async {
    final diff = await ref.read(libraryServiceProvider).refreshCatalog();
    if (diff != null) await reload();
    return diff;
  }

  /// Applies [filter] (and clears the search).
  Future<void> setFilter(LibraryFilter filter) async {
    var inCollection = const <String>{};
    final c = filter.collection;
    if (filter.kind == LibraryFilterKind.collection && c != null) {
      inCollection = await _dao.collectionItemIds(c.id);
    }
    if (!ref.mounted) return;
    state = state.copyWith(
      filter: filter,
      collectionItemIds: inCollection,
      query: '',
    );
  }

  /// Applies a search; an empty [query] shows everything again.
  void setQuery(String query) => state = state.copyWith(query: query.trim());

  /// Filters in the order the Filter control cycles through them.
  List<LibraryFilter> get cycle => [
    LibraryFilter.all,
    const LibraryFilter(LibraryFilterKind.documents),
    const LibraryFilter(LibraryFilterKind.books),
    const LibraryFilter(LibraryFilterKind.downloaded),
    const LibraryFilter(LibraryFilterKind.finished),
    const LibraryFilter(LibraryFilterKind.favorites),
    for (final c in state.collections)
      LibraryFilter(LibraryFilterKind.collection, collection: c),
  ];

  /// Makes a collection; returns it.
  Future<LibraryCollection> createCollection(String name) async {
    final c = await _dao.createCollection(_userId, name.trim());
    await reload();
    return c;
  }

  /// Renames a collection.
  Future<void> renameCollection(LibraryCollection c, String name) async {
    await _dao.renameCollection(c.id, name.trim());
    await reload();
  }

  /// Deletes a collection (its items stay).
  Future<void> deleteCollection(LibraryCollection c) async {
    await _dao.deleteCollection(c.id);
    await reload();
  }
}

/// The Library lists. Disposed when the Library closes.
final libraryControllerProvider =
    NotifierProvider.autoDispose<LibraryController, LibraryState>(
      LibraryController.new,
    );
