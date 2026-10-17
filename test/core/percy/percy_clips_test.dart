import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/accessibility/announcer.dart';
import 'package:percipere_app/core/percy/percy_clips.dart';
import 'package:percipere_app/core/percy/percy_responses.dart';

import '../../helpers/fakes.dart';

class _FakePlayer implements ClipPlayer {
  final List<double> rates = [];
  int stops = 0;
  ClipResult result = ClipResult.finished;
  Completer<ClipResult>? _pending;
  bool hold = false;

  @override
  Future<ClipResult> play(Uint8List bytes, double rate) {
    rates.add(rate);
    if (!hold) return Future.value(result);
    return (_pending = Completer<ClipResult>()).future;
  }

  @override
  Future<void> stop() async {
    stops++;
    final p = _pending;
    if (p != null && !p.isCompleted) p.complete(ClipResult.stopped);
  }
}

PercyClipManifest _manifest() => PercyClipManifest.parse(
  jsonEncode({
    'version': 1,
    'clips': {
      // Hashes computed with the generation script's rule (Python sha256).
      'ab3c3a3bd3fcd78f': {'file': 'fil_ab3c3a3bd3fcd78f.mp3'},
      '7e637162ced67c39': {'file': 'en_7e637162ced67c39.mp3'},
    },
  }),
);

Future<Uint8List?> _load(String file) async => Uint8List.fromList([1, 2, 3]);

void main() {
  group('clip lookup by hash', () {
    test('same hash as the Python generation script', () {
      expect(
        PercyClipKey.hash('fil', 'Sige po, sa Home tayo.'),
        'ab3c3a3bd3fcd78f',
      );
      expect(PercyClipKey.hash('en', 'Anything else?'), '7e637162ced67c39');
    });

    test('whitespace does not change the hash; language does', () {
      expect(
        PercyClipKey.hash('fil', '  Sige po,  sa Home\ntayo. '),
        'ab3c3a3bd3fcd78f',
      );
      expect(
        PercyClipKey.hash('en', 'Sige po, sa Home tayo.'),
        isNot('ab3c3a3bd3fcd78f'),
      );
    });

    test('finds the file, or null', () {
      final m = _manifest();
      expect(m.fileFor('fil', 'Sige po, sa Home tayo.'), isNotNull);
      expect(m.fileFor('en', 'Anything else?'), 'en_7e637162ced67c39.mp3');
      expect(m.fileFor('fil', 'Ibang pangungusap.'), isNull);
    });

    test('broken or empty manifest gives no clips', () {
      expect(PercyClipManifest.parse('not json').files, isEmpty);
      expect(PercyClipManifest.parse('{"version":1,"clips":{}}').files, isEmpty);
    });

    test('sentences are split like the Announcer', () {
      const text = 'Isa. Dalawa?  Tatlo! Apat… lima';
      expect(PercyClipKey.sentences(text), Announcer.splitSentences(text));
    });

    test('fixed sentences skip {placeholders}', () {
      final r = PercyResponses.parse(
        '{"greeting":{"fil":{"po":["Hello po. Ako si Percy."]}}}',
        '{"intents":{"x":{"en":{"po":["Opening {title}. Done."]}}},"dialogue":{}}',
      );
      expect(r.fixedSentences(), {
        ('fil', 'Hello po.'),
        ('fil', 'Ako si Percy.'),
        ('en', 'Done.'),
      });
    });
  });

  group('Announcer with clips', () {
    late TestEnv env;
    late ProviderContainer container;
    late _FakePlayer player;
    Announcer announcer() => container.read(announcerProvider.notifier);

    Future<void> setUpWith({PercyClipManifest? manifest}) async {
      player = _FakePlayer();
      env = await TestEnv.create(tts: FakeTts());
      container = ProviderContainer(
        overrides: [
          ...env.overrides,
          percyClipsProvider.overrideWithValue(
            PercyClips(
              manifest: manifest ?? _manifest(),
              player: player,
              load: _load,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(announcerProvider, (_, _) {});
    }

    test('a fixed sentence plays its clip, not the offline voice', () async {
      await setUpWith();
      await announcer().say(
        'Sige po, sa Home tayo.',
        languageTag: 'fil-PH',
        rate: 1.25,
      );
      expect(player.rates, [1.25], reason: 'speech speed is the clip rate');
      expect(env.tts.spoken, isEmpty);
    });

    test('no clip for the sentence: the offline voice speaks it', () async {
      await setUpWith();
      await announcer().say('Aklat: Noli Me Tangere.', languageTag: 'fil-PH');
      expect(player.rates, isEmpty);
      expect(env.tts.spoken, ['Aklat: Noli Me Tangere.']);
    });

    test('mixed text: clip for the fixed sentence, voice for the rest', () async {
      await setUpWith();
      await announcer().say(
        'Sige po, sa Home tayo. Mayroon kayong 3 aklat.',
        languageTag: 'fil-PH',
      );
      expect(player.rates, hasLength(1));
      expect(env.tts.spoken, ['Mayroon kayong 3 aklat.']);
    });

    test('a clip that cannot play falls back to the offline voice', () async {
      await setUpWith();
      player.result = ClipResult.failed;
      await announcer().say('Sige po, sa Home tayo.', languageTag: 'fil-PH');
      expect(env.tts.spoken, ['Sige po, sa Home tayo.']);
    });

    test('zero clips: everything is spoken by the offline voice', () async {
      await setUpWith(manifest: PercyClipManifest.empty);
      await announcer().say('Sige po, sa Home tayo.', languageTag: 'fil-PH');
      expect(player.rates, isEmpty);
      expect(env.tts.spoken, ['Sige po, sa Home tayo.']);
    });

    test('push-to-talk (stopAndWait) stops the clip, nothing is re-spoken', () async {
      await setUpWith();
      player.hold = true;
      final done = announcer().say(
        'Sige po, sa Home tayo.',
        languageTag: 'fil-PH',
      );
      await pumpEventQueue();
      expect(player.rates, hasLength(1));

      await announcer().stopAndWait(
        max: const Duration(milliseconds: 200),
        focusGap: Duration.zero,
      );
      await done;

      expect(player.stops, 1);
      expect(env.tts.spoken, isEmpty, reason: 'a stopped clip is not repeated');
    });

    test('a stop while the clip is still loading keeps it from starting', () async {
      final loading = Completer<Uint8List?>();
      final clips = PercyClips(
        manifest: _manifest(),
        player: _FakePlayer(),
        load: (_) => loading.future,
      );
      final result = clips.play('Sige po, sa Home tayo.', 'fil-PH', 1);
      await pumpEventQueue();
      await clips.stop();
      loading.complete(Uint8List.fromList([1]));
      expect(await result, ClipResult.stopped);
    });
  });

  test('clip stats count sentences with a clip', () {
    final clips = PercyClips(
      manifest: _manifest(),
      player: _FakePlayer(),
      load: _load,
    );
    expect(
      clips.countWithClips({
        ('fil', 'Sige po, sa Home tayo.'),
        ('fil', 'Wala pa.'),
        ('en', 'Anything else?'),
      }),
      2,
    );
  });
}
