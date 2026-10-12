import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/app/router.dart';
import 'package:percipere_app/config/constants.dart';
import 'package:percipere_app/core/platform/permissions.dart';
import 'package:percipere_app/core/settings/app_settings.dart';
import 'package:percipere_app/core/widgets/gesture_pad.dart';
import 'package:percipere_app/core/widgets/page_padding.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

/// Every screen uses the same padding, is centered, is at most
/// [AppDimens.maxContentWidth] wide on a tablet, and has no overflow at the
/// largest text size (phone 360x800 and tablet 800x1280).
void main() {
  test('PagePadding: 32 at the sides on a phone, grows to center on wide', () {
    expect(PagePadding.sideFor(360), AppDimens.pagePadding);
    expect(PagePadding.sideFor(AppDimens.maxContentWidth + 64), 32);
    expect(PagePadding.sideFor(800), (800 - AppDimens.maxContentWidth) / 2);
    expect(PagePadding.sideFor(double.infinity), AppDimens.pagePadding);
  });

  const sizes = {
    'phone 360x800': Size(360, 800),
    'tablet 800x1280': Size(800, 1280),
  };
  const textSizes = {'normal': 18.0, 'largest': 48.0};
  const routes = [
    AppRoutes.welcome,
    AppRoutes.register,
    AppRoutes.login,
    AppRoutes.tutorial,
    AppRoutes.home,
    AppRoutes.capture,
    AppRoutes.settings,
    AppRoutes.library,
  ];

  for (final size in sizes.entries) {
    for (final text in textSizes.entries) {
      for (final route in routes) {
        testWidgets('$route: ${size.key}, ${text.key} text', (tester) async {
          final env = await createEnv(
            tester,
            loggedIn: true,
            setupDone: true,
            appSettings: AppSettings(textSize: text.value),
            permissions: FakePermissions(micOnRequest: PermissionAccess.denied),
          );
          await pumpApp(tester, env, size: size.value);
          ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
              .read(routerProvider)
              .go(route);
          await tester.pumpAndSettle();
          // A RenderFlex overflow is reported as an exception.
          expect(tester.takeException(), isNull);

          // Content stays centered and, on wide screens, at most 640 wide.
          for (final e in find.byType(PagePadding).evaluate()) {
            final rect = tester.getRect(find.byWidget(e.widget));
            expect(rect.center.dx, closeTo(size.value.width / 2, 0.5));
          }
          final pad = find.byType(GesturePad);
          if (pad.evaluate().isNotEmpty) {
            final rect = tester.getRect(pad.first);
            expect(rect.width, lessThanOrEqualTo(AppDimens.maxContentWidth));
            expect(rect.center.dx, closeTo(size.value.width / 2, 0.5));
          }
        });
      }
    }
  }
}
