import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/app/router.dart';
import 'package:percipere_app/app/theme/app_palette.dart';
import 'package:percipere_app/core/accessibility/command_bus.dart';
import 'package:percipere_app/core/accessibility/navigation_mode.dart';
import 'package:percipere_app/core/auth/session.dart';
import 'package:percipere_app/core/db/daos/documents_dao.dart';
import 'package:percipere_app/core/db/daos/preferences_dao.dart';
import 'package:percipere_app/core/platform/permissions.dart';
import 'package:percipere_app/core/settings/app_settings.dart';
import 'package:percipere_app/core/widgets/gesture_pad.dart';
import 'package:percipere_app/features/auth/auth_choice_screen.dart';
import 'package:percipere_app/features/capture/capture_screen.dart';
import 'package:percipere_app/features/history/history_screen.dart';
import 'package:percipere_app/features/reader/reader_screen.dart';
import 'package:percipere_app/features/settings/settings_screen.dart';
import 'package:percipere_app/features/setup/profiling_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

extension on WidgetTester {
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
  Future<void> swipeUp() => swipe(const Offset(0, -150));

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
}

Future<TestEnv> _start(WidgetTester tester, {bool mic = false}) async {
  final env = await createEnv(
    tester,
    mode: NavMode.gestures,
    permissions: FakePermissions(
      mic: mic ? PermissionAccess.granted : PermissionAccess.denied,
    ),
  );
  await pumpApp(tester, env);
  expect(find.byType(CaptureScreen), findsOneWidget);
  return env;
}

