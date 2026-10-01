import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/app/router.dart';
import 'package:percipere_app/core/platform/permissions.dart';
import 'package:percipere_app/core/settings/app_settings.dart';
import 'package:percipere_app/features/setup/setup_flow.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

/// Review feedback: nothing may need page scrolling, and a bigger text size
/// must not push anything down. Checked at the emulator's size (720 × 1600
/// px = 360 × 800 dp, minus the system bars) and at the largest text
/// size. Lists inside a fixed
/// box (`BoxedList`, the setup preview) may scroll inside it.
void main() {
  const size = Size(360, 800);

  /// Scroll extents of page-level scrollables. Fixed boxes that scroll
  /// inside (boxed lists, the setup preview, the Document Box) show a
  /// Scrollbar and are left out.
  List<double> pageScroll(WidgetTester tester) => [
    for (final e in find.byType(Scrollable).evaluate())
      if (find
          .ancestor(
            of: find.byWidget(e.widget),
            matching: find.byType(Scrollbar),
          )
          .evaluate()
          .isEmpty)
        if ((e as StatefulElement).state case final ScrollableState s
            when s.widget.axisDirection == AxisDirection.down)
          s.position.maxScrollExtent,
  ];

  Future<TestEnv> start(WidgetTester tester, {bool setupDone = true}) async {
    final env = await createEnv(
      tester,
      loggedIn: true,
      setupDone: setupDone,
      appSettings: const AppSettings(textSize: 48),
      permissions: FakePermissions(micOnRequest: PermissionAccess.denied),
    );
    await setSurface(tester, size);
    // Android's status bar and navigation bar (24 dp each on the emulator).
    tester.view
      ..padding = const FakeViewPadding(top: 72, bottom: 72)
      ..viewPadding = const FakeViewPadding(top: 72, bottom: 72);
    return env;
  }

  const routes = [
    AppRoutes.welcome,
    AppRoutes.register,
    AppRoutes.login,
    AppRoutes.forgotPassword,
    AppRoutes.securityQuestion,
    AppRoutes.fingerprintOffer,
    AppRoutes.authChoice,
    AppRoutes.legacyAccount,
    AppRoutes.upgradeAccount,
    AppRoutes.capture,
  ];

  for (final route in routes) {
    testWidgets('$route fits without page scrolling', (tester) async {
      final env = await start(tester);
      await pumpApp(tester, env);
      ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
          .read(routerProvider)
          .go(route);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(pageScroll(tester), everyElement(0));
    });
  }

  for (final step in SetupStep.values) {
    testWidgets('setup ${step.name} fits without page scrolling', (
      tester,
    ) async {
      final env = await start(tester, setupDone: false);
      await tester.runAsync(
        () => env.database.db.insert('preferences', {
          'user_id': env.account!.id,
          'key': 'setup.step',
          'value': '"${step.name}"',
          'updated_at': 0,
        }),
      );
      await pumpApp(tester, env);
      expect(tester.takeException(), isNull);
      expect(pageScroll(tester), everyElement(0), reason: step.name);
    });
  }
}
