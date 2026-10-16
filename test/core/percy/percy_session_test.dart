// Percy's session (revisions 2026-10-13, item 4): it stays open through a
// conversation, asks once after a silence and only then says goodbye,
// survives recognizer errors, ends on "paalam" — and never says "the
// conversation has ended". Also the analysis panel's data (item 7).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/accessibility/action_registry.dart';
import 'package:percipere_app/core/accessibility/announcer.dart';
import 'package:percipere_app/core/accessibility/command_bus.dart';
import 'package:percipere_app/core/accessibility/nav_intent.dart';
import 'package:percipere_app/core/accessibility/navigation_mode.dart';
import 'package:percipere_app/core/accessibility/screen_registration.dart';
import 'package:percipere_app/core/percy/percy_analysis.dart';
import 'package:percipere_app/core/percy/percy_controller.dart';
import 'package:percipere_app/core/settings/app_settings.dart';
import 'package:percipere_app/core/settings/settings_controller.dart';
import 'package:percipere_app/core/tts/language_detector.dart';
import 'package:percipere_app/core/voice/voice_controller.dart';

import '../../helpers/fakes.dart';

/// Longer than the auto-listen delay after speech.
const _settle = Duration(milliseconds: 600);

/// Short silence timings for the tests.
const _silence = PercySilence(
  reprompt: Duration(milliseconds: 900),
  end: Duration(milliseconds: 900),
);

const _reprompt = 'Nandito pa po ako. Ano po ang maitutulong ko?';

/// Lines that must never be heard any more.
final _endedLine = RegExp(
  'tapos na po ang usapan|has ended',
  caseSensitive: false,
);

