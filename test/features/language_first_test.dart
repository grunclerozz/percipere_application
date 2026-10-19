// The language is asked on the first launch, before the tutorial.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/app/app.dart';
import 'package:percipere_app/app/locale_provider.dart';
import 'package:percipere_app/app/router.dart';
import 'package:percipere_app/core/accessibility/command_bus.dart';
import 'package:percipere_app/core/accessibility/nav_intent.dart';
import 'package:percipere_app/core/auth/session.dart';
import 'package:percipere_app/core/db/daos/preferences_dao.dart';
import 'package:percipere_app/core/offline_voice/offline_voice_setup.dart';
import 'package:percipere_app/core/settings/settings_controller.dart';
import 'package:percipere_app/core/voice/voice_readiness.dart';
import 'package:percipere_app/features/language/language_screen.dart';
import 'package:percipere_app/features/tutorial/tutorial_screen.dart';
import 'package:percipere_app/features/welcome/welcome_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

extension on WidgetTester {
  ProviderContainer get scope =>
      ProviderScope.containerOf(element(find.byType(Scaffold).first));

  Future<void> say(String words) async {
    unawaited(scope.read(commandBusProvider).handleUtterance(words));
    await pump(const Duration(milliseconds: 200));
    await pump(const Duration(milliseconds: 200));
  }