void main() {
  group('Settings', () {
    testWidgets('opens from Capture; swipes focus settings with values; '
        'swipe up changes and speaks at the new speed', (tester) async {
      final env = await _start(tester);
      await tester.tap(find.text('Mga Setting'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(env.tts.transcript, contains('Mga Setting.'));

      await tester.swipeRight();
      expect(env.tts.spoken.last, 'Bilis ng pagbasa: 1.0x, 1 sa 19.');

      await tester.swipeUp();
      expect(env.tts.spoken.last, 'Bilis ng pagbasa: 1.25x');
      expect(env.tts.rates.last, 1.25, reason: 'demonstrated at the new speed');
      expect(find.text('1.25x'), findsOneWidget);
      expect(
        await PreferencesDao(env.database.db)
            .get(PrefKeys.readingRate, userId: env.account!.id),
        1.25,
      );
    });

    testWidgets('double-tap cycles a choice and the theme changes at once', (
      tester,
    ) async {
      final env = await _start(tester);
      await tester.tap(find.text('Mga Setting'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 6; i++) {
        await tester.swipeRight(); // … to "Tema"
      }
      expect(env.tts.spoken.last, startsWith('Tema: Cream at Navy'));
      await tester.doubleTapPad();
      expect(env.tts.spoken.last, 'Tema: Dark mode na dilaw ang teksto');
      final bg = tester
          .widget<Scaffold>(find.byType(Scaffold).first)
          .backgroundColor;
      final theme = Theme.of(tester.element(find.byType(SettingsScreen)));
      expect(
        bg ?? theme.scaffoldBackgroundColor,
        AppPalette.darkYellow.background,
      );
    });

    testWidgets('switching the language switches the prompts', (tester) async {
      final env = await _start(tester);
      await tester.tap(find.text('Mga Setting'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.swipeRight(); // → Wika
      }
      await tester.doubleTapPad();
      expect(env.tts.spoken.last, 'Language: English');
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('brief verbosity shortens screen announcements', (
      tester,
    ) async {
      final env = await createEnv(
        tester,
        mode: NavMode.gestures,
        appSettings: const AppSettings(verbosity: Verbosity.brief),
      );
      await pumpApp(tester, env);
      expect(
        env.tts.transcript,
        'Pagkuha ng dokumento. '
        'Paano mo gustong i-capture ang iyong dokyumento? '
        'Pwede mo ring gamitin ang bago naming feature: Maglarawan. Sasabihin '
        'nito kung ano ang nasa isang larawan.',
      );
    });
  });

  group('History', () {
    Future<(TestEnv, int, int)> seeded(WidgetTester tester) async {
      final env = await _start(tester, mic: true);
      final dao = DocumentsDao(env.database.db);
      final a = (await tester.runAsync(
        () => dao.insert(
          title: 'Liham kay Nanay',
          fullText: sampleText,
          sourceType: 'docx',
          language: 'fil',
          userId: env.account!.id,
        ),
      ))!;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      final b = (await tester.runAsync(
        () => dao.insert(
          title: 'Resibo sa palengke',
          fullText: 'Bigas 250.00',
          sourceType: 'camera',
          language: 'fil',
          userId: env.account!.id,
        ),
      ))!;
      await tester.tap(find.text('Kasaysayan'));
      await tester.pumpAndSettle();
      expect(find.byType(HistoryScreen), findsOneWidget);
      return (env, a, b);
    }

    testWidgets('announces, lists newest first, opens and resumes', (
      tester,
    ) async {
      final (env, a, _) = await seeded(tester);
      expect(env.tts.transcript, contains('May 2 na dokumento.'));

      await tester.swipeRight();
      expect(env.tts.spoken.last, startsWith('Resibo sa palengke, litrato,'));
      await tester.swipeRight();
      expect(env.tts.spoken.last, startsWith('Liham kay Nanay, Word,'));

      await tester.doubleTapPad();
      expect(find.byType(ReaderScreen), findsOneWidget);

      // Back to History: it reloads (Liham was just reopened → first).
      await tester.twoFingerSwipeRight();
      expect(find.byType(HistoryScreen), findsOneWidget);
      final titles = tester
          .widgetList<Text>(find.textContaining('Liham kay Nanay'))
          .toList();
      expect(titles, isNotEmpty);
      final dao = DocumentsDao(env.database.db);
      expect(
        (await tester.runAsync(() => dao.list(userId: env.account!.id)))!
            .first
            .id,
        a,
      );
    });

    testWidgets('swipe up → options → rename by dictation', (tester) async {
      final (env, _, b) = await seeded(tester);
      await tester.swipeRight(); // Resibo
      await tester.swipeUp();
      expect(env.tts.transcript, contains('Mga opsyon para sa Resibo'));

      await tester.swipeRight(); // Buksan
      await tester.swipeRight(); // Palitan ang pangalan
      await tester.doubleTapPad();
      expect(env.speech.sessions.last.dictation, isTrue);
      env.speech.hear('Resibo sa tindahan');
      await tester.pumpAndSettle();

      expect(
        env.tts.spoken.last,
        'Pinalitan ang pangalan: Resibo sa tindahan.',
      );
      expect(find.text('Resibo sa tindahan'), findsOneWidget);
      final dao = DocumentsDao(env.database.db);
      expect(
        (await tester.runAsync(() => dao.get(b)))!.title,
        'Resibo sa tindahan',
      );
    });

    testWidgets('delete asks first; double-tap confirms', (tester) async {
      final (env, _, b) = await seeded(tester);
      await tester.swipeRight();
      await tester.swipeUp();
      for (var i = 0; i < 3; i++) {
        await tester.swipeRight(); // → Burahin
      }
      await tester.doubleTapPad();
      expect(env.tts.transcript, contains('Burahin ang “Resibo sa palengke”?'));
      expect(
        await tester.runAsync(() => DocumentsDao(env.database.db).get(b)),
        isNotNull,
        reason: 'not deleted before confirming',
      );

      await tester.doubleTapPad();
      expect(env.tts.spoken.last, 'Nabura ang “Resibo sa palengke”.');
      expect(
        await tester.runAsync(() => DocumentsDao(env.database.db).get(b)),
        isNull,
      );
      expect(find.text('Resibo sa palengke'), findsNothing);
    });

    testWidgets('voice search: "hanapin palengke", then "ipakita lahat"', (
      tester,
    ) async {
      final (env, _, _) = await seeded(tester);
      // Speak through the command bus as the recognizer would.
      final cb = tester.scope.read(commandBusProvider);
      await cb.handleUtterance('hanapin palengke');
      await tester.pumpAndSettle();
      expect(
        env.tts.transcript,
        contains('1 resulta para sa “palengke”. Resibo sa palengke'),
      );
      expect(find.text('Liham kay Nanay'), findsNothing);

      await cb.handleUtterance('ipakita lahat');
      await tester.pumpAndSettle();
      expect(env.tts.spoken.last, 'Ipinapakita muli ang lahat.');
      expect(find.text('Liham kay Nanay'), findsOneWidget);
    });
  });

  group('Settings (6B)', () {
    testWidgets('Logout asks first, then "Nais mo bang mag login?"', (
      tester,
    ) async {
      final env = await _start(tester);
      await tester.tap(find.text('Mga Setting'));
      await tester.pumpAndSettle();
      final bus = tester.scope.read(commandBusProvider);
      await bus.handleUtterance('logout');
      await tester.pumpAndSettle();
      expect(
        env.tts.transcript,
        contains('Sigurado ka bang gusto mong mag-logout?'),
      );
      expect(env.sessions.userId, isNotNull, reason: 'not yet');

      await tester.doubleTapPad();
      expect(env.tts.transcript, contains('Naka-logout ka na.'));
      expect(env.sessions.userId, isNull);
      expect(find.byType(AuthChoiceScreen), findsOneWidget);
      expect(
        env.tts.transcript,
        contains('Nais mo bang mag login sa iyong account?'),
      );
    });

    testWidgets('"Ulitin ang setup" opens the full setup', (tester) async {
      final env = await _start(tester);
      await tester.tap(find.text('Mga Setting'));
      await tester.pumpAndSettle();
      await tester.scope
          .read(commandBusProvider)
          .handleUtterance('ulitin ang setup');
      await tester.pumpAndSettle();
      expect(find.byType(ProfilingScreen), findsOneWidget);
      expect(env.tts.transcript, contains('Hakbang 1 ng 10.'));
    });

    testWidgets('guests hear the registration reminder once in Settings', (
      tester,
    ) async {
      final env = await createEnv(
        tester,
        permissions: FakePermissions(micOnRequest: PermissionAccess.denied),
      );
      await pumpApp(tester, env);
      final container = tester.scope;
      await container
          .read(currentAccountProvider.notifier)
          .startGuest('Bisita');
      container.read(routerProvider).go(AppRoutes.capture);
      await tester.pumpAndSettle();

      Future<void> openSettings() async {
        await tester.tap(find.text('Mga Setting'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
      }

      const reminder =
          'Naka-save ito sa phone na ito lamang. Mag-register para hindi ito '
          'mawala.';
      await openSettings();
      expect(env.tts.transcript, contains(reminder));

      await tester.scope.read(commandBusProvider).handleUtterance('bumalik');
      await tester.pumpAndSettle();
      env.tts.spoken.clear();
      await openSettings();
      expect(env.tts.transcript, isNot(contains('Mag-register para')));
    });
  });
}
