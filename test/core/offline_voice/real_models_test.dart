// Runs the real offline engines on this PC (sherpa-onnx native library) with
// the packaged model archives. Skipped unless PERCIPERE_MODELS points at the
// folder holding the three .tar.gz files (tool/voice_models/README.md); on
// Windows also set SHERPA_DLL_DIR to the sherpa_onnx_windows plugin's
// `windows` folder.
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/accessibility/nav_intent.dart';
import 'package:percipere_app/core/offline_voice/command_recognizer.dart';
import 'package:percipere_app/core/offline_voice/model_catalog.dart';
import 'package:percipere_app/core/offline_voice/model_store.dart';
import 'package:percipere_app/core/offline_voice/offline_speaker.dart';
import 'package:percipere_app/core/voice/command_matcher.dart';
import 'package:percipere_app/core/voice/voice_commands.dart';

class CapturePlayer implements PcmPlayer {
  final List<(Float32List, int)> played = [];
  @override
  Future<bool> play(Float32List samples, int sampleRate) async {
    played.add((samples, sampleRate));
    return true;
  }

  @override
  Future<void> stop() async {}
}

Uint8List pcm16(Float32List samples, int rate) {
  // To 16 kHz by linear interpolation, then PCM16 with 0.4 s of silence
  // on both sides (as if said into the microphone).
  final n = (samples.length * 16000 / rate).floor();
  final out = Int16List(n + 12800);
  for (var i = 0; i < n; i++) {
    final x = i * (samples.length - 1) / (n - 1);
    final a = samples[x.floor()];
    final b = samples[x.ceil()];
    final v = a + (b - a) * (x - x.floor());
    out[6400 + i] = (v.clamp(-1.0, 1.0) * 32767).round();
  }
  return out.buffer.asUint8List();
}

