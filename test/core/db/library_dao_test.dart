import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/db/daos/library_dao.dart';
import 'package:percipere_app/core/library/catalog_book.dart';
import 'package:percipere_app/core/library/library_models.dart';

import '../../helpers/fakes.dart';

CatalogBook book(
  String id, {
  int version = 1,
  bool active = true,
  String title = 'Aklat',
}) => CatalogBook(
  id: id,
  title: '$title $id',
  author: 'May-akda',
  language: 'fil',
  category: 'Nobela',
  description: 'Isang aklat.',
  format: LibraryFormat.epub,
  fileSize: 1000,
  version: version,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  active: active,
);

void main() {
  late LibraryDao dao;

  setUp(() async {
    final db = await openTestDatabase();
    dao = LibraryDao(db.db);
  });

  Future<LibraryItem> add(String title, [String text = 'Teksto.']) =>
      dao.insertDocument(
        title: title,
        fullText: text,
        source: LibrarySource.upload,
        format: LibraryFormat.pdf,
        language: 'fil',
      );

  test('insert and get: own documents are local-only with a uuid', () async {
    final item = await add('Liham', 'Mahal na Ginoo.');
    expect(item.id.length, 36);
    expect(item.title, 'Liham');
    expect(item.source, LibrarySource.upload);
    expect(item.format, LibraryFormat.pdf);
    expect(item.localOnly, isTrue);
    expect(item.percent, 0);
    expect(item.lastOpenedAt, isNull);
    expect(await dao.get('missing'), isNull);

    final text = await dao.loadText(item);
    expect(text.single.text, 'Mahal na Ginoo.');
  });

  test('list is newest first and reopened items move up', () async {
    final a = await add('Liham kay Nanay');
    final b = await add('Resibo');
    expect((await dao.list(null)).map((r) => r.id), [b.id, a.id]);

    await Future<void>.delayed(const Duration(milliseconds: 5));
    await dao.markOpened(a.id);
    expect((await dao.list(null)).map((r) => r.id), [a.id, b.id]);
  });

  test('items are separated per user', () async {
    await dao.insertDocument(
      title: 'Ana',
      fullText: 't',
      source: LibrarySource.camera,
      format: LibraryFormat.image,
      language: 'fil',
    );
    expect(await dao.list('someone-else'), isEmpty);
    expect(await dao.list(null), hasLength(1));
  });

  test('progress: percent from sentences, resume position, finished', () async {
    final item = await add('Libro');
    await dao.setTotals(item.id, totalSentences: 10, wordCount: 100);
    await dao.updateProgress(
      item.id,
      chapterIndex: 0,
      sentenceIndex: 4,
      globalSentence: 4,
    );
    var r = (await dao.get(item.id))!;
    expect(r.sentenceIndex, 4);
    expect(r.percent, 40);
    expect(r.inProgress, isTrue);
    expect(r.finished, isFalse);

    await dao.setFinished(item.id, finished: true);
    r = (await dao.get(item.id))!;
    expect(r.finished, isTrue);
    expect(r.percent, 100);
    expect(r.inProgress, isFalse);

    await dao.setFinished(item.id, finished: false);
    r = (await dao.get(item.id))!;
    expect(r.finished, isFalse);
    expect(r.percent, 40, reason: 'position is kept');

    await dao.resetProgress(item.id);
    r = (await dao.get(item.id))!;
    expect(r.sentenceIndex, 0);
    expect(r.percent, 0);
  });

  test('progress over chapters counts earlier chapters', () async {
    final item = await add('Libro');
    await dao.setTotals(
      item.id,
      totalSentences: 20,
      wordCount: 200,
      chapters: const [ChapterInfo('Isa', 8), ChapterInfo('Dalawa', 12)],
    );
    await dao.updateProgress(
      item.id,
      chapterIndex: 1,
      sentenceIndex: 2,
      globalSentence: 10,
    );
    final r = (await dao.get(item.id))!;
    expect(r.chapterIndex, 1);
    expect(r.sentenceIndex, 2);
    expect(r.globalSentence, 10);
    expect(r.percent, 50);
  });

  test('rename, and delete removes favorites and collection links', () async {
    final item = await add('Resibo');
    await dao.rename(item.id, 'Resibo sa palengke');
    expect((await dao.get(item.id))!.title, 'Resibo sa palengke');

    await dao.addFavorite(
      itemId: item.id,
      chapterIndex: 0,
      sentenceIndex: 1,
      label: 'Bigas',
    );
    final c = await dao.createCollection(null, 'Resibo');
    await dao.addToCollection(c.id, item.id);

    await dao.delete(item.id);
    expect(await dao.get(item.id), isNull);
    expect(await dao.favorites(item.id), isEmpty);
    expect(await dao.collectionItemIds(c.id), isEmpty);
    expect(
      await dao.collections(null),
      hasLength(1),
      reason: 'collection stays',
    );
  });

  test(
    'favorites: save once per spot, list in reading order, delete',
    () async {
      final item = await add('Libro');
      await dao.addFavorite(
        itemId: item.id,
        chapterIndex: 2,
        sentenceIndex: 0,
        label: 'Huli',
      );
      await dao.addFavorite(
        itemId: item.id,
        chapterIndex: 0,
        sentenceIndex: 5,
        label: 'Una',
      );
      await dao.addFavorite(
        itemId: item.id,
        chapterIndex: 0,
        sentenceIndex: 5,
        label: 'Una ulit',
      );
      final favs = await dao.favorites(item.id);
      expect(favs.map((f) => f.label), ['Una', 'Huli']);
      expect(await dao.itemsWithFavorites(null), {item.id});

      await dao.deleteFavorite(favs.first.id);
      expect((await dao.favorites(item.id)).single.label, 'Huli');
    },
  );

  test('collections: create, add, count, rename, delete keeps items', () async {
    final a = await add('Isa');
    final b = await add('Dalawa');
    final c = await dao.createCollection(null, 'Gamot');
    await dao.addToCollection(c.id, a.id);
    await dao.addToCollection(c.id, a.id);
    await dao.addToCollection(c.id, b.id);

    var list = await dao.collections(null);
    expect(list.single.name, 'Gamot');
    expect(list.single.itemCount, 2);
    expect(await dao.collectionItemIds(c.id), {a.id, b.id});
    expect(await dao.collectionsOf(a.id), {c.id});

    await dao.removeFromCollection(c.id, b.id);
    expect(await dao.collectionItemIds(c.id), {a.id});

    await dao.renameCollection(c.id, 'Mga gamot');
    list = await dao.collections(null);
    expect(list.single.name, 'Mga gamot');

    await dao.deleteCollection(c.id);
    expect(await dao.collections(null), isEmpty);
    expect(await dao.list(null), hasLength(2), reason: 'items are kept');
  });

  group('catalog', () {
    test('the first sync marks nothing new; later books are new', () async {
      var diff = await dao.syncCatalog(null, [book('1'), book('2')]);
      expect(diff.added, isEmpty);
      expect((await dao.list(null)).where((i) => i.isNew), isEmpty);

      diff = await dao.syncCatalog(null, [book('1'), book('2'), book('3')]);
      expect(diff.added, ['Aklat 3']);
      final newOnes = (await dao.list(null)).where((i) => i.isNew);
      expect(newOnes.single.bookId, '3');

      // Same catalog again: no new notice.
      diff = await dao.syncCatalog(null, [book('1'), book('2'), book('3')]);
      expect(diff.isEmpty, isTrue);

      // Viewing the details clears "Bago".
      await dao.clearNew(newOnes.single.id);
      expect((await dao.list(null)).where((i) => i.isNew), isEmpty);
    });

    test('a removed book is kept but unavailable; progress stays', () async {
      await dao.syncCatalog(null, [book('1')]);
      final item = (await dao.getBook(null, '1'))!;
      await dao.updateProgress(
        item.id,
        chapterIndex: 0,
        sentenceIndex: 3,
        globalSentence: 3,
      );

      var diff = await dao.syncCatalog(null, [book('1', active: false)]);
      expect(diff.removed, ['Aklat 1']);
      var r = (await dao.getBook(null, '1'))!;
      expect(r.unavailable, isTrue);
      expect(r.sentenceIndex, 3);

      // Reported once only.
      diff = await dao.syncCatalog(null, []);
      expect(diff.removed, isEmpty);
      r = (await dao.getBook(null, '1'))!;
      expect(r.unavailable, isTrue);
    });

    test('a downloaded book with a newer version is reported', () async {
      await dao.syncCatalog(null, [book('1')]);
      final item = (await dao.getBook(null, '1'))!;
      await dao.setDownloaded(item.id, filePath: '/x/1.epub', version: 1);

      final diff = await dao.syncCatalog(null, [book('1', version: 2)]);
      expect(diff.updated, ['Aklat 1']);
      final r = (await dao.getBook(null, '1'))!;
      expect(r.downloaded, isTrue);
      expect(r.updateAvailable, isTrue);

      final files = await dao.clearDownload(item.id);
      expect(files, ['/x/1.epub']);
      final cleared = (await dao.getBook(null, '1'))!;
      expect(cleared.downloaded, isFalse);
      expect(cleared.filePath, isNull);
    });

    test('books are per user', () async {
      await dao.syncCatalog(null, [book('1')]);
      expect(await dao.getBook('u1', '1'), isNull);
    });

    test('books cannot be renamed', () async {
      await dao.syncCatalog(null, [book('1')]);
      final item = (await dao.getBook(null, '1'))!;
      await dao.rename(item.id, 'Iba');
      expect((await dao.get(item.id))!.title, 'Aklat 1');
    });
  });
}
