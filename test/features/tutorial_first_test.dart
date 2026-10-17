// The controls tutorial comes first (2026-10-17, feat/tutorial-first):
// before Welcome on the first launch, with the skip rule on step one.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/app/app.dart';
import 'package:percipere_app/app/router.dart';
import 'package:percipere_app/config/tutorial_config.dart';
import 'package:percipere_app/core/accessibility/command_bus.dart';
import 'package:percipere_app/core/accessibility/nav_intent.dart';
import 'package:percipere_app/core/auth/session.dart';
import 'package:percipere_app/core/db/daos/preferences_dao.dart';
import 'package:percipere_app/core/offline_voice/offline_voice_setup.dart';
import 'package:percipere_app/core/voice/voice_readiness.dart';
import 'package:percipere_app/features/auth/auth_choice_screen.dart';
import 'package:percipere_app/features/home/home_screen.dart';
import 'package:percipere_app/features/offline_voice/offline_voice_setup_screen.dart';
import 'package:percipere_app/features/settings/settings_screen.dart';
import 'package:percipere_app/features/tutorial/tutorial_screen.dart';
import 'package:percipere_app/features/welcome/welcome_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

extension on WidgetTester {
  ProviderContainer get scope =>
      ProviderScope.containerOf(element(find.byType(Scaffold).first));

  Future<void> say(String words) async {
    // Not awaited: the handler waits for the (fake) speech it starts.
    unawaited(scope.read(commandBusProvider).handleUtterance(words));
    await pump(const Duration(milliseconds: 200));
    await pump(const Duration(milliseconds: 200));
  }

  Future<void> intent(NavIntent intent) async {
    unawaited(scope.read(commandBusProvider).dispatch(intent));
    await pump(const Duration(milliseconds: 200));
    await pump(const Duration(milliseconds: 200));
  }

  /// Lets time pass in small steps (the announcer polls; nothing settles).
  Future<void> wait(Duration total) async {
    var left = total;
    while (left > Duration.zero) {
      final step = left > const Duration(milliseconds: 500)
          ? const Duration(milliseconds: 500)
          : left;
      await pump(step);
      left -= step;
    }
  }
}

