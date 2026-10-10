import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/accessibility/action_registry.dart';
import 'package:percipere_app/core/accessibility/announcer.dart';
import 'package:percipere_app/core/accessibility/command_bus.dart';
import 'package:percipere_app/core/accessibility/focus_controller.dart';
import 'package:percipere_app/core/accessibility/nav_intent.dart';
import 'package:percipere_app/core/accessibility/navigation_mode.dart';
import 'package:percipere_app/core/accessibility/screen_registration.dart';
import 'package:percipere_app/core/gestures/gesture_map.dart';

import '../../helpers/fakes.dart';

void main() {
  late TestEnv env;
  late ProviderContainer container;
  late List<String> activated;

  CommandBus bus() => container.read(commandBusProvider);

  ScreenRegistration menu({Map<NavIntent, BusHandler> overrides = const {}}) {
    return ScreenRegistration(
      id: 'capture',
      title: (l) => l.screenCapture,
      prompt: (l) => l.capturePrompt,
      intentHandlers: overrides,
      actions: [
        A11yAction(
          id: 'a',
          label: (l) => l.captureUpload,
          onActivate: (_) => activated.add('a'),
        ),
        A11yAction(
          id: 'b',
          label: (l) => l.captureCamera,
          onActivate: (_) => activated.add('b'),
        ),
      ],
    );
  }

  Future<void> setUpWith({NavMode? mode}) async {
    activated = [];
    env = await TestEnv.create(mode: mode);
    container = ProviderContainer(overrides: env.overrides);
    addTearDown(container.dispose);
    container
      ..listen(announcerProvider, (_, _) {})
      ..listen(focusControllerProvider, (_, _) {});
  }

  void register(ScreenRegistration r) =>
      container.read(actionRegistryProvider.notifier).register(r);

  test('entry announcement: title, prompt, options, mode hint', () async {
    await setUpWith(mode: NavMode.gestures);
    final screen = menu();
    register(screen);
    expect(
      bus().entryAnnouncement(screen),
      'Pagkuha ng dokumento. '
      'Paano mo gustong i-capture ang iyong dokyumento? '
      'Mga pagpipilian: Mag-upload o Gamit ang Camera. '
      'Mag-swipe pakanan o pakaliwa para lumipat, at i-double tap para '
      'pumili.',
    );
  });

  test('voice mode ends with the voice hint', () async {
    await setUpWith(mode: NavMode.voice);
    final screen = menu();
    register(screen);
    expect(
      bus().entryAnnouncement(screen),
      endsWith('Gumagana rin ang mga galaw.'),
    );
  });

  test('swipes move focus with wrap-around and speak position', () async {
    await setUpWith();
    register(menu());

    await bus().onGesture(GestureType.swipeRight);
    expect(container.read(focusControllerProvider), 'a');
    expect(env.tts.spoken.last, 'Mag-upload, 1 sa 2.');

    await bus().onGesture(GestureType.swipeRight);
    await bus().onGesture(GestureType.swipeRight);
    expect(container.read(focusControllerProvider), 'a', reason: 'wraps');

    await bus().onGesture(GestureType.swipeLeft);
    expect(container.read(focusControllerProvider), 'b');
    expect(env.tts.spoken.last, 'Gamit ang Camera, 2 sa 2.');
    expect(env.haptics.events, everyElement('tick'));
  });

  test('double tap activates the focused action with confirmation', () async {
    await setUpWith();
    register(menu());
    await bus().onGesture(GestureType.swipeRight);
    await bus().onGesture(GestureType.doubleTap);
    await pumpEventQueue();

    expect(activated, ['a']);
    expect(env.haptics.events.last, 'confirm');
    expect(env.tts.spoken.last, 'Mag-upload');
  });

  test('double tap with nothing focused explains, with error haptic', () async {
    await setUpWith();
    register(menu());
    await bus().onGesture(GestureType.doubleTap);
    expect(activated, isEmpty);
    expect(env.haptics.events, ['error']);
    expect(env.tts.transcript, startsWith('Wala pang napili.'));
  });

  test('unsupported intents give an error', () async {
    await setUpWith();
    register(menu());
    await bus().onGesture(GestureType.swipeUp);
    expect(env.haptics.events, ['error']);
    expect(env.tts.spoken.single, 'Hindi magagamit ang utos na iyan dito.');
  });

  test('screen overrides win over defaults', () async {
    await setUpWith();
    register(menu(overrides: {NavIntent.repeat: (b) => b.activate('b')}));
    await bus().onGesture(GestureType.singleTap);
    expect(activated, ['b']);
  });

  test('tap repeats the entry announcement', () async {
    await setUpWith();
    register(menu());
    await bus().onGesture(GestureType.singleTap);
    expect(env.tts.spoken.first, 'Pagkuha ng dokumento.');
  });

  test('three-finger tap speaks help for the screen', () async {
    await setUpWith();
    register(menu());
    await bus().onGesture(GestureType.threeFingerTap);
    expect(env.tts.spoken.first, 'Tulong para sa Pagkuha ng dokumento.');
  });

  test('focus resets when another screen becomes active', () async {
    await setUpWith();
    register(menu());
    await bus().onGesture(GestureType.swipeRight);
    register(const ScreenRegistration(id: 'reader', prompt: _prompt));
    expect(container.read(focusControllerProvider), isNull);
  });

  group('voice commands', () {
    test('screen actions match their label, in either language', () async {
      await setUpWith();
      register(menu());
      await bus().handleUtterance('mag-upload');
      await bus().handleUtterance('use the camera');
      expect(activated, ['a', 'b']);
    });

    test('app-wide commands dispatch intents', () async {
      await setUpWith();
      register(menu());
      await bus().handleUtterance('susunod');
      expect(container.read(focusControllerProvider), 'a');
      await bus().handleUtterance('piliin');
      expect(activated, ['a']);
    });

    test('unclear: asks back, "oo" runs it', () async {
      await setUpWith();
      register(menu());
      await bus().handleUtterance('susonud po ba');
      expect(env.tts.spoken.first, 'Ang ibig mo bang sabihin ay “susunod”?');
      await bus().handleUtterance('oo');
      expect(container.read(focusControllerProvider), 'a');
    });

    test('unclear: "hindi" cancels', () async {
      await setUpWith();
      register(menu());
      await bus().handleUtterance('susonud po ba');
      env.tts.spoken.clear();
      await bus().handleUtterance('hindi');
      expect(env.tts.spoken.single, 'Sige.');
      expect(container.read(focusControllerProvider), isNull);
    });

    test('unknown with nothing close: says how to hear the commands', () async {
      await setUpWith();
      register(menu());
      await bus().handleUtterance('saging at mangga');
      expect(env.haptics.events, ['error']);
      expect(
        env.tts.transcript,
        'Hindi kita naintindihan. Sabihin ang “ano ang pwede kong gawin” '
        'para marinig ang mga utos.',
      );
    });

    test('wake word alone replies; as a prefix it is ignored', () async {
      await setUpWith();
      register(menu());
      await bus().handleUtterance('Percipere');
      expect(env.tts.spoken.single, 'Nakikinig ako.');
      await bus().handleUtterance('Percipere, susunod');
      expect(container.read(focusControllerProvider), 'a');
    });

    test('not-yet-built screens say so', () async {
      await setUpWith();
      register(menu());
      await bus().handleUtterance('ulat');
      expect(
        env.tts.spoken.single,
        'Wala pa ang bahaging iyan sa bersyong ito.',
      );
    });

    test('an offer is accepted by double-tap', () async {
      await setUpWith();
      register(menu());
      var accepted = 0;
      await bus().offer('Buksan?', () => accepted++);
      // Speech stops after the question: how to answer waits for silence.
      expect(env.tts.transcript, isNot(contains('I-double tap')));
      await bus().onGesture(GestureType.doubleTap);
      expect(accepted, 1);
      expect(activated, isEmpty, reason: 'the offer took the double-tap');
    });

    test('"pa-galaw" switches mode and saves it', () async {
      await setUpWith(mode: NavMode.voice);
      register(menu());
      await bus().handleUtterance('pa-galaw');
      expect(container.read(navigationModeProvider), NavMode.gestures);
      expect(env.tts.transcript, contains('Napili mo ang pa-galaw.'));
    });
  });
}

String _prompt(Object _) => 'x';
