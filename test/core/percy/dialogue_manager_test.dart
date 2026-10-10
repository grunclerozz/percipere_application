// Percy's dialogue manager: confidence thresholds, out-of-scope, slots,
// pending questions and the app's own (destructive) confirmations. The
// classifier is scripted here (intent_classifier_test checks the real one);
// the lines come from the real assets/percy files.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/config/percy_config.dart';
import 'package:percipere_app/core/accessibility/nav_intent.dart';
import 'package:percipere_app/core/library/library_models.dart';
import 'package:percipere_app/core/percy/dialogue_manager.dart';
import 'package:percipere_app/core/percy/intent_classifier.dart';
import 'package:percipere_app/core/percy/percy_intent.dart';
import 'package:percipere_app/core/percy/percy_responses.dart';
import 'package:percipere_app/core/percy/slots.dart';

/// Returns whatever the test scripted for a sentence (default: unsure).
class _ScriptedModel implements IntentModel {
  final Map<String, (PercyIntent, double)> script = {};

  @override
  String get version => 'test';

  @override
  IntentPrediction predict(String text) {
    final (intent, p) = script[text] ?? (PercyIntent.outOfScope, 0.1);
    final rest = (1 - p) / (PercyIntent.values.length - 1);
    return IntentPrediction([
      IntentScore(intent.label, p),
      for (final i in PercyIntent.values)
        if (i != intent) IntentScore(i.label, rest),
    ]);
  }
}

class _Env implements PercyEnvironment {
  @override
  String? screenId = 'home';

  @override
  bool appQuestionPending = false;

  final Set<NavIntent> unsupported = {};

  List<LibraryItem> items = [];

  @override
  bool supports(NavIntent intent) => !unsupported.contains(intent);

  @override
  Future<List<LibraryItem>> libraryItems() async => items;
}

LibraryItem _item(String id, String title) => LibraryItem(
  id: id,
  source: LibrarySource.upload,
  format: LibraryFormat.pdf,
  language: 'fil',
  title: title,
  createdAt: DateTime(2026, 10, 1),
);

