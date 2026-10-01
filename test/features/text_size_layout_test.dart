import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/app/router.dart';
import 'package:percipere_app/core/accessibility/navigation_mode.dart';
import 'package:percipere_app/core/platform/permissions.dart';
import 'package:percipere_app/core/settings/app_settings.dart';
import 'package:percipere_app/core/widgets/document_box.dart';
import 'package:percipere_app/core/widgets/gesture_pad.dart';
import 'package:percipere_app/core/widgets/pill_button.dart';
import 'package:percipere_app/features/reader/reader_controller.dart';
import 'package:percipere_app/features/setup/profiling_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

/// Review feedback: a bigger text size must not move the layout or make
/// the page scroll. Only the reading text grows, inside its box.
void main() {
  /// Where the Capture buttons and the Gesture Pad are, at [textSize].
  Future<List<Rect>> captureLayout(WidgetTester tester, double textSize) async {
    final env = await createEnv(
      tester,
      mode: NavMode.gestures,
      appSettings: AppSettings(textSize: textSize),
    );
    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester, env);
    expect(tester.takeException(), isNull);
    return [
      for (final e in find.byType(PillButton).evaluate())
        tester.getRect(find.byWidget(e.widget)),
      tester.getRect(find.byType(GesturePad)),
    ];
  }

  testWidgets('Capture: buttons and Gesture Pad are identical at 18 and 48', (
    tester,
  ) async {
    final small = await captureLayout(tester, 18);
    final big = await captureLayout(tester, 48);
    expect(big, small);
  });

  testWidgets('Reader: the document text is exactly 48 and the box keeps its '
      'size; the page itself does not grow', (tester) async {
    Future<Rect> boxAt(double size) async {
      final env = await createEnv(
        tester,
        mode: NavMode.gestures,
        appSettings: AppSettings(textSize: size, autoRead: false),
      );
      await tester.pumpWidget(const SizedBox());
      await pumpApp(tester, env);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );
      container
          .read(routerProvider)
          .go(AppRoutes.reader, extra: const TextSource(sampleText));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final text = tester.widget<RichText>(
        find
            .descendant(
              of: find.byType(DocumentBox),
              matching: find.byType(RichText),
            )
            .first,
      );
      expect(text.text.style!.fontSize, size);
      expect(text.textScaler, TextScaler.noScaling);
      return tester.getRect(find.byType(DocumentBox));
    }

    final small = await boxAt(18);
    final big = await boxAt(48);
    expect(big, small);
  });

  testWidgets('Setup text-size step: the preview box keeps its size at 48; '
      'nothing overflows', (tester) async {
    Future<Rect> previewAt(double size) async {
      final env = await createEnv(
        tester,
        loggedIn: true,
        setupDone: false,
        appSettings: AppSettings(textSize: size),
        permissions: FakePermissions(micOnRequest: PermissionAccess.denied),
      );
      await tester.runAsync(
        () => env.database.db.insert('preferences', {
          'user_id': env.account!.id,
          'key': 'setup.step',
          'value': '"textSize"',
          'updated_at': 0,
        }),
      );
      await tester.pumpWidget(const SizedBox());
      await pumpApp(tester, env);
      expect(find.byType(ProfilingScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      final sample = find.textContaining('Ang Percipere ay tumutulong');
      expect(tester.widget<Text>(sample).style!.fontSize, size);
      return tester.getRect(
        find.ancestor(of: sample, matching: find.byType(Scrollbar)),
      );
    }

    final small = await previewAt(18);
    final big = await previewAt(48);
    expect(big, small);
  });
}
