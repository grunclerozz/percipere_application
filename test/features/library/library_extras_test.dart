import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/accessibility/command_bus.dart';
import 'package:percipere_app/core/accessibility/navigation_mode.dart';
import 'package:percipere_app/core/auth/session.dart';
import 'package:percipere_app/core/db/daos/library_dao.dart';
import 'package:percipere_app/core/db/daos/preferences_dao.dart';
import 'package:percipere_app/core/library/library_models.dart';
import 'package:percipere_app/features/library/library_actions.dart';
import 'package:percipere_app/features/library/library_screen.dart';
import 'package:percipere_app/features/reader/reader_screen.dart';

import '../../helpers/fakes.dart';
import '../../helpers/library_ui.dart';
import '../../helpers/pump_app.dart';

void main() {
  group('new books', () {
    testWidgets('the Library announces them without a number and labels them', (
      tester,
    ) async {
      final env = await libraryEnv(tester);
      await tester.runAsync(() async {
        final dao = LibraryDao(env.database.db);
        // The user has seen the catalog once...
        await dao.syncCatalog(env.account!.id, await env.books.catalog());
        // ...then the admin adds a book.
        env.books.simulateNewBook();
      });
      await pumpApp(tester, env);
      await tester.tap(find.text('Aklatan').first);
      await tester.pump();
      await tester.settleUntil(
        () => env.tts.transcript.contains('May mga bagong aklat sa Aklatan.'),
      );
      await tester.settleReal();

      expect(env.tts.transcript, contains('May mga bagong aklat sa Aklatan.'));
      expect(env.tts.transcript, isNot(contains('1 bagong')));
      expect(find.text('Bago'), findsOneWidget);
      expect(find.byType(LibraryScreen), findsOneWidget);
    });

    testWidgets('no notice when nothing changed', (tester) async {
      final env = await libraryEnv(tester);
      await tester.runAsync(() async {
        await LibraryDao(env.database.db)
            .syncCatalog(env.account!.id, await env.books.catalog());
      });
      await pumpApp(tester, env);
      await tester.tap(find.text('Aklatan').first);
      await tester.pump();
      await tester.settleReal();
      expect(env.tts.transcript, isNot(contains('bagong aklat')));
      expect(find.text('Bago'), findsNothing);
    });
  });

  group('the Reader', () {
    testWidgets('has a Paborito button that saves the spot', (tester) async {
      final env = await withLibrary(tester);
      await openLibrary(tester);
      await tester.say('ituloy ang liham kay nanay');
      expect(find.byType(ReaderScreen), findsOneWidget);
      expect(find.textContaining('Paborito'), findsOneWidget);

      await tester.tap(find.textContaining('Paborito'));
      await tester.pumpAndSettle();
      expect(env.tts.transcript, contains('Na-save bilang paborito'));
      final item = (await tester.runAsync(() async {
        final dao = LibraryDao(env.database.db);
        final all = await dao.list(env.account!.id);
        return all.firstWhere((i) => i.title == 'Liham kay Nanay');
      }))!;
      final favs = (await tester.runAsync(
        () => LibraryDao(env.database.db).favorites(item.id),
      ))!;
      expect(favs, hasLength(1));
      expect(favs.single.sentenceIndex, 2);
      expect(env.haptics.events, contains('confirm'));
    });

    for (final phrase in ['favorite', 'paborito', 'i-favorite ito']) {
      testWidgets('saying "$phrase" saves a favorite', (tester) async {
        final env = await withLibrary(tester);
        await openLibrary(tester);
        await tester.say('ituloy ang liham kay nanay');
        await tester.say(phrase);
        expect(env.tts.transcript, contains('Na-save bilang paborito'));
      });
    }

    testWidgets('"mga paborito ko" lists them; choosing one jumps there', (
      tester,
    ) async {
      final env = await withLibrary(tester);
      await tester.runAsync(() async {
        final dao = LibraryDao(env.database.db);
        final all = await dao.list(env.account!.id);
        final liham = all.firstWhere((i) => i.title == 'Liham kay Nanay');
        await dao.addFavorite(
          itemId: liham.id,
          chapterIndex: 0,
          sentenceIndex: 4,
          label: 'Maaari mong i-pause…',
        );
      });
      await openLibrary(tester);
      await tester.say('ituloy ang liham kay nanay');
      await tester.say('mga paborito ko');
      expect(env.tts.transcript, contains('Mga paborito sa Liham kay Nanay.'));
      await tester.swipeRight();
      expect(env.tts.spoken.last, 'Maaari mong i-pause…, 1 sa 1.');
      await tester.doubleTapPad();
      expect(find.byType(ReaderScreen), findsOneWidget);
    });

    testWidgets('chapter commands on a document without chapters', (
      tester,
    ) async {
      final env = await withLibrary(tester);
      await openLibrary(tester);
      await tester.say('ituloy ang liham kay nanay');
      await tester.say('susunod na kabanata');
      expect(
        env.tts.transcript,
        contains('Walang kabanata ang dokumentong ito.'),
      );
    });
  });

  group('guests', () {
    late TestEnv env;
    late ProviderContainer container;

    setUp(() async {
      env = await TestEnv.create(mode: NavMode.gestures);
      container = ProviderContainer(overrides: env.overrides);
      addTearDown(container.dispose);
    });

    Future<void> startGuest() async {
      await container
          .read(currentAccountProvider.notifier)
          .startGuest('Bisita');
      // Make the speech/command machinery exist.
      container.read(commandBusProvider);
    }

    Future<List<LibraryItem>> twoBooks() async {
      final id = container.read(currentAccountProvider)!.id;
      final dao = container.read(libraryDaoProvider);
      await dao.syncCatalog(id, await env.books.catalog());
      return [
        (await dao.getBook(id, 'bk-hare'))!,
        (await dao.getBook(id, 'bk-kindness'))!,
      ];
    }

    test(
      'the first download warns; "hindi" carries on; not repeated',
      () async {
        await startGuest();
        final books = await twoBooks();
        final actions = container.read(libraryActionsProvider);

        final first = actions.download(books[0]);
        await pumpEventQueue();
        expect(
          env.tts.transcript,
          contains('Naka-save lang ang iyong mga aklat sa phone na ito.'),
        );
        expect(
          env.tts.transcript,
          contains('Gusto mo bang mag-register ngayon?'),
        );
        await container.read(commandBusProvider).handleUtterance('hindi');
        expect(await first, isTrue, reason: 'declining continues the download');

        final dao = container.read(libraryDaoProvider);
        final id = container.read(currentAccountProvider)!.id;
        expect((await dao.getBook(id, 'bk-hare'))!.downloaded, isTrue);
        final prefs = container.read(userPrefsProvider);
        expect(await prefs.get(PrefKeys.guestReminderDownload, userId: id), 1);

        env.tts.spoken.clear();
        expect(await actions.download(books[1]), isTrue);
        expect(
          env.tts.transcript,
          isNot(contains('Gusto mo bang mag-register')),
        );
      },
    );

    test('accounts are never warned', () async {
      final id = env.account!.id;
      final dao = container.read(libraryDaoProvider);
      await dao.syncCatalog(id, await env.books.catalog());
      final book = (await dao.getBook(id, 'bk-hare'))!;
      final ok = await container.read(libraryActionsProvider).download(book);
      expect(ok, isTrue);
      expect(env.tts.transcript, isNot(contains('mag-register')));
    });

    test('low storage asks first; "oo" goes on', () async {
      final id = env.account!.id;
      final dao = container.read(libraryDaoProvider);
      await dao.syncCatalog(id, await env.books.catalog());
      final book = (await dao.getBook(id, 'bk-hare'))!;
      env.storage.free = 1024;

      final done = container.read(libraryActionsProvider).download(book);
      await pumpEventQueue();
      expect(
        env.tts.transcript,
        contains('Kaunti na lang ang espasyo ng phone.'),
      );
      await container.read(commandBusProvider).handleUtterance('oo');
      expect(await done, isTrue);
      expect((await dao.getBook(id, 'bk-hare'))!.downloaded, isTrue);
    });

    test('low storage and "hindi" downloads nothing', () async {
      final id = env.account!.id;
      final dao = container.read(libraryDaoProvider);
      await dao.syncCatalog(id, await env.books.catalog());
      final book = (await dao.getBook(id, 'bk-hare'))!;
      env.storage.free = 1024;

      final done = container.read(libraryActionsProvider).download(book);
      await pumpEventQueue();
      await container.read(commandBusProvider).handleUtterance('hindi');
      expect(await done, isFalse);
      expect((await dao.getBook(id, 'bk-hare'))!.downloaded, isFalse);
    });

    test('sizes and dates are spoken in words', () {
      final l = container.read(commandBusProvider).strings;
      expect(LibraryActions.sizeLabel(3 * 1024 * 1024 + 200000, l), '3.2 MB');
      expect(LibraryActions.sizeLabel(2048, l), '2 KB');
      final now = DateTime(2026, 10, 10, 12);
      expect(
        LibraryActions.whenLabel(DateTime(2026, 10, 10, 1), l, now),
        'ngayon',
      );
      expect(
        LibraryActions.whenLabel(DateTime(2026, 10, 9, 23), l, now),
        'kahapon',
      );
      expect(
        LibraryActions.whenLabel(DateTime(2026, 10, 5), l, now),
        '5 araw na ang nakalipas',
      );
    });
  });

  testWidgets('a guest keeps the Library after registering', (tester) async {
    final env = await withLibrary(tester);
    // (The migration itself is covered in auth_test; here: Home still opens
    // the same shelves for the new owner.)
    await openLibrary(tester);
    expect(find.text('Florante at Laura'), findsWidgets);
    expect(find.byType(Scaffold), findsWidgets);
    expect(env.account, isNotNull);
  });
}
