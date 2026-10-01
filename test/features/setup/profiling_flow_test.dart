import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/app/theme/app_palette.dart';
import 'package:percipere_app/core/accessibility/command_bus.dart';
import 'package:percipere_app/core/accessibility/navigation_mode.dart';
import 'package:percipere_app/core/auth/account_repository.dart';
import 'package:percipere_app/core/auth/session.dart';
import 'package:percipere_app/core/db/daos/preferences_dao.dart';
import 'package:percipere_app/core/platform/permissions.dart';
import 'package:percipere_app/core/settings/settings_controller.dart';
import 'package:percipere_app/core/widgets/gesture_pad.dart';
import 'package:percipere_app/features/capture/capture_screen.dart';
import 'package:percipere_app/features/setup/profiling_screen.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

extension on WidgetTester {
  ProviderContainer get scope =>
      ProviderScope.containerOf(element(find.byType(Scaffold).first));

  Future<void> say(String words) async {
    await scope.read(commandBusProvider).handleUtterance(words);
    await pumpAndSettle();
  }

  Offset get pad => getCenter(find.byType(GesturePad));

  Future<void> doubleTapPad({Offset? at}) async {
    for (var i = 0; i < 2; i++) {
      final g = await startGesture(at ?? pad);
      await pump(const Duration(milliseconds: 50));
      await g.up();
      await pump(const Duration(milliseconds: 100));
    }
    await pumpAndSettle();
  }

  Future<void> swipe(Offset delta, {int fingers = 1, Offset? at}) async {
    final start = at ?? pad;
    final gestures = [
      for (var f = 0; f < fingers; f++)
        await startGesture(start + Offset(0, 40.0 * f), pointer: 60 + f),
    ];
    for (var i = 1; i <= 5; i++) {
      await pump(const Duration(milliseconds: 20));
      for (var f = 0; f < fingers; f++) {
        await gestures[f].moveTo(start + Offset(0, 40.0 * f) + delta * (i / 5));
      }
    }
    for (final g in gestures) {
      await g.up();
    }
    await pumpAndSettle();
  }

  Future<void> swipeUp() => swipe(const Offset(0, -150));
  Future<void> swipeDown() => swipe(const Offset(0, 150));
  Future<void> swipeRight() => swipe(const Offset(150, 0));
  Future<void> back() => swipe(const Offset(150, 0), fingers: 2);
}

/// No microphone: the tests speak through the bus (an open recognizer
/// would keep the waveform animating).
FakePermissions _noMic() =>
    FakePermissions(micOnRequest: PermissionAccess.denied);

