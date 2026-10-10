import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/app/locale_provider.dart';
import 'package:percipere_app/core/accessibility/action_registry.dart';
import 'package:percipere_app/core/accessibility/announcer.dart';
import 'package:percipere_app/core/accessibility/command_bus.dart';
import 'package:percipere_app/core/accessibility/focus_controller.dart';
import 'package:percipere_app/core/accessibility/nav_intent.dart';
import 'package:percipere_app/core/accessibility/navigation_mode.dart';
import 'package:percipere_app/core/accessibility/screen_registration.dart';
import 'package:percipere_app/core/assistant/assistant_config.dart';
import 'package:percipere_app/core/assistant/assistant_controller.dart';
import 'package:percipere_app/core/assistant/assistant_platform.dart';
import 'package:percipere_app/core/assistant/assistant_tools.dart';
import 'package:percipere_app/core/assistant/reader_snapshot.dart';
import 'package:percipere_app/core/gestures/gesture_map.dart';
import 'package:percipere_app/core/platform/permissions.dart';
import 'package:percipere_app/core/settings/settings_controller.dart';
import 'package:percipere_app/core/voice/voice_controller.dart';

import '../../helpers/fakes.dart';

const _agent = AssistantConfig(agentId: 'agent_test', voiceId: 'voice_x');
const _consentQuestion = 'online na bersyon ni Percy';
const _settle = Duration(milliseconds: 600);

