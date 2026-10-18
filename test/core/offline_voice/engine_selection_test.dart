import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/config/voice_config.dart';
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

/// A microphone that takes a moment to open and to close, like the real
/// one, and logs the calls in order.
class SlowMic extends FakeMic {
  final List<String> calls = [];
  Completer<void>? opening;
  Completer<void>? closing;

  @override
  Future<bool> start() async {
    calls.add('start');
    final gate = opening = Completer<void>();
    await gate.future;
    return open = opens;
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    final gate = closing = Completer<void>();
    await gate.future;
    open = false;
  }
}

/// A recognizer whose results the test decides.
class FakeRecognizer implements SpeechRecognizerPort {
  final StreamController<RecognizerEvent> _events =
      StreamController.broadcast(sync: true);
  final List<(int, String)> begun = [];
  final List<bool> whole = [];
  final List<int> flushed = [];
  final List<int> ended = [];
  int fed = 0;

  @override
  Stream<RecognizerEvent> get events => _events.stream;

  @override
  void begin(int session, String language, {bool whole = false}) {
    begun.add((session, language));
    this.whole.add(whole);
  }

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

    // 2026-10-17, fix/voice-capture: the first pause used to end a
    // push-to-talk command ("basahin" … "ang Liham" ran as "basahin").
    test('push-to-talk: a pause does not end it; the release reports '
        'everything said as one result', () async {
      var speechStarts = 0;
      await listener.listen(
        const ListenRequest(
          localeId: 'fil-PH',
          onDevice: true,
          offline: true,
          pushToTalk: true,
        ),
        onResult: (words, isFinal, {alternates = const [], confidence = -1}) =>
            results.add((words, isFinal)),
        onSpeechStart: () => speechStarts++,
      );
      expect(recognizer.whole.single, isTrue, reason: 'recognized at once');
      recognizer
        ..speechStarts()
        ..says('basahin');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(results, isEmpty, reason: 'still held');
      expect(speechStarts, 1);
      recognizer.says('ang Liham');
      await listener.stop(); // the release
      await Future<void>.delayed(Duration.zero);
      expect(results, [('basahin ang Liham', true)]);
      expect(statuses.last, 'done');
    });

    test('push-to-talk: no speech cap while held', () async {
      await listener.listen(
        const ListenRequest(
          localeId: 'fil-PH',
          onDevice: true,
          offline: true,
          pushToTalk: true,
        ),
        onResult: (words, isFinal, {alternates = const [], confidence = -1}) =>
            results.add((words, isFinal)),
      );
      recognizer.speechStarts();
      await Future<void>.delayed(
        VoiceConfig.commandSpeechMax + const Duration(milliseconds: 200),
      );
      expect(recognizer.flushed, isEmpty);
      expect(listener.listening, isTrue);
    });

    test('an ordinary command session is recognized stretch by stretch',
        () async {
      await listen();
      expect(recognizer.whole.single, isFalse);
    });

    test('cancelled while the microphone opens: the microphone is closed '
        'again, no session runs (2026-10-17)', () async {
      final slow = SlowMic();
      final l = OfflineCommandListener(recognizer, slow, onStatus: statuses.add);
      final started = l.listen(
        const ListenRequest(localeId: 'fil-PH', onDevice: true, offline: true),
        onResult: (w, f, {alternates = const [], confidence = -1}) =>
            results.add((w, f)),
      );
      await pumpEventQueue();
      final cancelled = l.cancel();
      slow.opening!.complete();
      await pumpEventQueue();
      slow.closing!.complete();
      expect(await started, isTrue);
      await cancelled;
      expect(slow.calls, ['start', 'stop']);
      expect(slow.open, isFalse);
      expect(l.listening, isFalse);
      expect(statuses, isEmpty);
    });