void main() {
  testWidgets('guest: the short setup by voice, with a jump back from the '
      'summary, ends on Capture', (tester) async {
    final env = await createEnv(tester, permissions: _noMic());
    await pumpApp(tester, env);
    await tester.tap(find.text('Subukan muna (Try first)'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfilingScreen), findsOneWidget);
    expect(env.tts.transcript, contains('Hakbang 1 ng 4.'));
    expect(
      env.tts.transcript,
      contains('Paano mo gustong mag-navigate sa app?'),
    );

    await tester.say('galaw');
    expect(env.tts.transcript, contains('Napili mo ang pa-galaw.'));
    expect(tester.scope.read(navigationModeProvider), NavMode.gestures);
    expect(env.tts.transcript, contains('Hakbang 2 ng 4.'));
    expect(
      env.tts.transcript,
      contains('Gusto mo ba ang boses sa Ingles o sa Tagalog?'),
    );

    await tester.say('tagalog');
    expect(env.tts.transcript, contains('Napili: Tagalog.'));
    expect(env.tts.transcript, contains('Hakbang 3 ng 4.'));

    await tester.say('bilisan');
    expect(env.tts.spoken.last, 'Ganito kabilis ang boses.');
    expect(env.tts.transcript, contains('Bilis: 1.25x.'));
    expect(env.tts.rates.last, 1.25, reason: 'the sample uses the new speed');
    await tester.say('okay');

    expect(env.tts.transcript, contains('Hakbang 4 ng 4. Buod.'));
    expect(
      env.tts.transcript,
      contains(
        'Ito ang iyong mga napili: Paraan: Pa-galaw (Gestures). '
        'Wika ng boses: Tagalog. Bilis: 1.25x.',
      ),
    );

    // Jump back by voice; confirming returns to the summary.
    await tester.say('bumalik sa bilis');
    expect(env.tts.spoken, contains('Bilis: 1.25x.'));
    await tester.say('bagalan');
    expect(tester.scope.read(settingsProvider).readingRate, 1.0);
    await tester.say('sige');
    expect(env.tts.transcript, contains('Bilis: 1.0x. Tama ba ang lahat?'));

    await tester.say('oo');
    expect(env.tts.transcript, contains('Tapos na ang setup.'));
    expect(find.byType(CaptureScreen), findsOneWidget);
    final account = tester.scope.read(currentAccountProvider)!;
    expect(account.profilingCompleted, isTrue);
    final done = await tester.runAsync(
      () =>
          PreferencesDao(env.database.db)
              .get(PrefKeys.setupDone, userId: account.id),
    );
    expect(done, containsAll(['navMode', 'voiceLanguage', 'speed']));
  });

  testWidgets('text size and color steps by gestures, live; theme change '
      'resets an unavailable color; back keeps values', (tester) async {
    final env = await createEnv(
      tester,
      permissions: _noMic(),
      loggedIn: true,
      setupDone: false,
    );
    await pumpApp(tester, env);
    expect(find.byType(ProfilingScreen), findsOneWidget);
    expect(env.tts.transcript, contains('Hakbang 1 ng 10.'));

    // Step 1 has no Gesture Pad: the whole screen takes gestures.
    const spot = Offset(195, 200);
    await tester.swipe(const Offset(150, 0), at: spot);
    await tester.swipe(const Offset(150, 0), at: spot);
    expect(env.tts.spoken.last, 'Pa-galaw (Gestures), 2 sa 2.');
    await tester.doubleTapPad(at: spot);

    // "Can you see text?" → Oo.
    expect(env.tts.transcript, contains('Hakbang 2 ng 10.'));
    expect(
      env.tts.transcript,
      contains('Nakakakita ka ba ng kahit kaunting teksto sa screen?'),
    );
    await tester.swipeRight();
    await tester.doubleTapPad();

    // Step 2: text size, previewed live.
    expect(env.tts.transcript, contains('Nababasa mo ba ng maayos ang texto?'));
    expect(env.tts.transcript, contains('Laki ng teksto: 18.'));
    await tester.swipeUp();
    expect(env.tts.spoken.last, 'Laki ng teksto: 20.');
    expect(tester.scope.read(settingsProvider).textSize, 20);
    expect(find.text('Laki ng teksto: 20.'), findsWidgets);
    await tester.swipeDown();
    await tester.swipeDown();
    expect(env.tts.spoken.last, 'Laki ng teksto: 18.');
    expect(env.tts.transcript, contains('Hanggang dito na lang.'));
    expect(env.haptics.events, contains('error'));
    await tester.swipeUp();
    await tester.doubleTapPad();

    // Step 3: text color.
    expect(env.tts.transcript, contains('Hakbang 3 ng 10.'));
    expect(env.tts.transcript, contains('Anong kulay ang nais mo sa texto?'));
    await tester.swipeRight();
    expect(env.tts.spoken.last, 'Kulay: Itim.');
    expect(tester.scope.read(settingsProvider).textColor, 'black');
    await tester.doubleTapPad();

    // Steps 4–6 skipped (defaults kept).
    for (var i = 0; i < 3; i++) {
      await tester.say('laktawan');
    }

    // Step 7: theme. Black isn't offered on the dark theme → default color.
    expect(env.tts.transcript, contains('Anong tema ang gusto mong simulan?'));
    await tester.swipeRight();
    expect(
      env.tts.spoken.last,
      'Pinalitan ang kulay ng teksto para mas mabasa.',
    );
    expect(
      env.tts.transcript,
      contains('Tema: Dark mode na dilaw ang teksto.'),
    );
    final s = tester.scope.read(settingsProvider);
    expect(s.themeId, ThemeId.darkYellow);
    expect(s.textColor, isNull);
    final bg = Theme.of(tester.element(find.byType(ProfilingScreen)))
        .scaffoldBackgroundColor;
    expect(bg, AppPalette.darkYellow.background, reason: 'live preview');

    // Back: Step 6 again; values kept.
    await tester.back();
    expect(env.tts.transcript, contains('Hakbang 6 ng 10.'));
    expect(tester.scope.read(settingsProvider).textSize, 20);
    expect(tester.scope.read(settingsProvider).themeId, ThemeId.darkYellow);
  });

  testWidgets('an interrupted setup resumes at the saved step', (tester) async {
    final env = await createEnv(
      tester,
      permissions: _noMic(),
      loggedIn: true,
      setupDone: false,
    );
    await tester.runAsync(
      () =>
          PreferencesDao(env.database.db)
              .set(PrefKeys.setupStep, 'speed', userId: env.account!.id),
    );
    await pumpApp(tester, env);
    expect(find.byType(ProfilingScreen), findsOneWidget);
    expect(env.tts.transcript, contains('Hakbang 5 ng 10.'));
    expect(env.tts.transcript, contains('Gusto mo bang bilisan ang boses?'));

    // Completed accounts don't see it again.
    final repo = AccountRepository(env.database.db, TestEnv.testHasher);
    expect(
      (await tester.runAsync(() => repo.get(env.account!.id)))!
          .profilingCompleted,
      isFalse,
    );
  });
}
