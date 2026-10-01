import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/accessibility/navigation_mode.dart';
import 'package:percipere_app/core/platform/permissions.dart';
import 'package:percipere_app/features/camera/camera_screen.dart';
import 'package:percipere_app/features/capture/capture_screen.dart';
import 'package:percipere_app/features/welcome/welcome_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

void main() {
  testWidgets('voice mode: Capture speaks, then listens; "camera" shows as '
      'heard and opens the Reader', (tester) async {
    final env = await createEnv(
      tester,
      mode: NavMode.voice,
      permissions: FakePermissions(mic: PermissionAccess.granted),
    );
    await pumpApp(tester, env);
    expect(find.byType(CaptureScreen), findsOneWidget);
    expect(env.tts.transcript, contains('Sabihin ang utos'));

    // Auto-listen starts shortly after the announcement ends.
    await tester.pump(const Duration(milliseconds: 600));
    expect(env.speech.listening, isTrue);
    expect(find.text('Nakikinig…'), findsOneWidget);

    env.speech.partial('susu');
    await tester.pump();
    expect(find.text('“susu”'), findsOneWidget);

    env.speech.hear('susunod');
    await tester.pumpAndSettle();
    expect(find.text('Narinig: “susunod”'), findsOneWidget);
    expect(env.tts.spoken.last, 'Mag-upload, 1 sa 4.');

    // The heard line fades after a few seconds.
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 400)); // fade-out
    expect(find.textContaining('Narinig'), findsNothing);

    // Listening re-armed after the reply; a screen command opens the Reader.
    expect(env.speech.listening, isTrue);
    env.speech.hear('camera');
    await tester.pumpAndSettle();
    expect(find.byType(CameraScreen), findsOneWidget);
    expect(env.tts.transcript, contains('Gamit ang Camera'));
  });

  testWidgets('Welcome with the mic already allowed: says "boses/galaw" and '
      'listens for it', (tester) async {
    final env = await createEnv(
      tester,
      permissions: FakePermissions(mic: PermissionAccess.granted),
    );
    await pumpApp(tester, env);
    expect(env.tts.transcript, contains('sabihin ang “boses” o “galaw”'));

    await tester.pump(const Duration(milliseconds: 600));
    expect(env.speech.listening, isTrue);
    env.speech.hear('galaw');
    await tester.pumpAndSettle();

    expect(find.byType(CaptureScreen), findsOneWidget);
    expect(env.tts.transcript, contains('Napili mo ang pa-galaw.'));
  });

  testWidgets('fresh install: Welcome does not listen or mention speaking; '
      'choosing voice explains then asks for the mic', (tester) async {
    final env = await createEnv(tester);
    await pumpApp(tester, env);
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(env.tts.transcript, isNot(contains('boses” o')));
    await tester.pump(const Duration(milliseconds: 600));
    expect(env.speech.sessions, isEmpty);

    await tester.tap(find.text('Pa-boses (Voice)'));
    await tester.pumpAndSettle();
    expect(env.permissions.micRequests, 1);
    expect(env.tts.transcript, contains('Habang ginagamit ang app'));
    expect(find.byType(CaptureScreen), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 600));
    expect(env.speech.listening, isTrue, reason: 'voice mode now listens');
  });
}