void main() {
  late TestEnv env;
  late ProviderContainer container;
  PercyController percy() => container.read(percyControllerProvider.notifier);
  bool active() => container.read(percyActiveProvider);
  // The announcer speaks sentence by sentence: compare joined text.
  String spokenSince(int i) => env.tts.spoken.sublist(i).join(' ');
  bool endsWithLine(String line) => env.tts.transcript.endsWith(line);
  int countLine(String line) => line.allMatches(env.tts.transcript).length;

  Future<void> setUpWith({bool analysis = false}) async {
    env = await TestEnv.create(mode: NavMode.gestures);
    container = ProviderContainer(
      overrides: [
        ...env.overrides,
        percySilenceProvider.overrideWithValue(_silence),
        percyAnalysisOnProvider.overrideWithValue(analysis),
      ],
    );
    addTearDown(container.dispose);
    container
      ..listen(voiceControllerProvider, (_, _) {})
      ..listen(announcerProvider, (_, _) {})
      ..listen(percyControllerProvider, (_, _) {})
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

  Future<void> startPercy() async {
    await percy().start();
    await Future<void>.delayed(_settle);
    expect(active(), isTrue);
  }

  /// The user says [words]; the recognizer delivers them as a final result.
  Future<void> say(String words) async {
    expect(env.speech.listening, isTrue, reason: 'Percy should be listening');
    env.speech.hear(words);
    await Future<void>.delayed(_settle);
  }

  test('a multi-turn conversation keeps the session open', () async {
    await setUpWith();
    await startPercy();
    expect(env.tts.transcript, contains('Percy'));

    final mark = env.tts.spoken.length;
    await say('sino ka');
    expect(active(), isTrue);
    expect(spokenSince(mark), contains('Percy'));

    await say('salamat');
    expect(active(), isTrue);

    await say('ano ang kaya mo');
    expect(active(), isTrue);
    // Each turn reopened the microphone for the next one.
    expect(env.speech.listening, isTrue);
    expect(env.tts.transcript, isNot(matches(_endedLine)));
  });

  test('holding to listen while Percy works out an answer drops that answer',
      () async {
    await setUpWith();
    await startPercy();
    final mark = env.tts.spoken.length;

    final turn = percy().handle('sino ka'); // not an exact command
    percy().interruptTurn(); // the user held the gesture area
    await turn;
    await Future<void>.delayed(_settle);

    expect(spokenSince(mark), isNot(contains('Percy')));
    expect(active(), isTrue, reason: 'the session itself goes on');
  });

  test('silence: Percy asks once, then says goodbye and ends', () async {
    await setUpWith();
    await startPercy();

    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(endsWithLine(_reprompt), isTrue);
    expect(active(), isTrue, reason: 'the reminder does not end the session');
    expect(countLine(_reprompt), 1, reason: 'asked only once');

    await Future<void>.delayed(const Duration(milliseconds: 1400));
    expect(active(), isFalse);
    expect(endsWithLine('Paalam muna po. Tawagin lang po ako ulit.'), isTrue);
    expect(countLine(_reprompt), 1);
    expect(env.tts.transcript, isNot(matches(_endedLine)));
  });

  test('speaking after the reminder keeps the session going', () async {
    await setUpWith();
    await startPercy();
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(endsWithLine(_reprompt), isTrue);

    await say('salamat');
    expect(active(), isTrue);
    // The silence count starts over: a new reminder comes before any end.
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(active(), isTrue);
    expect(endsWithLine(_reprompt), isTrue);
    expect(countLine(_reprompt), 2);
  });

  test('a recognizer error is retried, not treated as the end', () async {
    await setUpWith();
    await startPercy();
    final before = env.speech.sessions.length;

    env.speech.fail('error_client');
    await Future<void>.delayed(_settle + const Duration(milliseconds: 200));
    expect(active(), isTrue);
    expect(env.speech.sessions.length, greaterThan(before));
    expect(env.speech.listening, isTrue);

    // The retried session hears the user.
    final mark = env.tts.spoken.length;
    await say('sino ka');
    expect(active(), isTrue);
    expect(spokenSince(mark), contains('Percy'));
  });

  test('"paalam" ends the session with a goodbye', () async {
    await setUpWith();
    await startPercy();
    await say('paalam na percy');
    expect(active(), isFalse);
    expect(env.tts.transcript, isNot(matches(_endedLine)));
  });

  test('long-press and single tap keep the session; a swipe ends it '
      'with a goodbye', () async {
    await setUpWith();
    await startPercy();
    final greeting = env.tts.transcript;
    final bus = container.read(commandBusProvider);

    await bus.dispatch(NavIntent.listen); // long-press: "listen now"
    expect(active(), isTrue);

    final mark = env.tts.spoken.length;
    await bus.dispatch(NavIntent.repeat); // single tap: repeat Percy
    expect(active(), isTrue);
    expect(spokenSince(mark), contains('Percy'));
    expect(greeting, endsWith(spokenSince(mark)));

    await bus.dispatch(NavIntent.stopSpeech); // two-finger double tap
    expect(active(), isTrue);

    await bus.dispatch(NavIntent.next); // the user's own swipe
    expect(active(), isFalse);
    expect(endsWithLine('Sige po, paalam! Tawagin lang po ako ulit.'), isTrue);
    expect(env.tts.transcript, isNot(matches(_endedLine)));
  });

  test('a reading command heard during the session does not end it', () async {
    await setUpWith();
    await startPercy();
    await percy().runReadingCommand(NavIntent.pause);
    expect(active(), isTrue);
    await percy().runReadingCommand(NavIntent.assistant);
    expect(active(), isTrue);
  });

  test('ElevenLabs and the analysis panel stay off in a normal build, even '
      'if saved on', () async {
    const saved = AppSettings(percyElevenLabs: true, percyAnalysis: true);
    final normal = ProviderContainer(
      overrides: [initialSettingsProvider.overrideWithValue(saved)],
    );
    addTearDown(normal.dispose);
    expect(normal.read(devBuildProvider), isFalse);
    expect(normal.read(elevenLabsActiveProvider), isFalse);
    expect(normal.read(percyAnalysisOnProvider), isFalse);
    final dev = ProviderContainer(
      overrides: [
        initialSettingsProvider.overrideWithValue(saved),
        devBuildProvider.overrideWithValue(true),
      ],
    );
    addTearDown(dev.dispose);
    expect(dev.read(elevenLabsActiveProvider), isTrue);
    expect(dev.read(percyAnalysisOnProvider), isTrue);
    expect(const AppSettings().percyAnalysis, isFalse);
    expect(
      AppSettings.fromPrefs(saved.toPrefs()),
      saved,
      reason: 'the analysis switch is saved',
    );
  });

  group('analysis panel data', () {
    test('records transcript, language, intent, confidence, top 3 and the '
        'action, newest first', () async {
      await setUpWith(analysis: true);
      await startPercy();
      await say('sino ka');
      await say('salamat');

      final entries = container.read(percyAnalysisProvider);
      expect(entries, hasLength(2));
      final last = entries.first;
      expect(last.heard, 'salamat');
      expect(last.intent, 'thanks');
      expect(last.confidence, isNotNull);
      expect(last.top, hasLength(3));
      expect(last.top.first.label, 'thanks');
      expect(last.top.first.probability, last.confidence);
      expect(last.action, 'chat');
      expect(last.language.language, DocLanguage.filipino);

      expect(entries[1].heard, 'sino ka');
      expect(entries[1].intent, 'greeting');
    });

    test('nothing is recorded while the setting is off', () async {
      await setUpWith();
      await startPercy();
      await say('salamat');
      expect(container.read(percyAnalysisProvider), isEmpty);
    });

    test(
      'an exact command is shown as such, with the classifier\'s view',
      () async {
        await setUpWith(analysis: true);
        await startPercy();
        await say('susunod');
        final entry = container.read(percyAnalysisProvider).single;
        expect(entry.action, startsWith('exact:'));
        expect(entry.intent, isNull);
        expect(entry.top, hasLength(3));
      },
    );
  });
}
