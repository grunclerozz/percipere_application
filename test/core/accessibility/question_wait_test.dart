// A question stops the speech: the app waits for the answer before giving
// the instructions that follow it (user request, 2026-10-07).

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/config/voice_config.dart';
import 'package:percipere_app/core/accessibility/action_registry.dart';
import 'package:percipere_app/core/accessibility/announcer.dart';
import 'package:percipere_app/core/accessibility/command_bus.dart';
import 'package:percipere_app/core/accessibility/focus_controller.dart';
import 'package:percipere_app/core/accessibility/navigation_mode.dart';
import 'package:percipere_app/core/accessibility/screen_registration.dart';
import 'package:percipere_app/core/gestures/gesture_map.dart';

import '../../helpers/fakes.dart';

const _hint = 'Mag-swipe pakanan o pakaliwa';

void main() {
  late TestEnv env;
  late ProviderContainer container;

  ScreenRegistration menu() => ScreenRegistration(
    id: 'capture',
    title: (l) => l.screenCapture,
    prompt: (l) => l.capturePrompt,
    actions: [
      A11yAction(id: 'a', label: (l) => l.captureUpload, onActivate: (_) {}),
      A11yAction(id: 'b', label: (l) => l.captureCamera, onActivate: (_) {}),
    ],
  );

  ScreenRegistration status() => ScreenRegistration(
    id: 'status',
    prompt: (_) => 'Handa na ang dokumento. I-double tap para basahin.',
  );

  /// Creates the environment (real async), then runs [body] in fake time.
  Future<void> run(void Function(FakeAsync async) body) async {
    env = await TestEnv.create(mode: NavMode.gestures);
    container = ProviderContainer(overrides: env.overrides);
    addTearDown(container.dispose);
    container
      ..listen(announcerProvider, (_, _) {})
      ..listen(focusControllerProvider, (_, _) {});
    fakeAsync(body);
  }

  CommandBus bus() => container.read(commandBusProvider);
  Announcer announcer() => container.read(announcerProvider.notifier);

  void register(ScreenRegistration r) =>
      container.read(actionRegistryProvider.notifier).register(r);

  test('splitAtQuestion cuts after the last question', () {
    expect(
      Announcer.splitAtQuestion('Ayos na ba ang lahat? I-double tap. Iba pa.'),
      ('Ayos na ba ang lahat?', 'I-double tap. Iba pa.'),
    );
    expect(Announcer.splitAtQuestion('Walang tanong.'), (
      'Walang tanong.',
      null,
    ));
    expect(Announcer.splitAtQuestion('Una. Ano ito?'), ('Una. Ano ito?', null));
    expect(
      Announcer.splitAtQuestion('Ang ibig mo bang sabihin ay “camera”? Oo.'),
      ('Ang ibig mo bang sabihin ay “camera”?', 'Oo.'),
    );
  });

  test('entry: question and options first, the mode hint only after '
      'the answer wait', () async {
    await run((async) {
      final screen = menu();
      register(screen);
      bus().announceScreen(screen);
      async.flushMicrotasks();
      expect(env.tts.transcript, contains('Mga pagpipilian: Mag-upload'));
      expect(env.tts.transcript, isNot(contains(_hint)));
      expect(announcer().awaitingAnswer, isTrue);

      async.elapse(VoiceConfig.answerWait - const Duration(milliseconds: 100));
      expect(env.tts.transcript, isNot(contains(_hint)));
      async.elapse(const Duration(milliseconds: 200));
      expect(env.tts.transcript, contains(_hint));
      expect(announcer().awaitingAnswer, isFalse);
    });
  });

  test('an answer drops the instructions', () async {
    await run((async) {
      final screen = menu();
      register(screen);
      bus().announceScreen(screen);
      async.flushMicrotasks();
      bus().onGesture(GestureType.swipeRight);
      async.elapse(VoiceConfig.answerWait * 2);
      expect(env.tts.transcript, isNot(contains(_hint)));
    });
  });

  test('speaking restarts the wait', () async {
    await run((async) {
      final screen = menu();
      register(screen);
      bus().announceScreen(screen);
      async.flushMicrotasks();
      async.elapse(VoiceConfig.answerWait - const Duration(seconds: 1));
      announcer().userResponding();
      async.elapse(const Duration(seconds: 2));
      expect(env.tts.transcript, isNot(contains(_hint)));
      async.elapse(VoiceConfig.answerWait);
      expect(env.tts.transcript, contains(_hint));
    });
  });

  test('queued notices wait for the answer too', () async {
    await run((async) {
      final screen = menu();
      register(screen);
      bus().announceScreen(screen);
      async.flushMicrotasks();
      announcer().say('Bagong paliwanag.', interrupt: false);
      async.flushMicrotasks();
      expect(env.tts.transcript, isNot(contains('Bagong paliwanag')));
      async.elapse(VoiceConfig.answerWait + const Duration(milliseconds: 100));
      expect(
        env.tts.transcript,
        allOf(contains(_hint), contains('Bagong paliwanag')),
      );
      expect(
        env.tts.transcript.indexOf(_hint),
        lessThan(env.tts.transcript.indexOf('Bagong paliwanag')),
      );
    });
  });

  test('offer: how to answer comes only after the wait', () async {
    await run((async) {
      register(menu());
      var accepted = 0;
      bus().offer('Buksan ang Settings?', () => accepted++);
      async.flushMicrotasks();
      expect(env.tts.transcript, contains('Buksan ang Settings?'));
      expect(env.tts.transcript, isNot(contains('I-double tap')));
      async.elapse(VoiceConfig.answerWait + const Duration(milliseconds: 100));
      expect(env.tts.transcript, contains('I-double tap'));
      // Still answerable after the instructions.
      bus().onGesture(GestureType.doubleTap);
      async.flushMicrotasks();
      expect(accepted, 1);
    });
  });

  test('context after the question mark is part of the question', () async {
    await run((async) {
      register(menu());
      bus().offer('Burahin ang koleksyon? Hindi mabubura ang laman.', () {});
      async.flushMicrotasks();
      expect(
        env.tts.transcript,
        contains('Burahin ang koleksyon? Hindi mabubura ang laman.'),
      );
      expect(env.tts.transcript, isNot(contains('I-double tap')));
    });
  });

  test("a screen's follow-up (how to answer) waits for the answer", () async {
    await run((async) {
      final screen = ScreenRegistration(
        id: 'step',
        prompt: (_) => 'Mas mabilis ba? Bilis: 1.0.',
        followUp: (_) => 'Mag-swipe pataas para bumilis.',
        includeModeHint: false,
        listOptions: false,
      );
      register(screen);
      bus().announceScreen(screen);
      async.flushMicrotasks();
      expect(env.tts.transcript, contains('Mas mabilis ba? Bilis: 1.0.'));
      expect(env.tts.transcript, isNot(contains('Mag-swipe pataas')));
      async.elapse(VoiceConfig.answerWait + const Duration(milliseconds: 100));
      expect(env.tts.transcript, contains('Mag-swipe pataas para bumilis.'));
    });
  });

  test('a screen without a question is said in one go', () async {
    await run((async) {
      final screen = status();
      register(screen);
      bus().announceScreen(screen);
      async.flushMicrotasks();
      expect(env.tts.transcript, contains('I-double tap para basahin'));
      expect(announcer().awaitingAnswer, isFalse);
    });
  });
}
