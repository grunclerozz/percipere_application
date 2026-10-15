import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/accessibility/action_registry.dart';
import 'package:percipere_app/core/accessibility/announcer.dart';
import 'package:percipere_app/core/accessibility/navigation_mode.dart';
import 'package:percipere_app/core/accessibility/screen_registration.dart';
import 'package:percipere_app/core/offline_voice/command_recognizer.dart';
import 'package:percipere_app/core/offline_voice/hybrid_speech_input.dart';
import 'package:percipere_app/core/offline_voice/hybrid_tts_service.dart';
import 'package:percipere_app/core/offline_voice/offline_engines.dart';
import 'package:percipere_app/core/offline_voice/offline_listener.dart';
import 'package:percipere_app/core/offline_voice/offline_speaker.dart';
import 'package:percipere_app/core/platform/permissions.dart';
import 'package:percipere_app/core/tts/tts_service.dart';
import 'package:percipere_app/core/voice/speech_input.dart';
import 'package:percipere_app/core/voice/voice_controller.dart';

import '../../helpers/fakes.dart';

/// A microphone that can be opened (or not) and fed by hand.
class FakeMic implements MicStream {
  FakeMic({this.opens = true});

  bool opens;
  bool open = false;
  final StreamController<Uint8List> _audio = StreamController.broadcast();

  @override
  Stream<Uint8List> get audio => _audio.stream;

  @override
  Future<bool> start() async => open = opens;

  @override
  Future<void> stop() async => open = false;

  void send(int bytes) => _audio.add(Uint8List(bytes));
}

/// A recognizer whose results the test decides.
class FakeRecognizer implements SpeechRecognizerPort {
  final StreamController<RecognizerEvent> _events =
      StreamController.broadcast(sync: true);
  final List<(int, String)> begun = [];
  final List<int> flushed = [];
  final List<int> ended = [];
  int fed = 0;

  @override
  Stream<RecognizerEvent> get events => _events.stream;

  @override
  void begin(int session, String language) => begun.add((session, language));

  @override
  void feed(int session, Uint8List pcm16) => fed++;

  @override
  void flush(int session) {
    flushed.add(session);
    _events.add(RecognizerFlushed(session));
  }

  @override
  void end(int session) => ended.add(session);

  int get session => begun.last.$1;
  void speechStarts() => _events.add(SpeechStarted(session));
  void says(String text) => _events.add(SpeechRecognized(session, text, 120));
}

/// An offline voice that records what it says.
class FakeOfflineVoice implements OfflineVoice {
  FakeOfflineVoice(this.languages);

  final Set<String> languages;
  final List<(String, String)> spoken = [];
  int stops = 0;

  @override
  bool speaks(String tag) =>
      languages.contains(OfflineSpeaker.languageOf(tag));

  @override
  Future<bool> speak(String text, {required String tag, double rate = 1}) async {
    spoken.add((text, tag));
    return true;
  }

  @override
  Future<void> stop() async => stops++;
}

