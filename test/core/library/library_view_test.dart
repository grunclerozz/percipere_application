import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/library/library_models.dart';
import 'package:percipere_app/core/library/library_view.dart';

LibraryItem doc(
  String id,
  String title, {
  double percent = 0,
  bool finished = false,
  DateTime? opened,
  DateTime? created,
  int? words,
  int sentence = 0,
}) => LibraryItem(
  id: id,
  source: LibrarySource.upload,
  format: LibraryFormat.pdf,
  language: 'fil',
  title: title,
  createdAt: created ?? DateTime(2026, 1, 1),
  percent: percent,
  finished: finished,
  lastOpenedAt: opened,
  wordCount: words,
  sentenceIndex: sentence,
);

LibraryItem book(
  String id,
  String title, {
  String category = 'Nobela',
  String author = 'Balagtas',
  bool downloaded = false,
  bool isNew = false,
  double percent = 0,
  DateTime? opened,
}) => LibraryItem(
  id: id,
  source: LibrarySource.book,
  format: LibraryFormat.epub,
  language: 'fil',
  title: title,
  author: author,
  category: category,
  createdAt: DateTime(2026, 1, 1),
  downloaded: downloaded,
  isNew: isNew,
  percent: percent,
  lastOpenedAt: opened,
  bookId: id,
);

