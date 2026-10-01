import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/accessibility/nav_intent.dart';
import 'package:percipere_app/core/voice/command_matcher.dart';
import 'package:percipere_app/core/voice/voice_commands.dart';

void main() {
  const matcher = CommandMatcher();
  final global = [
    for (final e in globalVoiceCommands.entries)
      for (final p in e.value) CommandPhrase(p, ValueTarget(e.key)),
  ];

  NavIntent? intentOf(String heard) => switch (matcher.match(heard, global)) {
    Matched(target: ValueTarget(:final NavIntent value)) => value,
    _ => null,
  };

  group('normalize', () {
    test('lowercases, drops diacritics, hyphens and punctuation', () {
      expect(CommandMatcher.normalize('I-Pause!'), 'ipause');
      expect(CommandMatcher.normalize('Pakibasa,  PÓ…'), 'pakibasa po');
      expect(CommandMatcher.normalize('Kasaysayán?'), 'kasaysayan');
      expect(CommandMatcher.normalize('Señor'), 'senor');
    });
  });

  test('levenshtein and similarity', () {
    expect(CommandMatcher.levenshtein('kamera', 'camera'), 1);
    expect(CommandMatcher.levenshtein('', 'abc'), 3);
    expect(CommandMatcher.similarity('abc', 'abc'), 1);
    expect(CommandMatcher.similarity('kamira', 'camera'), closeTo(0.667, 0.01));
  });

  group('every required command in both languages', () {
    const pairs = {
      'basahin': NavIntent.read,
      'read': NavIntent.read,
      'i-pause': NavIntent.pause,
      'pause': NavIntent.pause,
      'ituloy': NavIntent.resume,
      'continue': NavIntent.resume,
      'itigil': NavIntent.stopSpeech,
      'stop': NavIntent.stopSpeech,
      'ulitin': NavIntent.repeat,
      'susunod': NavIntent.next,
      'next': NavIntent.next,
      'nakaraan': NavIntent.previous,
      'previous': NavIntent.previous,
      'bumalik': NavIntent.back,
      'back': NavIntent.back,
      'bilisan': NavIntent.faster,
      'bagalan': NavIntent.slower,
      'kamera': NavIntent.camera,
      'kunan': NavIntent.capture,
      'mag-upload': NavIntent.upload,
      'i-save': NavIntent.save,
      'kasaysayan': NavIntent.history,
      'ayos': NavIntent.settings,
      'tulong': NavIntent.help,
      'simula': NavIntent.home,
      'ulat': NavIntent.report,
      'feedback': NavIntent.report,
    };
    for (final MapEntry(key: heard, value: intent) in pairs.entries) {
      test(heard, () => expect(intentOf(heard), intent));
    }
  });

  test('hyphenated commands match however the recognizer splits them', () {
    expect(intentOf('i pause'), NavIntent.pause);
    expect(intentOf('ipause'), NavIntent.pause);
    expect(intentOf('mag upload'), NavIntent.upload);
  });

  test('commands inside a longer sentence', () {
    expect(intentOf('basahin mo nga'), NavIntent.read);
    expect(intentOf('please go back'), NavIntent.back);
    expect(intentOf('Tulong po!'), NavIntent.help);
  });

  test('small recognition errors still match', () {
    expect(intentOf('kamira'), NavIntent.camera); // vs "kamera"
    expect(intentOf('tulung'), NavIntent.help);
    expect(intentOf('susonod'), NavIntent.next);
  });

  test('close-but-unsure asks back with the best phrase', () {
    final result = matcher.match('bilis', global);
    expect(result, isA<Ambiguous>());
    expect((result as Ambiguous).phrase, 'bilisan');
  });

  test('two different commands in one utterance asks instead of guessing', () {
    expect(matcher.match('ulitin basahin', global), isA<Ambiguous>());
  });

  test('longer phrases win over shorter ones they contain', () {
    expect(intentOf('susunod na talata'), NavIntent.nextParagraph);
    expect(intentOf('nakaraang talata po'), NavIntent.previousParagraph);
    expect(intentOf('basahin mula sa simula'), NavIntent.readFromStart);
    expect(intentOf('susunod'), NavIntent.next);
  });

  test('unrelated speech is no match', () {
    expect(matcher.match('saging at mangga', global), isA<NoMatch>());
    expect(matcher.match('', global), isA<NoMatch>());
  });

  test('yes and no', () {
    final yesNo = [
      for (final w in yesWords) CommandPhrase(w, const ValueTarget(true)),
      for (final w in noWords) CommandPhrase(w, const ValueTarget(false)),
    ];
    for (final w in ['oo', 'Opo.', 'yes', 'sige po']) {
      final r = matcher.match(w, yesNo);
      expect(r, isA<Matched>(), reason: w);
      expect((r as Matched).target, const ValueTarget(true), reason: w);
    }
    for (final w in ['hindi', 'no', 'huwag na']) {
      final r = matcher.match(w, yesNo) as Matched;
      expect(r.target, const ValueTarget(false), reason: w);
    }
  });
}
