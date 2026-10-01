import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/app/locale_provider.dart';
import 'package:percipere_app/core/widgets/document_box.dart';
import 'package:percipere_app/core/widgets/gesture_pad.dart';
import 'package:percipere_app/core/widgets/speaking_zone.dart';
import 'package:percipere_app/features/capture/capture_screen.dart';
import 'package:percipere_app/features/reader/reader_controller.dart';
import 'package:percipere_app/features/reader/reader_screen.dart';
import 'package:percipere_app/features/welcome/welcome_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

void main() {
  group('WelcomeScreen', () {
    testWidgets('shows title, prompt and both mode buttons', (tester) async {
      await pumpThemed(tester, const WelcomeScreen());
      expect(find.text('Welcome to\nPercipere'), findsOneWidget);
      expect(find.text('An app built on your behalf'), findsOneWidget);
      expect(
        find.text('Paano mo gustong mag-navigate sa app?'),
        findsOneWidget,
      );
      expect(find.text('Pa-boses (Voice)'), findsOneWidget);
      expect(find.text('Pa-galaw (Gestures)'), findsOneWidget);
      // No Gesture Pad on Welcome — the whole screen is the gesture surface.
      expect(find.byType(GesturePad), findsNothing);
    });

    testWidgets('renders in English', (tester) async {
      await pumpThemed(
        tester,
        const WelcomeScreen(),
        locale: AppLocales.english,
      );
      expect(
        find.text('How would you like to navigate the app?'),
        findsOneWidget,
      );
    });

    testWidgets('scrolls instead of overflowing at 2x text', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpApp(tester, await createEnv(tester));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('CaptureScreen shows Speaking Zone, buttons and Gesture Pad', (
    tester,
  ) async {
    await pumpThemed(tester, const CaptureScreen());
    expect(find.byType(SpeakingZone), findsOneWidget);
    expect(
      find.text('Paano mo gustong i-capture ang iyong dokyumento?'),
      findsOneWidget,
    );
    expect(find.text('Mag-upload'), findsOneWidget);
    expect(find.text('Gamit ang Camera'), findsOneWidget);

    final pad = tester.getRect(find.byType(GesturePad));
    expect(pad.height, greaterThanOrEqualTo(phoneSize.height * 0.25));
    expect(pad.top, greaterThan(phoneSize.height / 2));
  });

  testWidgets('ReaderScreen replaces Speaking Zone with the Document Box', (
    tester,
  ) async {
    await pumpThemed(
      tester,
      const ReaderScreen(source: TextSource(sampleText)),
    );
    expect(find.byType(SpeakingZone), findsNothing);
    expect(find.byType(DocumentBox), findsOneWidget);
    expect(find.byType(GesturePad), findsOneWidget);
    expect(
      tester.getRect(find.byType(DocumentBox)).bottom,
      lessThan(tester.getRect(find.byType(GesturePad)).top),
    );
  });
}
