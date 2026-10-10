import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/accessibility/command_bus.dart';
import 'package:percipere_app/core/accessibility/navigation_mode.dart';
import 'package:percipere_app/core/auth/session.dart';
import 'package:percipere_app/core/db/daos/preferences_dao.dart';
import 'package:percipere_app/core/platform/permissions.dart';
import 'package:percipere_app/core/tts/tts_service.dart';
import 'package:percipere_app/core/widgets/gesture_pad.dart';
import 'package:percipere_app/features/auth/login_screen.dart';
import 'package:percipere_app/features/auth/register_screen.dart';
import 'package:percipere_app/features/capture/capture_screen.dart';
import 'package:percipere_app/features/reader/reader_screen.dart';
import 'package:percipere_app/features/setup/profiling_screen.dart';
import 'package:percipere_app/features/welcome/welcome_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

/// Real-gesture helpers.
extension on WidgetTester {
  Future<void> tapAt(Offset at) async {
    final g = await startGesture(at);
    await pump(const Duration(milliseconds: 60));
    await g.up();
  }

  Future<void> doubleTapAt(Offset at) async {
    await tapAt(at);
    await pump(const Duration(milliseconds: 120));
    await tapAt(at);
    await pumpAndSettle();
  }

  Future<void> swipeAt(Offset at, Offset delta) async {
    final g = await startGesture(at);
    for (var i = 1; i <= 5; i++) {
      await pump(const Duration(milliseconds: 20));
      await g.moveTo(at + delta * (i / 5));
    }
    await g.up();
    await pumpAndSettle();
  }

  Future<void> twoFingerSwipeRight(Offset at) async {
    final a = await startGesture(at, pointer: 21);
    final b = await startGesture(at + const Offset(0, 40), pointer: 22);
    for (var i = 1; i <= 5; i++) {
      await pump(const Duration(milliseconds: 20));
      await a.moveTo(at + Offset(30.0 * i, 0));
      await b.moveTo(at + Offset(30.0 * i, 40));
    }
    await a.up();
    await b.up();
    await pumpAndSettle();
  }

  /// A spot on Welcome away from the buttons.
  Offset get welcomeBlank => const Offset(195, 160);

  Offset get padCenter => getCenter(find.byType(GesturePad));

  ProviderContainer get scope =>
      ProviderScope.containerOf(element(find.byType(Scaffold).first));
}

