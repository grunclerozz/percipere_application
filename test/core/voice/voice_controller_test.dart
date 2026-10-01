import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/accessibility/action_registry.dart';
import 'package:percipere_app/core/accessibility/announcer.dart';
import 'package:percipere_app/core/accessibility/command_bus.dart';
import 'package:percipere_app/core/accessibility/nav_intent.dart';
import 'package:percipere_app/core/accessibility/navigation_mode.dart';
import 'package:percipere_app/core/accessibility/screen_registration.dart';
import 'package:percipere_app/core/platform/permissions.dart';
import 'package:percipere_app/core/voice/voice_controller.dart';

import '../../helpers/fakes.dart';

/// Longer than the auto-listen delay.
const _settle = Duration(milliseconds: 600);

void main() {
  late TestEnv env;
  late ProviderContainer container;
  VoiceController voice() => container.read(voiceControllerProvider.notifier);
  VoiceState state() => container.read(voiceControllerProvider);

  Future<void> setUpWith({
    NavMode? mode = NavMode.voice,
    PermissionAccess mic = PermissionAccess.granted,
    PermissionAccess onRequest = PermissionAccess.granted,
    bool recognizer = true,
  }) async {
    env = await TestEnv.create(
      mode: mode,
      permissions: FakePermissions(mic: mic, micOnRequest: onRequest),
      speech: FakeSpeechInput(available: recognizer),
    );
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
              onActivate: (_) {},
            ),
          ],
        ),
      );
  }

  Future<void> speakThenSettle(String text) async {
    await container.read(announcerProvider.notifier).say(text);
    await Future<void>.delayed(_settle);
  }

  test(
    'voice mode: listens after speech ends, on-device, Filipino locale',
    () async {
      await setUpWith();
      await speakThenSettle('Pagkuha ng dokumento.');

      expect(env.speech.sessions, hasLength(1));
      final req = env.speech.sessions.single;
      expect(req.onDevice, isTrue);
      expect(req.localeId, 'fil_PH');
      expect(req.phrases, containsAll(['Mag-upload', 'susunod', 'oo']));
      expect(state().listening, isTrue);
    },
  );

  test('gesture mode does not auto-listen', () async {
    await setUpWith(mode: NavMode.gestures);
    await speakThenSettle('Pagkuha ng dokumento.');
    expect(env.speech.sessions, isEmpty);
  });

  test('speech starting closes the session (never hears itself)', () async {
    await setUpWith();
    await speakThenSettle('Una.');
    expect(env.speech.listening, isTrue);

    await container.read(announcerProvider.notifier).say('Ikalawa.');
    expect(env.speech.cancels, greaterThanOrEqualTo(1));
    await Future<void>.delayed(_settle);
    expect(env.speech.sessions, hasLength(2), reason: 're-armed after');
  });

  test('a final result shows as heard and runs the command', () async {
    await setUpWith();
    await speakThenSettle('Una.');
    env.tts.spoken.clear();

    env.speech.partial('tu');
    expect(state().partial, 'tu');
    env.speech.hear('tulong');
    expect(state().heard, 'tulong');
    await pumpEventQueue();
    expect(env.tts.spoken.first, 'Tulong para sa Pagkuha ng dokumento.');
  });

  test('missing offline pack: retries once with online recognition', () async {
    await setUpWith();
    await speakThenSettle('Una.');
    env.speech.fail('error_language_unavailable');
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(env.speech.sessions, hasLength(2));
    expect(env.speech.sessions.last.onDevice, isFalse);
  });

  test(
    'no offline pack and no internet: explains and offers settings',
    () async {
      await setUpWith();
      await speakThenSettle('Una.');
      env.speech.fail('error_language_unavailable');
      await Future<void>.delayed(const Duration(milliseconds: 400));
      env.speech.fail('error_network');
      await pumpEventQueue();

      expect(env.tts.transcript, contains('Walang internet'));
      expect(env.tts.transcript, contains('I-double tap'));
      await container.read(commandBusProvider).dispatch(NavIntent.activate);
      expect(env.settings.voiceInputOpened, 1);
    },
  );

  test(
    'long-press in gesture mode: one session; silence is reported',
    () async {
      await setUpWith(mode: NavMode.gestures);
      await voice().listenNow();
      expect(env.speech.sessions, hasLength(1));

      env.speech.silence();
      await pumpEventQueue();
      expect(env.tts.spoken.last, 'Wala akong narinig.');
      await Future<void>.delayed(_settle);
      expect(env.speech.sessions, hasLength(1), reason: 'no auto re-listen');
    },
  );

  test('first use explains, then asks for the microphone', () async {
    await setUpWith(mode: NavMode.gestures, mic: PermissionAccess.denied);
    await voice().listenNow();

    expect(env.tts.transcript, contains('mikropono'));
    expect(env.permissions.micRequests, 1);
    expect(env.speech.sessions, hasLength(1));
  });

  test('refused microphone: explains gestures will be used', () async {
    await setUpWith(
      mode: NavMode.gestures,
      mic: PermissionAccess.denied,
      onRequest: PermissionAccess.denied,
    );
    await voice().listenNow();
    expect(env.speech.sessions, isEmpty);
    expect(
      env.tts.spoken.last,
      'Hindi ko magagamit ang mikropono, kaya mga '
      'galaw muna ang gagamitin.',
    );
  });

  test('blocked microphone: offers the app settings page', () async {
    await setUpWith(mic: PermissionAccess.permanentlyDenied);
    await voice().listenNow();
    expect(env.tts.transcript, contains('Naka-block'));
    await container.read(commandBusProvider).handleUtterance('oo');
    expect(env.permissions.settingsOpened, 1);
  });

  test(
    'dictation returns the words without running them as a command',
    () async {
      await setUpWith(mode: NavMode.gestures);
      final result = voice().dictate();
      await pumpEventQueue();
      expect(env.speech.sessions.single.dictation, isTrue);
      env.tts.spoken.clear();
      env.speech.hear('tulong'); // would be "help" as a command
      expect(await result, 'tulong');
      await pumpEventQueue();
      expect(env.tts.spoken, isEmpty);
    },
  );

  test('dictation with silence returns null', () async {
    await setUpWith(mode: NavMode.gestures);
    final result = voice().dictate();
    await pumpEventQueue();
    env.speech.silence();
    expect(await result, isNull);
  });

  test('no recognizer: explains and switches to gestures', () async {
    await setUpWith(recognizer: false);
    await voice().listenNow();
    expect(env.tts.transcript, contains('Walang speech recognition'));
    expect(container.read(navigationModeProvider), NavMode.gestures);
    expect(state().status, ListenStatus.unavailable);
  });
}
