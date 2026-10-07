import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/accessibility/navigation_mode.dart';
import 'package:percipere_app/core/platform/permissions.dart';
import 'package:percipere_app/features/camera/camera_screen.dart';
import 'package:percipere_app/features/capture/capture_screen.dart';

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
    await pumpAppOnCapture(tester, env);
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
}
