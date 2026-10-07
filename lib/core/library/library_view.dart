import 'package:flutter/foundation.dart';

import '../voice/command_matcher.dart';
import 'library_models.dart';

/// Which items the Library shows.
enum LibraryFilterKind {
  /// Everything, in shelves.
  all,

  /// The user's own documents.
  documents,

  /// Admin books.
  books,

  /// Books saved on the phone.
  downloaded,

  /// Finished items.
  finished,

  /// Items with at least one favorite.
  favorites,

  /// One collection.
  collection,
}

/// The active filter.
@immutable
class LibraryFilter {
  /// Creates a filter.
  const LibraryFilter(this.kind, {this.collection});

  /// Everything.
  static const LibraryFilter all = LibraryFilter(LibraryFilterKind.all);

  /// What it filters on.
  final LibraryFilterKind kind;

  /// The collection, when [kind] is `collection`.
  final LibraryCollection? collection;

  @override
  bool operator ==(Object other) =>
      other is LibraryFilter &&
      other.kind == kind &&
      other.collection?.id == collection?.id;

  @override
  int get hashCode => Object.hash(kind, collection?.id);
}

/// The kinds of rows on the Library screen.
enum ShelfKind {
  /// Search, filter and new collection.
  controls,

  /// Started but not finished.
  continueReading,

  /// Own documents.
  documents,

  /// The user's collections.
  collections,

  /// Admin books (one shelf per category).
  books,

  /// Search or filter results.
  results,
}

/// One horizontal row of the Library.
@immutable
class Shelf {
  /// Creates a shelf.
  const Shelf(
    this.kind, {
    this.title,
    this.items = const [],
    this.collections = const [],
  });

  /// What it is.
  final ShelfKind kind;

  /// A category or collection name; otherwise the kind names the shelf.
  final String? title;

  /// Items on the shelf.
  final List<LibraryItem> items;

  /// Collections on the shelf (collections shelf only).
  final List<LibraryCollection> collections;

  /// Number of tiles.
  int get length => kind == ShelfKind.collections
      ? collections.length
      : kind == ShelfKind.controls
      ? 3
      : items.length;
}

/// Pure functions that turn the user's items into what the Library shows.
abstract final class LibraryView {
  /// Items passing [filter]. [favoriteIds] holds the ids with favorites;
  /// [collectionItemIds] the ids in the filter's collection.
  static List<LibraryItem> applyFilter(
    List<LibraryItem> items,
    LibraryFilter filter, {
    Set<String> favoriteIds = const {},
    Set<String> collectionItemIds = const {},
  }) => switch (filter.kind) {
    LibraryFilterKind.all => items,
    LibraryFilterKind.documents => [
      for (final i in items)
        if (!i.isBook) i,
    ],
    LibraryFilterKind.books => [
      for (final i in items)
        if (i.isBook) i,
    ],
    LibraryFilterKind.downloaded => [
      for (final i in items)
        if (i.downloaded) i,
    ],
    LibraryFilterKind.finished => [
      for (final i in items)
        if (i.finished) i,
    ],
    LibraryFilterKind.favorites => [
      for (final i in items)
        if (favoriteIds.contains(i.id)) i,
    ],
    LibraryFilterKind.collection => [
      for (final i in items)
        if (collectionItemIds.contains(i.id)) i,
    ],
  };

  /// Items whose title or author contains every word of [query]
  /// (case, accents and punctuation ignored).
  static List<LibraryItem> search(List<LibraryItem> items, String query) {
    final words = CommandMatcher.tokens(query);
    if (words.isEmpty) return items;
    return [
      for (final i in items)
        if (_matches(i, words)) i,
    ];
  }

  static bool _matches(LibraryItem item, List<String> words) {
    final hay = CommandMatcher.normalize('${item.title} ${item.author ?? ''}');
    return words.every(hay.contains);
  }

  /// The shelves for the current view. Unfiltered, the usual four appear
  /// (continue, documents, collections, books by category); filtered or
  /// searched, one results shelf (or one per category for books).
  static List<Shelf> shelves({
    required List<LibraryItem> items,
    required List<LibraryCollection> collections,
    required LibraryFilter filter,
    String query = '',
    Set<String> favoriteIds = const {},
    Set<String> collectionItemIds = const {},
  }) {
    const controls = Shelf(ShelfKind.controls);
    final searching = query.trim().isNotEmpty;
    if (filter.kind == LibraryFilterKind.all && !searching) {
      final started = [
        for (final i in items)
          if (i.inProgress) i,
      ]..sort(_byLastOpened);
      final documents = [
        for (final i in items)
          if (!i.isBook) i,
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return [
        controls,
        if (started.isNotEmpty)
          Shelf(ShelfKind.continueReading, items: started),
        Shelf(ShelfKind.documents, items: documents),
        Shelf(ShelfKind.collections, collections: collections),
        ..._bookShelves([
          for (final i in items)
            if (i.isBook) i,
        ]),
      ];
    }
    final filtered = search(
      applyFilter(
        items,
        filter,
        favoriteIds: favoriteIds,
        collectionItemIds: collectionItemIds,
      ),
      query,
    );
    return [
      controls,
      Shelf(ShelfKind.results, title: filter.collection?.name, items: filtered),
    ];
  }

  static List<Shelf> _bookShelves(List<LibraryItem> books) {
    if (books.isEmpty) return const [Shelf(ShelfKind.books)];
    final byCategory = <String, List<LibraryItem>>{};
    for (final b in books) {
      byCategory.putIfAbsent(b.category ?? '', () => []).add(b);
    }
    final names = byCategory.keys.toList()..sort();
    return [
      for (final name in names)
        Shelf(
          ShelfKind.books,
          title: name.isEmpty ? null : name,
          items: byCategory[name]!
            ..sort((a, b) {
              if (a.isNew != b.isNew) return a.isNew ? -1 : 1;
              return a.title.compareTo(b.title);
            }),
        ),
    ];
  }

  static int _byLastOpened(LibraryItem a, LibraryItem b) =>
      (b.lastOpenedAt ?? b.createdAt).compareTo(a.lastOpenedAt ?? a.createdAt);

  /// Minutes left to read at [readingRate] (1.0 = normal speech, about 150
  /// words a minute), or null when the word count is not known yet.
  static int? minutesLeft(LibraryItem item, double readingRate) {
    final words = item.wordCount;
    if (words == null || words == 0) return null;
    final remaining = item.finished ? words : words * (1 - item.percent / 100);
    final perMinute = 150 * readingRate.clamp(0.25, 4.0);
    final minutes = remaining / perMinute;
    return minutes < 1 ? 0 : minutes.ceil();
  }

  /// Items to "ituloy" (continue) matching [title]: the best title match.
  static LibraryItem? findByTitle(List<LibraryItem> items, String title) {
    final words = CommandMatcher.tokens(title);
    if (words.isEmpty) return null;
    final exact = CommandMatcher.normalize(title);
    LibraryItem? best;
    var bestScore = 0.0;
    for (final item in items) {
      final name = CommandMatcher.normalize(item.title);
      var score = 0.0;
      if (name == exact) {
        score = 2;
      } else if (name.contains(exact)) {
        score = 1 + exact.length / name.length;
      } else if (words.every(name.contains)) {
        score = 0.9;
      } else {
        final s = CommandMatcher.similarity(name, exact);
        if (s >= 0.75) score = s;
      }
      if (score > bestScore) {
        best = item;
        bestScore = score;
      }
    }
    return best;
  }
}
