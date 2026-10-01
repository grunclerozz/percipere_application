import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/app/locale_provider.dart';
import 'package:percipere_app/core/accessibility/announcer.dart';
import 'package:percipere_app/core/tts/speech_language.dart';
import 'package:percipere_app/core/tts/tts_service.dart';

import '../../helpers/fakes.dart';

void main() {
  late TestEnv env;
  late ProviderContainer container;
  Announcer announcer() => container.read(announcerProvider.notifier);

  Future<void> setUpWith(FakeTts tts) async {
    env = await TestEnv.create(tts: tts);
    container = ProviderContainer(overrides: env.overrides);
    addTearDown(container.dispose);
    container.listen(announcerProvider, (_, _) {});
  }

  test('splits text into sentences, keeping punctuation', () {
    expect(Announcer.splitSentences('Isa. Dalawa?  Tatlo! Apat… lima'), [
      'Isa.',
      'Dalawa?',
      'Tatlo!',
      'Apat…',
      'lima',
    ]);
    expect(Announcer.splitSentences('   '), isEmpty);
  });

  test('speaks sentence by sentence and publishes each as subtitle', () async {
    await setUpWith(FakeTts(autoComplete: false));
    final done = announcer().say('Una. Ikalawa.', screenId: 'capture');
    await pumpEventQueue();

    expect(env.tts.spoken, ['Una.']);
    var state = container.read(announcerProvider);
    expect(state.text, 'Una.');
    expect(state.screenId, 'capture');
    expect(state.speaking, isTrue);

    env.tts.finishCurrent();
    await pumpEventQueue();
    expect(container.read(announcerProvider).text, 'Ikalawa.');

    env.tts.finishCurrent();
    await done;
    await pumpEventQueue();
    state = container.read(announcerProvider);
    expect(state.speaking, isFalse);
    expect(state.text, 'Ikalawa.', reason: 'last line stays visible');
  });

  test('interrupting drops the queue and stops the current sentence', () async {
    await setUpWith(FakeTts(autoComplete: false));
    final first = announcer().say('A. B. C.');
    await pumpEventQueue();
    final second = announcer().say('Bago.');
    await pumpEventQueue();

    await first; // completes even though B and C were dropped
    expect(env.tts.stopCalls, 1);
    expect(env.tts.spoken, ['A.', 'Bago.']);
    env.tts.finishCurrent();
    await second;
  });

  test('protected sentences finish before the next text starts', () async {
    await setUpWith(FakeTts(autoComplete: false));
    announcer().say('Napili.', protect: true).ignore();
    await pumpEventQueue();
    announcer().say('Susunod na screen.').ignore();
    await pumpEventQueue();

    expect(env.tts.stopCalls, 0);
    expect(env.tts.spoken, ['Napili.']);
    env.tts.finishCurrent();
    await pumpEventQueue();
    expect(env.tts.spoken, ['Napili.', 'Susunod na screen.']);
    env.tts.finishCurrent();
  });

  test('queued text (interrupt: false) waits its turn', () async {
    await setUpWith(FakeTts());
    announcer().say('Una.').ignore();
    await announcer().say('Pangalawa.', interrupt: false);
    expect(env.tts.spoken, ['Una.', 'Pangalawa.']);
  });

  test('stop() silences even protected speech', () async {
    await setUpWith(FakeTts(autoComplete: false));
    final said = announcer().say('Napili. Iba pa.', protect: true);
    await pumpEventQueue();
    await announcer().stop();
    await said;
    expect(env.tts.spoken, ['Napili.']);
    expect(container.read(announcerProvider).speaking, isFalse);
  });

  group('speech language', () {
    test('Filipino UI speaks with the Filipino voice when installed', () async {
      await setUpWith(FakeTts());
      await announcer().say('Kumusta.');
      expect(env.tts.tags.single, 'fil-PH');
    });

    test('falls back to English prompts without a Filipino voice', () async {
      await setUpWith(FakeTts(voices: const VoiceStatus(filipinoReady: false)));
      final lang = container.read(speechLanguageProvider);
      expect(lang.locale, AppLocales.english);
      expect(lang.ttsTag, 'en-US');
      expect(lang.strings.commandNotAvailable, contains("isn't available"));
    });
  });
}
