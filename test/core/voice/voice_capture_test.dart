// Voice capture (2026-10-17, branch fix/voice-capture). Tablet results
// after push-to-talk: recognition poor, the microphone heard the app's own
// voice ("Medyo maingay po" and wrong results), the output voice changed.
// Root causes reproduced here:
//
// A. The room was judged by the first level readings of a session: the end
//    of the app's own voice and the user's first word (push-to-talk: they
//    talk at once) counted as noise.
// B. Push-to-talk ended at the first pause: the recognizer's end of speech
//    finished the session (and a strong partial ran) while the finger was
//    still down.
// C. Listening went on while the document was read aloud (barge-in).

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/config/voice_config.dart';
import 'package:percipere_app/core/accessibility/action_registry.dart';
import 'package:percipere_app/core/accessibility/announcer.dart';
import 'package:percipere_app/core/accessibility/command_bus.dart';
import 'package:percipere_app/core/accessibility/nav_intent.dart';
import 'package:percipere_app/core/accessibility/navigation_mode.dart';
import 'package:percipere_app/core/accessibility/screen_registration.dart';
import 'package:percipere_app/core/gestures/gesture_map.dart';
import 'package:percipere_app/core/platform/permissions.dart';
import 'package:percipere_app/core/voice/noise_monitor.dart';
import 'package:percipere_app/core/voice/voice_controller.dart';

import '../../helpers/fakes.dart';

const _noisy = 'Medyo maingay po';

