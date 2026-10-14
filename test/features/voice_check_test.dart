// "Pagsusuri ng boses" (Voice check): opens from Settings, speaks what it
// found (recognizer, language, offline yes/no, voice local or online,
// microphone) and runs the five-second test without running the command.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/app/router.dart';
import 'package:percipere_app/config/voice_config.dart';
import 'package:percipere_app/core/accessibility/command_bus.dart';
import 'package:percipere_app/core/platform/permissions.dart';
import 'package:percipere_app/core/tts/tts_service.dart';
import 'package:percipere_app/core/voice/speech_input.dart';
import 'package:percipere_app/features/home/home_screen.dart';
import 'package:percipere_app/features/settings/voice_check_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

extension on WidgetTester {
  ProviderContainer get scope =>
      ProviderScope.containerOf(element(find.byType(Scaffold).first));
}

Future<TestEnv> _open(WidgetTester tester, {bool online = true}) async {
  final speech = FakeSpeechInput()
    ..info = const RecognizerInfo(
      sdk: 35,
      service: 'com.google.android.googlequicksearchbox',
      onDevice: true,
      installed: ['en-US'],
      supported: ['en-US', 'fil-PH'],
    );
  final env = await createEnv(
    tester,
    speech: speech,
    loggedIn: true,
    permissions: FakePermissions(mic: PermissionAccess.granted),
  );
  env.online = online;
  env.tts.ttsReport = const TtsReport(
    engine: 'com.google.android.tts',
    voiceName: 'fil-ph-x-fie-local',
    local: true,
  );
  await pumpApp(tester, env);
  expect(find.byType(HomeScreen), findsOneWidget);
  unawaited(tester.scope.read(routerProvider).push(AppRoutes.voiceCheck));
  await tester.pumpAndSettle();
  // The facts are read in the background.
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pumpAndSettle();
  return env;
}

void main() {
  testWidgets('speaks recognizer, language, offline, voice and microphone', (
    tester,
  ) async {
    final env = await _open(tester);
    expect(find.byType(VoiceCheckScreen), findsOneWidget);
    final said = env.tts.transcript;
    expect(said, contains('Pagkilala sa boses: Google.'));
    expect(said, contains('Offline na Filipino: hindi.'));
    expect(said, contains('Offline na Ingles: oo.'));
    expect(said, contains('online, kailangan ng internet'));
    expect(said, contains('Pahintulot sa mikropono: oo.'));
    expect(said, contains('Boses: fil-ph-x-fie-local, naka-install sa tablet'));
  });

  testWidgets('the test listen shows what was heard and the command, '
      'without running it', (tester) async {
    final env = await _open(tester);
    final bus = tester.scope.read(commandBusProvider);
    unawaited(bus.activate('voiceCheck.test'));
    // Not pumpAndSettle: the listening pulse animates while the mic is open.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(env.tts.transcript, contains('Sabihin: buksan ang Aklatan.'));
    expect(env.speech.listening, isTrue);
    expect(env.speech.sessions.last.listenFor, VoiceConfig.probeListenFor);

    env.speech.hearWith('buksan ang aklatan', const [], confidence: 0.9);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(VoiceCheckScreen), findsOneWidget, reason: 'not run');
    expect(env.tts.transcript, contains('Narinig: buksan ang aklatan.'));
    expect(env.tts.transcript, contains('Utos: library'));
    expect(env.tts.transcript, contains('Kumpiyansa ng pagkilala: 90%.'));
    expect(env.tts.transcript, contains('Bilis ng sagot:'));
  });

  testWidgets('download asks the phone for the offline language', (
    tester,
  ) async {
    final env = await _open(tester);
    await tester.scope.read(commandBusProvider).activate('voiceCheck.download');
    await tester.pumpAndSettle();
    expect(env.speech.downloads, ['fil-PH']);
    expect(env.tts.transcript, contains('Sinimulan ang pag-download'));
  });
}
