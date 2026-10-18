// Half-duplex turns (2026-10-18). Tablet results (Galaxy Tab S10 Lite): the
// microphone heard the app's own voice ("too much noise", false commands),
// the listening tone sometimes got stuck, commands had to be said 2–3 times
// (better on Home than elsewhere), the output voice changed between screens.
// Covered here:
//
// A. The turn state machine: speaking → wait → listening → done / timeout,
//    with a watchdog, reset on screen change and app pause.
// B. Room calibration: the speech threshold follows the measured room;
//    "noisy" only when it stays high for a while.
// C. The app's own microphone stays open between back-to-back sessions and
//    gives the next one what it heard (the first syllable), mutes the
//    app's tones, ignores speech no louder than the room, measures the
//    room.
// D. The controller: waits after speech, mutes for the tone, closes on a
//    screen change and on app pause, a session that never ends is closed,
//    the user's speech (voice detector) holds back queued instructions.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/config/voice_config.dart';
import 'package:percipere_app/core/accessibility/action_registry.dart';
import 'package:percipere_app/core/accessibility/announcer.dart';
import 'package:percipere_app/core/accessibility/nav_intent.dart';
import 'package:percipere_app/core/accessibility/navigation_mode.dart';
import 'package:percipere_app/core/accessibility/screen_registration.dart';
import 'package:percipere_app/core/offline_voice/command_recognizer.dart';
import 'package:percipere_app/core/offline_voice/offline_listener.dart';
import 'package:percipere_app/core/platform/permissions.dart';
import 'package:percipere_app/core/voice/mic_turn.dart';
import 'package:percipere_app/core/voice/noise_monitor.dart';
import 'package:percipere_app/core/voice/speech_input.dart';
import 'package:percipere_app/core/voice/voice_controller.dart';

import '../../helpers/fakes.dart';

/// A microphone that can be fed by hand and counts its opens.
class _Mic implements MicStream {
  int starts = 0;
  int stops = 0;
  bool open = false;
  final StreamController<Uint8List> _audio = StreamController.broadcast(
    sync: true,
  );

  @override
  Stream<Uint8List> get audio => _audio.stream;

  @override
  Future<bool> start() async {
    starts++;
    return open = true;
  }

  @override
  Future<void> stop() async {
    stops++;
    open = false;
  }

  /// 100 ms of a steady sound at [dbfs].
  void send({double dbfs = -60}) {
    final amplitude = (32768 * math.pow(10, dbfs / 20)).round().clamp(0, 32767);
    final samples = Int16List(1600)..fillRange(0, 1600, amplitude);
    _audio.add(samples.buffer.asUint8List());
  }
}

/// A recognizer that counts what it was fed and says what the test wants.
class _Recognizer implements SpeechRecognizerPort {
  final StreamController<RecognizerEvent> _events = StreamController.broadcast(
    sync: true,
  );
  final List<int> begun = [];
  int fed = 0;

  @override
  Stream<RecognizerEvent> get events => _events.stream;

  @override
  void begin(int session, String language, {bool whole = false}) =>
      begun.add(session);

  @override
  void feed(int session, Uint8List pcm16) => fed++;

  @override
  void flush(int session) => _events.add(RecognizerFlushed(session));

  @override
  void end(int session) {}

  void speechStarts() => _events.add(SpeechStarted(begun.last));
  void says(String text) => _events.add(SpeechRecognized(begun.last, text, 90));
}

