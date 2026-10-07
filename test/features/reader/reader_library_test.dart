import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/accessibility/announcer.dart';
import 'package:percipere_app/core/accessibility/navigation_mode.dart';
import 'package:percipere_app/core/db/daos/library_dao.dart';
import 'package:percipere_app/core/extraction/document_extractor.dart';
import 'package:percipere_app/core/library/library_models.dart';
import 'package:percipere_app/core/platform/permissions.dart';
import 'package:percipere_app/core/voice/voice_controller.dart';
import 'package:percipere_app/features/reader/reader_controller.dart';

import '../../helpers/fakes.dart';
import '../../helpers/library_seed.dart';

void main() {
  late TestEnv env;
  late ProviderContainer container;
  late ReaderSource source;

  ReaderController reader() =>
      container.read(readerControllerProvider(source).notifier);
  ReaderState state() => container.read(readerControllerProvider(source));
  LibraryDao dao() => LibraryDao(env.database.db);

  Future<void> open(
    LibraryItem item, {
    FakeTts? tts,
    ItemSource Function(String id)? sourceFor,
  }) async {
    env = env;
    source = (sourceFor ?? ItemSource.new)(item.id);
    container.listen(readerControllerProvider(source), (_, _) {});
    await pumpEventQueue();
    for (var i = 0; i < 50 && state().phase == ReaderPhase.loading; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await pumpEventQueue();
    }
  }

  Future<void> start({FakeTts? tts}) async {
    env = await TestEnv.create(
      tts: tts ?? FakeTts(autoComplete: false),
      mode: NavMode.gestures,
      permissions: FakePermissions(mic: PermissionAccess.granted),
    );
    container = ProviderContainer(overrides: env.overrides);
    addTearDown(container.dispose);
    container
      ..listen(announcerProvider, (_, _) {})
      ..listen(voiceControllerProvider, (_, _) {});
  }

  group('chapters', () {
    test('lays the chapters out and resumes at chapter + sentence', () async {
      await start();
      final book = await seedBook(env, chapters: threeChapters);
      await dao().updateProgress(
        book.id,
        chapterIndex: 1,
        sentenceIndex: 1,
        globalSentence: 4,
      );
      await open(book);

      final s = state();
      expect(s.phase, ReaderPhase.ready);
      expect(s.sentences, hasLength(9));
      expect(s.chapterStarts, [0, 3, 6]);
      expect(s.chapterTitles, [
        'Unang Kabanata',
        'Ikalawang Kabanata',
        'Ikatlong Kabanata',
      ]);
      expect(s.hasChapters, isTrue);
      expect(s.index, 4);
      expect(s.chapter, 1);
      expect(s.resumedFrom, 4);
      expect(s.sentences[4].textIn(s.text), 'Lima.');
      expect(s.title, 'Aklat');
      expect((await dao().get(book.id))!.lastOpenedAt, isNotNull);
    });

    test('from the start ignores the saved position', () async {
      await start();
      final book = await seedBook(env, chapters: threeChapters);
      await dao().updateProgress(
        book.id,
        chapterIndex: 2,
        sentenceIndex: 2,
        globalSentence: 8,
      );
      await open(book, sourceFor: (id) => ItemSource(id, fromStart: true));
      expect(state().index, 0);
    });

    test('a favorite opens at its chapter and sentence', () async {
      await start();
      final book = await seedBook(env, chapters: threeChapters);
      await open(
        book,
        sourceFor: (id) => ItemSource(id, chapter: 2, sentence: 1),
      );
      expect(state().index, 7);
      expect(state().sentences[7].textIn(state().text), 'Walo.');
    });

    test('the position is saved as chapter and sentence', () async {
      await start(tts: FakeTts(autoComplete: false));
      final book = await seedBook(env, chapters: threeChapters);
      await open(book);
      unawaited(reader().play());
      await pumpEventQueue();
      while (state().index < 4) {
        env.tts.finishCurrent();
        await pumpEventQueue();
      }
      expect(state().index, 4);
      await reader().pause(quiet: true);
      env.tts.finishCurrent();
      await pumpEventQueue();

      final saved = (await dao().get(book.id))!;
      expect(saved.chapterIndex, 1);
      expect(saved.sentenceIndex, 1);
      expect(saved.globalSentence, 4);
      expect(saved.percent, closeTo(44.4, 0.1));
      expect(saved.inProgress, isTrue);
    });

    test('announces each chapter title as it starts', () async {
      await start(tts: FakeTts());
      final book = await seedBook(env, chapters: threeChapters);
      await open(book);
      await reader().play();
      await pumpEventQueue();

      final spoken = env.tts.spoken;
      final second = spoken.indexOf('Ikalawang Kabanata.');
      final third = spoken.indexOf('Ikatlong Kabanata.');
      expect(second, greaterThan(spoken.indexOf('Tatlo.')));
      expect(spoken[second + 1], 'Apat.', reason: 'title, then the text');
      expect(third, greaterThan(spoken.indexOf('Anim.')));
      expect(
        spoken.indexOf('Unang Kabanata.'),
        -1,
        reason: 'no title before the first chapter that is already open',
      );
    });

    test('next and previous chapter jump and keep reading', () async {
      await start(tts: FakeTts(autoComplete: false));
      final book = await seedBook(env, chapters: threeChapters);
      await open(book);

      unawaited(reader().skipChapter(1));
      await pumpEventQueue();
      expect(state().index, 3);
      expect(state().chapter, 1);
      expect(env.tts.transcript, contains('Ikalawang Kabanata.'));
      env.tts.finishCurrent(); // the title
      await pumpEventQueue();
      expect(state().playing, isTrue);
      expect(env.tts.spoken.last, 'Apat.');

      unawaited(reader().skipChapter(1)); // while reading
      await pumpEventQueue();
      env.tts.finishCurrent();
      await pumpEventQueue();
      expect(state().chapter, 2);
      expect(env.tts.spoken.last, 'Pito.');

      // At the start of a chapter, previous goes to the chapter before.
      unawaited(reader().skipChapter(-1));
      await pumpEventQueue();
      expect(state().index, 3);
    });

    test('the end and start of the book say so', () async {
      await start(tts: FakeTts());
      final book = await seedBook(env, chapters: threeChapters);
      await open(book, sourceFor: (id) => ItemSource(id, chapter: 2));
      await reader().skipChapter(1);
      expect(env.tts.transcript, contains('Ito na ang huling pangungusap.'));
      expect(env.haptics.events, contains('error'));
    });

    test('a document without chapters says so', () async {
      await start(tts: FakeTts());
      final doc = await seedDocument(env, title: 'Liham', text: sampleText);
      await open(doc);
      await reader().skipChapter(1);
      expect(
        env.tts.transcript,
        contains('Walang kabanata ang dokumentong ito.'),
      );
    });
  });

  group('progress and the finished state', () {
    test('reading to the end marks it finished and says so', () async {
      await start(tts: FakeTts());
      final book = await seedBook(env, chapters: threeChapters);
      await open(book);
      await reader().play();
      await pumpEventQueue();

      expect(env.tts.spoken.last, 'Tapos mo nang basahin ang Aklat.');
      final done = (await dao().get(book.id))!;
      expect(done.finished, isTrue);
      expect(done.percent, 100);
      expect(done.inProgress, isFalse);
      expect(done.chapterIndex, 0, reason: 'next time from the start');
      expect(done.sentenceIndex, 0);
    });

    test('reading a finished item again makes it unfinished', () async {
      await start(tts: FakeTts(autoComplete: false));
      final book = await seedBook(env, chapters: threeChapters);
      await dao().setFinished(book.id, finished: true);
      await open(book);
      expect(state().index, 0, reason: 'finished items start over');

      unawaited(reader().play());
      await pumpEventQueue();
      final after = (await dao().get(book.id))!;
      expect(after.finished, isFalse);
    });

    test('closing the Reader saves where it stopped', () async {
      await start(tts: FakeTts(autoComplete: false));
      final book = await seedBook(env, chapters: threeChapters);
      await open(book);
      unawaited(reader().play());
      await pumpEventQueue();
      env.tts.finishCurrent();
      await pumpEventQueue();
      env.tts.finishCurrent();
      await pumpEventQueue();
      expect(state().index, 2);

      container.dispose(); // the Reader screen closed
      await pumpEventQueue();
      final saved = (await dao().get(book.id))!;
      expect(saved.sentenceIndex, 2);
    });

    test('an own document stores its progress and total at once', () async {
      await start(tts: FakeTts(autoComplete: false));
      const src = FileSource(
        DocumentFile(path: 'x.pdf', kind: DocumentKind.pdf),
      );
      source = src;
      container.listen(readerControllerProvider(src), (_, _) {});
      await pumpEventQueue();

      final saved = (await dao().list(env.account!.id)).single;
      expect(saved.totalSentences, 5);
      expect(saved.wordCount, greaterThan(20));
      unawaited(reader().play());
      await pumpEventQueue();
      for (var i = 0; i < 2; i++) {
        env.tts.finishCurrent();
        await pumpEventQueue();
      }
      await reader().pause(quiet: true);
      env.tts.finishCurrent();
      await pumpEventQueue();
      final half = (await dao().get(saved.id))!;
      expect(half.percent, closeTo(40, 0.1));
    });

    test(
      'a migrated document gets its totals the first time it opens',
      () async {
        await start();
        final doc = await seedDocument(env, title: 'Lumang', text: sampleText);
        // As the migration leaves it: text, a position, no totals.
        await env.database.db.update(
          'library_items',
          {'total_sentences': null, 'word_count': null, 'sentence_index': 2},
          where: 'id = ?',
          whereArgs: [doc.id],
        );
        await open(doc);

        expect(state().index, 2);
        await pumpEventQueue();
        final after = (await dao().get(doc.id))!;
        expect(after.totalSentences, 5);
        expect(after.wordCount, isNotNull);
        expect(after.percent, closeTo(40, 0.1));
      },
    );
  });

  group('favorites', () {
    test('saves the current spot with its first words, and confirms', () async {
      await start(tts: FakeTts());
      final book = await seedBook(env, chapters: threeChapters);
      await dao().updateProgress(
        book.id,
        chapterIndex: 1,
        sentenceIndex: 2,
        globalSentence: 5,
      );
      await open(book);

      await reader().addFavorite();
      final favs = await dao().favorites(book.id);
      expect(favs, hasLength(1));
      expect(favs.single.chapterIndex, 1);
      expect(favs.single.sentenceIndex, 2);
      expect(favs.single.label, 'Anim.');
      expect(env.tts.transcript, contains('Na-save bilang paborito'));
      expect(env.haptics.events, contains('confirm'));

      await reader().addFavorite(); // the same spot again
      expect(await dao().favorites(book.id), hasLength(1));
    });

    test('long sentences are shortened to the first words', () async {
      await start(tts: FakeTts());
      final doc = await seedDocument(env, title: 'Liham', text: sampleText);
      await open(doc);
      await reader().addFavorite();
      final fav = (await dao().favorites(doc.id)).single;
      expect(fav.label, 'Ang Bataan ay isang lalawigan sa rehiyon ng…');
    });

    test('go to a favorite jumps there and keeps reading', () async {
      await start(tts: FakeTts(autoComplete: false));
      final book = await seedBook(env, chapters: threeChapters);
      await open(book);
      unawaited(reader().goTo(2, 1));
      await pumpEventQueue();
      expect(state().index, 7);
      expect(state().playing, isTrue);
      expect(env.tts.spoken.last, 'Walo.');
    });

    test('not available before the document is saved', () async {
      await start(tts: FakeTts());
      source = const TextSource('Isa. Dalawa.');
      container.listen(readerControllerProvider(source), (_, _) {});
      await pumpEventQueue();
      await reader().addFavorite();
      expect(env.tts.transcript, contains('Hindi magagamit'));
    });
  });
}
