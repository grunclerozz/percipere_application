import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../library/catalog_book.dart';
import '../../library/epub_parser.dart';
import '../../library/library_models.dart';
import '../../library/library_sync_repository.dart';
import '../app_database.dart';

/// Reads and writes the Library: items, favorites, collections.
///
/// Replaces the old Reading History DAO. Listing queries leave out the text
/// columns, so the Library opens fast however many documents there are.
class LibraryDao {
  /// Creates the DAO.
  LibraryDao(this._db);

  final DatabaseExecutor _db;

  static const Uuid _uuid = Uuid();
  static int get _now => DateTime.now().millisecondsSinceEpoch;

  /// Columns of a list row: everything except the text.
  static const List<String> _listColumns = [
    'id',
    'user_id',
    'source',
    'format',
    'language',
    'title',
    'author',
    'cover_path',
    'file_path',
    'text_ref',
    'text_path',
    'chapters',
    'total_sentences',
    'word_count',
    'chapter_index',
    'sentence_index',
    'percent',
    'finished',
    'last_opened_at',
    'created_at',
    'book_id',
    'book_version',
    'remote_version',
    'category',
    'description',
    'cover_url',
    'file_size',
    'downloaded',
    'is_new',
    'unavailable',
    'local_only',
  ];

  static LibraryItem _item(Map<String, Object?> r) => LibraryItem(
    id: r['id']! as String,
    userId: r['user_id'] as String?,
    source: LibrarySource.parse(r['source']! as String),
    format: LibraryFormat.parse(r['format']! as String),
    language: r['language']! as String,
    title: r['title']! as String,
    author: r['author'] as String?,
    coverPath: r['cover_path'] as String?,
    filePath: r['file_path'] as String?,
    textRef: r['text_ref']! as String,
    textPath: r['text_path'] as String?,
    chapters: ChapterInfo.decode(r['chapters'] as String?),
    totalSentences: r['total_sentences'] as int?,
    wordCount: r['word_count'] as int?,
    chapterIndex: r['chapter_index']! as int,
    sentenceIndex: r['sentence_index']! as int,
    percent: (r['percent']! as num).toDouble(),
    finished: r['finished'] == 1,
    lastOpenedAt: r['last_opened_at'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(r['last_opened_at']! as int),
    createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at']! as int),
    bookId: r['book_id'] as String?,
    bookVersion: r['book_version'] as int?,
    remoteVersion: r['remote_version'] as int?,
    category: r['category'] as String?,
    description: r['description'] as String?,
    coverUrl: r['cover_url'] as String?,
    fileSize: r['file_size'] as int?,
    downloaded: r['downloaded'] == 1,
    isNew: r['is_new'] == 1,
    unavailable: r['unavailable'] == 1,
    localOnly: r['local_only'] == 1,
  );

  // ── Items ─────────────────────────────────────────────────────────────────

  /// Saves a newly read document of the user's own; returns it.
  Future<LibraryItem> insertDocument({
    required String title,
    required String fullText,
    required LibrarySource source,
    required LibraryFormat format,
    required String language,
    String? userId,
    String? coverPath,
    int? totalSentences,
    int? wordCount,
  }) async {
    final id = _uuid.v4();
    final now = _now;
    await _db.insert('library_items', {
      'id': id,
      'user_id': userId,
      'source': source.name,
      'format': format.name,
      'language': language,
      'title': title,
      'cover_path': coverPath,
      'text_ref': 'db',
      'full_text': fullText,
      'total_sentences': totalSentences,
      'word_count': wordCount,
      'created_at': now,
      'updated_at': now,
      'local_only': 1,
    });
    return (await get(id))!;
  }

  /// Loads one item (without its text), or null.
  Future<LibraryItem?> get(String id) async {
    final rows = await _db.query(
      'library_items',
      columns: _listColumns,
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : _item(rows.single);
  }

  /// The item of [userId] for catalog book [bookId], or null.
  Future<LibraryItem?> getBook(String? userId, String bookId) async {
    final rows = await _db.query(
      'library_items',
      columns: _listColumns,
      where: 'user_id IS ? AND book_id = ?',
      whereArgs: [userId, bookId],
    );
    return rows.isEmpty ? null : _item(rows.single);
  }

  /// All of [userId]'s items, most recently opened (or added) first.
  Future<List<LibraryItem>> list(String? userId) async {
    final rows = await _db.query(
      'library_items',
      columns: _listColumns,
      where: 'user_id IS ?',
      whereArgs: [userId],
      orderBy: 'COALESCE(last_opened_at, created_at) DESC, created_at DESC',
    );
    return rows.map(_item).toList();
  }

  /// Loads the item's text as chapters. Own documents are one chapter.
  /// Returns an empty list if the cache is missing or unreadable.
  Future<List<ChapterText>> loadText(LibraryItem item) async {
    try {
      if (item.textRef == 'file') {
        final path = item.textPath;
        if (path == null) return const [];
        return BookText.fromJsonString(await File(path).readAsString())
            .chapters;
      }
      final rows = await _db.query(
        'library_items',
        columns: ['full_text'],
        where: 'id = ?',
        whereArgs: [item.id],
      );
      final text = rows.isEmpty ? null : rows.single['full_text'] as String?;
      return text == null ? const [] : [ChapterText(item.title, text)];
    } on Object {
      return const [];
    }
  }

  /// Items whose sentence total is not known yet (migrated history).
  Future<List<({String id, String text})>> itemsNeedingTotals() async {
    final rows = await _db.query(
      'library_items',
      columns: ['id', 'full_text'],
      where:
          "total_sentences IS NULL AND text_ref = 'db' "
          'AND full_text IS NOT NULL',
    );
    return [
      for (final r in rows)
        (id: r['id']! as String, text: r['full_text']! as String),
    ];
  }

  /// Stores the counts of an item and recomputes its percentage.
  Future<void> setTotals(
    String id, {
    required int totalSentences,
    required int wordCount,
    List<ChapterInfo>? chapters,
  }) async {
    final item = await get(id);
    if (item == null) return;
    final global = item.globalSentence;
    await _db.update(
      'library_items',
      {
        'total_sentences': totalSentences,
        'word_count': wordCount,
        if (chapters != null) 'chapters': ChapterInfo.encode(chapters),
        'percent': _percent(global, totalSentences, item.finished),
        'updated_at': _now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static double _percent(int global, int total, bool finished) {
    if (finished) return 100;
    if (total <= 0) return 0;
    return (global / total * 100).clamp(0, 99.0).toDouble();
  }

  /// Saves the resume position and progress. Reaching the last sentence is
  /// done with [markFinished].
  Future<void> updateProgress(
    String id, {
    required int chapterIndex,
    required int sentenceIndex,
    required int globalSentence,
  }) async {
    final rows = await _db.query(
      'library_items',
      columns: ['total_sentences', 'finished'],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return;
    final total = rows.single['total_sentences'] as int?;
    final finished = rows.single['finished'] == 1;
    await _db.update(
      'library_items',
      {
        'chapter_index': chapterIndex,
        'sentence_index': sentenceIndex,
        if (total != null && !finished)
          'percent': _percent(globalSentence, total, false),
        'updated_at': _now,
        'synced': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Marks an item finished (or not), keeping its position.
  Future<void> setFinished(String id, {required bool finished}) async {
    final item = await get(id);
    if (item == null) return;
    await _db.update(
      'library_items',
      {
        'finished': finished ? 1 : 0,
        'percent': finished
            ? 100
            : _percent(item.globalSentence, item.totalSentences ?? 0, false),
        'updated_at': _now,
        'synced': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Back to the start: position 0, not finished.
  Future<void> resetProgress(String id) => _db.update(
    'library_items',
    {
      'chapter_index': 0,
      'sentence_index': 0,
      'percent': 0,
      'finished': 0,
      'updated_at': _now,
      'synced': 0,
    },
    where: 'id = ?',
    whereArgs: [id],
  );

  /// Replaces the text of a saved description (a detailed one arrived).
  Future<void> updateText(String id, String fullText) => _db.update(
    'library_items',
    {'full_text': fullText, 'total_sentences': null, 'updated_at': _now},
    where: 'id = ?',
    whereArgs: [id],
  );

  /// Sets the cover file of an item.
  Future<void> setCover(String id, String path) => _db.update(
    'library_items',
    {'cover_path': path},
    where: 'id = ?',
    whereArgs: [id],
  );

  /// Records that the item was opened.
  Future<void> markOpened(String id) => _db.update(
    'library_items',
    {'last_opened_at': _now, 'is_new': 0},
    where: 'id = ?',
    whereArgs: [id],
  );

  /// Clears the "Bago" label (the details were viewed).
  Future<void> clearNew(String id) => _db.update(
    'library_items',
    {'is_new': 0},
    where: 'id = ?',
    whereArgs: [id],
  );

  /// Renames an own document.
  Future<void> rename(String id, String title) => _db.update(
    'library_items',
    {'title': title, 'updated_at': _now},
    where: 'id = ? AND source != ?',
    whereArgs: [id, LibrarySource.book.name],
  );

  /// Deletes an own document with its favorites and collection links (cascade).
  /// Returns the files that belonged to it, for the caller to delete.
  Future<List<String>> delete(String id) async {
    final item = await get(id);
    if (item == null) return const [];
    await _db.delete('library_items', where: 'id = ?', whereArgs: [id]);
    return [?item.coverPath, ?item.filePath, ?item.textPath];
  }

  // ── Books ─────────────────────────────────────────────────────────────────

  /// Merges a fresh [catalog] into [userId]'s book rows and says what changed.
  /// The first sync for a user marks nothing "new".
  Future<CatalogDiff> syncCatalog(String? userId, List<CatalogBook> catalog) =>
      _transaction((txn) async {
        final existingRows = await txn.query(
          'library_items',
          columns: [
            'id',
            'book_id',
            'book_version',
            'downloaded',
            'title',
            'unavailable',
          ],
          where: 'user_id IS ? AND book_id IS NOT NULL',
          whereArgs: [userId],
        );
        final firstSync = existingRows.isEmpty;
        final byBook = {
          for (final r in existingRows) r['book_id']! as String: r,
        };
        final added = <String>[];
        final removed = <String>[];
        final updated = <String>[];
        final seen = <String>{};
        for (final b in catalog) {
          seen.add(b.id);
          final row = byBook[b.id];
          final fields = <String, Object?>{
            'title': b.title,
            'author': b.author,
            'language': b.language,
            'format': b.format.name,
            'category': b.category,
            'description': b.description,
            'cover_url': b.coverUrl,
            'file_size': b.fileSize,
            'remote_version': b.version,
            'unavailable': b.active ? 0 : 1,
            'updated_at': _now,
          };
          if (row == null) {
            if (!b.active) continue;
            await txn.insert('library_items', {
              ...fields,
              'id': _uuid.v4(),
              'user_id': userId,
              'source': LibrarySource.book.name,
              'text_ref': 'file',
              'book_id': b.id,
              'is_new': firstSync ? 0 : 1,
              'created_at': b.createdAt.millisecondsSinceEpoch,
            });
            if (!firstSync) added.add(b.title);
          } else {
            await txn.update(
              'library_items',
              fields,
              where: 'id = ?',
              whereArgs: [row['id']],
            );
            if (!b.active && row['unavailable'] != 1) removed.add(b.title);
            if (b.active &&
                row['downloaded'] == 1 &&
                (row['book_version'] as int? ?? 0) < b.version) {
              updated.add(b.title);
            }
          }
        }
        // Gone from the catalog altogether = removed by the admin.
        for (final e in byBook.entries) {
          if (!seen.contains(e.key) && e.value['unavailable'] != 1) {
            await txn.update(
              'library_items',
              {'unavailable': 1, 'updated_at': _now},
              where: 'id = ?',
              whereArgs: [e.value['id']],
            );
            removed.add(e.value['title']! as String);
          }
        }
        return CatalogDiff(added: added, removed: removed, updated: updated);
      });

  /// Marks a book downloaded at [version] with its [filePath] and text cache.
  Future<void> setDownloaded(
    String id, {
    required String filePath,
    required int version,
    String? textPath,
    List<ChapterInfo>? chapters,
    int? totalSentences,
    int? wordCount,
    String? coverPath,
  }) => _db.update(
    'library_items',
    {
      'downloaded': 1,
      'file_path': filePath,
      'book_version': version,
      'text_path': ?textPath,
      'chapters': ?(chapters == null ? null : ChapterInfo.encode(chapters)),
      'total_sentences': ?totalSentences,
      'word_count': ?wordCount,
      'cover_path': ?coverPath,
      'updated_at': _now,
      'synced': 0,
    },
    where: 'id = ?',
    whereArgs: [id],
  );

  /// Forgets a downloaded book's files but keeps its progress.
  Future<List<String>> clearDownload(String id) async {
    final item = await get(id);
    if (item == null) return const [];
    await _db.update(
      'library_items',
      {
        'downloaded': 0,
        'file_path': null,
        'text_path': null,
        'book_version': null,
        'updated_at': _now,
        'synced': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    return [?item.filePath, ?item.textPath];
  }

  /// Saves the text cache of a book that is only being read online.
  Future<void> setTextCache(
    String id, {
    required String textPath,
    required List<ChapterInfo> chapters,
    required int totalSentences,
    required int wordCount,
  }) async {
    final item = await get(id);
    if (item == null) return;
    final pos = item.globalSentence;
    await _db.update(
      'library_items',
      {
        'text_path': textPath,
        'chapters': ChapterInfo.encode(chapters),
        'total_sentences': totalSentences,
        'word_count': wordCount,
        'percent': _percent(pos, totalSentences, item.finished),
        'updated_at': _now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// What [userId] would send to the web app (Phase 7): admin books they have
  /// started or downloaded, progress, favorites inside books and collections
  /// with their book links. Own documents are never included.
  Future<LibrarySyncBatch> syncBatch(String userId) async {
    final books = await _db.query(
      'library_items',
      columns: _listColumns,
      where:
          'user_id = ? AND source = \x27book\x27 AND local_only = 0 AND '
          '(downloaded = 1 OR percent > 0 OR finished = 1)',
      whereArgs: [userId],
    );
    final bookIds = {for (final b in books) b['id']! as String};
    final favorites = <Map<String, Object?>>[];
    for (final id in bookIds) {
      for (final f in await this.favorites(id)) {
        favorites.add({
          'id': f.id,
          'bookId': books.firstWhere((b) => b['id'] == id)['book_id'],
          'chapter': f.chapterIndex,
          'sentence': f.sentenceIndex,
          'label': f.label,
        });
      }
    }
    final collections = <Map<String, Object?>>[];
    for (final c in await this.collections(userId)) {
      final ids = await collectionItemIds(c.id);
      collections.add({
        'id': c.id,
        'name': c.name,
        'bookIds': [
          for (final b in books)
            if (ids.contains(b['id'])) b['book_id'],
        ],
      });
    }
    return LibrarySyncBatch(
      books: [
        for (final b in books)
          {'bookId': b['book_id'], 'downloaded': b['downloaded'] == 1},
      ],
      progress: [
        for (final b in books)
          {
            'bookId': b['book_id'],
            'chapter': b['chapter_index'],
            'sentence': b['sentence_index'],
            'percent': b['percent'],
            'finished': b['finished'] == 1,
          },
      ],
      favorites: favorites,
      collections: collections,
    );
  }

  // ── Favorites ─────────────────────────────────────────────────────────────

  /// Saves a spot; the same spot twice is stored once. Returns the favorite.
  Future<Favorite> addFavorite({
    required String itemId,
    required int chapterIndex,
    required int sentenceIndex,
    required String label,
  }) async {
    final existing = await _db.query(
      'library_favorites',
      where: 'item_id = ? AND chapter_index = ? AND sentence_index = ?',
      whereArgs: [itemId, chapterIndex, sentenceIndex],
    );
    if (existing.isNotEmpty) return _favorite(existing.first);
    final id = _uuid.v4();
    final now = _now;
    await _db.insert('library_favorites', {
      'id': id,
      'item_id': itemId,
      'chapter_index': chapterIndex,
      'sentence_index': sentenceIndex,
      'label': label,
      'created_at': now,
      'updated_at': now,
    });
    return Favorite(
      id: id,
      itemId: itemId,
      chapterIndex: chapterIndex,
      sentenceIndex: sentenceIndex,
      label: label,
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
  }

  static Favorite _favorite(Map<String, Object?> r) => Favorite(
    id: r['id']! as String,
    itemId: r['item_id']! as String,
    chapterIndex: r['chapter_index']! as int,
    sentenceIndex: r['sentence_index']! as int,
    label: r['label']! as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at']! as int),
  );

  /// The item's favorites in reading order.
  Future<List<Favorite>> favorites(String itemId) async {
    final rows = await _db.query(
      'library_favorites',
      where: 'item_id = ?',
      whereArgs: [itemId],
      orderBy: 'chapter_index, sentence_index',
    );
    return rows.map(_favorite).toList();
  }

  /// Deletes a favorite.
  Future<void> deleteFavorite(String id) =>
      _db.delete('library_favorites', where: 'id = ?', whereArgs: [id]);

  /// Ids of [userId]'s items that have at least one favorite.
  Future<Set<String>> itemsWithFavorites(String? userId) async {
    final rows = await _db.rawQuery(
      'SELECT DISTINCT f.item_id AS id FROM library_favorites f '
      'JOIN library_items i ON i.id = f.item_id WHERE i.user_id IS ?',
      [userId],
    );
    return {for (final r in rows) r['id']! as String};
  }

  // ── Collections ───────────────────────────────────────────────────────────

  /// Creates a collection.
  Future<LibraryCollection> createCollection(
    String? userId,
    String name,
  ) async {
    final id = _uuid.v4();
    final now = _now;
    await _db.insert('library_collections', {
      'id': id,
      'user_id': userId,
      'name': name,
      'created_at': now,
      'updated_at': now,
    });
    return LibraryCollection(id: id, name: name, itemCount: 0);
  }

  /// [userId]'s collections, oldest first, with item counts.
  Future<List<LibraryCollection>> collections(String? userId) async {
    final rows = await _db.rawQuery(
      'SELECT c.id, c.name, '
      '(SELECT COUNT(*) FROM library_collection_items x '
      ' WHERE x.collection_id = c.id) AS n '
      'FROM library_collections c WHERE c.user_id IS ? '
      'ORDER BY c.created_at, c.name',
      [userId],
    );
    return [
      for (final r in rows)
        LibraryCollection(
          id: r['id']! as String,
          name: r['name']! as String,
          itemCount: (r['n']! as num).toInt(),
        ),
    ];
  }

  /// Renames a collection.
  Future<void> renameCollection(String id, String name) => _db.update(
    'library_collections',
    {'name': name, 'updated_at': _now, 'synced': 0},
    where: 'id = ?',
    whereArgs: [id],
  );

  /// Deletes a collection. Its items stay.
  Future<void> deleteCollection(String id) =>
      _db.delete('library_collections', where: 'id = ?', whereArgs: [id]);

  /// Adds an item to a collection (twice is fine).
  Future<void> addToCollection(String collectionId, String itemId) =>
      _db.insert('library_collection_items', {
        'collection_id': collectionId,
        'item_id': itemId,
        'added_at': _now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

  /// Removes an item from a collection.
  Future<void> removeFromCollection(String collectionId, String itemId) =>
      _db.delete(
        'library_collection_items',
        where: 'collection_id = ? AND item_id = ?',
        whereArgs: [collectionId, itemId],
      );

  /// Ids of the items in a collection.
  Future<Set<String>> collectionItemIds(String collectionId) async {
    final rows = await _db.query(
      'library_collection_items',
      columns: ['item_id'],
      where: 'collection_id = ?',
      whereArgs: [collectionId],
    );
    return {for (final r in rows) r['item_id']! as String};
  }

  /// Ids of the collections an item is in.
  Future<Set<String>> collectionsOf(String itemId) async {
    final rows = await _db.query(
      'library_collection_items',
      columns: ['collection_id'],
      where: 'item_id = ?',
      whereArgs: [itemId],
    );
    return {for (final r in rows) r['collection_id']! as String};
  }

  Future<T> _transaction<T>(Future<T> Function(Transaction txn) action) {
    final db = _db;
    if (db is Database) return db.transaction(action);
    if (db is Transaction) return action(db);
    throw StateError('Unsupported executor ${db.runtimeType}');
  }
}

/// Library access.
final libraryDaoProvider = Provider<LibraryDao>(
  (ref) => LibraryDao(ref.watch(appDatabaseProvider).db),
);
