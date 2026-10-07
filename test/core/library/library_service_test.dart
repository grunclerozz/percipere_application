import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/accessibility/navigation_mode.dart';
import 'package:percipere_app/core/db/daos/library_dao.dart';
import 'package:percipere_app/core/library/book_content.dart';
import 'package:percipere_app/core/library/library_models.dart';
import 'package:percipere_app/core/library/library_service.dart';

import '../../helpers/fakes.dart';

void main() {
  late TestEnv env;
  late ProviderContainer container;

  LibraryService service() => container.read(libraryServiceProvider);
  LibraryDao dao() => container.read(libraryDaoProvider);
  String user() => env.account!.id;

  setUp(() async {
    env = await TestEnv.create(mode: NavMode.gestures);
    container = ProviderContainer(overrides: env.overrides);
    addTearDown(container.dispose);
  });

  Future<LibraryItem> bookItem(String id) async {
    final item = await dao().getBook(user(), id);
    return item!;
  }

  group('catalog', () {
    test(
      'the first refresh fills the shelves with covers, nothing is new',
      () async {
        final diff = await service().refreshCatalog();
        expect(diff!.added, isEmpty);
        final items = await dao().list(user());
        expect(items.where((i) => i.isBook), hasLength(3));
        expect(items.where((i) => i.isNew), isEmpty);
        final fables = await bookItem('bk-fables');
        expect(fables.title, "Aesop's Fables, Selected");
        expect(fables.category, 'Fables');
        expect(fables.fileSize, greaterThan(0));
        expect(File(fables.coverPath!).existsSync(), isTrue);
      },
    );

    test('books added later are new, once', () async {
      await service().refreshCatalog();
      env.books.simulateNewBook();
      final diff = await service().refreshCatalog();
      expect(diff!.added, ['The Crow and the Pitcher']);
      expect((await bookItem('bk-crow')).isNew, isTrue);
      expect((await service().refreshCatalog())!.added, isEmpty);
    });

    test(
      'offline: the refresh returns null and the cached list stays',
      () async {
        await service().refreshCatalog();
        env.books.offline = true;
        expect(await service().refreshCatalog(), isNull);
        expect((await dao().list(user())).where((i) => i.isBook), hasLength(3));
      },
    );

    test('a removed book is reported once and marked unavailable', () async {
      await service().refreshCatalog();
      env.books.simulateRemoval('bk-hare');
      final diff = await service().refreshCatalog();
      expect(diff!.removed, ['The Tortoise and the Hare']);
      expect((await bookItem('bk-hare')).unavailable, isTrue);
      expect((await service().refreshCatalog())!.removed, isEmpty);
    });
  });

  group('reading online', () {
    test(
      'fetches into the cache, parses chapters, keeps it not downloaded',
      () async {
        await service().refreshCatalog();
        final item = await bookItem('bk-fables');
        final progress = <double?>[];
        final result = await service().prepareToRead(
          item,
          onProgress: progress.add,
        );
        expect(result, BookResult.ready);
        expect(progress, isNotEmpty);
        expect(progress.last, 1.0);

        final after = await bookItem('bk-fables');
        expect(after.downloaded, isFalse);
        expect(after.chapters.map((c) => c.title), [
          'The Tortoise and the Hare',
          'The Ant and the Grasshopper',
          'The Lion and the Mouse',
        ]);
        expect(after.totalSentences, greaterThan(10));
        final text = await dao().loadText(after);
        expect(text, hasLength(3));
        expect(text.first.text, contains('A hare once laughed'));
      },
    );

    test('the same book is not fetched twice', () async {
      await service().refreshCatalog();
      final item = await bookItem('bk-fables');
      await service().prepareToRead(item);
      env.books.offline = true;
      final again = await service().prepareToRead(await bookItem('bk-fables'));
      expect(again, BookResult.ready, reason: 'read from the cached text');
    });

    test('offline and not on the phone: needs internet', () async {
      await service().refreshCatalog();
      env.books.offline = true;
      final result = await service().prepareToRead(await bookItem('bk-fables'));
      expect(result, BookResult.offline);
    });

    test('a removed book that was never downloaded cannot be read', () async {
      await service().refreshCatalog();
      env.books.simulateRemoval('bk-fables');
      await service().refreshCatalog();
      final result = await service().prepareToRead(await bookItem('bk-fables'));
      expect(result, BookResult.unavailable);
    });

    test('DRM and damaged files give their own result', () async {
      await service().refreshCatalog();
      final item = await bookItem('bk-fables');
      env.bookLoader.problem = BookReadProblem.drm;
      expect(await service().prepareToRead(item), BookResult.drm);
      env.bookLoader.problem = BookReadProblem.invalid;
      expect(await service().prepareToRead(item), BookResult.invalid);
      env.bookLoader.problem = BookReadProblem.passwordProtected;
      expect(await service().prepareToRead(item), BookResult.passwordProtected);
    });
  });

  group('downloading', () {
    test(
      'saves the file, marks it downloaded and lists it under Na-download',
      () async {
        await service().refreshCatalog();
        final item = await bookItem('bk-hare');
        final result = await service().download(item);
        expect(result, BookResult.ready);

        final after = await bookItem('bk-hare');
        expect(after.downloaded, isTrue);
        expect(File(after.filePath!).existsSync(), isTrue);
        expect(after.bookVersion, 1);
        expect(after.chapters.map((c) => c.title), ['The Race', 'The Finish']);
      },
    );

    test('works offline once downloaded', () async {
      await service().refreshCatalog();
      await service().download(await bookItem('bk-fables'));
      env.books.offline = true;
      final result = await service().prepareToRead(await bookItem('bk-fables'));
      expect(result, BookResult.ready);
    });

    test('low storage asks first; going on anyway downloads', () async {
      await service().refreshCatalog();
      final item = await bookItem('bk-fables');
      env.storage.free = 1024;
      expect(await service().download(item), BookResult.lowStorage);
      expect((await bookItem('bk-fables')).downloaded, isFalse);
      expect(
        await service().download(item, ignoreLowStorage: true),
        BookResult.ready,
      );
    });

    test('unknown free space does not block', () async {
      await service().refreshCatalog();
      env.storage.free = null;
      expect(
        await service().download(await bookItem('bk-hare')),
        BookResult.ready,
      );
    });

    test('a failed download leaves nothing behind', () async {
      await service().refreshCatalog();
      final item = await bookItem('bk-hare');
      env.bookLoader.problem = BookReadProblem.invalid;
      expect(await service().download(item), BookResult.invalid);
      final after = await bookItem('bk-hare');
      expect(after.downloaded, isFalse);
      expect(after.filePath, isNull);
    });

    test('offline download fails cleanly', () async {
      await service().refreshCatalog();
      env.books.offline = true;
      expect(
        await service().download(await bookItem('bk-hare')),
        BookResult.offline,
      );
    });

    test('removing the download keeps progress and favorites', () async {
      await service().refreshCatalog();
      var item = await bookItem('bk-fables');
      await service().download(item);
      item = await bookItem('bk-fables');
      await dao().updateProgress(
        item.id,
        chapterIndex: 1,
        sentenceIndex: 2,
        globalSentence: 8,
      );
      await dao().addFavorite(
        itemId: item.id,
        chapterIndex: 1,
        sentenceIndex: 0,
        label: 'All summer long',
      );
      final file = item.filePath!;

      await service().removeDownload(item);

      final after = await bookItem('bk-fables');
      expect(after.downloaded, isFalse);
      expect(File(file).existsSync(), isFalse);
      expect(after.chapterIndex, 1);
      expect(after.sentenceIndex, 2);
      expect(await dao().favorites(after.id), hasLength(1));
    });

    test('a new version: the download updates and progress stays', () async {
      await service().refreshCatalog();
      var item = await bookItem('bk-hare');
      await service().download(item);
      item = await bookItem('bk-hare');
      await dao().updateProgress(
        item.id,
        chapterIndex: 1,
        sentenceIndex: 1,
        globalSentence: 4,
      );

      env.books.simulateUpdate('bk-hare');
      final diff = await service().refreshCatalog();
      expect(diff!.updated, ['The Tortoise and the Hare']);
      item = await bookItem('bk-hare');
      expect(item.updateAvailable, isTrue);
      final oldFile = item.filePath!;

      expect(await service().download(item), BookResult.ready);
      final after = await bookItem('bk-hare');
      expect(after.bookVersion, 2);
      expect(after.updateAvailable, isFalse);
      expect(after.chapterIndex, 1);
      expect(after.sentenceIndex, 1);
      expect(File(oldFile).existsSync(), isFalse, reason: 'old version gone');
    });

    test('a removed but downloaded book stays readable', () async {
      await service().refreshCatalog();
      await service().download(await bookItem('bk-hare'));
      env.books.simulateRemoval('bk-hare');
      final diff = await service().refreshCatalog();
      expect(diff!.removed, ['The Tortoise and the Hare']);
      final item = await bookItem('bk-hare');
      expect(item.unavailable, isTrue);
      expect(await service().prepareToRead(item), BookResult.ready);
    });
  });

  test(
    'deleting an own document removes its files, favorites and links',
    () async {
      final item = await dao().insertDocument(
        title: 'Resibo',
        fullText: 'Bigas.',
        source: LibrarySource.camera,
        format: LibraryFormat.image,
        language: 'fil',
        userId: user(),
        coverPath: '${env.libraryPaths.root.path}/cover.jpg',
      );
      File(item.coverPath!).writeAsStringSync('x');
      await dao().addFavorite(
        itemId: item.id,
        chapterIndex: 0,
        sentenceIndex: 0,
        label: 'Bigas',
      );
      final c = await dao().createCollection(user(), 'Resibo');
      await dao().addToCollection(c.id, item.id);

      await service().deleteItem(item);

      expect(await dao().get(item.id), isNull);
      expect(File(item.coverPath!).existsSync(), isFalse);
      expect(await dao().favorites(item.id), isEmpty);
      expect(await dao().collectionItemIds(c.id), isEmpty);
      expect(await dao().collections(user()), hasLength(1));
    },
  );

  test('sync batches carry book data only, never own documents', () async {
    await service().refreshCatalog();
    var book = await bookItem('bk-hare');
    await service().download(book);
    book = await bookItem('bk-hare');
    await dao().addFavorite(
      itemId: book.id,
      chapterIndex: 0,
      sentenceIndex: 0,
      label: 'A hare',
    );
    final own = await dao().insertDocument(
      title: 'Liham',
      fullText: 'Mahal kong Nanay.',
      source: LibrarySource.upload,
      format: LibraryFormat.docx,
      language: 'fil',
      userId: user(),
    );
    await dao().updateProgress(
      own.id,
      chapterIndex: 0,
      sentenceIndex: 1,
      globalSentence: 1,
    );
    final c = await dao().createCollection(user(), 'Pabula');
    await dao().addToCollection(c.id, book.id);
    await dao().addToCollection(c.id, own.id);

    final batch = await dao().syncBatch(user());
    expect(batch.books.map((b) => b['bookId']), ['bk-hare']);
    expect(batch.books.single['downloaded'], isTrue);
    expect(batch.progress.map((p) => p['bookId']), ['bk-hare']);
    expect(batch.favorites, hasLength(1));
    expect(batch.collections.single['bookIds'], ['bk-hare']);
    expect(batch.toString(), isNot(contains('Liham')));
  });
}
