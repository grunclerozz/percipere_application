import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/app/router.dart';
import 'package:percipere_app/core/accessibility/command_bus.dart';
import 'package:percipere_app/core/auth/session.dart';
import 'package:percipere_app/core/db/daos/preferences_dao.dart';
import 'package:percipere_app/core/platform/permissions.dart';
import 'package:percipere_app/features/home/home_screen.dart';
import 'package:percipere_app/features/tutorial/tutorial_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

extension on WidgetTester {
  ProviderContainer get scope =>
      ProviderScope.containerOf(element(find.byType(Scaffold).first));

  Future<void> say(String words) async {
    await scope.read(commandBusProvider).handleUtterance(words);
    await pumpAndSettle();
  }
}

/// The tutorial begins with Percy's introduction, can be skipped and
/// repeated, is replayable by voice, and is remembered per account.
void main() {
  Future<TestEnv> start(WidgetTester tester) async {
    final env = await createEnv(
      tester,
      loggedIn: true,
      setupDone: true,
      permissions: FakePermissions(micOnRequest: PermissionAccess.denied),
    );
    await pumpApp(tester, env);
    return env;
  }

  testWidgets('starts with Percy\'s introduction, then the tutorial intro', (
    tester,
  ) async {
    final env = await start(tester);
    tester.scope.read(routerProvider).go(AppRoutes.tutorial);
    await tester.pumpAndSettle();

    expect(find.byType(TutorialScreen), findsOneWidget);
    final said = env.tts.transcript.toString();
    expect(said, contains('Ako si Percy'));
    expect(said, contains('basahin mo'));
    expect(said, contains('Gumagana ako kahit walang internet'));

    // "ulitin" repeats the step.
    final before = 'Ako si Percy'.allMatches(said).length;
    await tester.say('ulitin');
    expect(
      'Ako si Percy'.allMatches(env.tts.transcript.toString()).length,
      before + 1,
    );

    // Double-tap goes on to the tutorial itself.
    final at = tester.getCenter(find.byType(TutorialScreen));
    for (var i = 0; i < 2; i++) {
      final g = await tester.startGesture(at);
      await tester.pump(const Duration(milliseconds: 50));
      await g.up();
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    expect(env.tts.transcript, contains('Tuturuan kita'));
  });

  testWidgets('"laktawan" skips, remembers it for this account and goes home', (
    tester,
  ) async {
    final env = await start(tester);
    final account = tester.scope.read(currentAccountProvider)!;
    final prefs = PreferencesDao(env.database.db);
    expect(await tester.runAsync(() => tutorialSeen(prefs, account)), isFalse);

    tester.scope.read(routerProvider).go(AppRoutes.tutorial);
    await tester.pumpAndSettle();
    await tester.say('laktawan');

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(await tester.runAsync(() => tutorialSeen(prefs, account)), isTrue);
  });

  for (final phrase in ['tutorial', 'turuan mo ako', 'paano gamitin']) {
    testWidgets('saying "$phrase" replays it; finishing goes back', (
      tester,
    ) async {
      await start(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      await tester.say(phrase);
      expect(find.byType(TutorialScreen), findsOneWidget);
      await tester.say('laktawan');
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  }
}