void main() {
  late PercyResponses responses;
  late _ScriptedModel model;
  late _Env env;
  late DialogueManager dm;
  var now = DateTime(2026, 10, 10, 9);
  const style = PercyStyle();

  setUpAll(() {
    responses = PercyResponses.parse(
      File(PercyConfig.personaAsset).readAsStringSync(),
      File(PercyConfig.responsesAsset).readAsStringSync(),
      random: math.Random(1),
    );
  });

  setUp(() {
    model = _ScriptedModel();
    env = _Env();
    now = DateTime(2026, 10, 10, 9);
    dm = DialogueManager(model: model, responses: responses, clock: () => now);
  });

  Future<PercyReply> say(String text, [(PercyIntent, double)? as]) {
    if (as != null) model.script[text] = as;
    return dm.handle(text, env, style);
  }

  group('confidence thresholds', () {
    test('≥ 0.60 acts', () async {
      final r = await say('dalhin mo ako sa aklatan', (
        PercyIntent.openLibrary,
        0.82,
      ));
      expect(r.outcome, TurnOutcome.acted);
      expect((r.action! as RunIntent).intent, NavIntent.library);
      expect(r.say, isNotEmpty); // moving screens: a short acknowledgement
    });

    test('exactly the act threshold acts', () async {
      final r = await say('x', (PercyIntent.back, PercyConfig.actThreshold));
      expect(r.outcome, TurnOutcome.acted);
    });

    test('0.30–0.60 asks "Ang ibig mo bang sabihin…?", yes runs it', () async {
      final r = await say('ilakas mo yung boses', (PercyIntent.faster, 0.45));
      expect(r.outcome, TurnOutcome.asked);
      expect(r.action, isNull);
      expect(r.say, contains('Ang ibig mo po bang sabihin ay bilisan'));
      final yes = await say('oo', (PercyIntent.yes, 0.9));
      expect(yes.outcome, TurnOutcome.confirmed);
      expect((yes.action! as RunIntent).intent, NavIntent.faster);
    });

    test('"no" or "cancel" to Percy\'s question: nothing happens', () async {
      await say('ilakas mo', (PercyIntent.faster, 0.45));
      final no = await say('hindi', (PercyIntent.no, 0.5));
      expect(no.outcome, TurnOutcome.corrected);
      expect(no.action, isNull);

      await say('ilakas mo', (PercyIntent.faster, 0.45));
      final cancel = await say('wag na', (PercyIntent.cancel, 0.8));
      expect(cancel.outcome, TurnOutcome.corrected); // same as no
      expect(cancel.action, isNull);
    });

    test(
      'below 0.30: "Hindi ko pa kaya iyan" with screen suggestions',
      () async {
        final r = await say('mmm ano nga', (PercyIntent.read, 0.2));
        expect(r.outcome, TurnOutcome.fallback);
        expect(r.action, isNull);
        expect(r.say, startsWith('Hindi ko pa po kaya iyan.'));
        expect(r.say, contains('“buksan ang Aklatan”')); // Home's suggestions
      },
    );

    test('Percy\'s question expires', () async {
      await say('ilakas mo', (PercyIntent.faster, 0.45));
      now = now.add(PercyConfig.questionValid + const Duration(seconds: 1));
      final r = await say('oo', (PercyIntent.yes, 0.9));
      expect(r.outcome, TurnOutcome.chat); // nothing was asked any more
    });
  });

  group('out of scope', () {
    test('a confident out_of_scope falls back', () async {
      env.screenId = 'reader';
      final r = await say('sino ang presidente', (PercyIntent.outOfScope, 0.9));
      expect(r.outcome, TurnOutcome.fallback);
      expect(r.say, contains('“i-pause”')); // Reader suggestions
    });

    test('English and casual style', () async {
      final r = await dm.handle(
        'sing a song',
        env,
        const PercyStyle(lang: 'en', politeness: PercyPoliteness.casual),
      );
      expect(r.say, startsWith("I can't do that yet."));
    });
  });

  test('an action this screen doesn\'t have is explained', () async {
    env.unsupported.add(NavIntent.faster);
    final r = await say('bilisan mo', (PercyIntent.faster, 0.9));
    expect(r.outcome, TurnOutcome.notAvailable);
    expect(r.action, isNull);
    expect(r.say, contains('screen na ito'));
  });

  test('talkativeness: brief has no acknowledgement', () async {
    model.script['home'] = (PercyIntent.openHome, 0.9);
    final r = await dm.handle(
      'home',
      env,
      const PercyStyle(talk: PercyTalk.brief),
    );
    expect(r.say, isEmpty);
    expect(r.action, isA<RunIntent>());
  });

  test('goodbye ends the session; greeting and thanks are chat', () async {
    final bye = await say('paalam na', (PercyIntent.goodbye, 0.9));
    expect(bye.action, isA<EndSession>());
    expect(bye.say, isNotEmpty);
    final hi = await say('hello', (PercyIntent.greeting, 0.9));
    expect(hi.outcome, TurnOutcome.chat);
    expect(hi.action, isNull);
  });

  test('"nasaan ako" asks the app', () async {
    final r = await say('nasaan ako', (PercyIntent.whereAmI, 0.9));
    expect(r.action, isA<TellWhereAmI>());
  });

  group('the app\'s own questions (destructive actions)', () {
    test('"oo" confirms the app\'s "Burahin ito?"', () async {
      env.appQuestionPending = true;
      final r = await say('oo sige', (PercyIntent.yes, 0.7));
      expect(r.outcome, TurnOutcome.answered);
      expect((r.action! as AnswerApp).yes, isTrue);
    });

    test('"hindi" or "wag na" declines it', () async {
      env.appQuestionPending = true;
      final no = await say('hindi', (PercyIntent.no, 0.49));
      expect((no.action! as AnswerApp).yes, isFalse);
      final cancel = await say('wag na lang', (PercyIntent.cancel, 0.74));
      expect((cancel.action! as AnswerApp).yes, isFalse);
    });

    test('yes-words work even when the model is unsure', () async {
      env.appQuestionPending = true;
      final r = await say('opo', (PercyIntent.outOfScope, 0.2));
      expect((r.action! as AnswerApp).yes, isTrue);
    });

    test('something else is not taken as an answer', () async {
      env.appQuestionPending = true;
      final r = await say('buksan ang settings', (
        PercyIntent.openSettings,
        0.9,
      ));
      expect(r.action, isA<RunIntent>());
    });
  });

  group('open_item slots', () {
    setUp(() {
      env.items = [
        _item('a', 'Bill ng Meralco'),
        _item('b', 'Liham kay Nanay'),
        _item('c', 'Resibo sa Puregold'),
      ];
    });

    test('one title match opens it', () async {
      final r = await say('buksan mo yung liham kay nanay', (
        PercyIntent.openItem,
        0.9,
      ));
      expect((r.action! as OpenDocument).item.id, 'b');
      expect(r.say, contains('Liham kay Nanay'));
    });

    test('a named document opens even when the classifier is unsure', () async {
      // Titles are new words to the model: the slot rule goes first.
      final r = await say('basahin mo yung liham kay nanay', (
        PercyIntent.read,
        0.18,
      ));
      final open = r.action! as OpenDocument;
      expect(open.item.id, 'b');
      expect(open.play, isTrue); // "basahin" reads at once
      final b = await say('buksan mo yung bill ng meralco', (
        PercyIntent.openItem,
        0.24,
      ));
      expect((b.action! as OpenDocument).play, isFalse);
    });

    test('a confident other command wins over a title-like word', () async {
      env.items = [_item('s', 'Settings ng printer')];
      final r = await say('buksan ang settings', (
        PercyIntent.openSettings,
        0.9,
      ));
      expect((r.action! as RunIntent).intent, NavIntent.settings);
    });

    test('a misheard title still matches', () async {
      final r = await say('basahin ang resibo sa puregol', (
        PercyIntent.openItem,
        0.9,
      ));
      expect((r.action! as OpenDocument).item.id, 'c');
    });

    test('no match: says so and offers the Library search', () async {
      final r = await say('buksan ang noli me tangere', (
        PercyIntent.openItem,
        0.9,
      ));
      expect(r.action, isNull);
      expect(r.say, contains('noli me tangere'));
      final yes = await say('oo', (PercyIntent.yes, 0.9));
      expect((yes.action! as RunIntent).intent, NavIntent.library);
    });

    test('several matches: asks which, "yung pangalawa" picks', () async {
      env.items = [
        _item('1', 'Liham kay Nanay'),
        _item('2', 'Liham kay Tatay'),
        _item('3', 'Bill ng Meralco'),
      ];
      final r = await say('buksan ang liham', (PercyIntent.openItem, 0.9));
      expect(r.outcome, TurnOutcome.asked);
      expect(r.say, contains('Liham kay Nanay'));
      expect(r.say, contains('Liham kay Tatay'));
      final pick = await say('yung pangalawa', (PercyIntent.outOfScope, 0.3));
      expect((pick.action! as OpenDocument).item.id, '2');
    });

    test(
      'missing title: asks which (up to 3) and fills from the answer',
      () async {
        env.items = [for (var i = 1; i <= 5; i++) _item('$i', 'Dokumento $i')];
        final r = await say('may bubuksan ako', (PercyIntent.openItem, 0.8));
        expect(r.outcome, TurnOutcome.asked);
        expect(r.say, contains('Dokumento 3'));
        expect(r.say, isNot(contains('Dokumento 4')));
        final pick = await say('dokumento 3', (PercyIntent.openItem, 0.5));
        expect((pick.action! as OpenDocument).item.id, '3');
      },
    );

    test('"ang huli" opens the most recent', () async {
      final r = await say('buksan ang huli', (PercyIntent.openItem, 0.9));
      expect((r.action! as OpenDocument).item.id, 'a');
    });

    test('cancel while choosing', () async {
      await say('may bubuksan ako', (PercyIntent.openItem, 0.8));
      final r = await say('wag na', (PercyIntent.cancel, 0.8));
      expect(r.outcome, TurnOutcome.declined);
      expect(r.action, isNull);
    });

    test('empty Library', () async {
      env.items = [];
      final r = await say('buksan ang liham', (PercyIntent.openItem, 0.9));
      expect(r.action, isNull);
      expect(r.say, contains('Wala pa pong laman'));
    });
  });

  group('slot helpers', () {
    test('ordinals', () {
      expect(PercySlots.ordinal('yung pangalawa'), 1);
      expect(PercySlots.ordinal('the first one'), 0);
      expect(PercySlots.ordinal('yung huli po'), -1);
      expect(PercySlots.ordinal('number 3'), 2);
      expect(PercySlots.ordinal('buksan mo'), isNull);
    });

    test('title words drop the command around them', () {
      expect(
        PercySlots.titleWords(
          'Percy, pakibukas mo nga po yung Liham kay Nanay',
        ),
        'liham kay nanay',
      );
      expect(PercySlots.titleWords('open my receipt'), 'receipt');
      expect(PercySlots.titleWords('buksan mo'), '');
    });
  });

  test('remembers the last 3 turns and the last intent', () async {
    for (final t in ['a', 'b', 'c', 'd']) {
      await say(t, (PercyIntent.help, 0.9));
    }
    expect(dm.history.map((t) => t.text), ['b', 'c', 'd']);
    expect(dm.lastIntent, PercyIntent.help);
  });

  test('every dialogue line exists in responses.json', () {
    for (final key in PercyResponses.dialogueKeys) {
      for (final lang in ['fil', 'en']) {
        for (final p in PercyPoliteness.values) {
          expect(
            responses.dialogue(key, lang, p),
            isNotEmpty,
            reason: '$key $lang $p',
          );
        }
      }
    }
    for (final i in PercyIntent.values) {
      expect(responses.actionName(i, 'fil'), isNot(i.label), reason: i.label);
    }
  });
}