void main() {
  /// Collects debugPrint lines; call the result to restore (inside the
  /// test: the framework checks it before tear-downs run).
  late List<String> logs;
  void Function() captureLogs() {
    logs = [];
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };
    return () => debugPrint = original;
  }

  /// The route the router starts on, and its `extra`.
  (String, Object?) startOf(
    TestEnv env, {
    bool seen = false,
    bool expired = false,
    bool startup = false,
    bool voiceSetup = false,
    bool noAccount = false,
  }) {
    final container = ProviderContainer(
      overrides: [
        ...env.overrides,
        if (noAccount) initialAccountProvider.overrideWithValue(null),
        initialTutorialSeenProvider.overrideWithValue(seen),
        initialSessionExpiredProvider.overrideWithValue(expired),
        startupScreenProvider.overrideWithValue(startup),
        offlineVoiceSetupPendingProvider.overrideWithValue(voiceSetup),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(routerProvider);
    return (
      router.routeInformationProvider.value.uri.path,
      (router.routeInformationProvider.value.state as dynamic)?.extra
          as Object?,
    );
  }

  group('start location', () {
    testWidgets('no session and tutorial not seen: tutorial', (tester) async {
      final env = await createEnv(tester);
      expect(startOf(env).$1, AppRoutes.tutorial);
    });

    testWidgets('tutorial seen: Welcome', (tester) async {
      final env = await createEnv(tester);
      expect(startOf(env, seen: true).$1, AppRoutes.welcome);
    });

    testWidgets('saved session: Home, never the tutorial', (tester) async {
      final env = await createEnv(tester, loggedIn: true);
      expect(startOf(env).$1, AppRoutes.home);
    });

    testWidgets('saved session, setup unfinished: the setup as before', (
      tester,
    ) async {
      final env = await createEnv(tester, loggedIn: true, setupDone: false);
      expect(startOf(env).$1, AppRoutes.setup);
    });

    testWidgets('expired session: log in again', (tester) async {
      final env = await createEnv(tester);
      expect(startOf(env, expired: true).$1, AppRoutes.authChoice);
    });

    testWidgets('loading screen first, then the tutorial', (tester) async {
      final env = await createEnv(tester);
      final (path, extra) = startOf(env, startup: true);
      expect(path, AppRoutes.startup);
      expect((extra! as OfflineVoiceNext).location, AppRoutes.tutorial);
    });

    testWidgets('voice setup first, then loading, then the tutorial', (
      tester,
    ) async {
      final env = await createEnv(tester);
      final (path, extra) = startOf(env, startup: true, voiceSetup: true);
      expect(path, AppRoutes.offlineVoice);
      final loading = extra! as OfflineVoiceNext;
      expect(loading.location, AppRoutes.startup);
      expect((loading.extra! as OfflineVoiceNext).location, AppRoutes.tutorial);
    });

    testWidgets('voice setup alone leads to the tutorial', (tester) async {
      final env = await createEnv(tester);
      final (path, extra) = startOf(env, voiceSetup: true);
      expect(path, AppRoutes.offlineVoice);
      expect((extra! as OfflineVoiceNext).location, AppRoutes.tutorial);
    });
  });

  Future<TestEnv> launch(
    WidgetTester tester, {
    FakeTts? tts,
    bool seen = false,
    bool expired = false,
  }) async {
    final env = await createEnv(tester, tts: tts);
    await setSurface(tester, phoneSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...env.overrides,
          initialTutorialSeenProvider.overrideWithValue(seen),
          initialSessionExpiredProvider.overrideWithValue(expired),
        ],
        child: const PercipereApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return env;
  }

  Future<bool> deviceFlag(WidgetTester tester, TestEnv env) async =>
      await tester.runAsync(
        () =>
            PreferencesDao(env.database.db)
                .get(PrefKeys.tutorialDone, userId: PreferencesDao.deviceScope),
      ) ==
      true;

  group('first launch, with no account', () {
    testWidgets('opens on the tutorial and announces Percy', (tester) async {
      final env = await launch(tester);
      expect(find.byType(TutorialScreen), findsOneWidget);
      expect(env.tts.transcript, contains('Pag-aaral ng mga kontrol'));
      expect(env.tts.transcript, contains('Ako si Percy'));
      expect(
        tester.scope.read(currentAccountProvider),
        isNull,
        reason: 'no account is needed',
      );
    });

    testWidgets('seen: opens on Welcome instead', (tester) async {
      await launch(tester, seen: true);
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.byType(TutorialScreen), findsNothing);
    });

    testWidgets('expired session: log in again, no tutorial', (tester) async {
      await launch(tester, expired: true);
      expect(find.byType(AuthChoiceScreen), findsOneWidget);
    });

    testWidgets('step one not heard (speech ends at once): skip, swipe, '
        'voice, button and double-tap are all ignored', (tester) async {
      final env = await launch(tester);
      await tester.wait(const Duration(seconds: 1));

      expect(find.text('Laktawan'), findsNothing, reason: 'button hidden');
      await tester.say('laktawan');
      await tester.say('skip');
      await tester.intent(NavIntent.back); // two-finger swipe right
      await tester.intent(NavIntent.activate); // double-tap
      for (var i = 0; i < 4; i++) {
        await tester.intent(NavIntent.next); // wrong gesture, over and over
      }
      expect(find.byType(TutorialScreen), findsOneWidget);
      expect(env.tts.transcript, isNot(contains('Tuturuan kita')));
      expect(await deviceFlag(tester, env), isFalse);
      expect(env.tts.transcript, isNot(contains('Nilaktawan')));
    });

    testWidgets('the safety timeout allows skipping, and logs it', (
      tester,
    ) async {
      final restore = captureLogs();
      final env = await launch(tester);
      await tester.wait(const Duration(seconds: 1));
      expect(
        logs.any((l) => l.contains('[TUTORIAL] first step ended in under')),
        isTrue,
        reason: 'speech ended too fast: logged, still locked',
      );
      expect(find.text('Laktawan'), findsNothing);

      await tester.wait(TutorialConfig.firstStepTimeout);
      expect(
        logs.any((l) => l.contains('[TUTORIAL] skip allowed: safety timeout')),
        isTrue,
      );
      expect(find.text('Laktawan'), findsOneWidget);

      await tester.say('laktawan');
      await tester.wait(const Duration(seconds: 1));
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(await deviceFlag(tester, env), isTrue, reason: 'device scope');
      restore();
    });

    testWidgets('step one heard: skip works, goes to Welcome and remembers it '
        'for the device', (tester) async {
      final restore = captureLogs();
      final tts = FakeTts(autoComplete: false);
      final env = await launch(tester, tts: tts);
      // The introduction is being spoken: still locked.
      await tester.wait(const Duration(seconds: 3));
      expect(find.text('Laktawan'), findsNothing);
      await tester.say('laktawan');
      expect(find.byType(TutorialScreen), findsOneWidget);

      // It is spoken for a while, then ends.
      await tester.wait(TutorialConfig.firstStepMinSpoken);
      for (var i = 0; i < 20 && tts.isSpeaking; i++) {
        tts.finishCurrent();
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.wait(const Duration(seconds: 1));
      expect(logs.any((l) => l.contains('first step heard')), isTrue);
      expect(find.text('Laktawan'), findsOneWidget);

      await tester.say('laktawan');
      for (var i = 0; i < 10; i++) {
        tts.finishCurrent();
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(await deviceFlag(tester, env), isTrue);
      restore();
    });

    testWidgets('step one heard: double-tap goes on, then swiping back skips '
        'after a question-free intro', (tester) async {
      final tts = FakeTts(autoComplete: false);
      final env = await launch(tester, tts: tts);
      await tester.wait(TutorialConfig.firstStepMinSpoken);
      for (var i = 0; i < 20 && tts.isSpeaking; i++) {
        tts.finishCurrent();
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.wait(const Duration(seconds: 1));

      await tester.intent(NavIntent.activate);
      expect(env.tts.transcript, contains('Tuturuan kita'));

      await tester.intent(NavIntent.back); // skip on the intro: no question
      for (var i = 0; i < 10; i++) {
        tts.finishCurrent();
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(await deviceFlag(tester, env), isTrue);
    });
  });

  group('replay', () {
    testWidgets('from Settings: skip and double-tap work at once, and it '
        'returns to Settings', (tester) async {
      final env = await createEnv(tester, loggedIn: true);
      await setSurface(tester, phoneSize);
      await tester.pumpWidget(
        ProviderScope(overrides: env.overrides, child: const PercipereApp()),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(HomeScreen), findsOneWidget);

      final router = tester.scope.read(routerProvider);
      unawaited(router.push(AppRoutes.settings));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SettingsScreen), findsOneWidget);
      unawaited(router.push(AppRoutes.tutorial, extra: true));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TutorialScreen), findsOneWidget);
      expect(find.text('Laktawan'), findsOneWidget, reason: 'from the start');

      await tester.intent(NavIntent.activate);
      expect(env.tts.transcript, contains('Tuturuan kita'));

      await tester.say('laktawan');
      await tester.wait(const Duration(seconds: 1));
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.byType(TutorialScreen), findsNothing);
    });
  });
}
