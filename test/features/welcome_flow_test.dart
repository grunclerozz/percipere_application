import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/app/app.dart';
import 'package:percipere_app/core/accessibility/navigation_mode.dart';
import 'package:percipere_app/core/db/daos/preferences_dao.dart';
import 'package:percipere_app/core/tts/tts_service.dart';
import 'package:percipere_app/core/widgets/gesture_pad.dart';
import 'package:percipere_app/features/capture/capture_screen.dart';
import 'package:percipere_app/features/reader/reader_screen.dart';
import 'package:percipere_app/features/welcome/welcome_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

/// Real-gesture helpers on a target widget.
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

  Future<void> twoFingerSwipeDown(Offset at) async {
    final a = await startGesture(at, pointer: 21);
    final b = await startGesture(at + const Offset(40, 0), pointer: 22);
    for (var i = 1; i <= 5; i++) {
      await pump(const Duration(milliseconds: 20));
      await a.moveTo(at + Offset(0, 30.0 * i));
      await b.moveTo(at + Offset(40, 30.0 * i));
    }
    await a.up();
    await b.up();
    await pumpAndSettle();
  }

  /// A spot on the Welcome screen away from the buttons.
  Offset get welcomeBlank => const Offset(195, 120);

  Offset get padCenter => getCenter(find.byType(GesturePad));
}

void main() {
  testWidgets('first launch: Welcome announces itself, double-tap picks '
      'voice, choice is saved, Capture announces itself', (tester) async {
    final env = await createEnv(tester);
    await pumpApp(tester, env);

    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(
      env.tts.spoken.first,
      'Maligayang pagdating sa Percipere, isang app na ginawa para sa iyo.',
    );
    expect(env.tts.transcript, contains('I-double tap kahit saan'));

    env.tts.spoken.clear();
    await tester.doubleTapAt(tester.welcomeBlank);

    expect(find.byType(CaptureScreen), findsOneWidget);
    expect(env.tts.spoken.first, 'Napili mo ang pa-boses.');
    expect(env.tts.transcript, contains('Pagkuha ng dokumento.'));
    expect(
      env.tts.transcript,
      contains(
        'Mga pagpipilian: Mag-upload, Gamit ang Camera, Kasaysayan o Mga Setting.',
      ),
    );
    expect(env.tts.spoken.last, 'Gumagana rin ang mga galaw.');
    expect(env.haptics.events, contains('confirm'));

    final saved = await PreferencesDao(env.database.db)
        .get(PrefKeys.navigationMode);
    expect(saved, 'voice');
  });

  testWidgets('swipe right on Welcome picks gestures', (tester) async {
    final env = await createEnv(tester);
    await pumpApp(tester, env);
    await tester.swipeAt(tester.welcomeBlank, const Offset(200, 0));

    expect(find.byType(CaptureScreen), findsOneWidget);
    expect(env.tts.transcript, contains('Napili mo ang pa-galaw.'));
    expect(
      await PreferencesDao(env.database.db).get(PrefKeys.navigationMode),
      'gestures',
    );
  });

  testWidgets('tapping a Welcome button works for sighted helpers and is not '
      'also treated as a gesture', (tester) async {
    final env = await createEnv(tester);
    await pumpApp(tester, env);
    env.tts.spoken.clear();

    await tester.tap(find.text('Pa-galaw (Gestures)'));
    await tester.pumpAndSettle();

    expect(find.byType(CaptureScreen), findsOneWidget);
    expect(env.tts.spoken.first, 'Napili mo ang pa-galaw.');
    expect(env.tts.transcript, isNot(contains('Maligayang pagdating')));
  });

  testWidgets('saved mode skips Welcome; pad gestures navigate Capture → '
      'Reader → back', (tester) async {
    final env = await createEnv(tester, mode: NavMode.gestures);
    await pumpApp(tester, env);
    expect(find.byType(CaptureScreen), findsOneWidget);

    // Swipe right focuses the first option and speaks it.
    await tester.swipeAt(tester.padCenter, const Offset(150, 0));
    expect(env.tts.spoken.last, 'Mag-upload, 1 sa 4.');

    // Double-tap opens it.
    await tester.doubleTapAt(tester.padCenter);
    expect(find.byType(ReaderScreen), findsOneWidget);
    expect(
      env.tts.transcript,
      contains('Pagbasa. Handa na ang dokumento, may 3 talata.'),
    );

    // Two-finger swipe down goes back and Capture re-announces itself.
    env.tts.spoken.clear();
    await tester.twoFingerSwipeDown(tester.padCenter - const Offset(20, 60));
    expect(find.byType(CaptureScreen), findsOneWidget);
    expect(env.tts.spoken.first, 'Pagkuha ng dokumento.');

    // At the first screen, back explains instead.
    env.tts.spoken.clear();
    await tester.twoFingerSwipeDown(tester.padCenter - const Offset(20, 60));
    expect(env.tts.spoken.single, 'Nasa unang screen ka na.');
  });

  testWidgets('no Filipino voice: English notice first, English prompts, and '
      'swipe up opens TTS settings', (tester) async {
    final env = await createEnv(
      tester,
      tts: FakeTts(voices: const VoiceStatus(filipinoReady: false)),
    );
    await pumpApp(tester, env);

    expect(env.tts.spoken.first, startsWith('The Filipino voice is not'));
    expect(env.tts.transcript, contains('Swipe up now'));
    expect(env.tts.transcript, contains('Welcome to Percipere'));
    expect(env.tts.tags, everyElement('en-US'));

    await tester.swipeAt(tester.welcomeBlank, const Offset(0, -200));
    expect(env.settings.ttsOpened, 1);
  });

  testWidgets('Welcome subtitle follows speech', (tester) async {
    final env = await createEnv(tester, tts: FakeTts(autoComplete: false));
    // Speech is held, so the waveform animates: pump frames, don't settle.
    await setSurface(tester, phoneSize);
    await tester.pumpWidget(
      ProviderScope(overrides: env.overrides, child: const PercipereApp()),
    );
    await tester.pump();
    await tester.pump();
    expect(
      find.text(
        'Maligayang pagdating sa Percipere, isang app na ginawa para sa iyo.',
      ),
      findsOneWidget,
    );
    env.tts.finishCurrent();
    await tester.pump();
    expect(find.text('Paano mo gustong mag-navigate sa app?'), findsOneWidget);
    // Let the queue drain so the test ends cleanly.
    env.tts.autoComplete = true;
    env.tts.finishCurrent();
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