  Future<void> intent(NavIntent intent) async {
    unawaited(scope.read(commandBusProvider).dispatch(intent));
    await pump(const Duration(milliseconds: 200));
    await pump(const Duration(milliseconds: 200));
  }

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
  (String, Object?) startOf(
    TestEnv env, {
    bool chosen = false,
    bool seen = false,
    bool noAccount = true,
  }) {
    final container = ProviderContainer(
      overrides: [
        ...env.overrides,
        if (noAccount) initialAccountProvider.overrideWithValue(null),
        initialTutorialSeenProvider.overrideWithValue(seen),
        initialLanguageChosenProvider.overrideWithValue(chosen),
        startupScreenProvider.overrideWithValue(false),
        offlineVoiceSetupPendingProvider.overrideWithValue(false),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(routerProvider);
    return (router.routeInformationProvider.value.uri.path, null);
  }

  group('start location', () {
    testWidgets('a fresh install asks for the language first', (tester) async {
      final env = await createEnv(tester);
      expect(startOf(env).$1, AppRoutes.language);
    });

    testWidgets('language chosen: the tutorial, as before', (tester) async {
      final env = await createEnv(tester);
      expect(startOf(env, chosen: true).$1, AppRoutes.tutorial);
    });

    testWidgets('tutorial seen: Welcome, never the language', (tester) async {
      final env = await createEnv(tester);
      expect(startOf(env, seen: true).$1, AppRoutes.welcome);
    });

    testWidgets('a saved session: Home, never the language', (tester) async {
      final env = await createEnv(tester, loggedIn: true);
      expect(startOf(env, noAccount: false).$1, AppRoutes.home);
    });
  });

  Future<TestEnv> launch(WidgetTester tester) async {
    final env = await createEnv(tester, tts: FakeTts());
    await setSurface(tester, phoneSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...env.overrides,
          initialAccountProvider.overrideWithValue(null),
          initialTutorialSeenProvider.overrideWithValue(false),
          initialLanguageChosenProvider.overrideWithValue(false),
        ],
        child: const PercipereApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return env;
  }

  Future<bool> chosenFlag(WidgetTester tester, TestEnv env) async =>
      await tester.runAsync(
        () => PreferencesDao(env.database.db).get(
          PrefKeys.languageChosen,
          userId: PreferencesDao.deviceScope,
        ),
      ) ==
      true;

  group('the screen', () {
    testWidgets('speaks the question and the gestures in both languages', (
      tester,
    ) async {
      final env = await launch(tester);
      expect(find.byType(LanguageScreen), findsOneWidget);
      final said = env.tts.transcript;
      expect(said, contains('Pumili ng wika. Sabihin ang "Tagalog" o "English".'));
      expect(
        said,
        contains(
          'Mag-swipe pakaliwa o pakanan para pumili, at mag-double tap para '
          'piliin.',
        ),
      );
      expect(said, contains('Choose a language. Say "Tagalog" or "English".'));
      expect(
        said,
        contains('Swipe left or right to choose, then double-tap to select.'),
      );
      // Filipino first, with the Filipino voice; then English with the
      // English voice.
      expect(said.indexOf('Pumili ng wika'), lessThan(said.indexOf('Choose a')));
      expect(env.tts.tags.toSet().length, greaterThan(1));
    });

    testWidgets('on screen: both sentences and two labelled buttons', (
      tester,
    ) async {
      await launch(tester);
      expect(find.textContaining('Pumili ng wika'), findsWidgets);
      expect(find.textContaining('Choose a language'), findsWidgets);
      expect(find.text('Tagalog'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      // Proper labels for TalkBack.
      expect(find.bySemanticsLabel('Tagalog'), findsWidgets);
      expect(find.bySemanticsLabel('English'), findsWidgets);
    });
  });

  group('choosing', () {
    for (final word in ['english', 'ingles']) {
      testWidgets('saying "$word" chooses English', (tester) async {
        final env = await launch(tester);
        await tester.say(word);
        await tester.wait(const Duration(seconds: 1));
        expect(tester.scope.read(appLocaleProvider), AppLocales.english);
        expect(env.tts.transcript, contains('English selected.'));
        expect(await chosenFlag(tester, env), isTrue);
        expect(find.byType(TutorialScreen), findsOneWidget);
      });
    }

    for (final word in ['tagalog', 'filipino']) {
      testWidgets('saying "$word" chooses Tagalog', (tester) async {
        final env = await launch(tester);
        await tester.say(word);
        await tester.wait(const Duration(seconds: 1));
        expect(tester.scope.read(appLocaleProvider), AppLocales.filipino);
        expect(env.tts.transcript, contains('Tagalog ang napili.'));
        expect(await chosenFlag(tester, env), isTrue);
        expect(find.byType(TutorialScreen), findsOneWidget);
      });
    }

    testWidgets('the large buttons choose too', (tester) async {
      final env = await launch(tester);
      await tester.tap(find.text('English'));
      await tester.wait(const Duration(seconds: 1));
      expect(tester.scope.read(appLocaleProvider), AppLocales.english);
      expect(await chosenFlag(tester, env), isTrue);
    });

    testWidgets('swipe reads each option, double-tap chooses the highlighted '
        'one', (tester) async {
      final env = await launch(tester);
      env.tts.spoken.clear();
      await tester.intent(NavIntent.next);
      expect(env.tts.transcript, contains('Tagalog'));
      env.tts.spoken.clear();
      await tester.intent(NavIntent.next);
      expect(env.tts.transcript, contains('English'));
      // Swiping back goes to the other one.
      env.tts.spoken.clear();
      await tester.intent(NavIntent.previous);
      expect(env.tts.transcript, contains('Tagalog'));
      await tester.intent(NavIntent.next); // English again
      await tester.intent(NavIntent.activate); // double-tap
      await tester.wait(const Duration(seconds: 1));
      expect(tester.scope.read(appLocaleProvider), AppLocales.english);
      expect(find.byType(TutorialScreen), findsOneWidget);
    });

    testWidgets('the confirmation and the next screen use the new language', (
      tester,
    ) async {
      final env = await launch(tester);
      await tester.say('english');
      await tester.wait(const Duration(seconds: 2));
      expect(env.tts.transcript, contains('English will be used throughout'));
      expect(env.tts.transcript, contains('Percy'));
      expect(tester.scope.read(settingsProvider).locale, AppLocales.english);
    });
  });

  group('no answer', () {
    testWidgets('repeated once after ~10 s, then Tagalog', (tester) async {
      final env = await launch(tester);
      int asked() =>
          'Choose a language.'.allMatches(env.tts.transcript).length;
      expect(asked(), 1);

      await tester.wait(LanguageScreen.silence + const Duration(seconds: 1));
      expect(asked(), 2, reason: 'repeated once');
      expect(find.byType(LanguageScreen), findsOneWidget);

      await tester.wait(LanguageScreen.silence + const Duration(seconds: 2));
      expect(asked(), 2, reason: 'not repeated again');
      expect(tester.scope.read(appLocaleProvider), AppLocales.filipino);
      expect(env.tts.transcript, contains('Tagalog ang napili.'));
      expect(await chosenFlag(tester, env), isTrue);
      expect(find.byType(TutorialScreen), findsOneWidget);
    });

    testWidgets('an answer cancels the waiting', (tester) async {
      final env = await launch(tester);
      await tester.wait(const Duration(seconds: 5));
      await tester.say('english');
      await tester.wait(const Duration(seconds: 25));
      expect(tester.scope.read(appLocaleProvider), AppLocales.english);
      expect(
        'Choose a language.'.allMatches(env.tts.transcript).length,
        1,
        reason: 'no repeat after the answer',
      );
    });
  });

  testWidgets('already chosen: Welcome after the tutorial, no language screen', (
    tester,
  ) async {
    final env = await createEnv(tester, tts: FakeTts());
    await setSurface(tester, phoneSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...env.overrides,
          initialAccountProvider.overrideWithValue(null),
          initialTutorialSeenProvider.overrideWithValue(true),
          initialLanguageChosenProvider.overrideWithValue(true),
        ],
        child: const PercipereApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(LanguageScreen), findsNothing);
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });
}