void main() {
  group('offline command listener', () {
    late FakeRecognizer recognizer;
    late FakeMic mic;
    late OfflineCommandListener listener;
    late List<(String, bool)> results;
    late List<String> statuses;

    setUp(() {
      recognizer = FakeRecognizer();
      mic = FakeMic();
      statuses = [];
      listener = OfflineCommandListener(
        recognizer,
        mic,
        onStatus: statuses.add,
      );
      results = [];
    });

    Future<bool> listen({
      String locale = 'fil-PH',
      Duration pauseFor = const Duration(seconds: 5),
    }) => listener.listen(
      ListenRequest(
        localeId: locale,
        onDevice: true,
        offline: true,
        pauseFor: pauseFor,
      ),
      onResult: (words, isFinal, {alternates = const [], confidence = -1}) =>
          results.add((words, isFinal)),
    );

    test('what is said is the final result, then "done"', () async {
      expect(await listen(), isTrue);
      expect(recognizer.begun.single.$2, 'tl');
      mic.send(3200);
      await Future<void>.delayed(Duration.zero);
      expect(recognizer.fed, 1);
      recognizer
        ..speechStarts()
        ..says(' Buksan ang aklatan. ');
      await Future<void>.delayed(Duration.zero);
      expect(results, [('Buksan ang aklatan.', true)]);
      expect(statuses, ['listening', 'notListening', 'done']);
      expect(mic.open, isFalse, reason: 'the microphone is released');
    });

    test('English app language listens in English', () async {
      await listen(locale: 'en-US');
      expect(recognizer.begun.single.$2, 'en');
    });

    test('nobody speaks: an empty final result after the wait', () async {
      await listen(pauseFor: const Duration(milliseconds: 50));
      for (var i = 0; i < 100 && results.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(results, [('', true)]);
      expect(statuses.last, 'done');
    });

    test('a cough (nothing recognized) keeps listening', () async {
      await listen(pauseFor: const Duration(seconds: 5));
      recognizer
        ..speechStarts()
        ..says('');
      await Future<void>.delayed(Duration.zero);
      expect(results, isEmpty);
      recognizer.says('susunod');
      await Future<void>.delayed(Duration.zero);
      expect(results, [('susunod', true)]);
    });

    test('sound notes from the recognizer are dropped', () {
      expect(CommandRecognizer.clean('[Music] susunod (tawa)'), 'susunod');
      expect(CommandRecognizer.clean(' ♪ '), '');
    });

    test('stop() ends the speech now and reports it', () async {
      await listen(pauseFor: const Duration(seconds: 5));
      await listener.stop();
      await Future<void>.delayed(Duration.zero);
      expect(recognizer.flushed, hasLength(1));
      expect(results, [('', true)]);
    });

    test('cancel() ends silently', () async {
      await listen(pauseFor: const Duration(seconds: 5));
      await listener.cancel();
      recognizer.says('susunod');
      await Future<void>.delayed(Duration.zero);
      expect(results, isEmpty);
      expect(statuses, ['listening']);
    });

    test('no microphone: false, so the caller can use Android', () async {
      mic.opens = false;
      expect(await listen(), isFalse);
    });
  });

  group('hybrid speech input', () {
    late FakeSpeechInput android;
    late OfflineEngines engines;
    late FakeMic mic;
    late HybridSpeechInput input;

    setUp(() async {
      android = FakeSpeechInput();
      mic = FakeMic();
      engines = OfflineEngines()
        ..debugUse(
          listener: OfflineCommandListener(FakeRecognizer(), mic),
        );
      input = HybridSpeechInput(android, engines);
      await input.initialize(onError: (_) {}, onStatus: (_) {});
    });

    Future<void> listen({required bool offline}) => input.listen(
      ListenRequest(
        localeId: 'fil-PH',
        onDevice: true,
        offline: offline,
        pauseFor: const Duration(seconds: 5),
      ),
      onResult: (_, _, {alternates = const [], confidence = -1}) {},
    );

    test('commands go to the offline recognizer', () async {
      await listen(offline: true);
      expect(mic.open, isTrue);
      expect(android.sessions, isEmpty);
      await input.cancel();
      expect(mic.open, isFalse);
    });

    test('other sessions go to Android', () async {
      await listen(offline: false);
      expect(mic.open, isFalse);
      expect(android.sessions, hasLength(1));
    });

    test('microphone busy: Android listens instead', () async {
      mic.opens = false;
      await listen(offline: true);
      expect(android.sessions, hasLength(1));
    });

    test('no Android recognizer, but offline commands: available', () async {
      final none = HybridSpeechInput(FakeSpeechInput(available: false), engines);
      expect(await none.initialize(onError: (_) {}, onStatus: (_) {}), isTrue);
      final nothing = HybridSpeechInput(
        FakeSpeechInput(available: false),
        OfflineEngines(),
      );
      expect(
        await nothing.initialize(onError: (_) {}, onStatus: (_) {}),
        isFalse,
      );
    });
  });

  group('voice output order', () {
    late FakeTts android;
    late OfflineEngines engines;
    late FakeOfflineVoice bundled;
    late HybridTtsService tts;

    setUp(() {
      android = FakeTts(voices: const VoiceStatus(filipinoReady: false));
      bundled = FakeOfflineVoice({'fil', 'en'});
      engines = OfflineEngines()
        ..debugUse(speaker: bundled, voices: {'fil', 'en'});
      tts = HybridTtsService(android, engines);
    });

    test('no Filipino voice on the phone: the downloaded voice speaks',
        () async {
      expect(await tts.routeFor('fil-PH'), TtsRoute.bundled);
      await tts.speak('Handa na.', languageTag: 'fil-PH');
      expect(bundled.spoken.single.$1, 'Handa na.');
      expect(android.spoken, isEmpty);
    });

    test('a voice installed on the phone comes first', () async {
      android.installedVoices = const [
        TtsVoice(name: 'fil-ph-x-fie-local', locale: 'fil-PH'),
      ];
      expect(await tts.routeFor('fil-PH'), TtsRoute.androidLocal);
      await tts.speak('Handa na.', languageTag: 'fil-PH');
      expect(android.spoken.single, 'Handa na.');
      expect(bundled.spoken, isEmpty);
    });

    test('a network-only voice is never chosen over the downloaded one',
        () async {
      android.installedVoices = const [
        TtsVoice(
          name: 'fil-ph-x-fic-network',
          locale: 'fil-PH',
          networkRequired: true,
        ),
      ];
      expect(await tts.routeFor('fil-PH'), TtsRoute.bundled);
    });

    test('an Android voice that fails is replaced by the downloaded one',
        () async {
      android
        ..installedVoices = const [
          TtsVoice(name: 'en-us-x-sfg-local', locale: 'en-US'),
        ]
        ..autoComplete = false;
      final done = tts.speak('Next.', languageTag: 'en-US');
      await Future<void>.delayed(Duration.zero);
      android.lastFailed = true;
      await android.stop();
      expect(await done, isTrue);
      expect(bundled.spoken.single.$1, 'Next.');
    });

    test('without the downloaded voice, Android speaks (online voice)',
        () async {
      final plain = HybridTtsService(android, OfflineEngines());
      expect(await plain.routeFor('fil-PH'), TtsRoute.androidAny);
      await plain.speak('Kumusta.', languageTag: 'fil-PH');
      expect(android.spoken.single, 'Kumusta.');
    });

    test('the downloaded voices count as offline voices', () async {
      final status = await tts.checkVoices();
      expect(status.filipinoReady, isTrue);
      expect(status.englishReady, isTrue);
      final report = await tts.report('fil-PH');
      expect(report.engine, HybridTtsService.bundledEngine);
      expect(report.local, isTrue);
    });

    test('stop() stops both', () async {
      await tts.stop();
      expect(android.stopCalls, 1);
      expect(bundled.stops, 1);
    });
  });

  group('listening plan with the offline recognizer', () {
    late TestEnv env;
    late ProviderContainer container;

    Future<void> setUpWith({required bool online, bool offline = true}) async {
      env = await TestEnv.create(
        mode: NavMode.voice,
        permissions: FakePermissions(
          mic: PermissionAccess.granted,
          micOnRequest: PermissionAccess.granted,
        ),
        speech: FakeSpeechInput()
          ..info = const RecognizerInfo(
            sdk: 35,
            onDevice: true,
            installed: ['fil-PH', 'en-US'],
          ),
      );
      env.online = online;
      final engines = OfflineEngines();
      if (offline) {
        engines.debugUse(
          listener: OfflineCommandListener(FakeRecognizer(), FakeMic()),
        );
      }
      container = ProviderContainer(
        overrides: [
          ...env.overrides,
          offlineEnginesProvider.overrideWithValue(engines),
        ],
      );
      addTearDown(container.dispose);
      container
        ..listen(voiceControllerProvider, (_, _) {})
        ..listen(announcerProvider, (_, _) {})
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

    Future<void> speakThenSettle() async {
      await container.read(announcerProvider.notifier).say('Una.');
      // Until listening starts (real time: the PC may be busy).
      for (var i = 0; i < 60 && env.speech.sessions.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }

    test('commands use the offline recognizer first, also online', () async {
      await setUpWith(online: true);
      await speakThenSettle();
      expect(env.speech.sessions.last.offline, isTrue);
      expect(
        container.read(voiceControllerProvider.notifier).nextPlan.offline,
        isTrue,
      );
    });

    test('commands use the offline recognizer without internet', () async {
      await setUpWith(online: false);
      await container.read(voiceControllerProvider.notifier).warmUp();
      await speakThenSettle();
      expect(env.speech.sessions.last.offline, isTrue);
      expect(env.tts.transcript, isNot(contains('walang naka-install')));
    });

    test('dictation still uses Android', () async {
      await setUpWith(online: true);
      final voice = container.read(voiceControllerProvider.notifier);
      unawaited(voice.dictate());
      for (var i = 0; i < 60 && env.speech.sessions.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(env.speech.sessions.last.offline, isFalse);
      expect(env.speech.sessions.last.dictation, isTrue);
    });

    test('without the model the old plan is unchanged', () async {
      await setUpWith(online: true, offline: false);
      await speakThenSettle();
      expect(env.speech.sessions.last.offline, isFalse);
      expect(env.speech.sessions.last.onDevice, isTrue);
    });
  });
}
