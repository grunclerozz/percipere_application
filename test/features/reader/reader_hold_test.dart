// Upload, then hold the gesture area at once (2026-10-17 tablet test: "voice
// is not working" right after an upload). The Reader announced the new
// document and then started reading even when the user had held to speak
// meanwhile: reading started over the hold and closed its listening
// session. Now the Reader leaves the microphone to the user.

import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/accessibility/navigation_mode.dart';
import 'package:percipere_app/core/platform/permissions.dart';
import 'package:percipere_app/core/widgets/gesture_pad.dart';
import 'package:percipere_app/features/reader/reader_screen.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

void main() {
  testWidgets('a hold during the "document ready" announcement stops it, '
      'listens, and the document is not read over it', (tester) async {
    final env = await createEnv(
      tester,
      mode: NavMode.gestures,
      permissions: FakePermissions(mic: PermissionAccess.granted),
    );
    await pumpAppOnCapture(tester, env);
    env.tts.autoComplete = false;
    await tester.tap(find.text('Mag-upload'));
    // Let earlier prompts end until the Reader announces the document.
    bool announcing() =>
        find.byType(ReaderScreen).evaluate().isNotEmpty &&
        env.tts.isSpeaking &&
        env.tts.spoken.last.startsWith('Handa na ang dokumento');
    for (var i = 0; i < 60 && !announcing(); i++) {
      if (env.tts.isSpeaking) env.tts.finishCurrent();
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(announcing(), isTrue, reason: 'announcing the document');

    // Hold the gesture area (push-to-talk) while it is being announced.
    final pad = tester.getCenter(find.byType(GesturePad));
    final finger = await tester.startGesture(pad);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(env.speech.listening, isTrue, reason: 'listening while held');
    for (var i = 0; i < 10; i++) {
      if (env.tts.isSpeaking) env.tts.finishCurrent();
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(
      env.tts.spoken.where((s) => s.startsWith('Ang Bataan')),
      isEmpty,
      reason: 'no reading over the user',
    );
    expect(env.speech.listening, isTrue);

    // Let go: the session finishes and the command runs.
    await finger.up();
    await tester.pump(const Duration(milliseconds: 600));
    expect(env.speech.stops, greaterThanOrEqualTo(1));
    env.tts.autoComplete = true;
    env.tts.finishCurrent();
    env.speech.hear('basahin');
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(
      env.tts.spoken.where((s) => s.startsWith('Ang Bataan')),
      isNotEmpty,
      reason: '"basahin" starts it',
    );
    await tester.tap(find.byType(GesturePad)); // stop reading for teardown
    await tester.pump(const Duration(seconds: 1));
  });
}