    test('a new session opens the microphone only after the old one is '
        'released (2026-10-17: "say it twice")', () async {
      final slow = SlowMic();
      final l = OfflineCommandListener(recognizer, slow, onStatus: statuses.add);
      Future<bool> open() => l.listen(
        const ListenRequest(localeId: 'fil-PH', onDevice: true, offline: true),
        onResult: (w, f, {alternates = const [], confidence = -1}) =>
            results.add((w, f)),
      );
      final first = open();
      await pumpEventQueue();
      slow.opening!.complete();
      expect(await first, isTrue);
      // The command is heard: the session ends and its microphone starts
      // closing; the next session is asked for at once.
      recognizer.says('susunod');
      final second = open();
      await pumpEventQueue();
      expect(slow.calls, ['start', 'stop'], reason: 'no start before the stop');
      slow.closing!.complete();
      await pumpEventQueue();
      expect(slow.calls, ['start', 'stop', 'start']);
      slow.opening!.complete();
      expect(await second, isTrue);
      expect(slow.open, isTrue);
      expect(l.listening, isTrue);
    });

    test('sound levels are on about the Android scale, from a quiet room', () {
      expect(OfflineCommandListener.soundLevel(-100), -2);
      expect(OfflineCommandListener.soundLevel(-60), 0);
      expect(OfflineCommandListener.soundLevel(-45), 5);
      expect(OfflineCommandListener.soundLevel(0), 10);
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

    test('a late error of an old Android session during an offline session '
        'is not this session failing', () async {
      final errors = <String>[];
      await input.initialize(onError: errors.add, onStatus: (_) {});
      await listen(offline: true);
      android.fail('error_client'); // late error of a cancelled session
      expect(errors, isEmpty);
      await input.cancel();
      await listen(offline: false);
      android.fail('error_client');
      expect(errors, ['error_client'], reason: 'real Android errors pass');
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

    /// The Android voice fails at once ([times] tries in a row).
    Future<bool> failing(String text, {int times = 2}) async {
      final done = tts.speak(text, languageTag: 'en-US');
      for (var i = 0; i < times; i++) {
        await pumpEventQueue();
        android.lastFailed = true;
        await android.stop();
      }
      return done;
    }

    test('an Android voice that fails twice is replaced by the downloaded one',
        () async {
      android
        ..installedVoices = const [
          TtsVoice(name: 'en-us-x-sfg-local', locale: 'en-US'),
        ]
        ..autoComplete = false;
      expect(await failing('Next.'), isTrue);
      expect(bundled.spoken.single.$1, 'Next.');
      expect(android.spoken, ['Next.', 'Next.'], reason: 'tried once more');
    });

    // 2026-10-18 tablet test: "the output voice changes between screens".
    // One hiccup of the Android voice switched the voice for good.
    test('one quick failure: the same voice says it again, the voice stays',
        () async {
      android
        ..installedVoices = const [
          TtsVoice(name: 'en-us-x-sfg-local', locale: 'en-US'),
        ]
        ..autoComplete = false;
      final done = tts.speak('Next.', languageTag: 'en-US');
      await pumpEventQueue();
      android.lastFailed = true;
      await android.stop();
      await pumpEventQueue();
      android.lastFailed = false;
      android.finishCurrent();
      expect(await done, isTrue);
      expect(android.spoken, ['Next.', 'Next.']);
      expect(bundled.spoken, isEmpty);
      expect(await tts.routeFor('en-US'), TtsRoute.androidLocal);
    });

    // 2026-10-17, fix/voice-capture: after a failure the next sentence went
    // back to the failed Android voice, so the voice kept changing.
    test('after it failed again the downloaded voice stays for that language',
        () async {
      android
        ..installedVoices = const [
          TtsVoice(name: 'en-us-x-sfg-local', locale: 'en-US'),
        ]
        ..autoComplete = false;
      await failing('Next.');
      android
        ..lastFailed = false
        ..autoComplete = true;
      await tts.speak('And then.', languageTag: 'en-US');
      expect(await tts.routeFor('en-US'), TtsRoute.bundled);
      expect(bundled.spoken.map((s) => s.$1), ['Next.', 'And then.']);
      expect(android.spoken, ['Next.', 'Next.'], reason: 'only the failed tries');
    });

    test('the voice chosen for a language is kept for the run', () async {
      android.installedVoices = const [
        TtsVoice(name: 'fil-ph-x-fie-local', locale: 'fil-PH'),
      ];
      expect(await tts.routeFor('fil-PH'), TtsRoute.androidLocal);
      // Voices listed differently later (a voice list refresh) don't move
      // the app to another engine mid-session.
      android.installedVoices = const [];
      expect(await tts.routeFor('fil-PH'), TtsRoute.androidLocal);
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
