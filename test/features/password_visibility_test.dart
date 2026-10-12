import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/app/router.dart';
import 'package:percipere_app/core/platform/permissions.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

/// The password is visible while typing (adviser/panel requirement) with an
/// eye button to hide it; the choice resets each time the screen opens.
void main() {
  Future<TestEnv> open(WidgetTester tester, String button) async {
    final env = await createEnv(
      tester,
      loggedIn: false,
      permissions: FakePermissions(micOnRequest: PermissionAccess.denied),
    );
    await pumpApp(tester, env);
    await tester.tap(find.text(button));
    await tester.pumpAndSettle();
    return env;
  }

  EditableText passwordField(WidgetTester tester) => tester
      .widgetList<EditableText>(find.byType(EditableText))
      .firstWhere((e) => e.keyboardType == TextInputType.visiblePassword);

  for (final screen in ['Login', 'Register']) {
    testWidgets('$screen: visible by default, the eye hides and shows it, '
        'and it resets when the screen opens again', (tester) async {
      final env = await open(tester, screen);
      expect(passwordField(tester).obscureText, isFalse);
      expect(find.bySemanticsLabel('Itago ang password'), findsOneWidget);

      // Large touch target.
      final eye = find.widgetWithIcon(IconButton, Icons.visibility_off);
      expect(tester.getSize(eye).width, greaterThanOrEqualTo(56));
      expect(tester.getSize(eye).height, greaterThanOrEqualTo(56));

      await tester.tap(eye);
      await tester.pumpAndSettle();
      expect(passwordField(tester).obscureText, isTrue);
      expect(find.bySemanticsLabel('Ipakita ang password'), findsOneWidget);

      await tester.tap(find.widgetWithIcon(IconButton, Icons.visibility));
      await tester.pumpAndSettle();
      expect(passwordField(tester).obscureText, isFalse);

      // Hide, leave and come back: visible again.
      await tester.tap(find.widgetWithIcon(IconButton, Icons.visibility_off));
      await tester.pumpAndSettle();
      expect(passwordField(tester).obscureText, isTrue);
      ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
          .read(routerProvider)
          .go(AppRoutes.welcome);
      await tester.pumpAndSettle();
      expect(find.text(screen), findsWidgets);
      await tester.tap(find.text(screen).first);
      await tester.pumpAndSettle();
      expect(passwordField(tester).obscureText, isFalse);
      // Never spoken aloud: the notice is the only password-related line.
      expect(env.tts.transcript, isNot(contains(passwordTestValue)));
    });
  }

  testWidgets('focusing the password field says once that it is visible', (
    tester,
  ) async {
    final env = await open(tester, 'Login');
    const notice =
        'Nakikita ang password habang nagta-type. Pindutin ang mata para itago.';
    expect(env.tts.transcript, isNot(contains(notice)));

    await tester.tap(
      find.byWidgetPredicate(
        (w) =>
            w is TextField && w.keyboardType == TextInputType.visiblePassword,
      ),
    );
    await tester.pumpAndSettle();
    expect(env.tts.transcript.toString().split(notice).length - 1, 1);

    // Tapping it again does not repeat the notice.
    await tester.tap(
      find.byWidgetPredicate(
        (w) =>
            w is TextField && w.keyboardType == TextInputType.visiblePassword,
      ),
    );
    await tester.pumpAndSettle();
    expect(env.tts.transcript.toString().split(notice).length - 1, 1);
  });
}

const String passwordTestValue = 'Hunter2-secret';