void main() {
  final dir = Platform.environment['PERCIPERE_MODELS'];
  final skip = dir == null ? 'PERCIPERE_MODELS not set' : null;
  late ModelStore store;
  late Directory tmp;

  setUpAll(() async {
    if (dir == null) return;
    // Windows has its own older onnxruntime.dll in System32: load the
    // plugin's first (SHERPA_DLL_DIR = sherpa_onnx_windows/windows).
    final dlls = Platform.environment['SHERPA_DLL_DIR'];
    if (Platform.isWindows && dlls != null) {
      DynamicLibrary.open('$dlls/onnxruntime.dll');
      DynamicLibrary.open('$dlls/sherpa-onnx-c-api.dll');
    }
    tmp = Directory.systemTemp.createTempSync('real_models');
    store = ModelStore(tmp.path);
    for (final m in OfflineModelCatalog.builtIn) {
      final file = File('$dir/${m.url.split('/').last}');
      final copy = File('${tmp.path}/${m.name}.tar.gz')
        ..writeAsBytesSync(file.readAsBytesSync());
      expect(copy.lengthSync(), m.size, reason: '${m.name} size');
      expect(
        sha256.convert(copy.readAsBytesSync()).toString(),
        m.sha256,
        reason: '${m.name} checksum',
      );
      await store.install(m, copy);
    }
  });

  tearDownAll(() {
    if (dir != null) tmp.deleteSync(recursive: true);
  });

  test('the archives unpack into complete engines', () {
    final asr = store.installed(OfflineModelCatalog.commandsName)!;
    expect(RecognizerFiles(asr.dir).complete, isTrue);
    for (final n in [
      OfflineModelCatalog.filipinoVoiceName,
      OfflineModelCatalog.englishVoiceName,
    ]) {
      expect(OfflineVoiceFiles.usable(store.installed(n)!.dir), isTrue);
    }
  }, skip: skip);

  test('the Tagalog voice speaks, and the recognizer hears the command',
      () async {
    final player = CapturePlayer();
    final speaker = await OfflineSpeaker.start(
      OfflineVoiceFiles(
        tagalogDir: store.installed(OfflineModelCatalog.filipinoVoiceName)!.dir,
        englishDir: store.installed(OfflineModelCatalog.englishVoiceName)!.dir,
      ),
      player: player,
    );
    expect(speaker, isNotNull);
    final watch = Stopwatch()..start();
    expect(
      await speaker!.speak(
        'Pakihintay habang dina-download namin ang mga boses at wika.',
        tag: 'fil-PH',
      ),
      isTrue,
    );
    debugPrint('Tagalog prompt generated in ${watch.elapsedMilliseconds}ms');
    expect(await speaker.speak('Ready. Page 12 of 20.', tag: 'en-US'), isTrue);
    expect(player.played, hasLength(2));
    expect(player.played.first.$1.length, greaterThan(16000));

    final started = await CommandRecognizer.start(
      RecognizerFiles(store.installed(OfflineModelCatalog.commandsName)!.dir),
    );
    expect(started, isNotNull);
    final recognizer = started!;
    Future<String> hear(Float32List samples, int rate, String language) async {
      final session = DateTime.now().microsecondsSinceEpoch & 0x3fffffff;
      final texts = <String>[];
      final sub = recognizer.events.listen((e) {
        if (e is SpeechRecognized && e.session == session) texts.add(e.text);
      });
      recognizer.begin(session, language);
      final bytes = pcm16(samples, rate);
      for (var i = 0; i < bytes.length; i += 3200) {
        recognizer.feed(session, bytes.sublist(i, (i + 3200).clamp(0, bytes.length)));
      }
      for (var i = 0; i < 10; i++) {
        recognizer.feed(session, Uint8List(3200));
      }
      recognizer.flush(session);
      await recognizer.events
          .firstWhere((e) => e is RecognizerFlushed && e.session == session)
          .timeout(const Duration(seconds: 30));
      await sub.cancel();
      return CommandRecognizer.clean(texts.join(' '));
    }

    final phrases = [
      for (final MapEntry(:key, :value) in globalVoiceCommands.entries)
        for (final p in value) CommandPhrase(p, ValueTarget(key)),
    ];
    const matcher = CommandMatcher();
    // Warm: the second generation shows the steady speed.
    watch.reset();
    await speaker.speak('Bumalik sa nakaraang pahina.', tag: 'fil-PH');
    debugPrint('warm Tagalog sentence in ${watch.elapsedMilliseconds}ms');

    var right = 0, asked = 0, total = 0;
    final tests = <(String, NavIntent, String)>[
      ('buksan ang aklatan', NavIntent.library, 'fil-PH'),
      ('susunod', NavIntent.next, 'fil-PH'),
      ('bumalik', NavIntent.back, 'fil-PH'),
      ('basahin', NavIntent.read, 'fil-PH'),
      ('itigil', NavIntent.stopSpeech, 'fil-PH'),
      ('ulitin', NavIntent.repeat, 'fil-PH'),
      ('bilisan', NavIntent.faster, 'fil-PH'),
      ('bagalan', NavIntent.slower, 'fil-PH'),
      ('tulong', NavIntent.help, 'fil-PH'),
      ('susunod na kabanata', NavIntent.nextChapter, 'fil-PH'),
      ('mga paborito ko', NavIntent.favorites, 'fil-PH'),
      ('kausapin si Percy', NavIntent.assistant, 'fil-PH'),
      ('next', NavIntent.next, 'en-US'),
      ('go back', NavIntent.back, 'en-US'),
      ('open the library', NavIntent.library, 'en-US'),
      ('pause', NavIntent.pause, 'en-US'),
      ('read from the beginning', NavIntent.readFromStart, 'en-US'),
      ('settings', NavIntent.settings, 'en-US'),
    ];
    for (final (text, intent, tag) in tests) {
      player.played.clear();
      await speaker.speak(text, tag: tag);
      final (samples, rate) = player.played.single;
      final t = Stopwatch()..start();
      final heard = await hear(samples, rate, tag.startsWith('en') ? 'en' : 'tl');
      final result = matcher.match(heard, phrases);
      total++;
      final said = CommandMatcher.tokens(heard).join(' ');
      final named = globalVoiceCommands[intent]!.any(
        (p) => ' $said '.contains(' ${CommandMatcher.tokens(p).join(' ')} '),
      );
      final verdict = switch (result) {
        // The command bus also runs "open X" / "read X" as X.
        _ when named && result is! NoMatch => 'RIGHT',
        Matched(:final target) when target == ValueTarget(intent) => 'RIGHT',
        Ambiguous(:final target) when target == ValueTarget(intent) => 'ASKED',
        Matched() => 'WRONG',
        Ambiguous() => 'ASKED-WRONG',
        NoMatch() => 'NO MATCH',
      };
      if (verdict == 'RIGHT') right++;
      if (verdict == 'ASKED') asked++;
      debugPrint('$verdict "$text" heard "$heard" (${t.elapsedMilliseconds}ms)');
    }
    debugPrint('synthetic commands: $right/$total right, $asked asked '
        '"Ito ba ang ibig mong sabihin...?"');
    expect(right + asked, greaterThan(0));
    await recognizer.dispose();
    await speaker.dispose();
  }, skip: skip, timeout: const Timeout(Duration(minutes: 3)));
}
