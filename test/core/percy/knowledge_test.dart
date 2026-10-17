// Percy's knowledge base: every example question finds its topic (alone, and
// through the real classifier + dialogue manager), unseen wordings still
// work, unsure questions are asked back, and commands are left alone.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/config/percy_config.dart';
import 'package:percipere_app/core/accessibility/nav_intent.dart';
import 'package:percipere_app/core/library/library_models.dart';
import 'package:percipere_app/core/percy/dialogue_manager.dart';
import 'package:percipere_app/core/percy/intent_classifier.dart';
import 'package:percipere_app/core/percy/knowledge_base.dart';
import 'package:percipere_app/core/percy/percy_intent.dart';
import 'package:percipere_app/core/percy/percy_responses.dart';

class _Env implements PercyEnvironment {
  @override
  String? screenId = 'home';
  @override
  bool appQuestionPending = false;
  @override
  bool supports(NavIntent intent) => true;
  @override
  bool supportsAction(String actionId) => true;
  @override
  Future<List<LibraryItem>> libraryItems() async => const [];
}

/// The questions the task named, with the topic each must reach.
const _named = <String, String>{
  'anong kaya mong gawin': 'percy_abilities',
  'ano ang kaya mo': 'percy_abilities',
  'anong kaya mo': 'percy_abilities',
  'ano pwede mong gawin': 'percy_abilities',
  'what can you do': 'percy_abilities',
  'anong purpose mo': 'percy_purpose',
  'ano ang layunin mo': 'percy_purpose',
  'para saan ka': 'percy_purpose',
  "what's your purpose": 'percy_purpose',
  'sino ka': 'percy_who',
  'ano pangalan mo': 'percy_who',
  'who are you': 'percy_who',
  "sino gumawa sa'yo": 'percy_creator',
  'tao ka ba': 'percy_human',
  'ano ang Percipere': 'app_what',
  'para saan ang app na ito': 'app_what',
  'what does this app do': 'app_what',
  'anong features nito': 'app_features',
  'paano magbasa ng dokumento': 'read_document',
  'paano mag-scan': 'scan_document',
  'how do I scan': 'scan_document',
  'paano mag-upload': 'upload_document',
  'pwede bang PDF': 'pdf_support',
  'paano kita kakausapin': 'talk_to_percy',
  'ano ang push to talk': 'push_to_talk',
  'ano ang mga gesture': 'gestures',
  'ano pwede kong sabihin': 'what_can_i_say',
  'what can I say': 'what_can_i_say',
  'paano gamitin ang aklatan': 'library_use',
  'paano mag-download ng libro': 'library_download',
  'paano mag-favorite': 'library_favorite',
  'ano ang collections': 'library_collections',
  'ano ang maglarawan': 'describe_what',
  'paano ilarawan ang larawan': 'describe_how',
  'can you describe pictures': 'describe_how',
  'paano lakihan ang text': 'settings_text_size',
  'paano bagalan ang boses': 'settings_voice_speed',
  'paano palitan ang kulay': 'settings_color',
  'gumagana ka ba kahit walang internet': 'offline_works',
  'ligtas ba ang mga dokumento ko': 'privacy_documents',
  'nakikita mo ba ang password ko': 'privacy_password',
  'paano mag-register': 'register_account',
  'nakalimutan ko ang password': 'forgot_password',
  'pwede bang guest lang': 'guest_mode',
  'tulungan mo ako': 'help_me',
  'hindi ko alam ang gagawin': 'stuck_lost',
  'naliligaw ako': 'stuck_lost',
  'help': 'help_me',
};

/// Wordings that are in no topic's question list.
const _unseen = <String, String>{
  'ano ba talaga ang kaya mong gawin dito': 'percy_abilities',
  'ano ba ang pangalan na itatawag ko sa iyo': 'percy_who',
  'paano ko i-scan ang papel': 'scan_document',
  'pano ko bagalan yung boses mo': 'settings_voice_speed',
  'what if i forgot my password': 'forgot_password',
  'pano ko gagamitin ung aklatan': 'library_use',
};

