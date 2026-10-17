// Voice commands that get cut off are not lost: words heard before the cut
// are kept and the next session continues them; a session that ends quietly
// after words acts on them; after repeated cut-offs the app asks to repeat.
// Plus the "listening" cue.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/config/voice_config.dart';
import 'package:percipere_app/core/accessibility/action_registry.dart';
import 'package:percipere_app/core/accessibility/announcer.dart';
import 'package:percipere_app/core/accessibility/nav_intent.dart';
import 'package:percipere_app/core/accessibility/navigation_mode.dart';
import 'package:percipere_app/core/accessibility/screen_registration.dart';
import 'package:percipere_app/core/platform/permissions.dart';
import 'package:percipere_app/core/voice/voice_controller.dart';

import '../../helpers/fakes.dart';

/// Longer than every listening gap.
const _settle = Duration(milliseconds: 600);

void main() {
  late TestEnv env;
  late ProviderContainer container;
  late List<NavIntent> ran;

  VoiceState voice() => container.read(voiceControllerProvider);
  Announcer announcer() => container.read(announcerProvider.notifier);

  Future<void> setUp() async {
    ran = [];
    env = await TestEnv.create(
      mode: NavMode.voice,
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

  Future<void> listening() async {
    await announcer().say('Una.');
    await Future<void>.delayed(_settle);
    expect(env.speech.listening, isTrue, reason: 'should be listening');
  }

  test('a short "listening" cue when the microphone opens after the app '
      'spoke, not on every silent restart', () async {
    await setUp();
    await listening();
    expect(
      env.earcon.listeningCues,
      0,
      reason: 'not before the microphone delivers sound',
    );
    env.speech.soundLevel();
    expect(env.earcon.listeningCues, 1);
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    env.speech.silence();
    await Future<void>.delayed(_settle);
    expect(env.speech.listening, isTrue);
    env.speech.soundLevel();
    expect(env.earcon.listeningCues, 1);
  });

  test('no sound from the microphone: the cue plays anyway after '
      '${VoiceConfig.cueFallback.inMilliseconds}ms', () async {
    await setUp();
    await listening();
    expect(env.earcon.listeningCues, 0);
    await Future<void>.delayed(
      VoiceConfig.cueFallback + const Duration(milliseconds: 100),
    );
    expect(env.earcon.listeningCues, 1);
  });

  test(
    'cut off mid-speech: listens again at once and keeps the words',
    () async {
      await setUp();
      await listening();
      final sessions = env.speech.sessions.length;
      env.speech
        ..partial('saging at')
        ..fail('error_audio');
      expect(voice().partial, 'saging at', reason: 'still shown');
      await Future<void>.delayed(_settle);
      expect(env.speech.sessions.length, sessions + 1);
      expect(
        env.speech.sessions.last.pauseFor,
        VoiceConfig.carryWait,
        reason: 'a short wait: the rest may already be over',
      );
      env.speech.hear('mangga');
      await pumpEventQueue();
      expect(voice().heard, 'saging at mangga');
    },
  );

  test('the command is joined across the cut and runs', () async {
    await setUp();
    await listening();
    env.speech
      ..partial('pa')
      ..fail('error_client');
    await Future<void>.delayed(_settle);
    env.speech.hear('pause');
    await pumpEventQueue();
    expect(voice().heard, 'pa pause');

    // Said again from the start: not doubled.
    await Future<void>.delayed(_settle);
    env.speech
      ..partial('saging at')
      ..fail('error_audio');
    await Future<void>.delayed(_settle);
    env.speech.hear('saging at mangga');
    await pumpEventQueue();
    expect(voice().heard, 'saging at mangga');

    // A command split by the cut runs.
    await Future<void>.delayed(_settle);
    env.speech
      ..partial('mas')
      ..fail('error_audio');
    await Future<void>.delayed(_settle);
    env.speech.hear('bilisan');
    await pumpEventQueue();
    expect(voice().heard, 'mas bilisan');
    expect(ran, contains(NavIntent.faster));
  });

  test('words then a quiet end: acted on, not dropped', () async {
    await setUp();
    await listening();
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    env.speech
      ..partial('saging at mangga')
      ..fail('error_no_match');
    await pumpEventQueue();
    expect(voice().heard, 'saging at mangga');
  });

  test('the app starting to talk keeps what the user had said', () async {
    await setUp();
    await listening();
    env.speech.partial('saging at');
    await announcer().say('Paalala.');
    await Future<void>.delayed(_settle);
    expect(env.speech.listening, isTrue);
    env.speech.hear('mangga');
    await pumpEventQueue();
    expect(voice().heard, 'saging at mangga');
  });

  test('cut off again and again: after 3 retries "Pasensya na po, '
      'pakiulit."', () async {
    await setUp();
    await listening();
    env.speech.partial('saging');
    for (var i = 0; i <= VoiceConfig.cutOffRetries; i++) {
      env.speech.fail('error_audio');
      await Future<void>.delayed(_settle);
    }
    expect(env.tts.transcript, contains('Pasensya na po, pakiulit.'));
    expect(env.haptics.events, contains('error'));
    expect(voice().heard, isNull, reason: 'nothing was run');
  });

  test('cut-off settings are in range', () async {
    expect(VoiceConfig.carryFor, greaterThan(VoiceConfig.carryWait));
    expect(VoiceConfig.cutOffRetries, 3);
    expect(
      VoiceConfig.commandPause.inMilliseconds,
      inInclusiveRange(1200, 1500),
    );
  });
}
