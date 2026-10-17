import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/config/voice_config.dart';
import 'package:percipere_app/core/accessibility/action_registry.dart';
import 'package:percipere_app/core/accessibility/announcer.dart';
import 'package:percipere_app/core/accessibility/navigation_mode.dart';
import 'package:percipere_app/core/accessibility/screen_registration.dart';
import 'package:percipere_app/core/platform/permissions.dart';
import 'package:percipere_app/core/voice/speech_input.dart';
import 'package:percipere_app/core/voice/voice_controller.dart';

import '../../helpers/fakes.dart';

/// Longer than the auto-listen delay.
const _settle = Duration(milliseconds: 600);

/// The listening plan (offline / online / offline English), noisy-room
/// limits, the recognizer's other guesses and the Voice check test listen
/// (2026-10-14).
void main() {
  late TestEnv env;
  late ProviderContainer container;
  VoiceController voice() => container.read(voiceControllerProvider.notifier);
  var activated = <String>[];

  Future<void> setUpWith({
    NavMode? mode = NavMode.voice,
    RecognizerInfo info = RecognizerInfo.unknown,
    bool online = true,
  }) async {
    activated = [];
    final speech = FakeSpeechInput()..info = info;
    env = await TestEnv.create(
      mode: mode,
      permissions: FakePermissions(
        mic: PermissionAccess.granted,
        micOnRequest: PermissionAccess.granted,
      ),
      speech: speech,
    );
    env.online = online;
    container = ProviderContainer(overrides: env.overrides);
    addTearDown(container.dispose);
    container
      ..listen(voiceControllerProvider, (_, _) {})
      ..listen(announcerProvider, (_, _) {})
      ..read(actionRegistryProvider.notifier).register(
        ScreenRegistration(
          id: 'capture',
          title: (l) => l.screenCapture,
          prompt: (l) => l.capturePrompt,
          actions: [
            A11yAction(
              id: 'capture.upload',
              label: (l) => l.captureUpload,
              onActivate: (_) => activated.add('upload'),
            ),
          ],
        ),
      );
  }

  Future<void> speakThenSettle(String text) async {
    await container.read(announcerProvider.notifier).say(text);
    await Future<void>.delayed(_settle);
  }

  const filipinoOffline = RecognizerInfo(
    sdk: 35,
    onDevice: true,
    installed: ['fil-PH', 'en-US'],
  );
  const englishOnly = RecognizerInfo(
    sdk: 35,
    onDevice: true,
    installed: ['en-US'],
  );
  const nothingOffline = RecognizerInfo(sdk: 35, onDevice: true, installed: []);

  group('listening plan', () {
    test('Filipino installed offline: on the device, also online', () async {
      await setUpWith(info: filipinoOffline);
      await speakThenSettle('Una.');
      final req = env.speech.sessions.single;
      expect(req.onDevice, isTrue);
      expect(req.localeId, 'fil_PH');
    });

    test('Filipino not offline, online: online Filipino', () async {
      await setUpWith(info: englishOnly);
      await speakThenSettle('Una.');
      final req = env.speech.sessions.single;
      expect(req.onDevice, isFalse);
      expect(req.localeId, 'fil_PH');
    });

    test('offline with only English installed: says so once, then listens '
        'in English on the device', () async {
      await setUpWith(info: englishOnly, online: false);
      // The first plan is made before the background network check ends.
      await voice().warmUp();
      await Future<void>.delayed(Duration.zero);
      await speakThenSettle('Una.');
      await Future<void>.delayed(_settle);

      expect(env.tts.transcript, contains('Ingles na offline'));
      final req = env.speech.sessions.last;
      expect(req.onDevice, isTrue);
      expect(req.localeId, 'en-US');
      final notices = 'Ingles na offline'.allMatches(env.tts.transcript);
      expect(notices, hasLength(1));
    });

    test('offline with nothing installed: one message, no sessions, and '
        'listening again when the connection is back', () async {
      await setUpWith(info: nothingOffline, online: false);
      await voice().warmUp();
      await Future<void>.delayed(Duration.zero);
      await speakThenSettle('Una.');
      await Future<void>.delayed(_settle);

      expect(env.speech.sessions, isEmpty);
      expect(env.tts.transcript, contains('walang naka-install'));
      expect(env.earcon.stoppedCues, greaterThanOrEqualTo(1));
      final said = 'walang naka-install'.allMatches(env.tts.transcript).length;
      await Future<void>.delayed(_settle);
      expect(
        'walang naka-install'.allMatches(env.tts.transcript).length,
        said,
        reason: 'said once, not in a loop',
      );

      env.online = true;
      env.connectionRestored.add(null);
      await Future<void>.delayed(_settle * 2);
      expect(env.speech.sessions, isNotEmpty);
      expect(env.speech.sessions.last.onDevice, isFalse);
    });

    test('a network error online switches to offline English', () async {
      await setUpWith(info: englishOnly);
      await speakThenSettle('Una.');
      expect(env.speech.sessions.single.onDevice, isFalse);
      env.online = false;
      env.speech.fail('error_network');
      await Future<void>.delayed(_settle * 2);
      final req = env.speech.sessions.last;
      expect(req.onDevice, isTrue);
      expect(req.localeId, 'en-US');
    });
  });

  group('response time and noise', () {
    test('commands: short session and pause, nothing handed to Android '
        'but the wait for speech', () async {
      await setUpWith();
      await speakThenSettle('Una.');
      final req = env.speech.sessions.single;
      expect(req.listenFor, VoiceConfig.commandListenFor);
      expect(req.pauseAfterSpeech, VoiceConfig.commandPause);
      expect(
        VoiceConfig.commandPause.inMilliseconds,
        inInclusiveRange(1200, 1500),
      );
    });

    test(
      'words that keep changing end the session after a few seconds',
      () async {
        await setUpWith();
        await speakThenSettle('Una.');
        env.speech.partial('may nag');
        await Future<void>.delayed(const Duration(milliseconds: 500));
        env.speech.partial('may nag uusap sa');
        expect(env.speech.stops, 0);
        await Future<void>.delayed(
          VoiceConfig.commandSpeechMax + const Duration(milliseconds: 100),
        );
        expect(env.speech.stops, 1);
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );

    test('a command at the end of noise runs once seen twice', () async {
      await setUpWith();
      await speakThenSettle('Una.');
      env.speech.partial('ang ingay mag-upload');
      await pumpEventQueue();
      expect(activated, isEmpty, reason: 'once is not enough');
      env.speech.partial('ang ingay mag-upload');
      await pumpEventQueue();
      expect(activated, ['upload']);
    });

    test('"hindi" before the command: not run from a partial', () async {
      await setUpWith();
      await speakThenSettle('Una.');
      env.speech.partial('hindi mag-upload');
      env.speech.partial('hindi mag-upload');
      await pumpEventQueue();
      expect(activated, isEmpty);
    });

    test(
      'the recognizer\'s other guess is used when it names a command',
      () async {
        await setUpWith();
        await speakThenSettle('Una.');
        env.speech.hearWith('maka bulaklak', ['mag-upload', 'magka upload']);
        await pumpEventQueue();
        expect(activated, ['upload']);
      },
    );

    test('the best guess wins when it is a command', () async {
      await setUpWith();
      await speakThenSettle('Una.');
      env.speech.hearWith('tulong', ['mag-upload']);
      await pumpEventQueue();
      expect(activated, isEmpty);
      expect(env.tts.transcript, contains('Tulong para sa'));
    });
  });

  group('Voice check test listen', () {
    test('returns what was heard, how, and without running it', () async {
      await setUpWith(mode: NavMode.gestures, info: filipinoOffline);
      final result = voice().probe();
      await pumpEventQueue();
      final req = env.speech.sessions.single;
      expect(req.listenFor, VoiceConfig.probeListenFor);
      expect(req.onDevice, isTrue);
      env.speech.partial('buksan ang');
      env.speech.hearWith('mag-upload', const [], confidence: 0.87);
      final probe = await result;
      expect(probe, isNotNull);
      expect(probe!.text, 'mag-upload');
      expect(probe.confidence, closeTo(0.87, 0.001));
      expect(probe.plan.onDevice, isTrue);
      await pumpEventQueue();
      expect(activated, isEmpty, reason: 'a test, not a command');
    });

    test('nothing heard: null', () async {
      await setUpWith(mode: NavMode.gestures);
      final result = voice().probe();
      await pumpEventQueue();
      env.speech.silence();
      expect(await result, isNull);
    });
  });

  test('RecognizerInfo matches installed languages by language', () {
    expect(filipinoOffline.filipinoOffline, isTrue);
    expect(englishOnly.filipinoOffline, isFalse);
    expect(englishOnly.englishOffline, 'en-US');
    expect(
      const RecognizerInfo(
        onDevice: true,
        installed: ['tl-PH'],
      ).filipinoOffline,
      isTrue,
    );
    expect(RecognizerInfo.unknown.filipinoOffline, isFalse);
    expect(
      const RecognizerInfo(
        onDevice: false,
        installed: ['fil-PH'],
      ).filipinoOffline,
      isFalse,
      reason: 'no on-device recognizer',
    );
  });
}
