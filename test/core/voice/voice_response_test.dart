import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/config/voice_config.dart';
import 'package:percipere_app/core/accessibility/action_registry.dart';
import 'package:percipere_app/core/accessibility/announcer.dart';
import 'package:percipere_app/core/accessibility/command_bus.dart';
import 'package:percipere_app/core/accessibility/nav_intent.dart';
import 'package:percipere_app/core/accessibility/navigation_mode.dart';
import 'package:percipere_app/core/accessibility/screen_registration.dart';
import 'package:percipere_app/core/platform/permissions.dart';
import 'package:percipere_app/core/settings/app_settings.dart';
import 'package:percipere_app/core/voice/barge_in.dart';
import 'package:percipere_app/core/voice/voice_controller.dart';

import '../../helpers/fakes.dart';

/// Longer than every listening gap.
const _settle = Duration(milliseconds: 600);

const _sentence = 'Ang mga bata ay naglalaro sa labas ng bahay.';

void main() {
  late TestEnv env;
  late ProviderContainer container;
  late List<NavIntent> ran;

  VoiceController voice() => container.read(voiceControllerProvider.notifier);
  Announcer announcer() => container.read(announcerProvider.notifier);
  CommandBus bus() => container.read(commandBusProvider);

  /// A screen that records every intent instead of acting on it.
  ScreenRegistration recorder({
    List<String>? freeTextPrefixes,
    bool withOnUtterance = false,
  }) => ScreenRegistration(
    id: 'test',
    title: (l) => l.screenCapture,
    prompt: (l) => l.capturePrompt,
    onUtterance: withOnUtterance ? (_, _) => false : null,
    freeTextPrefixes: freeTextPrefixes,
    intentHandlers: {
      for (final intent in NavIntent.values)
        if (intent != NavIntent.listen) intent: (_) async => ran.add(intent),
    },
  );

  Future<void> setUpWith({
    AppSettings settings = const AppSettings(),
    FakeTts? tts,
    ScreenRegistration? screen,
  }) async {
    ran = [];
    env = await TestEnv.create(
      mode: NavMode.voice,
      appSettings: settings,
      tts: tts,
      permissions: FakePermissions(mic: PermissionAccess.granted),
    );
    container = ProviderContainer(overrides: env.overrides);
    addTearDown(container.dispose);
    container
      ..listen(voiceControllerProvider, (_, _) {})
      ..listen(announcerProvider, (_, _) {})
      ..read(actionRegistryProvider.notifier).register(screen ?? recorder());
  }

  /// Speaks a prompt and waits until the app listens again.
  Future<void> listening() async {
    await announcer().say('Una.');
    await Future<void>.delayed(_settle);
    expect(env.speech.listening, isTrue, reason: 'should be listening');
  }

  group('pauses: short for commands, long for dictation', () {
    test('the config values are in the requested ranges', () {
      expect(
        VoiceConfig.commandPause.inMilliseconds,
        inInclusiveRange(1000, 1500),
      );
      expect(
        VoiceConfig.dictationPause.inMilliseconds,
        inInclusiveRange(3000, 5000),
      );
      // Long enough to start talking after the app stops speaking.
      expect(
        VoiceConfig.waitForSpeech,
        greaterThanOrEqualTo(const Duration(seconds: 3)),
      );
    });

    test('a command session waits for the first words, then uses the short '
        'command pause', () async {
      await setUpWith();
      await listening();
      final request = env.speech.sessions.last;
      expect(request.dictation, isFalse);
      // The plugin counts silence from the start of listening: the user
      // must get time to begin.
      expect(request.pauseFor, VoiceConfig.waitForSpeech);
      expect(request.pauseAfterSpeech, VoiceConfig.commandPause);
      expect(env.speech.pauseChanges, isEmpty);

      env.speech.partial('saging');
      expect(env.speech.pauseChanges, [VoiceConfig.commandPause]);
      env.speech.partial('saging at mangga');
      expect(
        env.speech.pauseChanges,
        hasLength(1),
        reason: 'switched once per session',
      );
    });

    test('regression: quiet sessions are not recognizer failures (listening '
        'never stops by itself)', () async {
      await setUpWith();
      await listening();
      // Three sessions in a row where nobody speaks, each lasting longer
      // than an "instant" failure.
      for (var i = 0; i < 3; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1600));
        env.speech.silence();
        await Future<void>.delayed(_settle);
      }
      expect(env.speech.listening, isTrue, reason: 'still listening');
      expect(
        env.speech.sessions.last.onDevice,
        isTrue,
        reason: 'no switch to online recognition',
      );
      expect(
        env.tts.transcript,
        isNot(contains('Hindi gumagana ang pakikinig')),
      );
      expect(env.speech.sessions.length, greaterThanOrEqualTo(4));
    });

    test('dictation uses the dictation pause', () async {
      await setUpWith();
      final said = voice().dictate();
      await pumpEventQueue();
      final request = env.speech.sessions.last;
      expect(request.dictation, isTrue);
      expect(request.pauseFor, VoiceConfig.dictationPause);
      env.speech.hear('Juan dela Cruz');
      expect(await said, 'Juan dela Cruz');
    });
  });

  group('acting on partial results', () {
    test('a close partial match runs at once and closes the session', () async {
      await setUpWith();
      await listening();
      final cancels = env.speech.cancels;

      env.speech.partial('i-pause');
      await pumpEventQueue();

      expect(ran, [NavIntent.pause]);
      expect(env.speech.cancels, greaterThan(cancels));
    });

    test('the final result of that session does not run it again', () async {
      await setUpWith();
      await listening();
      env.speech.partial('itigil');
      await pumpEventQueue();
      env.speech.hear('itigil');
      await pumpEventQueue();
      expect(ran, [NavIntent.stopSpeech]);
    });

    test('a weaker partial match waits for the final result', () async {
      await setUpWith();
      await listening();
      // "bilisa": 0.86 similar to "bilisan", below the 0.9 needed at once.
      env.speech.partial('bilisa');
      await pumpEventQueue();
      expect(ran, isEmpty);
      env.speech.hear('bilisan');
      await pumpEventQueue();
      expect(ran, [NavIntent.faster]);
    });

    test('the same weaker match twice in a row runs', () async {
      await setUpWith();
      await listening();
      env.speech
        ..partial('bilisa')
        ..partial('bilisa');
      await pumpEventQueue();
      expect(ran, [NavIntent.faster]);
    });

    test('unclear partial results never run anything', () async {
      await setUpWith();
      await listening();
      env.speech
        ..partial('saging')
        ..partial('saging at mangga');
      await pumpEventQueue();
      expect(ran, isEmpty);
    });

    test('the start of a longer command waits for the rest', () async {
      await setUpWith();
      await listening();
      env.speech.partial('susunod');
      await pumpEventQueue();
      expect(ran, isEmpty, reason: '"susunod na talata" may follow');
      env.speech.partial('susunod na talata');
      await pumpEventQueue();
      expect(ran, [NavIntent.nextParagraph]);
    });

    test('a lone "susunod" still runs, from the final result', () async {
      await setUpWith();
      await listening();
      env.speech.partial('susunod');
      await pumpEventQueue();
      env.speech.hear('susunod');
      await pumpEventQueue();
      expect(ran, [NavIntent.next]);
    });

    test('a free-text command start waits for the final result', () async {
      await setUpWith(screen: recorder(freeTextPrefixes: ['ituloy ang']));
      expect(bus().judgePartial('ituloy'), isNull);
      expect(bus().judgePartial('ituloy ang liham'), isNull);
      expect(bus().judgePartial('bumalik'), isNotNull);
    });

    test(
      'screens reading free text without prefixes never act early',
      () async {
        await setUpWith(screen: recorder(withOnUtterance: true));
        expect(bus().judgePartial('bumalik'), isNull);
      },
    );

    test('yes/no answers count while a question is pending', () async {
      await setUpWith();
      var accepted = false;
      await bus().offer('Buksan ang Settings?', () => accepted = true);
      await Future<void>.delayed(_settle);
      env.speech.partial('oo');
      await pumpEventQueue();
      expect(accepted, isTrue);
    });
  });

  group('one command per phrase', () {
    test('two commands: only the first one said runs', () async {
      await setUpWith();
      await listening();
      env.speech.hear('itigil bumalik');
      await pumpEventQueue();
      expect(ran, [NavIntent.stopSpeech]);
    });
  });

  group('stale results', () {
    test('a gesture while listening restarts the session; its old words are '
        'ignored', () async {
      await setUpWith();
      await listening();
      final sessions = env.speech.sessions.length;

      await bus().dispatch(NavIntent.next); // a swipe
      env.speech.hear('bumalik'); // said before the swipe
      await pumpEventQueue();
      expect(ran, [NavIntent.next], reason: 'the old "bumalik" is dropped');

      await Future<void>.delayed(_settle);
      expect(env.speech.sessions.length, greaterThan(sessions));
      env.speech.hear('bumalik');
      await pumpEventQueue();
      expect(ran, [NavIntent.next, NavIntent.back]);
    });
  });

  group('immediate feedback', () {
    test('a sound and a pulse the moment a command is recognized', () async {
      await setUpWith();
      await listening();
      env.haptics.events.clear();
      env.speech.partial('bumalik');
      await pumpEventQueue();
      expect(env.earcon.played, 1);
      expect(env.haptics.events.first, 'heard');
    });

    test('dictation gets no "heard" sound (the form reads it back)', () async {
      await setUpWith();
      final said = voice().dictate();
      await pumpEventQueue();
      env.speech.hear('Gamot');
      await said;
      expect(env.earcon.played, 0);
    });
  });

  group('listening while reading (barge-in)', () {
    Future<void> startReading() async {
      announcer()
        ..noteReadAloud(_sentence)
        ..setReading(true);
      await Future<void>.delayed(_settle);
    }

    test('listens during reading with only the reading commands', () async {
      await setUpWith(tts: FakeTts(autoComplete: false));
      await startReading();
      expect(env.speech.listening, isTrue);
      expect(env.speech.sessions.last.phrases, BargeIn.phrases);
      expect(BargeIn.phrases, containsAll(['i-pause', 'itigil', 'bilisan']));
    });

    test('a command over the app\'s own voice runs at once', () async {
      await setUpWith(tts: FakeTts(autoComplete: false));
      await startReading();
      env.speech.partial('ang mga bata ay naglalaro');
      await pumpEventQueue();
      expect(ran, isEmpty);
      env.speech.partial('ang mga bata ay naglalaro i-pause');
      await pumpEventQueue();
      expect(ran, [NavIntent.pause]);
    });

    test('its own voice is ignored and listening goes on', () async {
      await setUpWith(tts: FakeTts(autoComplete: false));
      await startReading();
      final sessions = env.speech.sessions.length;
      env.speech.hear('ang mga bata ay naglalaro sa labas');
      await Future<void>.delayed(_settle);
      expect(ran, isEmpty);
      expect(env.tts.transcript, isNot(contains('Hindi ko')));
      expect(env.speech.sessions.length, greaterThan(sessions));
    });

    test('other commands are ignored while reading', () async {
      await setUpWith(tts: FakeTts(autoComplete: false));
      await startReading();
      env.speech.hear('camera');
      await pumpEventQueue();
      expect(ran, isEmpty);
    });

    test('switched off in Settings: no listening while reading', () async {
      await setUpWith(
        settings: const AppSettings(listenWhileReading: false),
        tts: FakeTts(autoComplete: false),
      );
      await startReading();
      expect(env.speech.listening, isFalse);
    });

    test('long-press stops the reading and listens at once', () async {
      await setUpWith(tts: FakeTts(autoComplete: false));
      await startReading();
      final sessions = env.speech.sessions.length;
      await voice().listenNow();
      expect(container.read(announcerProvider).reading, isFalse);
      expect(env.speech.sessions.length, sessions + 1);
      expect(
        env.speech.sessions.last.phrases,
        isNot(BargeIn.phrases),
        reason: 'an ordinary command session',
      );
      env.speech.hear('ituloy');
      await pumpEventQueue();
      expect(ran, [NavIntent.resume]);
    });
  });

  group('the self-voice filter', () {
    test('removes words of the sentence being read', () {
      expect(BargeIn.residual('ang mga bata itigil', [_sentence]), ['itigil']);
      expect(BargeIn.isEcho('mga bata ay naglalaro', [_sentence]), isTrue);
    });

    test('also when the recognizer got them slightly wrong', () {
      expect(BargeIn.isEcho('naglaloro sa labas', [_sentence]), isTrue);
    });

    test('the previous sentence counts too', () {
      expect(
        BargeIn.isEcho('kumain sila ng saging', [
          'Kumain sila ng saging.',
          _sentence,
        ]),
        isTrue,
      );
    });

    test('finds a reading command said over the reading', () {
      expect(
        BargeIn.command('ang mga bata i-pause', [_sentence]),
        NavIntent.pause,
      );
      expect(BargeIn.command('bata bilisan', [_sentence]), NavIntent.faster);
      expect(BargeIn.command('paborito', [_sentence]), NavIntent.favorite);
    });

    test('a command word that is in the sentence is the app\'s own voice', () {
      const text = 'Sandali lang, sabi ng nanay.';
      expect(BargeIn.command('sandali lang', [text]), isNull);
    });

    test('ignores everything but reading commands', () {
      expect(BargeIn.command('susunod', [_sentence]), isNull);
      expect(BargeIn.command('camera', [_sentence]), isNull);
      expect(BargeIn.command('', [_sentence]), isNull);
    });
  });

  test('the announcer keeps the sentences read since a time', () async {
    await setUpWith();
    final a = announcer()..noteReadAloud('Una.');
    await Future<void>.delayed(const Duration(milliseconds: 40));
    final since = DateTime.now();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    a
      ..noteReadAloud('Ikalawa.')
      ..noteReadAloud('Ikatlo.');
    expect(a.readAloudSince(since), ['Una.', 'Ikalawa.', 'Ikatlo.']);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(a.readAloudSince(DateTime.now()), ['Ikatlo.']);
  });
}