void main() {
  group('turn state machine (A)', () {
    test('speaking → wait → idle: the microphone is allowed only after the '
        'guard', () {
      fakeAsync((async) {
        final turn = MicTurn();
        turn.speaking(true);
        expect(turn.phase, MicPhase.speaking);
        expect(turn.micAllowed, isFalse);
        turn.speaking(false);
        expect(turn.phase, MicPhase.wait);
        expect(turn.micAllowed, isFalse);
        async.elapse(VoiceConfig.speechGuard - const Duration(milliseconds: 1));
        expect(turn.micAllowed, isFalse);
        async.elapse(const Duration(milliseconds: 2));
        expect(turn.phase, MicPhase.idle);
        expect(turn.micAllowed, isTrue);
      });
    });

    test('ready() waits for the guard after speech', () {
      fakeAsync((async) {
        final turn = MicTurn()
          ..speaking(true)
          ..speaking(false);
        var ready = false;
        unawaited(turn.ready().then((_) => ready = true));
        async.elapse(const Duration(milliseconds: 100));
        expect(ready, isFalse);
        async.elapse(VoiceConfig.speechGuard);
        expect(ready, isTrue);
      });
    });

    test('listening → done', () {
      fakeAsync((async) {
        var timedOut = false;
        final turn = MicTurn(onTimeout: () => timedOut = true)
          ..listening(const Duration(seconds: 10));
        expect(turn.phase, MicPhase.listening);
        turn.ended();
        expect(turn.phase, MicPhase.done);
        async.elapse(const Duration(seconds: 30));
        expect(timedOut, isFalse, reason: 'the watchdog went with the session');
      });
    });

    test('listening that never ends → timeout after its limit + slack', () {
      fakeAsync((async) {
        var timedOut = 0;
        final turn = MicTurn(onTimeout: () => timedOut++)
          ..listening(const Duration(seconds: 10));
        async.elapse(const Duration(seconds: 10));
        expect(turn.phase, MicPhase.listening);
        async.elapse(VoiceConfig.listenWatchdogSlack);
        expect(turn.phase, MicPhase.timeout);
        expect(timedOut, 1);
      });
    });

    test('speaking ends a listening phase (and its watchdog)', () {
      fakeAsync((async) {
        var timedOut = false;
        final turn = MicTurn(onTimeout: () => timedOut = true)
          ..listening(const Duration(seconds: 1))
          ..speaking(true);
        async.elapse(const Duration(seconds: 10));
        expect(turn.phase, MicPhase.speaking);
        expect(timedOut, isFalse);
      });
    });

    test('reset: idle, no timers', () {
      fakeAsync((async) {
        var timedOut = false;
        final turn = MicTurn(onTimeout: () => timedOut = true)
          ..listening(const Duration(seconds: 1))
          ..reset();
        expect(turn.phase, MicPhase.idle);
        async.elapse(const Duration(seconds: 10));
        expect(timedOut, isFalse);
        expect(async.pendingTimers, isEmpty);
      });
    });
  });

  group('room calibration (B)', () {
    late DateTime now;
    late NoiseMonitor noise;

    setUp(() {
      now = DateTime(2026, 10, 18, 9);
      noise = NoiseMonitor(clock: () => now);
    });

    List<double> second(double level) => List.filled(10, level);

    test('the speech threshold is the room plus a margin', () {
      expect(noise.speechThreshold, isNull, reason: 'not measured yet');
      expect(noise.needsCalibration, isTrue);
      noise.calibrate(second(4));
      expect(noise.baseline, 4);
      expect(noise.speechThreshold, 4 + VoiceConfig.speechMargin);
      // A quiet room: never below the plain speech level.
      noise.calibrate(second(-1));
      expect(noise.speechThreshold, VoiceConfig.speechStartLevel);
    });

    test('a quiet, recent measurement is not taken again on the next screen; '
        'a noisy or old one is', () {
      noise.calibrate(second(0));
      expect(noise.needsCalibration, isFalse);
      now = now.add(VoiceConfig.noiseStale + const Duration(seconds: 1));
      expect(noise.needsCalibration, isTrue);
      noise.calibrate(second(VoiceConfig.noisyLevel + 1));
      expect(noise.needsCalibration, isTrue, reason: 'a noisy room');
    });

    test('one loud second (the warm-up) is not "noisy" yet; staying loud '
        'for a while is', () {
      noise.calibrate(second(7));
      expect(noise.noisy, isFalse);
      for (var i = 0; i < 12; i++) {
        now = now.add(const Duration(milliseconds: 100));
        noise.add(7);
      }
      expect(noise.noisy, isTrue);
    });

    test('nothing is measured while the app speaks', () {
      noise
        ..appSpeaking(true)
        ..calibrate(second(7));
      expect(noise.baseline, isNull);
    });

    test('a second of quiet before the user speaks also measures the room',
        () {
      noise.sessionStarted();
      for (var i = 0; i <= 10; i++) {
        noise.add(1);
        now = now.add(const Duration(milliseconds: 100));
      }
      expect(noise.baseline, 1);
    });
  });

  group('app microphone between sessions (C)', () {
    late _Recognizer recognizer;
    late _Mic mic;
    late OfflineCommandListener listener;
    late List<String> results;

    setUp(() {
      recognizer = _Recognizer();
      mic = _Mic();
      listener = OfflineCommandListener(recognizer, mic);
      results = [];
    });

    Future<bool> listen({
      Duration pauseFor = const Duration(seconds: 5),
      double? threshold,
    }) => listener.listen(
      ListenRequest(
        localeId: 'fil-PH',
        onDevice: true,
        offline: true,
        pauseFor: pauseFor,
        speechThreshold: threshold,
      ),
      onResult: (words, isFinal, {alternates = const [], confidence = -1}) =>
          results.add(words),
    );

    Future<void> silentSession() async {
      await listen(pauseFor: const Duration(milliseconds: 30));
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(results.last, '');
    }

    test('after a session that heard nothing the microphone stays open; the '
        'next session gets what it heard meanwhile ("say it 2–3 times")',
        () async {
      await silentSession();
      expect(mic.open, isTrue);
      expect(mic.stops, 0);
      // The user starts talking between the two sessions.
      mic
        ..send(dbfs: -30)
        ..send(dbfs: -30)
        ..send(dbfs: -30);
      final before = recognizer.fed;
      await listen();
      expect(mic.starts, 1, reason: 'not opened again');
      expect(recognizer.fed - before, 3, reason: 'the start of the command');
    });

    test('the lingering microphone closes on its own', () async {
      await silentSession();
      await Future<void>.delayed(
        VoiceConfig.micLinger + const Duration(milliseconds: 200),
      );
      expect(mic.open, isFalse);
    });

    test('releaseMic closes it at once (the app is about to speak)', () async {
      await silentSession();
      await listener.releaseMic();
      expect(mic.open, isFalse);
      await listen();
      expect(mic.starts, 2, reason: 'a fresh microphone, nothing kept');
    });

    test('a heard command closes the microphone (the app answers)', () async {
      await listen();
      recognizer
        ..speechStarts()
        ..says('susunod');
      await pumpEventQueue();
      expect(results, ['susunod']);
      expect(mic.open, isFalse);
    });

    test('muted audio (the app\'s tone) never reaches the recognizer',
        () async {
      await listen();
      listener.muteAudio(const Duration(milliseconds: 150));
      mic.send(dbfs: -20);
      expect(recognizer.fed, 0);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      mic.send(dbfs: -20);
      expect(recognizer.fed, 1);
    });

    test('speech no louder than the room is ignored; louder speech counts',
        () async {
      // Threshold 5 on the level scale (about −45 dBFS).
      await listen(threshold: 5);
      mic.send(dbfs: -54); // level 2: the TV in the next room
      recognizer
        ..speechStarts()
        ..says('susunod');
      await pumpEventQueue();
      expect(results, isEmpty, reason: 'ignored, still listening');
      expect(listener.listening, isTrue);
      mic.send(dbfs: -25); // level about 11: the user, close by
      recognizer.says('bumalik');
      await pumpEventQueue();
      expect(results, ['bumalik']);
    });

    test('without a threshold everything recognized counts', () async {
      await listen();
      mic.send(dbfs: -58);
      recognizer
        ..speechStarts()
        ..says('susunod');
      await pumpEventQueue();
      expect(results, ['susunod']);
    });

    test('measure: the room\'s levels for the time asked', () async {
      final measuring = listener.measure(const Duration(milliseconds: 250));
      await pumpEventQueue();
      mic
        ..send(dbfs: -60)
        ..send(dbfs: -45);
      final levels = await measuring;
      expect(levels.map((l) => l.round()), [0, 5]);
      expect(mic.open, isTrue, reason: 'kept open for the first session');
    });

    test('measure ends early when a session is asked for', () async {
      final measuring = listener.measure(const Duration(seconds: 5));
      await pumpEventQueue();
      final watch = Stopwatch()..start();
      final opened = listen();
      mic.send();
      await measuring;
      expect(await opened, isTrue);
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
      expect(mic.starts, 1, reason: 'the session took over the microphone');
    });
  });

  group('controller (D)', () {
    late TestEnv env;
    late ProviderContainer container;
    late List<NavIntent> ran;
    VoiceController voice() => container.read(voiceControllerProvider.notifier);

    Future<void> setUpWith({
      NavMode mode = NavMode.voice,
      FakeTts? tts,
      FakeSpeechInput? speech,
    }) async {
      ran = [];
      env = await TestEnv.create(
        mode: mode,
        tts: tts,
        speech: speech,
        permissions: FakePermissions(mic: PermissionAccess.granted),
      );
      container = ProviderContainer(overrides: env.overrides);
      addTearDown(container.dispose);
      container
        ..listen(voiceControllerProvider, (_, _) {})
        ..listen(announcerProvider, (_, _) {})
        ..read(actionRegistryProvider.notifier).register(_screen('test', ran));
    }

    test('speaking → wait → listening → done', () async {
      final tts = FakeTts(autoComplete: false);
      await setUpWith(tts: tts);
      unawaited(container.read(announcerProvider.notifier).say('Paalala.'));
      await pumpEventQueue();
      expect(voice().micPhase, MicPhase.speaking);
      expect(env.speech.micReleases, greaterThan(0),
          reason: 'the app microphone closes before the app talks');
      tts.finishCurrent();
      await pumpEventQueue();
      expect(voice().micPhase, MicPhase.wait);
      expect(env.speech.listening, isFalse);
      await Future<void>.delayed(
        VoiceConfig.afterSpeechGap + const Duration(milliseconds: 200),
      );
      expect(voice().micPhase, MicPhase.listening);
      expect(env.speech.listening, isTrue);
      env.speech.hear('susunod');
      await pumpEventQueue();
      expect(ran, [NavIntent.next]);
      expect(voice().micPhase, isNot(MicPhase.listening));
    });

    test('push-to-talk listens only after the speech stopped and the guard',
        () async {
      final tts = FakeTts(autoComplete: false);
      await setUpWith(mode: NavMode.gestures, tts: tts);
      unawaited(container.read(announcerProvider.notifier).say('Mahaba.'));
      await pumpEventQueue();
      final watch = Stopwatch()..start();
      await voice().listenNow();
      expect(tts.stopCalls, greaterThan(0));
      expect(env.speech.listening, isTrue);
      expect(
        watch.elapsed,
        greaterThanOrEqualTo(
          VoiceConfig.speechGuard - const Duration(milliseconds: 20),
        ),
      );
    });

    test('the "listening" tone mutes the app microphone, then the guard',
        () async {
      await setUpWith(mode: NavMode.gestures);
      await voice().listenNow();
      env.speech.soundLevel(); // the microphone is live: the cue plays
      await pumpEventQueue();
      expect(env.earcon.listeningCues, 1);
      expect(env.speech.mutes, [VoiceConfig.toneMax, VoiceConfig.toneGuard]);
    });

    test('a session that never ends is closed (the "stuck" state)', () async {
      await setUpWith(mode: NavMode.gestures);
      final probe = voice().probe();
      await pumpEventQueue();
      expect(env.speech.listening, isTrue);
      final cancels = env.speech.cancels;
      final result = await probe.timeout(
        VoiceConfig.probeListenFor +
            VoiceConfig.listenWatchdogSlack +
            const Duration(seconds: 2),
      );
      expect(result, isNull);
      expect(env.speech.cancels, greaterThan(cancels));
      expect(voice().micPhase, MicPhase.timeout);
      expect(container.read(voiceControllerProvider).listening, isFalse);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('a screen change closes the open session and the tone', () async {
      await setUpWith(mode: NavMode.gestures);
      await voice().listenNow();
      expect(env.speech.listening, isTrue);
      final cancels = env.speech.cancels;
      container
          .read(actionRegistryProvider.notifier)
          .register(_screen('other', ran));
      await pumpEventQueue();
      expect(env.speech.cancels, greaterThan(cancels));
      expect(container.read(voiceControllerProvider).listening, isFalse);
      env.speech.soundLevel();
      await pumpEventQueue();
      expect(env.earcon.listeningCues, 0, reason: 'no tone after leaving');
    });

    test('app paused: listening, tone and microphone end; the turn is idle',
        () async {
      await setUpWith(mode: NavMode.gestures);
      await voice().listenNow();
      final releases = env.speech.micReleases;
      voice().setAppActive(false);
      await pumpEventQueue();
      expect(env.speech.listening, isFalse);
      expect(env.earcon.stops, 1);
      expect(env.speech.micReleases, greaterThan(releases));
      expect(voice().micPhase, MicPhase.idle);
    });

    test('warm-up calibration sets the speech threshold of command sessions',
        () async {
      final speech = FakeSpeechInput()..room = List.filled(10, 4);
      await setUpWith(speech: speech);
      await voice().calibrateNoise();
      expect(speech.measurements, 1);
      // An automatic command session (after a prompt).
      await container.read(announcerProvider.notifier).say('Handa na po.');
      await Future<void>.delayed(
        VoiceConfig.afterSpeechGap + const Duration(milliseconds: 300),
      );
      expect(speech.listening, isTrue);
      expect(speech.sessions.last.speechThreshold, 4 + VoiceConfig.speechMargin);
      // Push-to-talk is always heard.
      voice().holdStarted();
      await voice().listenNow();
      expect(speech.sessions.last.pushToTalk, isTrue);
      expect(speech.sessions.last.speechThreshold, isNull);
    });

    test('the room is measured again on a new screen while it was noisy',
        () async {
      final speech = FakeSpeechInput()
        ..room = List.filled(10, VoiceConfig.noisyLevel + 2);
      await setUpWith(speech: speech);
      await voice().calibrateNoise();
      expect(speech.measurements, 1);
      container
          .read(actionRegistryProvider.notifier)
          .register(_screen('other', ran));
      // The new screen announces itself; listening starts after that.
      await container.read(announcerProvider.notifier).say('Ibang screen.');
      await Future<void>.delayed(
        VoiceConfig.afterSpeechGap + const Duration(milliseconds: 400),
      );
      expect(speech.measurements, 2);
      expect(speech.listening, isTrue, reason: 'then it listens');
    });

    test('the user talking (voice detector) holds back the instructions '
        'after a question', () async {
      await setUpWith();
      final announcer = container.read(announcerProvider.notifier);
      await announcer.ask('Buksan ko ba?', then: 'Sabihin ang oo o hindi.');
      await Future<void>.delayed(
        VoiceConfig.afterSpeechGap + const Duration(milliseconds: 300),
      );
      expect(env.speech.listening, isTrue);
      // Just before the wait ends, the user starts talking.
      await Future<void>.delayed(
        VoiceConfig.answerWait -
            VoiceConfig.afterSpeechGap -
            const Duration(milliseconds: 900),
      );
      env.speech.speechStarts();
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      expect(env.tts.transcript, isNot(contains('Sabihin ang oo')));
      expect(env.speech.listening, isTrue, reason: 'not cut by a prompt');
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}

ScreenRegistration _screen(String id, List<NavIntent> ran) => ScreenRegistration(
  id: id,
  title: (l) => l.screenCapture,
  prompt: (l) => l.capturePrompt,
  intentHandlers: {
    for (final intent in NavIntent.values)
      if (intent != NavIntent.listen) intent: (_) async => ran.add(intent),
  },
);