void main() {
  group('Welcome', () {
    testWidgets('first launch: announces the question and both ways to '
        'answer, then explains and asks for the microphone once', (
      tester,
    ) async {
      final env = await createEnv(tester);
      await pumpApp(tester, env);

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(env.tts.spoken.first, 'Welcome.');
      expect(
        env.tts.transcript,
        contains('Meron ka na bang account? Kung wala pa, mag-register ka.'),
      );
      // The app waits for an answer before explaining how to answer.
      expect(env.tts.transcript, isNot(contains('Mag-swipe pakanan')));
      expect(env.permissions.micRequests, 0);
      await tester.waitOutQuestion();
      // Gestures are explained before the mic is allowed…
      expect(env.tts.transcript, contains('Mag-swipe pakanan para pumili'));
      // …then the mic is requested after a spoken explanation.
      expect(env.permissions.micRequests, 1);
      expect(env.tts.transcript, contains('Habang ginagamit ang app'));
      expect(
        env.tts.transcript,
        contains(
          'Maaari mo nang sabihin ang “login”, “register”, o “subukan”.',
        ),
      );
      expect(
        await PreferencesDao(env.database.db).get(PrefKeys.micAsked),
        isTrue,
      );
    });

    testWidgets('swipe moves between Login, Register and Subukan muna; '
        'double-tap opens the focused one', (tester) async {
      final env = await createEnv(
        tester,
        permissions: FakePermissions(mic: PermissionAccess.granted),
      );
      await pumpApp(tester, env);
      await tester.swipeAt(tester.welcomeBlank, const Offset(200, 0));
      expect(env.tts.spoken.last, 'Login, 1 sa 3.');
      await tester.swipeAt(tester.welcomeBlank, const Offset(200, 0));
      expect(env.tts.spoken.last, 'Register, 2 sa 3.');
      await tester.doubleTapAt(tester.welcomeBlank);
      expect(find.byType(RegisterScreen), findsOneWidget);
    });

    testWidgets('voice: "login" opens Login (the mic was already allowed)', (
      tester,
    ) async {
      final env = await createEnv(
        tester,
        permissions: FakePermissions(mic: PermissionAccess.granted),
      );
      await pumpApp(tester, env);
      // The question, then silence: the app listens for the answer.
      expect(env.tts.transcript, contains('Meron ka na bang account?'));
      expect(env.tts.transcript, isNot(contains('Sabihin ang “login”')));
      await tester.pump(const Duration(milliseconds: 600));
      expect(env.speech.listening, isTrue);
      env.speech.hear('login');
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      // Answered, so the held-back instructions were never said.
      expect(env.tts.transcript, isNot(contains('Sabihin ang “login”')));
    });

    testWidgets('tapping a button works for sighted helpers and is not also '
        'a gesture', (tester) async {
      final env = await createEnv(
        tester,
        permissions: FakePermissions(mic: PermissionAccess.granted),
      );
      await pumpApp(tester, env);
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(env.tts.transcript, isNot(contains('nothingFocused')));
    });

    testWidgets('"Subukan muna" starts the guest profile and its short setup', (
      tester,
    ) async {
      final env = await createEnv(
        tester,
        permissions: FakePermissions(mic: PermissionAccess.granted),
      );
      await pumpApp(tester, env);
      await tester.tap(find.text('Subukan muna (Try first)'));
      await tester.pumpAndSettle();

      expect(find.byType(ProfilingScreen), findsOneWidget);
      expect(env.tts.transcript, contains('Hakbang 1 ng 4.'));
      final guest = tester.scope.read(currentAccountProvider);
      expect(guest?.isGuest, isTrue);
      expect(env.sessions.userId, guest!.id);
    });

    testWidgets('no Filipino voice: English notice first, English prompts, '
        'swipe up opens TTS settings', (tester) async {
      final env = await createEnv(
        tester,
        tts: FakeTts(voices: const VoiceStatus(filipinoReady: false)),
        permissions: FakePermissions(mic: PermissionAccess.granted),
      );
      await pumpApp(tester, env);

      expect(env.tts.spoken.first, startsWith('The Filipino voice is not'));
      expect(env.tts.transcript, contains('Do you already have an account?'));
      expect(env.tts.tags, everyElement('en-US'));

      await tester.swipeAt(tester.welcomeBlank, const Offset(0, -200));
      expect(env.settings.ttsOpened, 1);
    });

    testWidgets('scrolls instead of overflowing at 2x text', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpApp(
        tester,
        await createEnv(
          tester,
          permissions: FakePermissions(mic: PermissionAccess.granted),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Back navigation', () {
    Future<TestEnv> openReader(WidgetTester tester) async {
      final env = await createEnv(tester, mode: NavMode.gestures);
      await pumpAppOnCapture(tester, env);
      await tester.swipeAt(tester.padCenter, const Offset(150, 0));
      await tester.doubleTapAt(tester.padCenter); // Mag-upload
      expect(find.byType(ReaderScreen), findsOneWidget);
      env.tts.spoken.clear();
      return env;
    }

    void expectBackToCapture(WidgetTester tester, TestEnv env) {
      expect(find.byType(CaptureScreen), findsOneWidget);
      expect(env.tts.spoken.first, 'Bumalik sa Pagkuha ng dokumento.');
    }

    testWidgets('gesture: two-finger swipe right', (tester) async {
      final env = await openReader(tester);
      await tester.twoFingerSwipeRight(tester.padCenter - const Offset(60, 40));
      expectBackToCapture(tester, env);
    });

    testWidgets('voice: "bumalik ng page"', (tester) async {
      final env = await openReader(tester);
      await tester.scope
          .read(commandBusProvider)
          .handleUtterance('bumalik ng page');
      await tester.pumpAndSettle();
      expectBackToCapture(tester, env);
    });

    testWidgets('system back (Android back button)', (tester) async {
      final env = await openReader(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expectBackToCapture(tester, env);
    });

    testWidgets('on the first screen: "Nasa simula ka na", then closing the '
        'app is confirmed by a double-tap', (tester) async {
      final env = await createEnv(
        tester,
        permissions: FakePermissions(mic: PermissionAccess.granted),
      );
      await pumpApp(tester, env);
      env.tts.spoken.clear();
      await tester.twoFingerSwipeRight(tester.welcomeBlank);
      expect(
        env.tts.transcript,
        contains('Nasa simula ka na. Gusto mo bang isara ang app?'),
      );
      expect(env.appClosed, 0);

      // Android back asks the same.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeScreen), findsOneWidget);

      await tester.doubleTapAt(tester.welcomeBlank);
      expect(env.appClosed, 1);
    });

    testWidgets('unsaved input is confirmed before leaving', (tester) async {
      final env = await createEnv(
        tester,
        permissions: FakePermissions(mic: PermissionAccess.granted),
      );
      await pumpApp(tester, env);
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();
      final bus = tester.scope.read(commandBusProvider);
      await bus.handleUtterance('Juan');
      await tester.pumpAndSettle();

      await bus.handleUtterance('bumalik');
      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(
        env.tts.transcript,
        contains('May hindi pa naka-save. Sigurado ka bang babalik?'),
      );
      await bus.handleUtterance('oo');
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(env.tts.transcript, contains('Bumalik sa Welcome.'));
    });
  });
}
