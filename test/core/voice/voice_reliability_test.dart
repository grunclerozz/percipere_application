// Voice reliability (2026-10-17, branch fix/voice-reliability): the three
// problems seen on the tablet, reproduced with Android's real event order,
// and the fixes.
//
// 1. "Say it twice": the "listening" cue played before the microphone was
//    open, so the first words were lost (cue tests in voice_cutoff_test).
// 2. "Hold twice": the hold restarted a session that it then cancelled; the
//    cancelled session's late `done`/error landed on the new session and
//    ended it ("Wala akong narinig").
// 3. False "voice not working": Android sends `done` before the error, so
//    a busy recognizer counted as "ended at once" three times → give up;
//    and the late result that followed was thrown away.

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
import 'package:percipere_app/core/offline_voice/hybrid_tts_service.dart';
import 'package:percipere_app/core/offline_voice/offline_engines.dart';
import 'package:percipere_app/core/platform/permissions.dart';
import 'package:percipere_app/core/tts/tts_service.dart';
import 'package:percipere_app/core/voice/command_matcher.dart';
import 'package:percipere_app/core/voice/voice_controller.dart';
import 'package:percipere_app/core/voice/voice_trial.dart';

import '../../helpers/fakes.dart';

/// Longer than the auto-listen delay.
const _settle = Duration(milliseconds: 600);

/// Longer than [VoiceConfig.errorAfterDone].
const _afterDone = Duration(milliseconds: 300);

/// Android TTS that takes a while to list its voices (as on the tablet).
class _SlowVoicesTts extends FakeTts {
  final Completer<void> voicesListed = Completer();

  @override
  Future<List<TtsVoice>> listVoices() async {
    await voicesListed.future;
    return installedVoices;
  }
}