void main() {
  group('noise floor', () {
    late DateTime now;
    late NoiseMonitor noise;
    void after(int ms) => now = now.add(Duration(milliseconds: ms));

    /// Loud readings every 200 ms for [ms].
    void loud(int ms, {double level = 7}) {
      for (var t = 0; t <= ms; t += 200) {
        noise.add(level);
        after(200);
      }
    }

    setUp(() {
      now = DateTime(2026, 10, 17, 9);
      noise = NoiseMonitor(clock: () => now);
    });

    test('steady loud room for longer than the sustain time: noisy', () {
      loud(1200);
      expect(noise.noisy, isTrue);
      expect(noise.floor, 7);
    });

    test('a short loud moment is not a noisy room', () {
      loud(600);
      expect(noise.noisy, isFalse);
    });

    test('nothing counts while the app speaks or just after (echo)', () {
      noise.appSpeaking(true);
      loud(2000);
      noise.appSpeaking(false);
      loud(VoiceConfig.noiseSettle.inMilliseconds - 200);
      expect(noise.noisy, isFalse);
      expect(noise.floor, isNull);
    });

    test('the floor is measured afresh after the app spoke', () {
      loud(1200);
      expect(noise.noisy, isTrue);
      noise
        ..appSpeaking(true)
        ..appSpeaking(false);
      expect(noise.noisy, isFalse);
      after(VoiceConfig.noiseSettle.inMilliseconds);
      loud(1200, level: 0);
      expect(noise.noisy, isFalse);
    });

    test('the user\'s words (and the moment before them) are not noise', () {
      noise.sessionStarted();
      loud(800);
      noise.userSpoke();
      loud(2000);
      expect(noise.noisy, isFalse);
    });

    test('a tone of the app is not noise', () {
      noise.appSound();
      loud(VoiceConfig.noiseToneSettle.inMilliseconds - 200);
      expect(noise.floor, isNull);
    });
  });

  group('controller', () {
    late TestEnv env;
    late ProviderContainer container;
    late List<NavIntent> ran;
    VoiceController voice() => container.read(voiceControllerProvider.notifier);
    CommandBus bus() => container.read(commandBusProvider);

    Future<void> setUpWith({
      NavMode mode = NavMode.gestures,
      FakeTts? tts,
    }) async {
      ran = [];
      env = await TestEnv.create(
        mode: mode,
        tts: tts,
        permissions: FakePermissions(mic: PermissionAccess.granted),
      );
      container = ProviderContainer(overrides: env.overrides);
      addTearDown(container.dispose);
      container
        ..listen(voiceControllerProvider, (_, _) {})
        ..listen(announcerProvider, (_, _) {})
        ..read(actionRegistryProvider.notifier).register(
          ScreenRegistration(
            id: 'test',
            title: (l) => l.screenCapture,
            prompt: (l) => l.capturePrompt,
            intentHandlers: {
              for (final intent in NavIntent.values)
                if (intent != NavIntent.listen)
                  intent: (_) async => ran.add(intent),
            },
          ),
        );
    }

    Future<void> release() async {
      await bus().onGesture(GestureType.holdRelease);
      await Future<void>.delayed(
        VoiceConfig.pushToTalkReleaseGrace + const Duration(milliseconds: 100),
      );
    }

    test('push-to-talk: talking at once is not "noisy" (cause A)', () async {
      await setUpWith();
      await bus().onGesture(GestureType.longPress);
      // The user starts talking right away: loud readings, then the first
      // partial result a moment later. The old rule took the first five
      // readings as the room.
      for (var i = 0; i < VoiceConfig.noisyMinReadings + 1; i++) {
        env.speech.soundLevel(VoiceConfig.noisyLevel + 4);
        await Future<void>.delayed(const Duration(milliseconds: 60));
      }
      env.speech.partial('tilungan');
      await release();
      env.speech.hear('tilungan');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(env.tts.transcript, isNot(contains(_noisy)));
    });

    test(
      'push-to-talk: a strong partial waits for the release (cause B)',
      () async {
        await setUpWith();
        await bus().onGesture(GestureType.longPress);
        env.speech
          ..soundLevel(5)
          ..partial('susunod');
        await pumpEventQueue();
        expect(ran, isEmpty, reason: 'the finger is still down');
        expect(env.speech.listening, isTrue);
        await release();
        env.speech.hear('susunod');
        await pumpEventQueue();
        expect(ran, [NavIntent.next]);
      },
    );

    test('push-to-talk: the recognizer ending by itself while held keeps '
        'listening; the release acts on all of it (cause B)', () async {
      await setUpWith();
      await bus().onGesture(GestureType.longPress);
      final sessions = env.speech.sessions.length;
      env.speech
        ..soundLevel(5)
        ..hear('mas'); // Android ended the session after a pause
      await Future<void>.delayed(
        VoiceConfig.sessionGap + const Duration(milliseconds: 400),
      );
      expect(ran, isEmpty);
      expect(env.speech.sessions.length, sessions + 1, reason: 'listens on');
      expect(env.speech.sessions.last.pushToTalk, isTrue);
      await release();
      env.speech.hear('mabilis');
      await pumpEventQueue();
      expect(ran, [NavIntent.faster], reason: '"mas" + "mabilis"');
    });

    test('push-to-talk: released between two sessions of the hold: what '
        'was heard runs at once', () async {
      await setUpWith();
      await bus().onGesture(GestureType.longPress);
      env.speech
        ..soundLevel(5)
        ..hear('susunod');
      await pumpEventQueue();
      await bus().onGesture(GestureType.holdRelease);
      await pumpEventQueue();
      expect(ran, [NavIntent.next]);
    });

    test('the push-to-talk session is marked for the recognizer', () async {
      await setUpWith();
      await bus().onGesture(GestureType.longPress);
      expect(env.speech.sessions.last.pushToTalk, isTrue);
      await release();
      env.speech.hear('');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await voice().listenNow();
      expect(env.speech.sessions.last.pushToTalk, isFalse);
    });

    test(
      'half-duplex: no automatic listening while the app speaks (cause C)',
      () async {
        final tts = FakeTts(autoComplete: false);
        await setUpWith(mode: NavMode.voice, tts: tts);
        unawaited(
          container.read(announcerProvider.notifier).say('Mahabang paalala.'),
        );
        await Future<void>.delayed(const Duration(milliseconds: 900));
        expect(env.speech.listening, isFalse);
        tts.finishCurrent();
        await Future<void>.delayed(
          VoiceConfig.afterSpeechGap + const Duration(milliseconds: 300),
        );
        expect(env.speech.listening, isTrue, reason: 'after the speech + gap');
      },
    );

    test('half-duplex is on', () {
      expect(VoiceConfig.halfDuplex, isTrue);
    });
  });
}
