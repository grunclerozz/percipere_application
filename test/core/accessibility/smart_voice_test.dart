// Smarter voice (2026-10-07): everyday phrasing, questions answered from
// the app's state, suggestions instead of a fixed list, and announcements
// that get shorter as a screen becomes familiar.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/config/voice_config.dart';
import 'package:percipere_app/core/accessibility/action_registry.dart';
import 'package:percipere_app/core/accessibility/announcer.dart';
import 'package:percipere_app/core/accessibility/command_bus.dart';
import 'package:percipere_app/core/accessibility/familiarity.dart';
import 'package:percipere_app/core/accessibility/focus_controller.dart';
import 'package:percipere_app/core/accessibility/navigation_mode.dart';
import 'package:percipere_app/core/accessibility/screen_registration.dart';
import 'package:percipere_app/core/settings/app_settings.dart';

import '../../helpers/fakes.dart';

const _gestureHint = 'Mag-swipe pakanan o pakaliwa para lumipat';

void main() {
  late TestEnv env;
  late ProviderContainer container;
  late List<String> activated;

  CommandBus bus() => container.read(commandBusProvider);

  ScreenRegistration menu() => ScreenRegistration(
    id: 'capture',
    title: (l) => l.screenCapture,
    prompt: (l) => l.capturePrompt,
    whereAmI: (_) => 'Dagdag na detalye.',
    actions: [
      A11yAction(
        id: 'upload',
        label: (l) => l.captureUpload,
        voiceSynonyms: const ['mag-upload', 'upload'],
        onActivate: (_) => activated.add('upload'),
      ),
      A11yAction(
        id: 'camera',
        label: (l) => l.captureCamera,
        voiceSynonyms: const ['camera', 'kamera'],
        onActivate: (_) => activated.add('camera'),
      ),
    ],
  );

  Future<void> setUpWith({AppSettings? settings}) async {
    activated = [];
    env = await TestEnv.create(mode: NavMode.gestures, appSettings: settings);
    container = ProviderContainer(overrides: env.overrides);
    addTearDown(container.dispose);
    container
      ..listen(announcerProvider, (_, _) {})
      ..listen(focusControllerProvider, (_, _) {})
      ..listen(familiarityProvider, (_, _) {});
    container.read(actionRegistryProvider.notifier).register(menu());
    await pumpEventQueue();
  }

  group('everyday phrasing', () {
    test('polite Tagalog runs the command', () async {
      await setUpWith();
      await bus().handleUtterance('pwede bang mag-upload po');
      expect(activated, ['upload']);
    });

    test('"paki-" forms run the command', () async {
      await setUpWith();
      await bus().handleUtterance('pakiulit nga');
      expect(env.tts.transcript, contains('Paano mo gustong i-capture'));
    });

    test('English with filler runs the command', () async {
      await setUpWith();
      await bus().handleUtterance('can you open the camera please');
      expect(activated, ['camera'], reason: env.tts.transcript);
    });
  });

  group('questions', () {
    test(
      '"nasaan ako?" names the screen, the focus and screen details',
      () async {
        await setUpWith();
        container.read(focusControllerProvider.notifier).focus('camera');
        await bus().handleUtterance('nasaan ako');
        expect(
          env.tts.transcript,
          contains(
            'Nasa Pagkuha ng dokumento ka. Naka-focus: Gamit ang Camera. '
            'Dagdag na detalye.',
          ),
        );
      },
    );

    test('"ano ang pwede kong gawin?" lists this screen\'s commands', () async {
      await setUpWith();
      await bus().handleUtterance('ano ang pwede kong gawin');
      expect(
        env.tts.transcript,
        allOf(
          contains('Dito, pwede mong sabihin: Mag-upload, Gamit ang Camera'),
          contains('nasaan ako?'),
        ),
      );
    });

    test('"anong oras na?" says the time', () async {
      await setUpWith();
      await bus().handleUtterance('anong oras na po');
      expect(env.tts.transcript, endsWith('na ngayon.'));
    });

    test('"anong petsa?" says the date', () async {
      await setUpWith();
      await bus().handleUtterance('anong petsa ngayon');
      expect(env.tts.transcript, startsWith('Ngayon ay'));
      expect(env.tts.transcript, contains('${DateTime.now().year}'));
    });

    test('a document question outside the Reader explains', () async {
      await setUpWith();
      await bus().handleUtterance('magkano ang total');
      expect(
        env.tts.transcript,
        'Magbukas muna ng dokumento, saka mo ito itanong.',
      );
    });
  });

  group('not understood', () {
    test('suggests the closest commands, not the whole list', () async {
      await setUpWith();
      await bus().handleUtterance('cam');
      expect(env.tts.transcript, contains('Baka ang ibig mo ay:'));
      expect(env.tts.transcript, contains('Gamit ang Camera'));
    });

    test('after a few misses in a row, offers the tutorial', () async {
      await setUpWith();
      for (var i = 0; i < VoiceConfig.missesBeforeHelp; i++) {
        await bus().handleUtterance('saging at mangga');
      }
      expect(env.tts.spoken.last, contains('paano gamitin'));
      // Understood again: the count starts over.
      await bus().handleUtterance('mag-upload');
      await bus().handleUtterance('saging at mangga');
      expect(env.tts.spoken.last, isNot(contains('paano gamitin')));
    });
  });

  group('Awtomatiko announcements', () {
    test('full until familiar, then without the navigation hint', () async {
      await setUpWith();
      final screen = menu();
      expect(bus().entryAnnouncement(screen), contains(_gestureHint));
      for (var i = 0; i < VoiceConfig.familiarAfter; i++) {
        bus().noteVisit(screen.id);
      }
      expect(bus().entryAnnouncement(screen), isNot(contains(_gestureHint)));
      expect(
        bus().entryAnnouncement(screen),
        contains('Mga pagpipilian: Mag-upload o Gamit ang Camera.'),
        reason: 'the options always stay',
      );
      expect(
        bus().entryParts(screen, full: true).then,
        contains(_gestureHint),
        reason: '"ulitin" gives the full version',
      );
    });

    test('a stuck user gets the help again', () async {
      await setUpWith();
      final screen = menu();
      for (var i = 0; i < VoiceConfig.familiarAfter; i++) {
        bus().noteVisit(screen.id);
      }
      await bus().handleUtterance('saging');
      await bus().handleUtterance('mangga');
      expect(bus().struggling, isTrue);
      final text = bus().entryAnnouncement(screen);
      expect(text, contains(_gestureHint));
      expect(text, contains('I-double tap'), reason: 'screen help added');
    });

    test('visits are remembered per user', () async {
      await setUpWith();
      bus().noteVisit('capture');
      bus().noteVisit('capture');
      await pumpEventQueue();
      final c2 = ProviderContainer(overrides: env.overrides);
      addTearDown(c2.dispose);
      c2.listen(familiarityProvider, (_, _) {});
      await pumpEventQueue(times: 50);
      expect(c2.read(familiarityProvider.notifier).visits('capture'), 2);
    });

    test('"Karaniwan" never shortens', () async {
      await setUpWith(settings: const AppSettings(verbosity: Verbosity.normal));
      final screen = menu();
      for (var i = 0; i < 10; i++) {
        bus().noteVisit(screen.id);
      }
      expect(bus().entryAnnouncement(screen), contains(_gestureHint));
    });
  });
}