void main() {
  late TestEnv env;
  late ProviderContainer container;
  late List<NavIntent> ran;
  VoiceController voice() => container.read(voiceControllerProvider.notifier);
  VoiceState state() => container.read(voiceControllerProvider);

  Future<void> setUpWith({NavMode mode = NavMode.voice}) async {
    ran = [];
    env = await TestEnv.create(
      mode: mode,
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

  Future<void> listeningInVoiceMode() async {
    await container.read(announcerProvider.notifier).say('Una.');
    await Future<void>.delayed(_settle);
    expect(env.speech.listening, isTrue);
  }

  group('problem 2: one hold = listening, every time', () {
    test('the closed session\'s late end does not end the hold\'s session '
        '(gesture mode)', () async {
      await setUpWith(mode: NavMode.gestures);
      await voice().listenNow(); // a first hold
      env.speech.soundLevel();
      await voice().listenNow(); // held again: closes that one, opens anew
      // The closed session's end arrives late, Android's way.
      await env.speech.endLikeAndroid('error_client');
      await Future<void>.delayed(_settle);
      expect(env.tts.transcript, isNot(contains('Wala akong narinig')));
      expect(env.speech.listening, isTrue, reason: 'still listening');
      env.speech.hear('susunod');
      await pumpEventQueue();
      expect(state().heard, 'susunod');
      expect(ran, contains(NavIntent.next));
    });

    test('a hold while voice mode listens opens exactly one new session',
        () async {
      await setUpWith();
      await listeningInVoiceMode();
      final before = env.speech.sessions.length;
      final bus = container.read(commandBusProvider);
      await bus.dispatch(NavIntent.listen);
      // Past every restart delay: no second session from the hold's own
      // command restart.
      await Future<void>.delayed(_settle);
      expect(env.speech.sessions.length, before + 1);
      expect(env.speech.listening, isTrue);
    });

    test('a doubled hold gesture does not toggle listening off', () async {
      await setUpWith(mode: NavMode.gestures);
      final first = voice().listenNow();
      final second = voice().listenNow();
      await Future.wait([first, second]);
      await Future<void>.delayed(_settle);
      expect(env.speech.sessions, hasLength(1));
      expect(env.speech.cancels, 0);
      expect(env.speech.listening, isTrue);
    });
  });

  group('problem 3: no false "voice not working"', () {
    test('Android\'s order (done, then the error): the real error code is '
        'used', () async {
      await setUpWith();
      await listeningInVoiceMode();
      expect(env.speech.sessions.last.onDevice, isTrue);
      await env.speech.endLikeAndroid('error_language_unavailable');
      await Future<void>.delayed(_settle);
      expect(
        env.speech.sessions.last.onDevice,
        isFalse,
        reason: 'no offline pack: the next session is online',
      );
    });

    test('busy errors from a recognizer that hears sound never give up',
        () async {
      await setUpWith();
      await listeningInVoiceMode();
      for (var i = 0; i < 8; i++) {
        env.speech.soundLevel();
        await env.speech.endLikeAndroid('error_busy');
        await Future<void>.delayed(const Duration(milliseconds: 900));
      }
      expect(env.tts.transcript, isNot(contains('Hihinto muna ako')));
      expect(env.speech.listening, isTrue);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a late result during the grace drops the message and runs',
        () async {
      await setUpWith();
      await listeningInVoiceMode();
      // A recognizer that never delivers sound: dead.
      for (var i = 0; i < 600 && !voice().givingUp; i++) {
        if (env.speech.listening) env.speech.fail('error_audio');
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(voice().givingUp, isTrue);
      expect(env.speech.listening, isFalse);
      expect(env.tts.transcript, isNot(contains('Hihinto muna ako')));
      env.speech.hear('susunod');
      await Future<void>.delayed(
        VoiceConfig.giveUpGrace + const Duration(milliseconds: 200),
      );
      expect(state().heard, 'susunod');
      expect(ran, contains(NavIntent.next));
      expect(env.tts.transcript, isNot(contains('Hihinto muna ako')));
    }, timeout: const Timeout(Duration(seconds: 90)));
  });

  group('noise: unsure commands are asked back', () {
    /// The room at [level] for longer than [VoiceConfig.noiseSustain] (plus
    /// the "listening" tone's [VoiceConfig.noiseToneSettle] and
    /// [VoiceConfig.noiseOnsetLag], dropped as the start of the words),
    /// once the app's own voice has died away ([VoiceConfig.noiseSettle]).
    Future<void> room(double level) async {
      await Future<void>.delayed(VoiceConfig.noiseSettle);
      final span =
          VoiceConfig.noiseSustain +
          VoiceConfig.noiseToneSettle +
          VoiceConfig.noiseOnsetLag +
          const Duration(milliseconds: 400);
      for (var i = 0; i < span.inMilliseconds ~/ 200; i++) {
        env.speech.soundLevel(level);
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }

    test('a noisy room: a near miss is asked back, politely', () async {
      await setUpWith();
      await listeningInVoiceMode();
      await room(VoiceConfig.noisyLevel + 2);
      env.speech.hear('tilungan');
      await Future<void>.delayed(_afterDone);
      expect(env.tts.transcript, contains('Medyo maingay po'));
      expect(env.tts.transcript, contains('bilisan'));
      expect(ran, isEmpty, reason: 'nothing runs before the answer');
      await Future<void>.delayed(_settle);
      env.speech.hear('oo');
      await pumpEventQueue();
      expect(ran, contains(NavIntent.faster));
    });

    test('a quiet room: the same words are "not understood"', () async {
      await setUpWith();
      await listeningInVoiceMode();
      await room(0);
      env.speech.hear('tilungan');
      await Future<void>.delayed(_afterDone);
      expect(env.tts.transcript, isNot(contains('Medyo maingay po')));
      expect(ran, isEmpty);
    });

    test('an uncertain result is asked back, without "noisy"', () async {
      await setUpWith();
      await listeningInVoiceMode();
      env.speech.hearWith('tilungan', const [], confidence: 0.3);
      await Future<void>.delayed(_afterDone);
      expect(env.tts.transcript, contains('Ito ba ang ibig mong sabihin'));
      expect(env.tts.transcript, isNot(contains('Medyo maingay po')));
    });

    test('noise settings are in range', () {
      expect(VoiceConfig.noisyAskScore, lessThan(0.6));
      expect(VoiceConfig.noisyAskScore, greaterThanOrEqualTo(0.4));
      expect(VoiceConfig.lowConfidence, inInclusiveRange(0.3, 0.7));
    });
  });

  test('speech stopped while the voice is being chosen is not spoken '
      'afterwards (it used to talk over a hold)', () async {
    final android = _SlowVoicesTts();
    final tts = HybridTtsService(android, OfflineEngines());
    final speaking = tts.speak('Pagkuha ng dokumento.', languageTag: 'fil-PH');
    await pumpEventQueue();
    await tts.stop();
    android.voicesListed.complete();
    expect(await speaking, isFalse);
    expect(android.spoken, isEmpty);
  });

  group('reliability test (CSV)', () {
    test('20 commands, each matching its command on any screen', () async {
      await setUpWith(mode: NavMode.gestures);
      final bus = container.read(commandBusProvider);
      expect(VoiceTrial.commands, hasLength(20));
      for (final command in VoiceTrial.commands) {
        final match = bus.matchOnly(command.phrase);
        expect(
          VoiceTrial.isCorrect(command, match),
          isTrue,
          reason: '"${command.phrase}" → ${VoiceTrial.matchedName(match)}',
        );
      }
    });

    test('CSV lines: quoted text, header columns', () {
      final row = TrialRow(
        at: DateTime(2026, 10, 17, 9),
        room: TrialRoom.noisy,
        number: 3,
        command: VoiceTrial.commands[2],
        heard: 'ulit "po"',
        matched: VoiceTrial.matchedName(
          const Matched(ValueTarget(NavIntent.repeat), 'ulit', 1),
        ),
        correct: true,
        attempts: 2,
        responseMs: 420,
        listenMs: 1800,
        totalMs: 6100,
        engine: 'offline',
        noisy: true,
        confidence: -1,
      );
      final cells = VoiceTrialLog.line(row);
      expect(VoiceTrialLog.header.split(','), hasLength(15));
      expect(
        cells,
        '2026-10-17T09:00:00.000,noisy,3,"ulitin",repeat,"ulit ""po""",'
        '"repeat",1,2,420,1800,6100,offline,1,',
      );
    });
  });
}
