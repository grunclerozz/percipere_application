import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/db/daos/library_dao.dart';
import 'package:percipere_app/core/library/library_models.dart';
import 'package:percipere_app/features/library/chapters_screen.dart';
import 'package:percipere_app/features/library/favorites_screen.dart';
import 'package:percipere_app/features/library/item_details_screen.dart';
import 'package:percipere_app/features/library/library_screen.dart';
import 'package:percipere_app/features/reader/reader_screen.dart';

import '../../helpers/fakes.dart';
import '../../helpers/library_ui.dart';

Future<LibraryItem> _item(TestEnv env, String title) async {
  final items = await LibraryDao(env.database.db).list(env.account!.id);
  return items.firstWhere((i) => i.title == title);
}

/// Library → the details of [title] (via "buksan ang …").
Future<void> _openDetails(WidgetTester tester, String title) async {
  await tester.say('buksan ang $title');
  expect(find.byType(ItemDetailsScreen), findsOneWidget);
}

void main() {
  group('Item details', () {
    testWidgets('announces title, progress and time left', (tester) async {
      final env = await withLibrary(tester);
      await openLibrary(tester);
      await _openDetails(tester, 'liham kay nanay');
      final heard = env.tts.transcript;
      expect(heard, contains('Detalye.'));
      expect(heard, contains('Liham kay Nanay, Word'));
      expect(heard, contains('40 porsiyento ang nabasa.'));
      expect(heard, contains('Wala pang isang minuto ang natitira.'));
    });

    testWidgets('time left follows the reading speed', (tester) async {
      final env = await withLibrary(tester);
      await openLibrary(tester);
      await _openDetails(tester, 'liham kay nanay');
      final normal = RegExp(r'Mga (\d+) minuto').firstMatch(env.tts.transcript);
      // 5 sentences of sampleText hold about 55 words: under a minute left.
      expect(normal, isNull);
      expect(env.tts.transcript, contains('Wala pang isang minuto'));
    });

    testWidgets('Ituloy is focused first: double-tap resumes where you were', (
      tester,
    ) async {
      final env = await withLibrary(tester);
      await openLibrary(tester);
      await _openDetails(tester, 'liham kay nanay');
      await tester.doubleTapPad();
      expect(find.byType(ReaderScreen), findsOneWidget);
      expect(
        env.tts.transcript,
        contains('Magpapatuloy sa pangungusap 3 sa 5.'),
      );
    });

    testWidgets('a document not started is "Basahin", not "Ituloy"', (
      tester,
    ) async {
      await withLibrary(tester);
      await openLibrary(tester);
      await _openDetails(tester, 'resibo');
      expect(find.text('Basahin'), findsOneWidget);
      expect(find.text('Ituloy'), findsNothing);
    });

    testWidgets('own documents can be renamed and deleted; books cannot', (
      tester,
    ) async {
      await withLibrary(tester);
      await openLibrary(tester);
      await _openDetails(tester, 'resibo');
      for (final label in [
        'Basahin',
        'Basahin mula sa simula',
        'Mga paborito',
        'Idagdag sa koleksyon',
        'Markahan bilang tapos na',
        'Palitan ang pangalan',
        'Burahin',
      ]) {
        expect(
          find.text(label, skipOffstage: false),
          findsOneWidget,
          reason: label,
        );
      }
      expect(find.text('I-download'), findsNothing);

      await tester.say('bumalik');
      await tester.say('buksan ang florante');
      expect(
        find.text('Palitan ang pangalan', skipOffstage: false),
        findsNothing,
      );
      expect(find.text('Burahin', skipOffstage: false), findsNothing);
      expect(
        find.textContaining('I-download', skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('Mga kabanata'), findsOneWidget);
    });

    testWidgets('book details speak the author, description and size', (
      tester,
    ) async {
      final env = await withLibrary(tester);
      await openLibrary(tester);
      await _openDetails(tester, 'florante');
      expect(env.tts.transcript, contains('Isang aklat.'));
      expect(
        find.textContaining('I-download, 4 KB', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('rename by dictation', (tester) async {
      final env = await withLibrary(tester);
      await openLibrary(tester);
      await _openDetails(tester, 'resibo');
      unawaited(tester.bus.handleUtterance('palitan ang pangalan'));
      await tester.pumpAndSettle();
      expect(env.speech.sessions.last.dictation, isTrue);
      env.speech.hear('Resibo sa tindahan');
      await tester.pumpAndSettle();
      expect(
        env.tts.spoken.last,
        'Pinalitan ang pangalan: Resibo sa tindahan.',
      );
      final renamed = await tester.runAsync(
        () => _item(env, 'Resibo sa tindahan'),
      );
      expect(renamed, isNotNull);
    });

    testWidgets('delete asks first, then removes the item', (tester) async {
      final env = await withLibrary(tester);
      await openLibrary(tester);
      await _openDetails(tester, 'resibo');
      await tester.say('burahin');
      expect(env.tts.transcript, contains('Burahin ang “Resibo sa palengke”?'));
      var items = (await tester.runAsync(
        () => LibraryDao(env.database.db).list(env.account!.id),
      ))!;
      expect(items, hasLength(3), reason: 'not deleted before confirming');

      await tester.say('oo');
      expect(env.tts.transcript, contains('Nabura ang “Resibo sa palengke”.'));
      items = (await tester.runAsync(
        () => LibraryDao(env.database.db).list(env.account!.id),
      ))!;
      expect(items.map((i) => i.title), isNot(contains('Resibo sa palengke')));
      expect(find.byType(LibraryScreen), findsOneWidget);
      expect(find.text('Resibo sa palengke'), findsNothing);
    });

    testWidgets('mark as finished, then unfinished', (tester) async {
      final env = await withLibrary(tester);
      await openLibrary(tester);
      await _openDetails(tester, 'liham kay nanay');
      await tester.say('markahan bilang tapos na');
      expect(
        env.tts.transcript,
        contains('Minarkahan na tapos na ang Liham kay Nanay.'),
      );
      var item = (await tester.runAsync(() => _item(env, 'Liham kay Nanay')))!;
      expect(item.finished, isTrue);
      expect(
        find.text('Markahan bilang hindi pa tapos', skipOffstage: false),
        findsOneWidget,
      );

      await tester.say('tapos na');
      item = (await tester.runAsync(() => _item(env, 'Liham kay Nanay')))!;
      expect(item.finished, isFalse);
    });

    testWidgets('viewing a new book clears its "Bago" label', (tester) async {
      final env = await withLibrary(tester);
      await tester.runAsync(() async {
        final dao = LibraryDao(env.database.db);
        final book = await _item(env, 'Florante at Laura');
        await env.database.db.update(
          'library_items',
          {'is_new': 1},
          where: 'id = ?',
          whereArgs: [book.id],
        );
        expect((await dao.get(book.id))!.isNew, isTrue);
      });
      await openLibrary(tester);
      expect(find.text('Bago'), findsOneWidget);
      await _openDetails(tester, 'florante');
      final book = (await tester.runAsync(
        () => _item(env, 'Florante at Laura'),
      ))!;
      expect(book.isNew, isFalse);
      await tester.say('bumalik');
      expect(find.text('Bago'), findsNothing);
    });
  });

  group('Favorites', () {
    Future<TestEnv> withFavorites(WidgetTester tester) async {
      final env = await withLibrary(tester);
      await tester.runAsync(() async {
        final dao = LibraryDao(env.database.db);
        final book = await _item(env, 'Florante at Laura');
        await dao.addFavorite(
          itemId: book.id,
          chapterIndex: 2,
          sentenceIndex: 1,
          label: 'Walo.',
        );
        await dao.addFavorite(
          itemId: book.id,
          chapterIndex: 0,
          sentenceIndex: 2,
          label: 'Tatlo.',
        );
      });
      await openLibrary(tester);
      await _openDetails(tester, 'florante');
      await tester.say('mga paborito');
      expect(find.byType(FavoritesScreen), findsOneWidget);
      return env;
    }

    testWidgets('lists them in reading order with their chapter', (
      tester,
    ) async {
      final env = await withFavorites(tester);
      expect(
        env.tts.transcript,
        contains('Mga paborito sa Florante at Laura. 2 ang naka-save.'),
      );
      await tester.swipeRight();
      expect(env.tts.spoken.last, 'Unang Kabanata: Tatlo., 1 sa 2.');
      await tester.swipeRight();
      expect(env.tts.spoken.last, 'Ikatlong Kabanata: Walo., 2 sa 2.');
    });

    testWidgets('double-tap jumps there and the Reader continues', (
      tester,
    ) async {
      final env = await withFavorites(tester);
      await tester.swipeRight();
      await tester.swipeRight(); // Ikatlong Kabanata: Walo.
      await tester.doubleTapPadReal();
      expect(find.byType(ReaderScreen), findsOneWidget);
      expect(
        env.tts.transcript,
        contains('Magpapatuloy sa pangungusap 8 sa 9.'),
      );
    });

    testWidgets('swipe up → options → delete asks first', (tester) async {
      final env = await withFavorites(tester);
      await tester.swipeRight();
      await tester.swipeUp();
      expect(
        env.tts.transcript,
        contains('Mga opsyon: Pumunta dito, o Burahin.'),
      );
      await tester.swipeRight(); // Pumunta dito
      await tester.swipeRight(); // Burahin
      await tester.doubleTapPad();
      expect(env.tts.transcript, contains('Burahin ang paborito na “Tatlo.”?'));
      var favs = (await tester.runAsync(() async {
        final dao = LibraryDao(env.database.db);
        return dao.favorites((await _item(env, 'Florante at Laura')).id);
      }))!;
      expect(favs, hasLength(2));

      await tester.doubleTapPad();
      expect(env.tts.transcript, contains('Nabura ang paborito.'));
      favs = (await tester.runAsync(() async {
        final dao = LibraryDao(env.database.db);
        return dao.favorites((await _item(env, 'Florante at Laura')).id);
      }))!;
      expect(favs.map((f) => f.label), ['Walo.']);
    });

    testWidgets('an item without favorites says how to add one', (
      tester,
    ) async {
      final env = await withLibrary(tester);
      await openLibrary(tester);
      await _openDetails(tester, 'resibo');
      await tester.say('mga paborito');
      expect(
        env.tts.transcript,
        contains(
          'Wala ka pang paborito sa Resibo sa palengke. Sabihin ang '
          '“paborito” habang nagbabasa.',
        ),
      );
    });
  });

  group('Chapters', () {
    testWidgets('lists the chapters; choosing one starts reading there', (
      tester,
    ) async {
      final env = await withLibrary(tester);
      await openLibrary(tester);
      await _openDetails(tester, 'florante');
      await tester.say('mga kabanata');
      expect(find.byType(ChaptersScreen), findsOneWidget);
      expect(
        env.tts.transcript,
        contains('Mga kabanata ng Florante at Laura. 3 lahat.'),
      );
      await tester.swipeRight();
      expect(env.tts.spoken.last, 'Unang Kabanata, 1 sa 3.');
      await tester.swipeRight();
      await tester.doubleTapPadReal();
      expect(find.byType(ReaderScreen), findsOneWidget);
      expect(find.textContaining('Apat.'), findsWidgets);
    });

    testWidgets('an own document has no chapters entry', (tester) async {
      await withLibrary(tester);
      await openLibrary(tester);
      await _openDetails(tester, 'resibo');
      expect(find.text('Mga kabanata'), findsNothing);
    });
  });

  group('Collections', () {
    testWidgets('create by voice, add an item, filter, search inside', (
      tester,
    ) async {
      final env = await withLibrary(tester);
      await openLibrary(tester);
      await tester.say('gumawa ng koleksyon na Gamot');
      expect(env.tts.spoken.last, 'Nagawa ang koleksyon na Gamot.');
      expect(find.text('Gamot'), findsWidgets);

      await _openDetails(tester, 'resibo');
      await tester.say('idagdag sa koleksyon');
      expect(
        env.tts.transcript,
        contains('Idagdag ang Resibo sa palengke sa aling koleksyon?'),
      );
      await tester.say('gamot');
      expect(env.tts.spoken.last, 'Naidagdag ang Resibo sa palengke sa Gamot.');

      await tester.say('bumalik'); // out of the picker
      await tester.say('bumalik'); // out of the details
      expect(find.byType(LibraryScreen), findsOneWidget);

      await tester.say('gamot');
      expect(env.tts.spoken.last, 'Koleksyon: Gamot, 1 aytem.');
      expect(find.text('Liham kay Nanay'), findsNothing);
      expect(find.text('Resibo sa palengke'), findsWidgets);

      await tester.say('hanapin liham');
      expect(find.text('Resibo sa palengke'), findsNothing);
      expect(env.tts.spoken.last, 'Walang nahanap para sa “liham”.');
    });

    testWidgets('details: an unknown collection name is read back whole', (
      tester,
    ) async {
      final env = await withLibrary(tester);
      await openLibrary(tester);
      await _openDetails(tester, 'resibo');
      await tester.say('idagdag sa mga gastos sa bus');
      // Regression: the name was split on the letter "s", not on spaces.
      expect(
        env.tts.transcript,
        contains('Hindi ko nahanap ang “mga gastos sa bus” sa Aklatan.'),
      );
    });

    testWidgets('"idagdag sa [koleksyon]" while an item is focused', (
      tester,
    ) async {
      final env = await withLibrary(tester);
      await tester.runAsync(
        () =>
            LibraryDao(env.database.db)
                .createCollection(env.account!.id, 'Paaralan'),
      );
      await openLibrary(tester);
      await tester.swipeDown();
      await tester.swipeDown(); // Aking mga dokumento → Liham
      await tester.say('idagdag sa paaralan');
      expect(env.tts.spoken.last, 'Naidagdag ang Liham kay Nanay sa Paaralan.');
      final linked = (await tester.runAsync(() async {
        final dao = LibraryDao(env.database.db);
        final c = (await dao.collections(env.account!.id)).single;
        return dao.collectionItemIds(c.id);
      }))!;
      expect(linked, hasLength(1));
    });

    testWidgets('an item can be in two collections; pick again removes it', (
      tester,
    ) async {
      final env = await withLibrary(tester);
      await tester.runAsync(() async {
        final dao = LibraryDao(env.database.db);
        await dao.createCollection(env.account!.id, 'Isa');
        await dao.createCollection(env.account!.id, 'Dalawa');
      });
      await openLibrary(tester);
      await _openDetails(tester, 'resibo');
      await tester.say('idagdag sa koleksyon');
      await tester.say('isa');
      await tester.say('dalawa');
      expect(
        env.tts.spoken.last,
        'Naidagdag ang Resibo sa palengke sa Dalawa.',
      );
      await tester.say('isa');
      expect(env.tts.spoken.last, 'Naalis ang Resibo sa palengke sa Isa.');
      final c = (await tester.runAsync(
        () => LibraryDao(env.database.db).collections(env.account!.id),
      ))!;
      expect({for (final x in c) x.name: x.itemCount}, {'Isa': 0, 'Dalawa': 1});
    });

    testWidgets('without collections it says to create one first', (
      tester,
    ) async {
      final env = await withLibrary(tester);
      await openLibrary(tester);
      await _openDetails(tester, 'resibo');
      await tester.say('idagdag sa koleksyon');
      expect(
        env.tts.transcript,
        contains('Wala ka pang koleksyon. Gumawa muna ng isa sa Aklatan.'),
      );
    });

    testWidgets('rename and delete ask first; items survive the delete', (
      tester,
    ) async {
      final env = await withLibrary(tester);
      await tester.runAsync(() async {
        final dao = LibraryDao(env.database.db);
        final c = await dao.createCollection(env.account!.id, 'Resibo');
        await dao.addToCollection(
          c.id,
          (await _item(env, 'Resibo sa palengke')).id,
        );
      });
      await openLibrary(tester);
      // Down to the collections shelf: continue, documents, collections.
      for (var i = 0; i < 3; i++) {
        await tester.swipeDown();
      }
      expect(env.tts.transcript, contains('Mga koleksyon, 1 aytem.'));
      await tester.swipeUp();
      expect(
        env.tts.transcript,
        contains('Mga opsyon para sa koleksyong Resibo.'),
      );

      await tester.swipeRight(); // Buksan
      await tester.swipeRight(); // Palitan ang pangalan
      await tester.doubleTapPad();
      env.speech.hear('Mga resibo');
      await tester.pumpAndSettle();
      expect(
        env.tts.spoken.last,
        'Pinalitan ang pangalan ng koleksyon: Mga resibo.',
      );
      expect(find.text('Mga resibo'), findsWidgets);

      await tester.swipeUp();
      await tester.swipeRight();
      await tester.swipeRight();
      await tester.swipeRight(); // Burahin
      await tester.doubleTapPad();
      expect(
        env.tts.transcript,
        contains(
          'Burahin ang koleksyong Mga resibo? Hindi mabubura ang mga laman nito.',
        ),
      );
      await tester.doubleTapPad();
      expect(env.tts.transcript, contains('Nabura ang koleksyong Mga resibo.'));
      final left = (await tester.runAsync(
        () => LibraryDao(env.database.db).list(env.account!.id),
      ))!;
      expect(left.map((i) => i.title), contains('Resibo sa palengke'));
      final collections = (await tester.runAsync(
        () => LibraryDao(env.database.db).collections(env.account!.id),
      ))!;
      expect(collections, isEmpty);
    });
  });

  group('Reading a book', () {
    testWidgets('a book with its text on the phone opens at its chapter', (
      tester,
    ) async {
      final env = await withLibrary(tester);
      await openLibrary(tester);
      await tester.runAsync(
        () => tester.bus.handleUtterance('ituloy ang florante'),
      );
      await tester.settleReal();
      expect(find.byType(ReaderScreen), findsOneWidget);
      expect(
        env.tts.transcript,
        contains('Magpapatuloy sa pangungusap 4 sa 9.'),
      );
    });
  });
}
