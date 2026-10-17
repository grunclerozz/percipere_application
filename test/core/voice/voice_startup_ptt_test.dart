// Voice at startup, while busy, and push-to-talk (2026-10-17, branch
// fix/voice-startup-ptt). Tablet test after fix/voice-reliability: at app
// start (login, register, guest) and right after an upload, holding gave
// "Hindi gumagana ang pakikinig…" / "Hihinto muna ako", commands had to be
// said 2–3 times, and after a while it worked. Root causes reproduced here:
//
// A. Android's recognizer that failed to set up once (busy at startup) was
//    marked as missing for the whole run: every hold said "Walang speech
//    recognition…" until the offline model happened to finish loading.
// B. Sessions failing while the app was loading or processing (OCR) counted
//    toward giving up.
// C. A hold opened the microphone while the app's own voice was still
//    finishing its sentence (stop() returned before the speech ended).
// D. Nothing kept listening and prompts away from the startup work.

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
import 'package:percipere_app/core/offline_voice/hybrid_tts_service.dart';
import 'package:percipere_app/core/offline_voice/offline_engines.dart';
import 'package:percipere_app/core/platform/permissions.dart';
import 'package:percipere_app/core/voice/voice_activity.dart';
import 'package:percipere_app/core/voice/voice_controller.dart';
import 'package:percipere_app/core/voice/voice_readiness.dart';

import '../../helpers/fakes.dart';

/// Longer than the auto-listen delay.
const _settle = Duration(milliseconds: 600);

const _unavailable = 'Walang speech recognition';
const _notWorking = 'Hindi gumagana ang pakikinig';
const _oneMoment = 'Sandali lang po.';

/// TTS whose stop() returns before the sentence has really ended (as the
/// app's own voice did while generating audio): the sentence ends
/// [tail] later.
class _SlowStopTts extends FakeTts {
  _SlowStopTts(this.tail) : super(autoComplete: false);

  final Duration tail;
  Completer<bool>? _pending;
  DateTime? endedAt;

  @override
  Future<bool> speak(
    String text, {
    required String languageTag,
    double rate = 1.0,
  }) {
    spoken.add(text);
    return (_pending = Completer<bool>()).future;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    final pending = _pending;
    _pending = null;
    if (pending == null) return;
    unawaited(
      Future<void>.delayed(tail, () {
        endedAt = DateTime.now();
        pending.complete(false);
      }),
    );
  }
}

/// Offline engines whose voices are still loading.
class _LoadingEngines extends OfflineEngines {
  final Completer<void> voices = Completer<void>();

  @override
  Future<void> get voicesLoaded => voices.future;
}

