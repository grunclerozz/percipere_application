import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/db/daos/library_dao.dart';
import 'package:percipere_app/features/capture/capture_screen.dart';
import 'package:percipere_app/features/home/home_screen.dart';
import 'package:percipere_app/features/library/item_details_screen.dart';
import 'package:percipere_app/features/library/library_screen.dart';
import 'package:percipere_app/features/reader/reader_screen.dart';

import '../../helpers/library_ui.dart';
import '../../helpers/pump_app.dart';

void main() {
  group('Home', () {
    testWidgets('is where a logged-in user starts', (tester) async {
      final env = await libraryEnv(tester);
      await pumpApp(tester, env);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(
        env.tts.transcript,
        startsWith('Home. Ano ang gusto mong gawin? Mga pagpipilian'),
      );
      expect(find.text('Magbasa ng bago'), findsOneWidget);
      expect(find.text('Aklatan'), findsOneWidget);
    });

    testWidgets('"Magbasa ng bago" opens Capture; back returns to Home', (
      tester,
    ) async {
      final env = await libraryEnv(tester);
      await pumpApp(tester, env);
      await tester.tap(find.text('Magbasa ng bago'));
      await tester.pumpAndSettle();
      expect(find.byType(CaptureScreen), findsOneWidget);
      expect(find.text('Mag-upload'), findsOneWidget);
      expect(find.text('Gamit ang Camera'), findsOneWidget);
      expect(find.text('Maglarawan'), findsOneWidget);

      await tester.twoFingerSwipeRight();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(env.tts.transcript, contains('Bumalik sa Home.'));
    });

    testWidgets('"Aklatan" opens the Library; back returns to Home', (
      tester,
    ) async {
      final env = await libraryEnv(tester);
      await pumpApp(tester, env);
      await openLibrary(tester);
      await tester.twoFingerSwipeRight();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(env.tts.transcript, contains('Bumalik sa Home.'));
    });

    testWidgets('swiping and double-tapping work on Home', (tester) async {
      final env = await libraryEnv(tester);
      await pumpApp(tester, env);
      await tester.swipeRight();
      expect(env.tts.spoken.last, 'Magbasa ng bago, 1 sa 3.');
      await tester.swipeRight();
      expect(env.tts.spoken.last, 'Aklatan, 2 sa 3.');
      await tester.doubleTapPad();
      expect(find.byType(LibraryScreen), findsOneWidget);
    });

    for (final phrase in [
      'aklatan',
      'library',
      'mga aklat',
      'kasaysayan',
      'history',
    ]) {
      testWidgets('saying "$phrase" opens the Library', (tester) async {
        final env = await libraryEnv(tester);
        await pumpApp(tester, env);
        await tester.say(phrase);
        expect(find.byType(LibraryScreen), findsOneWidget);
        expect(env.tts.transcript, contains('Aklatan.'));
      });
    }

    for (final phrase in ['home', 'simula']) {
      testWidgets('"$phrase" goes Home from Capture and from the Library', (
        tester,
      ) async {
        final env = await libraryEnv(tester);
        await pumpApp(tester, env);
        await tester.tap(find.text('Magbasa ng bago'));
        await tester.pumpAndSettle();
        await tester.say(phrase);
        expect(find.byType(HomeScreen), findsOneWidget);

        await openLibrary(tester);
        await tester.say(phrase);
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(env.tts.transcript, contains('Home.'));
      });
    }

    testWidgets('Capture no longer has a Kasaysayan link', (tester) async {
      final env = await libraryEnv(tester);
      await pumpApp(tester, env);
      await tester.tap(find.text('Magbasa ng bago'));
      await tester.pumpAndSettle();
      expect(find.text('Kasaysayan'), findsNothing);
      expect(find.text('Mga Setting'), findsOneWidget);
      expect(env.tts.transcript, isNotEmpty);
    });
  });

  group('Library screen', () {
    testWidgets('announces itself and lists the shelves by swiping', (
      tester,
    ) async {
      final env = await withLibrary(tester);
      await openLibrary(tester);
      expect(env.tts.transcript, contains('Aklatan. Mag-swipe pakanan'));

      // Down: Ituloy ang pagbasa (the book and Liham are started).
      await tester.swipeDown();
      expect(
        env.tts.transcript,
        endsWith(
          'Ituloy ang pagbasa, 2 aytem. Florante at Laura, ni May-akda, '
          '33 porsiyento, huling binasa ngayon.',
        ),
      );
      await tester.swipeRight();
      expect(env.tts.spoken.last, startsWith('Liham kay Nanay, Word'));
      expect(env.tts.spoken.last, isNot(contains('ni ')));
      await tester.swipeRight();
      expect(env.tts.spoken.last, 'Dulo ng istante.');

      await tester.swipeDown();
      expect(env.tts.transcript, contains('Aking mga dokumento, 2 aytem. '));
      await tester.swipeLeft();
      expect(env.tts.spoken.last, 'Dulo ng istante.');
      await tester.swipeUp();
      expect(
        env.tts.transcript,
        endsWith(
          'Florante at Laura, ni May-akda, '
          '33 porsiyento, huling binasa ngayon.',
        ),
      );
      await tester.swipeUp();
      expect(
        env.tts.transcript,
        endsWith('Paghahanap at mga filter, 3 aytem. Hanapin'),
      );
      await tester.swipeUp();
      expect(env.tts.spoken.last, 'Nasa pinakaitaas ka na.');
    });

    testWidgets('an item line says title, author or type, percent, last read', (
      tester,
    ) async {
      final env = await withLibrary(tester);
      await openLibrary(tester);
      await tester.swipeDown();
      await tester.swipeDown();
      expect(env.tts.transcript, contains('Aking mga dokumento, 2 aytem. '));
      // Newest first: Liham was added last.
      expect(env.tts.spoken.last, startsWith('Liham kay Nanay, Word'));
      await tester.swipeRight();
      expect(
        env.tts.spoken.last,
        'Resibo sa palengke, litrato, hindi pa nasisimulan.',
      );
    });

    testWidgets('empty shelves say how to get started', (tester) async {
      final env = await libraryEnv(tester);
      env.books.offline = true;
      await pumpApp(tester, env);
      await openLibrary(tester);
      await tester.swipeDown();
      expect(
        env.tts.transcript,
        endsWith(
          'Aking mga dokumento. Wala ka pang dokumento. Mag-scan o '
          'mag-upload para magsimula.',
        ),
      );
      await tester.swipeDown();
      expect(
        env.tts.transcript,
        contains('Mga koleksyon. Wala ka pang koleksyon.'),
      );
      await tester.swipeDown();
      expect(
        env.tts.transcript,
        endsWith(
          'Mga aklat. Wala pang aklat sa ngayon. Kailangan ng internet '
          'para makita ang mga aklat.',
        ),
      );
      await tester.swipeDown();
      expect(env.tts.spoken.last, 'Nasa pinakababa ka na.');
    });

    testWidgets('tiles show covers, titles and progress bars', (tester) async {
      await withLibrary(tester);
      await openLibrary(tester);
      expect(find.text('Florante at Laura'), findsWidgets);
      expect(find.byType(LinearProgressIndicator), findsWidgets);
      expect(find.text('Ituloy ang pagbasa'), findsOneWidget);
      expect(find.text('Aking mga dokumento'), findsWidgets);
    });

    testWidgets('double-tap on an item opens its details', (tester) async {
      final env = await withLibrary(tester);
      await openLibrary(tester);
      await tester.swipeDown();
      await tester.swipeDown();
      await tester.swipeRight();
      await tester.doubleTapPad();
      expect(find.byType(ItemDetailsScreen), findsOneWidget);
      expect(env.tts.transcript, contains('Detalye.'));
      expect(env.tts.transcript, contains('Florante at Laura'));
    });

    testWidgets('"ituloy ang …" resumes an item at once', (tester) async {
      final env = await withLibrary(tester);
      await openLibrary(tester);
      await tester.say('ituloy ang liham kay nanay');
      expect(find.byType(ReaderScreen), findsOneWidget);
      expect(env.tts.transcript, contains('Binubuksan ang Liham kay Nanay.'));
      expect(env.tts.transcript, contains('Magpapatuloy sa pangungusap 3'));
    });

    testWidgets('"buksan ang …" opens the details', (tester) async {
      await withLibrary(tester);
      await openLibrary(tester);
      await tester.say('buksan ang resibo');
      expect(find.byType(ItemDetailsScreen), findsOneWidget);
    });

    testWidgets('a title that is not there is said so', (tester) async {
      final env = await withLibrary(tester);
      await openLibrary(tester);
      await tester.say('ituloy ang wala');
      expect(find.byType(LibraryScreen), findsOneWidget);
      expect(env.tts.spoken.last, 'Hindi ko nahanap ang “wala” sa Aklatan.');
    });
  });

  group('Library search and filters', () {
    testWidgets('voice search narrows the shelves; "ipakita lahat" clears', (
      tester,
    ) async {
      final env = await withLibrary(tester);
      await openLibrary(tester);
      await tester.say('hanapin florante');
      expect(env.tts.transcript, contains('1 resulta para sa “florante”.'));
      expect(find.text('Resibo sa palengke'), findsNothing);
      expect(find.text('Florante at Laura'), findsWidgets);

      await tester.say('ipakita lahat');
      expect(env.tts.spoken.last, 'Ipinapakita muli ang lahat.');
      expect(find.text('Resibo sa palengke'), findsWidgets);
    });

    testWidgets('a search with no match says so', (tester) async {
      final env = await withLibrary(tester);
      await openLibrary(tester);
      await tester.say('hanapin xyz');
      expect(env.tts.spoken.last, 'Walang nahanap para sa “xyz”.');
    });

    testWidgets('typing in the search field also searches', (tester) async {
      await withLibrary(tester);
      await openLibrary(tester);
      await tester.enterText(find.byType(TextField), 'resibo');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Florante at Laura'), findsNothing);
      expect(find.text('Resibo sa palengke'), findsWidgets);
    });

    testWidgets('filter chips and voice filters', (tester) async {
      final env = await withLibrary(tester);
      await openLibrary(tester);
      for (final chip in [
        'Lahat',
        'Aking mga dokumento',
        'Mga aklat',
        'Na-download',
        'Tapos na',
        'May paborito',
      ]) {
        expect(
          find.text(chip, skipOffstage: false),
          findsWidgets,
          reason: chip,
        );
      }

      final chip = find.widgetWithText(ChoiceChip, 'Mga aklat');
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.text('Resibo sa palengke'), findsNothing);
      expect(find.text('Florante at Laura'), findsWidgets);

      await tester.say('tapos na');
      expect(env.tts.spoken.last, 'Salain: Tapos na, 0 aytem.');

      await tester.say('salain aking mga dokumento');
      expect(env.tts.spoken.last, 'Salain: Aking mga dokumento, 2 aytem.');
      expect(find.text('Florante at Laura'), findsNothing);

      await tester.say('lahat');
      expect(env.tts.spoken.last, 'Salain: Lahat, 3 aytem.');
    });

    testWidgets('the Filter control cycles through the filters', (
      tester,
    ) async {
      final env = await withLibrary(tester);
      await openLibrary(tester);
      await tester.swipeDown();
      await tester.swipeUp(); // the controls row: Hanapin
      await tester.swipeRight(); // Salain
      expect(env.tts.spoken.last, 'Salain: Lahat');
      await tester.doubleTapPad();
      expect(env.tts.spoken.last, 'Salain: Aking mga dokumento, 2 aytem.');
    });

    testWidgets('the Downloaded and Favorites filters', (tester) async {
      final env = await withLibrary(tester);
      await tester.runAsync(() async {
        final dao = LibraryDao(env.database.db);
        final items = await dao.list(env.account!.id);
        final liham = items.firstWhere((i) => i.title == 'Liham kay Nanay');
        await dao.addFavorite(
          itemId: liham.id,
          chapterIndex: 0,
          sentenceIndex: 1,
          label: 'Kilala ito',
        );
        final book = items.firstWhere((i) => i.isBook);
        await dao.setDownloaded(book.id, filePath: 'x.epub', version: 1);
      });
      await openLibrary(tester);

      await tester.say('na-download');
      expect(env.tts.spoken.last, 'Salain: Na-download, 1 aytem.');
      expect(find.text('Florante at Laura'), findsWidgets);
      expect(find.text('Liham kay Nanay'), findsNothing);

      await tester.say('may paborito');
      expect(env.tts.spoken.last, 'Salain: May paborito, 1 aytem.');
      expect(find.text('Liham kay Nanay'), findsWidgets);
    });
  });
}