void main() {
  late KnowledgeBase base;
  late IntentClassifier model;
  late PercyResponses responses;

  setUpAll(() {
    base = KnowledgeBase.parse(
      File(PercyConfig.knowledgeAsset).readAsStringSync(),
    );
    model = IntentClassifier.parse(
      File(PercyConfig.modelAsset).readAsStringSync(),
    );
    responses = PercyResponses.parse(
      File(PercyConfig.personaAsset).readAsStringSync(),
      File(PercyConfig.responsesAsset).readAsStringSync(),
      random: math.Random(1),
    );
  });

  DialogueManager manager() =>
      DialogueManager(model: model, responses: responses, knowledge: base);

  test('every topic has 20+ questions and short answers with a follow-up', () {
    expect(base.topics.length, greaterThanOrEqualTo(30));
    for (final t in base.topics) {
      expect(t.questions.length, greaterThanOrEqualTo(20), reason: t.id);
      for (final lang in ['fil', 'en']) {
        for (final p in ['po', 'casual']) {
          final line = t.answer[lang]![p]!.single;
          expect(line, contains('“'), reason: '${t.id} $lang $p follow-up');
          // 1-3 sentences, then one follow-up (a question and its hint).
          expect(
            line.split(RegExp(r'(?<=[.!?])\s+')).length,
            lessThanOrEqualTo(5),
            reason: '${t.id} $lang $p',
          );
          if (lang == 'fil' && p == 'casual') {
            expect(line, isNot(contains(' po')), reason: t.id);
          }
        }
      }
    }
  });

  test('no question belongs to two topics', () {
    final seen = <String, String>{};
    for (final t in base.topics) {
      for (final q in t.questions) {
        final k = KnowledgeBase.tokens(q).join(' ');
        expect(seen[k] ?? t.id, t.id, reason: q);
        seen[k] = t.id;
      }
    }
  });

  test('every example question returns its own topic', () {
    for (final t in base.topics) {
      for (final q in t.questions) {
        final hits = base.rank(q);
        expect(hits.first.topic.id, t.id, reason: q);
        expect(
          hits.first.score,
          greaterThanOrEqualTo(PercyConfig.knowledgeAnswer),
          reason: q,
        );
      }
    }
  });

  test('the questions named in the task return the right topic', () {
    for (final e in _named.entries) {
      expect(base.rank(e.key).first.topic.id, e.value, reason: e.key);
    }
  });

  test('wordings that are in no list still find the topic', () {
    for (final e in _unseen.entries) {
      final hit = base.rank(e.key).first;
      expect(hit.topic.id, e.value, reason: '${e.key} (${hit.score})');
    }
  });

  test('leave one out: a held-out question still finds its topic '
      '(every 3rd question)', () {
    final json = (jsonDecode(File(PercyConfig.knowledgeAsset).readAsStringSync())
        as Map).cast<String, Object?>();
    final topics = (json['topics']! as List).cast<Map<String, Object?>>();
    var tried = 0;
    final wrong = <String>[];
    for (var t = 0; t < topics.length; t++) {
      final questions = (topics[t]['questions']! as List).cast<String>();
      for (var i = 0; i < questions.length; i += 3) {
        final held = questions[i];
        final copy = [...questions]..removeAt(i);
        topics[t]['questions'] = copy;
        final rest = KnowledgeBase.parse(jsonEncode(json));
        topics[t]['questions'] = questions;
        tried++;
        if (rest.rank(held).first.topic.id != topics[t]['id']) wrong.add(held);
      }
    }
    final accuracy = 1 - wrong.length / tried;
    // ignore: avoid_print
    print(
      'leave-one-out: ${(accuracy * 100).toStringAsFixed(1)}% of $tried; '
      'wrong: $wrong',
    );
    expect(accuracy, greaterThanOrEqualTo(0.85));
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('through the real classifier: every question is answered with the '
      'right topic, in both languages', () async {
    final env = _Env();
    final wrong = <String>[];
    final commandWins = <String>{};
    for (final lang in ['fil', 'en']) {
      for (final t in base.topics) {
        for (final q in t.questions) {
          final r = await manager().handle(q, env, PercyStyle(lang: lang));
          // The dataset's `help` intent owns a few of these phrases ("help
          // me", "tulungan mo ako"): the command wins, by design.
          if (r.intent == PercyIntent.help && r.topic == null) {
            commandWins.add(q);
            continue;
          }
          if (r.topic != t.id ||
              r.outcome != TurnOutcome.knowledge ||
              r.action != null ||
              r.say != base.answer(t, lang, PercyPoliteness.po)) {
            wrong.add('$q → ${r.intent?.label} ${r.outcome.name} ${r.topic}');
          }
        }
      }
    }
    expect(wrong, isEmpty);
    expect(commandWins.length, lessThanOrEqualTo(12), reason: '$commandWins');
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('an unsure question is asked back with the closest topic; yes '
      'answers it, no suggests examples', () async {
    final env = _Env();
    // Share a few words with the Library questions only.
    final dm = manager();
    final r = await dm.handle(
      'ano ang gagawin sa dokumento ng boses',
      env,
      const PercyStyle(),
    );
    expect(r.outcome, TurnOutcome.asked);
    expect(r.topic, isNotNull);
    expect(r.say, contains('Ito po ba ang tinatanong ninyo'));
    final yes = await dm.handle('oo', env, const PercyStyle());
    expect(yes.topic, r.topic);
    expect(yes.outcome, TurnOutcome.knowledge);
  });

  test('"Ito ba ang tinatanong mo?" then "hindi" suggests three examples',
      () async {
    final env = _Env();
    final dm = manager();
    var asked = false;
    // Find a vague question the base is unsure about.
    for (final q in [
      'ano ang gagawin sa dokumento ng boses',
      'ano ang kulay ng langit',
    ]) {
      dm.reset();
      final r = await dm.handle(q, env, const PercyStyle());
      if (r.outcome != TurnOutcome.asked) continue;
      asked = true;
      expect(r.say, contains('Ito po ba ang tinatanong ninyo'));
      final no = await dm.handle('hindi', env, const PercyStyle());
      expect(no.say, contains('ano ang kaya mo'));
      expect(no.say, contains('paano mag-scan ng dokumento'));
      expect(no.say, contains('paano gamitin ang Aklatan'));
      break;
    }
    expect(asked, isTrue, reason: 'no vague question reached the ask band');
  });

  test('a question about nothing we know suggests three examples', () async {
    final r = await manager().handle(
      'ano ang pinakamataas na bundok sa mundo',
      _Env(),
      const PercyStyle(),
    );
    expect(r.action, isNull);
    expect(r.say, contains('ano ang kaya mo'));
    expect(r.say, contains('paano mag-scan ng dokumento'));
    expect(r.say, contains('paano gamitin ang Aklatan'));
  });

  test('commands are never taken for questions', () async {
    final env = _Env();
    final rows = File('data/percy/intents.csv')
        .readAsLinesSync()
        .skip(1)
        .where((l) => !l.contains(',ask_question,'));
    final taken = <String>[];
    var checked = 0;
    for (final line in rows) {
      final text = line.split(',').first;
      if (text.isEmpty) continue;
      final r = await manager().handle(text, env, const PercyStyle());
      if (r.outcome == TurnOutcome.knowledge) taken.add(text);
      checked++;
    }
    expect(checked, greaterThan(900));
    // ignore: avoid_print
    print('command rows answered as questions: $taken');
    expect(taken, isEmpty);
    for (final text in [
      'buksan ang aklatan',
      'bumalik',
      'basahin mo',
      'bilisan',
      'palakihin ang teksto',
      'pumunta sa home',
      'buksan ang settings',
      'ulitin mo',
    ]) {
      final r = await manager().handle(text, env, const PercyStyle());
      expect(r.outcome, isNot(TurnOutcome.knowledge), reason: text);
      expect(r.topic, isNull, reason: text);
    }
  });
}
