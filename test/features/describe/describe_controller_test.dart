import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/accessibility/announcer.dart';
import 'package:percipere_app/core/accessibility/command_bus.dart';
import 'package:percipere_app/core/accessibility/navigation_mode.dart';
import 'package:percipere_app/core/auth/session.dart';
import 'package:percipere_app/core/db/daos/library_dao.dart';
import 'package:percipere_app/core/db/daos/preferences_dao.dart';
import 'package:percipere_app/core/describe/image_labeler.dart';
import 'package:percipere_app/core/library/library_models.dart';
import 'package:percipere_app/core/ocr/ocr_service.dart';
import 'package:percipere_app/core/settings/app_settings.dart';
import 'package:percipere_app/core/settings/settings_controller.dart';
import 'package:percipere_app/core/voice/voice_controller.dart';
import 'package:percipere_app/features/describe/describe_controller.dart';

import '../../helpers/fakes.dart';

const _subject = NewImage('picture.jpg');

const _offlineSentence =
    'May pagkain at plato sa larawan. Mukhang may mesa din.';

void main() {
  late TestEnv env;
  late ProviderContainer container;
  final provider = describeControllerProvider(_subject);
  DescribeController controller() => container.read(provider.notifier);
  DescribeState state() => container.read(provider);
  CommandBus bus() => container.read(commandBusProvider);

  Future<void> setUpWith({
    bool online = true,
    bool serverVision = false,
    bool serverFails = false,
    AppSettings? settings,
    bool guest = false,
  }) async {
    env =
        await TestEnv.create(
            tts: FakeTts(),
            mode: NavMode.gestures,
            appSettings: settings,
          )
          ..online = online
          ..vision.enabled = online && serverVision
          ..describeRepo.fail = serverFails;
    container = ProviderContainer(overrides: env.overrides);
    addTearDown(container.dispose);
    container
      ..listen(announcerProvider, (_, _) {})
      ..listen(voiceControllerProvider, (_, _) {})
      ..listen(provider, (_, _) {});
    if (guest) {
      await container
          .read(currentAccountProvider.notifier)
          .startGuest('Bisita');
    }
    await pumpEventQueue(); // analysis runs and speaks
  }

  group('offline description', () {
    test('speaks the Filipino labels, labelled offline', () async {
      await setUpWith();
      expect(state().phase, DescribePhase.ready);
      expect(state().description, _offlineSentence);
      expect(state().online, isFalse);
      expect(env.labeler.labeled, ['picture.jpg']);
      expect(env.tts.transcript, contains('(offline) $_offlineSentence'));
      expect(env.tts.transcript, isNot(contains('Payagan?')));
    });

    test('asks for consent BEFORE the first description', () async {
      await setUpWith(serverVision: true);
      expect(state().phase, DescribePhase.working);
      expect(env.tts.transcript, contains('ipapadala ang larawan sa Google'));
      expect(env.labeler.labeled, isEmpty);
      expect(env.describeRepo.languages, isEmpty, reason: 'not before consent');

      await bus().handleUtterance('hindi');
      await pumpEventQueue();
      expect(state().phase, DescribePhase.ready);
      expect(state().online, isFalse);
      expect(state().description, _offlineSentence);
    });

    test('offline: no error message, no question', () async {
      await setUpWith(online: false);
      expect(env.tts.transcript, contains(_offlineSentence));
      expect(env.tts.transcript, isNot(contains('Kailangan ng internet')));
      expect(env.tts.transcript, isNot(contains('Payagan?')));
      expect(env.describeRepo.languages, isEmpty);
    });

    test('server without vision: no question either', () async {
      await setUpWith(serverVision: false);
      expect(env.tts.transcript, contains(_offlineSentence));
      expect(env.tts.transcript, isNot(contains('Payagan?')));
    });

    test('nothing confident enough: asks to try again', () async {
      env = await TestEnv.create(tts: FakeTts(), mode: NavMode.gestures);
      env.labeler.results = const [LabelResult('Cup', 0.4)];
      container = ProviderContainer(overrides: env.overrides);
      addTearDown(container.dispose);
      container
        ..listen(announcerProvider, (_, _) {})
        ..listen(voiceControllerProvider, (_, _) {})
        ..listen(provider, (_, _) {});
      await pumpEventQueue();
      expect(env.tts.transcript, contains('Hindi ko matiyak'));
    });

    test('an unreadable picture is reported', () async {
      env = await TestEnv.create(tts: FakeTts(), mode: NavMode.gestures);
      env.labeler.fail = true;
      container = ProviderContainer(overrides: env.overrides);
      addTearDown(container.dispose);
      container
        ..listen(announcerProvider, (_, _) {})
        ..listen(voiceControllerProvider, (_, _) {})
        ..listen(provider, (_, _) {});
      await pumpEventQueue();
      expect(state().phase, DescribePhase.failed);
      expect(env.tts.transcript, contains('Hindi ko mabasa ang larawang ito'));
    });
  });

  group('text check', () {
    Future<void> withText() async {
      env = await TestEnv.create(tts: FakeTts(), mode: NavMode.gestures);
      env.ocr.page = const OcrPage(
        text:
            'Ang pagbabasa ay karapatan ng lahat. Sa tulong ng Percipere, '
            'maaaring pakinggan ang mga liham.',
      );
      container = ProviderContainer(overrides: env.overrides);
      addTearDown(container.dispose);
      container
        ..listen(announcerProvider, (_, _) {})
        ..listen(voiceControllerProvider, (_, _) {})
        ..listen(provider, (_, _) {});
      await pumpEventQueue();
    }

    test('readable text is offered before the detailed description', () async {
      await withText();
      expect(state().foundText, startsWith('Ang pagbabasa'));
      expect(env.tts.transcript, contains('May nakita rin akong teksto.'));
      expect(env.tts.transcript, isNot(contains('mas detalyadong')));
    });

    test('declining the text offers nothing more', () async {
      await withText();
      await bus().handleUtterance('hindi');
      await pumpEventQueue();
      expect(env.tts.transcript, isNot(contains('Payagan?')));
    });

    test('no text found: nothing is offered', () async {
      await setUpWith();
      expect(state().foundText, isNull);
      expect(env.tts.transcript, isNot(contains('May nakita rin akong')));
    });

    test('noise is not text', () async {
      env = await TestEnv.create(tts: FakeTts(), mode: NavMode.gestures);
      env.ocr.page = const OcrPage(text: '| ~ ;; 1 1 .. ^ ^');
      container = ProviderContainer(overrides: env.overrides);
      addTearDown(container.dispose);
      container
        ..listen(announcerProvider, (_, _) {})
        ..listen(voiceControllerProvider, (_, _) {})
        ..listen(provider, (_, _) {});
      await pumpEventQueue();
      expect(state().foundText, isNull);
    });
  });

  group('online description and consent', () {
    test('yes to the consent question: the first description is online', () async {
      await setUpWith(serverVision: true);
      expect(env.describeRepo.languages, isEmpty, reason: 'not before consent');

      await bus().handleUtterance('oo'); // yes to the consent question
      await pumpEventQueue();

      expect(env.describeRepo.languages, ['fil']);
      expect(env.describeRepo.details, [false]);
      expect(env.imagePrep.uploads, 1);
      expect(env.labeler.labeled, isEmpty);
      expect(state().online, isTrue);
      expect(state().description, startsWith('Mukhang isang mesa'));
      expect(
        env.tts.transcript,
        contains('(online) Mukhang isang mesa na may pagkain.'),
      );
      expect(
        container.read(settingsProvider).describeConsent,
        DescribeConsent.allowed,
      );
      final saved = await PreferencesDao(env.database.db)
          .getAll(userId: env.account!.id);
      expect(saved[PrefKeys.describeConsent], 'allowed');
    });

    test('saying no sends nothing and is remembered', () async {
      await setUpWith(serverVision: true);
      await bus().handleUtterance('hindi'); // no to the consent question
      await pumpEventQueue();

      expect(env.describeRepo.languages, isEmpty);
      expect(env.imagePrep.uploads, 0);
      expect(state().description, _offlineSentence);
      expect(env.tts.transcript, contains('hindi ko ipapadala ang larawan'));
      expect(
        container.read(settingsProvider).describeConsent,
        DescribeConsent.declined,
      );

      // Asking again explains where to change it; still nothing is sent.
      env.tts.spoken.clear();
      await controller().requestDetail();
      expect(env.tts.transcript, contains('hindi ko ipapadala ang larawan'));
      expect(env.describeRepo.languages, isEmpty);
    });

    test('with consent already given, the first description is online', () async {
      await setUpWith(
        serverVision: true,
        settings: const AppSettings(describeConsent: DescribeConsent.allowed),
      );
      expect(env.tts.transcript, isNot(contains('Payagan?')));
      expect(env.describeRepo.languages, ['fil']);
      expect(state().online, isTrue);
      expect(env.labeler.labeled, isEmpty, reason: 'ML Kit not needed');
      // "Mas detalyado" asks for the longer answer and adds it.
      await controller().requestDetail();
      expect(env.describeRepo.details, [false, true]);
      expect(state().detailed, startsWith('Mukhang isang mesa'));
    });

    test('the server failing falls back to ML Kit without a message', () async {
      await setUpWith(
        serverVision: true,
        serverFails: true,
        settings: const AppSettings(describeConsent: DescribeConsent.allowed),
      );
      expect(state().online, isFalse);
      expect(state().description, _offlineSentence);
      expect(env.tts.transcript, contains('(offline) $_offlineSentence'));
      expect(env.tts.transcript, isNot(contains('Hindi ko makuha')));
    });

    test('asking for detail while offline says it needs internet', () async {
      await setUpWith(online: false);
      env.tts.spoken.clear();
      await controller().requestDetail();
      expect(env.tts.transcript, contains('Kailangan ng internet'));
      expect(env.describeRepo.languages, isEmpty);
    });

    test('a failing detail request is reported, the text stays', () async {
      await setUpWith(
        serverVision: true,
        serverFails: true,
        settings: const AppSettings(describeConsent: DescribeConsent.allowed),
      );
      await controller().requestDetail();
      expect(env.tts.transcript, contains('Hindi ko makuha ang detalyadong'));
      expect(state().detailed, isNull);
      expect(state().description, _offlineSentence);
    });
  });

  group('saving to the Library', () {
    Future<List<LibraryItem>> history() =>
        LibraryDao(env.database.db).list(env.account!.id);

    Future<String> textOf(LibraryItem item) async =>
        (await LibraryDao(env.database.db).loadText(item)).single.text;

    test('saves once as a "description" with its thumbnail', () async {
      await setUpWith();
      await controller().save();
      await controller().save(); // again: no duplicate

      final docs = await history();
      expect(docs, hasLength(1));
      expect(docs.single.source, LibrarySource.description);
      expect(docs.single.coverPath, 'thumbs/thumb_1.jpg');
      expect(await textOf(docs.single), _offlineSentence);
      expect(env.imagePrep.thumbnails, 1);
      expect(env.tts.transcript, contains('Na-save sa Aklatan.'));
    });

    test(
      'a detailed description arriving later updates the saved text',
      () async {
        await setUpWith(
          settings: const AppSettings(describeConsent: DescribeConsent.allowed),
        );
        await controller().save();
        await controller().requestDetail();
        final docs = await history();
        expect(await textOf(docs.single), contains('Mukhang isang mesa'));
      },
    );

    test('a failing thumbnail still saves the description', () async {
      await setUpWith();
      env.imagePrep.failThumbnail = true;
      await controller().save();
      final docs = await history();
      expect(docs, hasLength(1));
      expect(docs.single.coverPath, isNull);
      expect(env.tts.transcript, contains('Na-save sa Aklatan.'));
    });

    test('activating save twice at once saves once', () async {
      await setUpWith();
      await Future.wait([controller().save(), controller().save()]);
      expect(await history(), hasLength(1));
    });

    test('a saved description can be reopened from history', () async {
      await setUpWith();
      await controller().save();
      final id = (await history()).single.id;

      final reopened = describeControllerProvider(SavedDescription(id));
      container.listen(reopened, (_, _) {});
      await pumpEventQueue();
      final s = container.read(reopened);
      expect(s.phase, DescribePhase.ready);
      expect(s.description, _offlineSentence);
      expect(s.thumbnailPath, 'thumbs/thumb_1.jpg');
      expect(env.labeler.labeled, hasLength(1), reason: 'not analysed again');
    });
  });

  group('text size', () {
    test('steps of 2, limits 18-48, saved to preferences', () async {
      await setUpWith();
      await controller().changeTextSize(1);
      expect(container.read(settingsProvider).textSize, 20);
      expect(state().caption, 'Laki: 20');
      await controller().changeTextSize(-1);
      await controller().changeTextSize(-1);
      expect(container.read(settingsProvider).textSize, 18);
      expect(state().caption, 'Pinakamaliit na.');

      for (var i = 0; i < 20; i++) {
        await controller().changeTextSize(1);
      }
      expect(container.read(settingsProvider).textSize, 48);
      expect(state().caption, 'Pinakamalaki na.');
      final saved = await PreferencesDao(env.database.db)
          .getAll(userId: env.account!.id);
      expect(saved[PrefKeys.textSize], 48);
    });
  });
}