void main() {
  late TestEnv env;
  late ProviderContainer container;
  late List<NavIntent> ran;
  VoiceController voice() => container.read(voiceControllerProvider.notifier);
  VoiceReadinessNotifier readiness() =>
      container.read(voiceReadinessProvider.notifier);

  Future<void> setUpWith({
    NavMode mode = NavMode.voice,
    FakeTts? tts,
    bool startup = false,
  }) async {
    ran = [];
    env = await TestEnv.create(
      mode: mode,
      tts: tts,
      permissions: FakePermissions(mic: PermissionAccess.granted),
    );
    container = ProviderContainer(
      overrides: [
        ...env.overrides,
        startupScreenProvider.overrideWithValue(startup),
      ],
    );
    addTearDown(container.dispose);
    container
      ..listen(voiceControllerProvider, (_, _) {})
      ..listen(announcerProvider, (_, _) {})
      ..listen(voiceReadinessProvider, (_, _) {})
      ..read(actionRegistryProvider.notifier).register(
        ScreenRegistration(
          id: 'test',
          title: (l) => l.screenCapture,
          prompt: (l) => l.capturePrompt,
          intentHandlers: {
            for (final intent in NavIntent.values)
              if (intent != NavIntent.listen &&
                  intent != NavIntent.listenRelease)
                intent: (_) async => ran.add(intent),
          },
        ),
      );
  }

  group('A: a recognizer that fails to set up at startup is tried again', () {
    test('a hold waits ("Sandali lang po") instead of "no speech '
        'recognition", and listens once it works', () async {
      await setUpWith(mode: NavMode.gestures);
      env.speech.available = false; // busy at startup
      final hold = voice().listenNow();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      env.speech.available = true; // free a moment later
      await hold;
      expect(env.tts.transcript, contains(_oneMoment));
      expect(env.tts.transcript, isNot(contains(_unavailable)));
      expect(env.speech.listening, isTrue);
      expect(
        container.read(navigationModeProvider),
        NavMode.gestures,
        reason: 'not switched away from voice by a busy start',
      );
    });

    test('only a recognizer that keeps failing, with nothing loading, is '
        'reported missing', () async {
      await setUpWith(mode: NavMode.gestures);
      env.speech.available = false;
      for (var i = 0; i < VoiceConfig.initAttempts; i++) {
        await voice().listenNow();
      }
      expect(env.tts.transcript, contains(_unavailable));
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('B: failures while loading or processing never count', () {
    /// Fails every session that opens (a recognizer with no sound) for
    /// [seconds], or until the app gives up.
    Future<int> failSessions(int seconds) async {
      var failed = 0;
      for (var i = 0; i < seconds * 10 && !voice().givingUp; i++) {
        if (env.speech.listening) {
          env.speech.fail('error_audio');
          failed++;
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      return failed;
    }

    test('control: repeated failures with nothing busy give up', () async {
      await setUpWith();
      await container.read(announcerProvider.notifier).say('Una.');
      await Future<void>.delayed(_settle);
      await failSessions(60);
      expect(voice().givingUp, isTrue);
      await Future<void>.delayed(VoiceConfig.giveUpGrace + _settle);
      expect(env.tts.transcript, contains(_notWorking));
    }, timeout: const Timeout(Duration(seconds: 90)));

    test(
      'the same failures during OCR restart quietly; no "not working"',
      () async {
        await setUpWith();
        await container.read(announcerProvider.notifier).say('Una.');
        await Future<void>.delayed(_settle);
        readiness().begin(VoiceBusy.processing);
        final failed = await failSessions(8);
        expect(failed, greaterThanOrEqualTo(5));
        expect(voice().givingUp, isFalse);
        await Future<void>.delayed(VoiceConfig.giveUpGrace + _settle);
        expect(env.tts.transcript, isNot(contains(_notWorking)));
        expect(env.speech.listening, isTrue, reason: 'still listening');
        readiness().end(VoiceBusy.processing);
        env.speech.hear('susunod');
        await pumpEventQueue();
        expect(ran, contains(NavIntent.next));
      },
    );

    test(
      'the same failures while the offline models load restart quietly',
      () async {
        await setUpWith();
        readiness().begin(VoiceBusy.loading);
        await container.read(announcerProvider.notifier).say('Una.');
        await Future<void>.delayed(_settle);
        expect(await failSessions(8), greaterThanOrEqualTo(5));
        expect(voice().givingUp, isFalse);
        await Future<void>.delayed(VoiceConfig.giveUpGrace);
        expect(env.tts.transcript, isNot(contains(_notWorking)));
        expect(env.speech.listening, isTrue);
      },
    );
  });

  group('C: the hold waits for the app\'s voice to really stop', () {
    test('the microphone opens only after the sentence has ended and audio '
        'focus had time to go', () async {
      final tts = _SlowStopTts(const Duration(milliseconds: 300));
      await setUpWith(mode: NavMode.gestures, tts: tts);
      unawaited(
        container.read(announcerProvider.notifier).say('Mahabang paalala.'),
      );
      await pumpEventQueue();
      expect(container.read(announcerProvider).speaking, isTrue);
      final hold = voice().listenNow();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(env.speech.sessions, isEmpty, reason: 'still speaking');
      await hold;
      expect(env.speech.listening, isTrue);
      final opened = DateTime.now();
      expect(tts.endedAt, isNotNull);
      expect(
        opened.difference(tts.endedAt!),
        greaterThanOrEqualTo(
          VoiceConfig.audioFocusRelease - const Duration(milliseconds: 20),
        ),
      );
    });

    test(
      'a stop returns at once while the offline voice is still loading',
      () async {
        final engines = _LoadingEngines()..debugUse(voices: {'fil'});
        final hybrid = HybridTtsService(FakeTts(), engines);
        final spoken = hybrid.speak('Kumusta po.', languageTag: 'fil-PH');
        await pumpEventQueue();
        await hybrid.stop();
        expect(
          await spoken.timeout(const Duration(milliseconds: 200)),
          isFalse,
        );
      },
    );
  });

  group('D: nothing listens while the loading screen is open', () {
    test('no automatic listening and no hold until startup ends', () async {
      await setUpWith(startup: true);
      expect(container.read(voiceReadinessProvider).starting, isTrue);
      expect(container.read(voiceActivityProvider), VoiceActivity.loading);
      await container.read(announcerProvider.notifier).say('Pakihintay po.');
      await Future<void>.delayed(_settle);
      expect(env.speech.sessions, isEmpty);
      await voice().listenNow();
      expect(env.speech.sessions, isEmpty);
      expect(env.tts.transcript, contains(_oneMoment));
      readiness().end(VoiceBusy.startup);
      await Future<void>.delayed(_settle);
      expect(env.speech.listening, isTrue, reason: 'voice mode starts now');
    });
  });

  group('push-to-talk', () {
    test('held: silences do not end the session; the release finishes it '
        'after the grace period', () async {
      await setUpWith(mode: NavMode.gestures);
      final bus = container.read(commandBusProvider);
      await bus.onGesture(GestureType.longPress);
      expect(env.speech.listening, isTrue);
      final request = env.speech.sessions.last;
      expect(request.pauseFor, VoiceConfig.pushToTalkMax);
      expect(request.pauseAfterSpeech, VoiceConfig.pushToTalkMax);
      expect(voice().pushToTalkHeld, isTrue);
      env.speech
        ..soundLevel(5)
        ..partial('buksan');
      await bus.onGesture(GestureType.holdRelease);
      await Future<void>.delayed(
        VoiceConfig.pushToTalkReleaseGrace - const Duration(milliseconds: 150),
      );
      expect(env.speech.stops, 0, reason: 'the last word still counts');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(env.speech.stops, 1);
      env.speech.hear('susunod');
      await pumpEventQueue();
      expect(ran, contains(NavIntent.next));
      expect(voice().pushToTalkHeld, isFalse);
    });

    test(
      'a release before listening started makes an ordinary session',
      () async {
        final tts = _SlowStopTts(const Duration(milliseconds: 200));
        await setUpWith(mode: NavMode.gestures, tts: tts);
        unawaited(container.read(announcerProvider.notifier).say('Paalala.'));
        await pumpEventQueue();
        final bus = container.read(commandBusProvider);
        final held = bus.onGesture(GestureType.longPress);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await bus.onGesture(GestureType.holdRelease);
        await held;
        expect(env.speech.listening, isTrue);
        expect(env.speech.sessions.last.pauseFor, VoiceConfig.waitForSpeech);
      },
    );

    test('letting go with nothing said is not a recognizer failure', () async {
      await setUpWith(mode: NavMode.gestures);
      final bus = container.read(commandBusProvider);
      for (var i = 0; i < 4; i++) {
        await bus.onGesture(GestureType.longPress);
        await bus.onGesture(GestureType.holdRelease);
        await Future<void>.delayed(
          VoiceConfig.pushToTalkReleaseGrace + const Duration(milliseconds: 50),
        );
        await env.speech.endLikeAndroid('error_no_match');
        await Future<void>.delayed(_settle);
      }
      await Future<void>.delayed(VoiceConfig.giveUpGrace);
      expect(env.tts.transcript, isNot(contains(_notWorking)));
      expect(env.tts.transcript, contains('Wala akong narinig'));
    });

    test('the release is never a command of its own', () async {
      await setUpWith(mode: NavMode.gestures);
      final bus = container.read(commandBusProvider);
      await bus.onGesture(GestureType.holdRelease);
      await pumpEventQueue();
      expect(ran, isEmpty);
      expect(env.speech.sessions, isEmpty);
    });
  });
}
