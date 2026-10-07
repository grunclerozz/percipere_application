import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/accessibility/command_bus.dart';
import 'package:percipere_app/core/accessibility/navigation_mode.dart';
import 'package:percipere_app/core/db/daos/library_dao.dart';
import 'package:percipere_app/core/library/library_models.dart';
import 'package:percipere_app/core/platform/permissions.dart';
import 'package:percipere_app/core/widgets/gesture_pad.dart';
import 'package:percipere_app/features/library/library_screen.dart';

import 'fakes.dart';
import 'library_seed.dart';
import 'pump_app.dart';

extension LibraryGestures on WidgetTester {
  Offset get pad => getCenter(find.byType(GesturePad));

  Future<void> tapPad({int times = 1}) async {
    for (var i = 0; i < times; i++) {
      final g = await startGesture(pad);
      await pump(const Duration(milliseconds: 50));
      await g.up();
      await pump(const Duration(milliseconds: 100));
    }
    await pumpAndSettle();
  }

  Future<void> doubleTapPad() => tapPad(times: 2);

  Future<void> swipe(Offset delta) async {
    final g = await startGesture(pad);
    for (var i = 1; i <= 5; i++) {
      await pump(const Duration(milliseconds: 20));
      await g.moveTo(pad + delta * (i / 5));
    }
    await g.up();
    await pumpAndSettle();
  }

  Future<void> swipeRight() => swipe(const Offset(150, 0));
  Future<void> swipeLeft() => swipe(const Offset(-150, 0));
  Future<void> swipeUp() => swipe(const Offset(0, -150));
  Future<void> swipeDown() => swipe(const Offset(0, 150));

  Future<void> twoFingerSwipeRight() async {
    final a = await startGesture(pad, pointer: 41);
    final b = await startGesture(pad + const Offset(0, 40), pointer: 42);
    for (var i = 1; i <= 5; i++) {
      await pump(const Duration(milliseconds: 20));
      await a.moveTo(pad + Offset(30.0 * i, 0));
      await b.moveTo(pad + Offset(30.0 * i, 40));
    }
    await a.up();
    await b.up();
    await pumpAndSettle();
  }

  ProviderContainer get scope =>
      ProviderScope.containerOf(element(find.byType(Scaffold).first));

  CommandBus get bus => scope.read(commandBusProvider);

  Future<void> say(String utterance) async {
    await bus.handleUtterance(utterance);
    await pumpAndSettle();
  }
}

Future<TestEnv> libraryEnv(
  WidgetTester tester, {
  NavMode mode = NavMode.gestures,
}) => createEnv(
  tester,
  mode: mode,
  permissions: FakePermissions(mic: PermissionAccess.granted),
);

/// Starts the app (at Home) with two documents and one book on the shelves.
Future<TestEnv> withLibrary(WidgetTester tester) async {
  final env = await libraryEnv(tester);
  await tester.runAsync(() async {
    await seedDocument(
      env,
      title: 'Resibo sa palengke',
      text: 'Bigas. Asukal. Asin.',
      source: LibrarySource.camera,
      format: LibraryFormat.image,
    );
    await seedDocument(
      env,
      title: 'Liham kay Nanay',
      text: sampleText,
      position: 2,
    );
    final book = await seedBook(
      env,
      title: 'Florante at Laura',
      chapters: threeChapters,
    );
    final dao = LibraryDao(env.database.db);
    await dao.updateProgress(
      book.id,
      chapterIndex: 1,
      sentenceIndex: 0,
      globalSentence: 3,
    );
    await dao.markOpened(book.id);
  });
  env.books.offline = true; // no catalog refresh in these tests
  await pumpApp(tester, env);
  return env;
}

Future<void> openLibrary(WidgetTester tester) async {
  await tester.tap(find.text('Aklatan').first);
  await tester.pumpAndSettle();
  expect(find.byType(LibraryScreen), findsOneWidget);
}

/// Gives real time to file reads (book text caches) that a widget test's
/// fake clock never completes, then lets the screen catch up.
extension RealTime on WidgetTester {
  Future<void> settleReal() async {
    for (var i = 0; i < 8; i++) {
      await runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await pump(const Duration(milliseconds: 100));
    }
  }

  /// Like [settleReal], but waits until [done] (up to about 6 s of real
  /// time): for real file work whose speed varies, e.g. a cold first test.
  Future<void> settleUntil(bool Function() done) async {
    for (var i = 0; i < 60 && !done(); i++) {
      await runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await pump(const Duration(milliseconds: 100));
    }
  }

  /// Two taps on the pad without waiting for the screen to settle.
  Future<void> doubleTapPadReal() async {
    for (var i = 0; i < 2; i++) {
      final g = await startGesture(pad);
      await pump(const Duration(milliseconds: 50));
      await g.up();
      await pump(const Duration(milliseconds: 100));
    }
    await settleReal();
  }
}