void main() {
  late TestEnv env;
  late ProviderContainer container;
  late List<String> activated;

  CommandBus bus() => container.read(commandBusProvider);
  AssistantController assistant() =>
      container.read(assistantControllerProvider.notifier);
  AssistantState state() => container.read(assistantControllerProvider);

  ScreenRegistration home() => ScreenRegistration(
    id: 'home',
    title: (l) => l.screenHome,
    prompt: (l) => l.homePrompt,
    actions: [
      A11yAction(
        id: 'home.new',
        label: (l) => l.homeRead,
        onActivate: (_) => activated.add('new'),
      ),
      A11yAction(
        id: 'home.library',
        label: (l) => l.homeLibrary,
        onActivate: (_) => activated.add('library'),
      ),
    ],
  );

  Future<void> setUpWith({
    AssistantConfig config = _agent,
    NavMode mode = NavMode.gestures,
    bool online = true,
    PermissionAccess mic = PermissionAccess.granted,
    TokenFetcher? tokens,
  }) async {
    activated = [];
    env = await TestEnv.create(
      mode: mode,
      permissions: FakePermissions(mic: mic, micOnRequest: mic),
    );
    env
      ..assistantConfig = config
      ..online = online
      // The ElevenLabs Percy is a developer option since Phase 9.
      ..percyElevenLabs = true;
    container = ProviderContainer(
      overrides: [
        ...env.overrides,
        if (tokens != null)
          assistantTokenFetcherProvider.overrideWithValue(tokens),
      ],
    );
    addTearDown(container.dispose);
    container
      ..listen(announcerProvider, (_, _) {})
      ..listen(focusControllerProvider, (_, _) {})
      ..listen(voiceControllerProvider, (_, _) {})
      ..listen(assistantControllerProvider, (_, _) {});
    container.read(actionRegistryProvider.notifier).register(home());
    await pumpEventQueue();
  }

  /// Starts a conversation, answering "oo" to the consent question.
  Future<void> startWithConsent() async {
    await bus().dispatch(NavIntent.assistant);
    await pumpEventQueue();
    if (env.tts.transcript.contains(_consentQuestion) ||
        env.tts.transcript.contains('online developer version of Percy')) {
      await bus().handleUtterance('oo');
      await pumpEventQueue();
    }
    env.assistant.emit(const AssistantConnected());
    await pumpEventQueue();
  }

  group('starting', () {
    test('not set up: says so, the usual commands still work', () async {
      await setUpWith(
        config: const AssistantConfig(agentId: '', voiceId: 'v'),
      );
      await bus().dispatch(NavIntent.assistant);
      expect(env.tts.transcript, contains('Hindi pa naka-set up si Percy'));
      expect(env.assistant.starts, isEmpty);
      expect(state().active, isFalse);
    });

    test('offline: says Percy needs the internet', () async {
      await setUpWith(online: false);
      await bus().dispatch(NavIntent.assistant);
      expect(
        env.tts.transcript,
        contains('Kailangan ng internet para kay Percy'),
      );
      expect(env.assistant.starts, isEmpty);
    });

    test(
      'first time: asks for consent; "oo" starts and is remembered',
      () async {
        await setUpWith();
        await bus().dispatch(NavIntent.assistant);
        await pumpEventQueue();
        expect(env.tts.transcript, contains(_consentQuestion));
        expect(env.assistant.starts, isEmpty, reason: 'waits for the answer');

        await bus().handleUtterance('oo');
        await pumpEventQueue();
        expect(env.assistant.starts, hasLength(1));
        final options = env.assistant.starts.single;
        expect(options.agentId, 'agent_test');
        expect(options.conversationToken, isNull);
        // Overrides off by default: the agent's own language, greeting and
        // voice (an agent that doesn't allow overrides ends the call at once).
        expect(options.language, isNull);
        expect(options.voiceId, isNull);
        expect(options.firstMessage, isNull);
        expect(options.dynamicVariables['app_language'], 'fil');
        expect(options.dynamicVariables['user_name'], isNotEmpty);
        expect(state().status, AssistantStatus.connecting);

        env.assistant.emit(const AssistantConnected());
        expect(state().status, AssistantStatus.listening);
        await assistant().stop();
        await Future<void>.delayed(_settle);

        // Second time: no question.
        final asked = RegExp(_consentQuestion)
            .allMatches(env.tts.transcript)
            .length;
        await bus().dispatch(NavIntent.assistant);
        await pumpEventQueue();
        expect(
          RegExp(_consentQuestion).allMatches(env.tts.transcript).length,
          asked,
        );
        expect(env.assistant.starts, hasLength(2));
      },
    );

    test('"hindi" to consent: nothing is sent', () async {
      await setUpWith();
      await bus().dispatch(NavIntent.assistant);
      await pumpEventQueue();
      await bus().handleUtterance('hindi');
      await pumpEventQueue();
      expect(env.tts.transcript, contains('hindi muna gagamitin si Percy'));
      expect(env.assistant.starts, isEmpty);
    });

    test('no microphone: explains', () async {
      await setUpWith(mic: PermissionAccess.permanentlyDenied);
      await bus().dispatch(NavIntent.assistant);
      await pumpEventQueue();
      await bus().handleUtterance('oo'); // consent
      await pumpEventQueue();
      expect(env.tts.transcript, contains('Kailangan ni Percy ang mikropono'));
      expect(env.assistant.starts, isEmpty);
    });

    test('private agent: connects with a token, not the agent id', () async {
      await setUpWith(
        config: const AssistantConfig(
          agentId: 'agent_test',
          voiceId: 'v',
          tokenUrl: 'http://pc:8787/assistant/token',
        ),
        tokens: (_) async => 'tok-123',
      );
      await startWithConsent();
      expect(env.assistant.starts.single.conversationToken, 'tok-123');
      expect(env.assistant.starts.single.agentId, isNull);
    });

    test(
      'a connection failure says so and gives the app its voice back',
      () async {
        await setUpWith();
        env.assistant.startError = Exception('no network');
        await startWithConsent();
        await Future<void>.delayed(_settle);
        expect(state().active, isFalse);
        expect(env.tts.transcript, contains('Hindi makakonekta kay Percy'));
      },
    );

    test('with overrides on: Tagalog greeting, language and voice', () async {
      await setUpWith(
        config: const AssistantConfig(
          agentId: 'agent_test',
          voiceId: 'voice_x',
          useOverrides: true,
        ),
      );
      await startWithConsent();
      final options = env.assistant.starts.single;
      expect(options.language, 'tl');
      expect(options.voiceId, 'voice_x');
      expect(options.firstMessage, contains('Ako si Percy'));
    });

    test(
      'with overrides on, English app: English greeting and language',
      () async {
        await setUpWith(
          config: const AssistantConfig(
            agentId: 'agent_test',
            voiceId: 'voice_x',
            useOverrides: true,
          ),
        );
        await container
            .read(settingsProvider.notifier)
            .update((s) => s.copyWith(locale: AppLocales.english));
        await startWithConsent();
        expect(env.assistant.starts.single.language, 'en');
        expect(env.assistant.starts.single.firstMessage, contains("I'm Percy"));
      },
    );
  });

  group('during a conversation', () {
    test("the app's own prompts are shown, not spoken", () async {
      await setUpWith();
      await startWithConsent();
      final spoken = env.tts.spoken.length;
      await bus().say('Isang paalala.');
      await pumpEventQueue();
      expect(env.tts.spoken.length, spoken);
      expect(container.read(announcerProvider).text, 'Isang paalala.');
    });

    test('what Percy and the user say shows as the subtitle', () async {
      await setUpWith();
      await startWithConsent();
      env.assistant.emit(const AssistantHeard('nasaan ako'));
      expect(container.read(announcerProvider).text, '“nasaan ako”');
      env.assistant.emit(const AssistantSaid('Nasa Home ka po.'));
      expect(container.read(announcerProvider).text, 'Nasa Home ka po.');
      env.assistant.emit(const AssistantModeChanged(speaking: true));
      expect(state().status, AssistantStatus.speaking);
    });

    test('the app does not listen meanwhile (voice mode)', () async {
      await setUpWith(mode: NavMode.voice);
      await startWithConsent();
      await Future<void>.delayed(_settle);
      expect(env.speech.listening, isFalse);
    });

    test("a user's gesture ends Percy and does nothing else", () async {
      await setUpWith();
      await startWithConsent();
      await bus().onGesture(GestureType.doubleTap);
      await Future<void>.delayed(_settle);
      expect(env.assistant.ends, 1);
      expect(activated, isEmpty);
      expect(state().active, isFalse);
      expect(env.tts.spoken.last, 'Tapos na ang usapan kay Percy.');
    });

    test('two-finger swipe left starts and ends Percy', () async {
      await setUpWith();
      expect(gestureMap[GestureType.twoFingerSwipeLeft], NavIntent.assistant);
      await startWithConsent();
      await bus().onGesture(GestureType.twoFingerSwipeLeft);
      await Future<void>.delayed(_settle);
      expect(env.assistant.ends, 1);
    });

    test('saying "Percy" starts it', () async {
      await setUpWith();
      await bus().handleUtterance('percy');
      await pumpEventQueue();
      expect(env.tts.transcript, contains(_consentQuestion));
    });

    test('Percy ending the call gives the voice back', () async {
      await setUpWith(mode: NavMode.voice);
      await startWithConsent();
      env.assistant.emit(const AssistantDisconnected('agent'));
      await Future<void>.delayed(_settle);
      expect(state().active, isFalse);
      expect(env.tts.spoken.last, 'Tapos na ang usapan kay Percy.');
      await Future<void>.delayed(_settle);
      expect(env.speech.listening, isTrue, reason: 'voice mode listens again');
    });
  });

  group('tools', () {
    test('every tool Percy is given has a handler, and only those', () {
      final file = File('assistant/agent_config/tools.json');
      final tools = (jsonDecode(file.readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
      expect({for (final t in tools) t['name']}, AssistantTools.names);
      for (final t in tools) {
        expect(t['description'], isNotEmpty);
        expect((t['parameters'] as Map)['type'], 'object');
      }
    });

    test('get_screen: the screen, its options and the focus', () async {
      await setUpWith();
      await startWithConsent();
      container.read(focusControllerProvider.notifier).focus('home.library');
      final (result, isError) = await env.assistant.callTool('get_screen');
      expect(isError, isFalse);
      expect(result, contains('Ano ang gusto mong gawin?'));
      expect(result, contains('Options: Magbasa ng bago, Aklatan'));
      expect(result, contains('Focused: Aklatan'));
    });

    test('choose_option activates by name, like a double-tap', () async {
      await setUpWith();
      await startWithConsent();
      final (result, isError) = await env.assistant.callTool('choose_option', {
        'option': 'aklatan',
      });
      expect(isError, isFalse);
      expect(activated, ['library']);
      expect(result, contains('Chose "Aklatan"'));
      expect(
        state().active,
        isTrue,
        reason: "Percy's own action doesn't end it",
      );
    });

    test('choose_option with an unknown name lists the options', () async {
      await setUpWith();
      await startWithConsent();
      final (result, isError) = await env.assistant.callTool('choose_option', {
        'option': 'sayaw',
      });
      expect(isError, isTrue);
      expect(result, contains('Options: Magbasa ng bago, Aklatan'));
    });

    test('reading_settings changes the saved speed and size', () async {
      await setUpWith();
      await startWithConsent();
      var (result, _) = await env.assistant.callTool('reading_settings', {
        'change': 'faster',
      });
      expect(container.read(settingsProvider).readingRate, 1.25);
      expect(result, contains('Reading speed is now'));
      (result, _) = await env.assistant.callTool('reading_settings', {
        'change': 'bigger_text',
      });
      expect(container.read(settingsProvider).textSize, 20);
    });

    test('get_document_text: the open document, cut when long', () async {
      await setUpWith();
      await startWithConsent();
      var (result, isError) = await env.assistant.callTool('get_document_text');
      expect(isError, isTrue, reason: 'no document open');
      container
          .read(readerSnapshotProvider.notifier)
          .set(
            ReaderSnapshot(
              title: 'Bill ng kuryente',
              text: 'Babayaran: 1,245.50. ${'x' * 7000}',
              sentence: 0,
              sentenceCount: 3,
              playing: false,
              canRead: true,
            ),
          );
      (result, isError) = await env.assistant.callTool('get_document_text');
      expect(isError, isFalse);
      expect(result, contains('Title: Bill ng kuryente'));
      expect(result, contains('Babayaran: 1,245.50.'));
      expect(result, contains('Only the first 6000'));
    });

    test('list_library: empty library', () async {
      await setUpWith();
      await startWithConsent();
      final (result, _) = await env.assistant.callTool('list_library');
      expect(result, contains('empty'));
    });

    test('a hand-over runs only after the call ends', () async {
      await setUpWith();
      await startWithConsent();
      container
          .read(readerSnapshotProvider.notifier)
          .set(
            const ReaderSnapshot(
              title: 'Liham',
              text: 'Mahal kita.',
              sentence: 0,
              sentenceCount: 1,
              playing: false,
              canRead: true,
            ),
          );
      final (result, _) = await env.assistant.callTool('read_document');
      expect(result, contains('call end_call'));
      expect(state().active, isTrue);
      env.assistant.emit(const AssistantDisconnected('agent'));
      await Future<void>.delayed(_settle);
      expect(state().active, isFalse);
      // Handed over: no "the conversation has ended" message.
      expect(env.tts.transcript, isNot(contains('Tapos na ang usapan')));
    });

    test('a tool call after the end is refused', () async {
      await setUpWith();
      await startWithConsent();
      await assistant().stop();
      await Future<void>.delayed(_settle);
      env.assistant.emit(
        const AssistantToolCall(id: 'late', name: 'get_screen', parameters: {}),
      );
      await pumpEventQueue();
      expect(env.assistant.results.single.$3, isTrue);
    });
  });
}