void main() {
  final items = [
    doc('d1', 'Resibo sa palengke', created: DateTime(2026, 3, 1)),
    doc(
      'd2',
      'Liham kay Nanay',
      percent: 40,
      sentence: 3,
      opened: DateTime(2026, 4, 2),
      created: DateTime(2026, 2, 1),
    ),
    doc(
      'd3',
      'Reseta',
      finished: true,
      percent: 100,
      created: DateTime(2026, 5, 1),
    ),
    book(
      'b1',
      'Florante at Laura',
      percent: 45,
      opened: DateTime(2026, 4, 5),
      downloaded: true,
    ),
    book('b2', 'Noli Me Tangere', author: 'Jose Rizal', isNew: true),
    book('b3', 'Aesop', category: 'Pabula'),
  ];
  const collection = LibraryCollection(id: 'c1', name: 'Gamot', itemCount: 1);

  group('shelves', () {
    final shelves = LibraryView.shelves(
      items: items,
      collections: const [collection],
      filter: LibraryFilter.all,
    );

    test('controls, continue, documents, collections, books by category', () {
      expect(shelves.map((s) => s.kind), [
        ShelfKind.controls,
        ShelfKind.continueReading,
        ShelfKind.documents,
        ShelfKind.collections,
        ShelfKind.books,
        ShelfKind.books,
      ]);
      expect(shelves[4].title, 'Nobela');
      expect(shelves[5].title, 'Pabula');
    });

    test('continue reading: started, not finished, most recent first', () {
      expect(shelves[1].items.map((i) => i.id), ['b1', 'd2']);
    });

    test('my documents: newest first', () {
      expect(shelves[2].items.map((i) => i.id), ['d3', 'd1', 'd2']);
    });

    test('new books come first on their shelf', () {
      expect(shelves[4].items.map((i) => i.id), ['b2', 'b1']);
    });

    test('empty shelves are still there to announce', () {
      final empty = LibraryView.shelves(
        items: const [],
        collections: const [],
        filter: LibraryFilter.all,
      );
      expect(empty.map((s) => s.kind), [
        ShelfKind.controls,
        ShelfKind.documents,
        ShelfKind.collections,
        ShelfKind.books,
      ]);
      expect(empty[1].length, 0);
    });
  });

  group('filters', () {
    List<String> ids(
      LibraryFilter f, {
      Set<String> fav = const {},
      Set<String> inCollection = const {},
    }) => LibraryView.applyFilter(
      items,
      f,
      favoriteIds: fav,
      collectionItemIds: inCollection,
    ).map((i) => i.id).toList();

    test('each filter keeps the right items', () {
      expect(ids(LibraryFilter.all), hasLength(6));
      expect(ids(const LibraryFilter(LibraryFilterKind.documents)), [
        'd1',
        'd2',
        'd3',
      ]);
      expect(ids(const LibraryFilter(LibraryFilterKind.books)), [
        'b1',
        'b2',
        'b3',
      ]);
      expect(ids(const LibraryFilter(LibraryFilterKind.downloaded)), ['b1']);
      expect(ids(const LibraryFilter(LibraryFilterKind.finished)), ['d3']);
      expect(
        ids(
          const LibraryFilter(LibraryFilterKind.favorites),
          fav: {'d2', 'b3'},
        ),
        ['d2', 'b3'],
      );
      expect(
        ids(
          const LibraryFilter(
            LibraryFilterKind.collection,
            collection: collection,
          ),
          inCollection: {'b2', 'd1'},
        ),
        ['d1', 'b2'],
      );
    });

    test('a filtered view is one results shelf', () {
      final shelves = LibraryView.shelves(
        items: items,
        collections: const [collection],
        filter: const LibraryFilter(LibraryFilterKind.finished),
      );
      expect(shelves.map((s) => s.kind), [
        ShelfKind.controls,
        ShelfKind.results,
      ]);
      expect(shelves.last.items.map((i) => i.id), ['d3']);
    });

    test('filters compare by kind and collection', () {
      expect(
        const LibraryFilter(
          LibraryFilterKind.collection,
          collection: collection,
        ),
        const LibraryFilter(
          LibraryFilterKind.collection,
          collection: LibraryCollection(id: 'c1', name: 'Bago', itemCount: 0),
        ),
      );
      expect(
        LibraryFilter.all,
        isNot(const LibraryFilter(LibraryFilterKind.books)),
      );
    });
  });

  group('search', () {
    test('matches title or author, ignoring case and accents', () {
      expect(LibraryView.search(items, 'FLORANTE').map((i) => i.id), ['b1']);
      expect(LibraryView.search(items, 'rizal').map((i) => i.id), ['b2']);
      expect(LibraryView.search(items, 'liham nanay').map((i) => i.id), ['d2']);
      expect(LibraryView.search(items, 'wala'), isEmpty);
      expect(LibraryView.search(items, '  '), hasLength(6));
    });

    test('search and filter work together (a collection is searchable)', () {
      final shelves = LibraryView.shelves(
        items: items,
        collections: const [collection],
        filter: const LibraryFilter(
          LibraryFilterKind.collection,
          collection: collection,
        ),
        query: 're',
        collectionItemIds: {'d1', 'd3', 'b1'},
      );
      expect(shelves.last.items.map((i) => i.id), ['d1', 'd3']);
    });
  });

  group('voice titles', () {
    test('finds an item by part of its title, or a near miss', () {
      expect(LibraryView.findByTitle(items, 'florante at laura')?.id, 'b1');
      expect(LibraryView.findByTitle(items, 'Florante')?.id, 'b1');
      expect(LibraryView.findByTitle(items, 'noli')?.id, 'b2');
      expect(LibraryView.findByTitle(items, 'liham kay nanai')?.id, 'd2');
      expect(LibraryView.findByTitle(items, 'xyz'), isNull);
      expect(LibraryView.findByTitle(items, ''), isNull);
    });
  });

  group('time left', () {
    test('words left at the user\'s speed', () {
      final half = doc('x', 'Libro', words: 3000, percent: 50, sentence: 1);
      expect(LibraryView.minutesLeft(half, 1), 10); // 1500 words at 150/min
      expect(LibraryView.minutesLeft(half, 2), 5);
      expect(LibraryView.minutesLeft(half, 0.5), 20);
    });

    test('unknown until the words are counted', () {
      expect(LibraryView.minutesLeft(doc('x', 'Libro'), 1), isNull);
    });

    test('a finished item counts the whole text again', () {
      final done = doc('x', 'Libro', words: 1500, finished: true, percent: 100);
      expect(LibraryView.minutesLeft(done, 1), 10);
    });
  });

  group('progress', () {
    test('global position adds earlier chapters', () {
      final item = LibraryItem(
        id: 'i',
        source: LibrarySource.book,
        format: LibraryFormat.epub,
        language: 'fil',
        title: 'T',
        createdAt: _t,
        chapters: const [
          ChapterInfo('a', 4),
          ChapterInfo('b', 5),
          ChapterInfo('c', 6),
        ],
        chapterIndex: 2,
        sentenceIndex: 3,
      );
      expect(item.globalSentence, 12);
    });
  });
}

final DateTime _t = DateTime(2026);
