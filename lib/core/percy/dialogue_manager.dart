import 'package:flutter/foundation.dart';

import '../../app/ids.dart';
import '../../config/percy_config.dart';
import '../accessibility/nav_intent.dart';
import '../library/library_models.dart';
import '../library/library_view.dart';
import '../tts/reading_rate.dart';
import '../voice/understanding.dart';
import '../voice/voice_commands.dart';
import 'intent_classifier.dart';
import 'knowledge_base.dart';
import 'percy_intent.dart';
import 'percy_responses.dart';
import 'percy_text.dart';
import 'slots.dart';

/// What the dialogue manager needs to know about the app right now.
/// Implemented by `PercyController` (and by fakes in tests).
abstract interface class PercyEnvironment {
  /// The active screen's id.
  String? get screenId;

  /// The app itself asked a yes/no question (e.g. "Burahin ito?") that is
  /// still waiting for an answer.
  bool get appQuestionPending;

  /// Whether [intent] does something on the active screen.
  bool supports(NavIntent intent);

  /// Whether the active screen exposes this existing accessibility action.
  bool supportsAction(String actionId);

  /// The user's Library, most recently opened first.
  Future<List<LibraryItem>> libraryItems();
}

/// How Percy talks this turn.
@immutable
class PercyStyle {
  /// Creates a style.
  const PercyStyle({
    this.lang = 'fil',
    this.politeness = PercyPoliteness.po,
    this.talk = PercyTalk.normal,
  });

  /// `fil` or `en` (the app's speech language).
  final String lang;

  /// With or without "po".
  final PercyPoliteness politeness;

  /// How much Percy says.
  final PercyTalk talk;
}

/// What Percy does in the app after speaking (always through the
/// CommandBus or the Library's own actions).
@immutable
sealed class PercyAction {
  const PercyAction();
}

/// Runs an app command ([NavIntent]) on the active screen.
final class RunIntent extends PercyAction {
  /// Creates the action.
  const RunIntent(this.intent);

  /// The command.
  final NavIntent intent;
}

/// Runs an existing accessibility action on the active screen.
final class RunAction extends PercyAction {
  /// Creates the action.
  const RunAction(this.actionId);

  /// Stable id from [Ids].
  final String actionId;
}

/// Sets an existing named reading-speed preset through the CommandBus.
final class SetSpeed extends PercyAction {
  /// Creates the action.
  const SetSpeed(this.speed);

  /// The setup speed preset to apply.
  final SpeechSpeed speed;
}

/// Opens a Library document in the Reader.
final class OpenDocument extends PercyAction {
  /// Creates the action.
  const OpenDocument(this.item, {this.play = false});

  /// The document.
  final LibraryItem item;

  /// Start reading at once ("basahin ang …").
  final bool play;
}

/// Answers the app's own pending question.
final class AnswerApp extends PercyAction {
  /// Creates the action.
  const AnswerApp({required this.yes});

  /// Yes or no.
  final bool yes;
}

/// Says where the user is (the app's "nasaan ako?").
final class TellWhereAmI extends PercyAction {
  /// Creates the action.
  const TellWhereAmI();
}

/// Ends the Percy session.
final class EndSession extends PercyAction {
  /// Creates the action.
  const EndSession();
}

/// How a turn ended (logged for retraining).
enum TurnOutcome {
  /// Acted on a confident prediction.
  acted,

  /// The user confirmed Percy's "did you mean …?".
  confirmed,

  /// The user said no to Percy's "did you mean …?" (the guess was wrong).
  corrected,

  /// The user declined or cancelled something else.
  declined,

  /// Percy asked "did you mean …?" or "which one?".
  asked,

  /// Not understood / out of scope: suggestions given.
  fallback,

  /// Small talk (greeting, thanks).
  chat,

  /// Answered the app's own question.
  answered,

  /// The intent can't be done on this screen.
  notAvailable,

  /// An exact command handled by the app's phrase matcher.
  matcher,

  /// A question about Percy or the app, answered from the knowledge base
  /// (or asked back / suggested examples).
  knowledge,
}

/// One turn's result: what to say, then what to do.
@immutable
class PercyReply {
  /// Creates a reply.
  const PercyReply({
    this.say = '',
    this.action,
    required this.outcome,
    this.intent,
    this.confidence,
    this.topic,
  });

  /// What Percy says first (may be empty).
  final String say;

  /// What happens in the app after speaking, if anything.
  final PercyAction? action;

  /// How the turn ended.
  final TurnOutcome outcome;

  /// The intent the turn was about (for the log).
  final PercyIntent? intent;

  /// The classifier's confidence in [intent], if it was used.
  final double? confidence;

  /// The knowledge topic answered or asked about, if any.
  final String? topic;
}

/// One remembered turn.
typedef PercyTurn = ({String text, String? intent});

sealed class _Pending {
  _Pending(DateTime now) : expires = now.add(PercyConfig.questionValid);
  final DateTime expires;
}

/// "Ang ibig mo bang sabihin ay …?"
final class _Confirm extends _Pending {
  _Confirm(super.now, this.intent, this.score, this.text);
  final PercyIntent intent;
  final double score;
  final String text;
}

/// "Aling dokumento …? A, B o C?"
final class _ChooseDocument extends _Pending {
  _ChooseDocument(super.now, this.options, {this.play = false});
  final List<LibraryItem> options;
  final bool play;
}

/// "Wala akong nakitang … Buksan ang Aklatan para maghanap?"
final class _OfferLibrary extends _Pending {
  _OfferLibrary(super.now);
}

/// "Ito ba ang tinatanong mo: …?" (the closest knowledge topic).
final class _ConfirmTopic extends _Pending {
  _ConfirmTopic(super.now, this.topic);
  final KnowledgeTopic topic;
}

/// Percy's frame-based dialogue manager: classifier → thresholds → slots →
/// pending questions → a [PercyReply]. The frame: current screen, open
/// document (via the environment), last intent, pending question, last
/// [PercyConfig.historyTurns] turns.
class DialogueManager {
  /// Creates a manager.
  DialogueManager({
    required this.model,
    required this.responses,
    this.knowledge,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// The intent classifier.
  final IntentModel model;

  /// Percy's lines.
  final PercyResponses responses;

  /// Answers to questions about Percy and the app (null: none).
  final KnowledgeBase? knowledge;

  final DateTime Function() _clock;
  _Pending? _pending;
  final List<PercyTurn> _history = [];

  /// The last intent acted on or asked about.
  PercyIntent? lastIntent;

  /// The classifier's prediction for the last sentence (analysis panel).
  IntentPrediction? lastPrediction;

  /// The last turns, oldest first.
  List<PercyTurn> get history => List.unmodifiable(_history);

  /// Whether Percy is waiting for an answer to its own question.
  bool get awaitingAnswer => _livePending != null;

  _Pending? get _livePending {
    final p = _pending;
    if (p != null && _clock().isAfter(p.expires)) _pending = null;
    return _pending;
  }

  /// Forgets the conversation (a new session).
  void reset() {
    _pending = null;
    _history.clear();
    lastIntent = null;
    lastPrediction = null;
  }

  /// Records a turn handled outside the manager (an exact command).
  void remember(String text, String? intent) {
    _history.add((text: text, intent: intent));
    while (_history.length > PercyConfig.historyTurns) {
      _history.removeAt(0);
    }
  }

  /// Handles one sentence the user said.
  Future<PercyReply> handle(
    String text,
    PercyEnvironment env,
    PercyStyle style,
  ) async {
    final prediction = lastPrediction = model.predict(text);
    debugPrint(
      '[PERCY] "${PercyText.preprocess(text)}" → ${prediction.topN(3)} '
      'in ${prediction.elapsed.inMicroseconds / 1000} ms',
    );
    final reply = await _decide(text, prediction, env, style);
    remember(text, reply.intent?.label);
    if (reply.intent != null) lastIntent = reply.intent;
    return reply;
  }

  Future<PercyReply> _decide(
    String text,
    IntentPrediction prediction,
    PercyEnvironment env,
    PercyStyle style,
  ) async {
    final top = prediction.top;
    final intent = _contextualIntent(top.intent, env);
    final answer = _yesNo(text, prediction);

    // 1. Percy's own question.
    final pending = _livePending;
    _pending = null;
    switch (pending) {
      case _ChooseDocument(:final options, :final play):
        final picked = _pickOption(text, options);
        if (picked != null) {
          return _open(picked, style, TurnOutcome.acted, null, play);
        }
        if (answer == false) return _declined(style, TurnOutcome.declined);
      case _Confirm(intent: final asked, :final score):
        if (answer == true) {
          return _act(asked, text, env, style, TurnOutcome.confirmed, score);
        }
        if (answer == false) {
          return _declined(style, TurnOutcome.corrected, asked, score);
        }
      case _ConfirmTopic(:final topic):
        if (answer == true) return _answerTopic(topic, style, top.probability);
        if (answer == false) {
          return _knowledgeLine('knowledge_other', style, top.probability);
        }
      case _OfferLibrary():
        if (answer == true) {
          return _act(
            PercyIntent.openLibrary,
            text,
            env,
            style,
            TurnOutcome.confirmed,
          );
        }
        if (answer == false) return _declined(style, TurnOutcome.declined);
      case null:
        break;
    }

    // 2. The app's own question (delete, logout, …): yes/no answers it.
    if (env.appQuestionPending && answer != null) {
      return PercyReply(
        action: AnswerApp(yes: answer),
        outcome: TurnOutcome.answered,
        intent: answer ? PercyIntent.yes : PercyIntent.no,
        confidence: top.probability,
      );
    }

    // 2b. Reporting a problem: the keyword wins over another intent the
    // sentence may name ("may sira ang camera").
    if (ReportIssueRule.matches(text)) {
      return _act(
        PercyIntent.reportIssue,
        text,
        env,
        style,
        TurnOutcome.acted,
        top.probability,
      );
    }

    // 2c. A question about Percy or the app ("Anong kaya mo?").
    final asked = _askedQuestion(text, intent, top, style);
    if (asked != null) return asked;

    // 3. A document named by title ("basahin ang Liham kay Nanay"): the
    // title words are new to the classifier, so the slot rule goes first —
    // unless the classifier is sure it is another command.
    final sureOther =
        intent != null &&
        intent != PercyIntent.openItem &&
        intent != PercyIntent.read &&
        intent != PercyIntent.outOfScope &&
        top.probability >= PercyConfig.actThreshold;
    if (!sureOther) {
      final titled = await _titleRequest(text, env, style);
      if (titled != null) return titled;
    }

    // 4. Confidence.
    if (intent == null ||
        intent == PercyIntent.outOfScope ||
        top.probability < PercyConfig.askThreshold) {
      return _fallback(env, style, intent, top.probability);
    }
    if (top.probability < PercyConfig.actThreshold) {
      _pending = _Confirm(_clock(), intent, top.probability, text);
      return PercyReply(
        say: responses.dialogue('confirm', style.lang, style.politeness, {
          'action': responses.actionName(intent, style.lang),
        }),
        outcome: TurnOutcome.asked,
        intent: intent,
        confidence: top.probability,
      );
    }
    return _act(intent, text, env, style, TurnOutcome.acted, top.probability);
  }

  /// Answers a question about Percy or the app from the knowledge base:
  /// the classifier calls it a question, or it is almost word for word one
  /// of the known questions. Null when [text] is not such a question.
  PercyReply? _askedQuestion(
    String text,
    PercyIntent? intent,
    IntentScore top,
    PercyStyle style,
  ) {
    final base = knowledge;
    if (base == null) return null;
    final asks = intent == PercyIntent.askQuestion &&
        top.probability >= PercyConfig.askThreshold;
    final hits = base.rank(text);
    final best = hits.isEmpty ? null : hits.first;
    debugPrint('[PERCY] knowledge: ${hits.take(3).toList()}');
    if (!asks &&
        (best == null ||
            best.score < PercyConfig.knowledgeRescue ||
            !KnowledgeBase.looksLikeQuestion(text))) {
      return null;
    }
    if (best != null && best.score >= PercyConfig.knowledgeAnswer) {
      return _answerTopic(best.topic, style, best.score);
    }
    if (best != null && best.score >= PercyConfig.knowledgeAsk) {
      _pending = _ConfirmTopic(_clock(), best.topic);
      return PercyReply(
        say: responses.dialogue(
          'knowledge_confirm',
          style.lang,
          style.politeness,
          {'topic': best.topic.title[style.lang] ?? best.topic.title['fil']!},
        ),
        outcome: TurnOutcome.asked,
        intent: PercyIntent.askQuestion,
        confidence: best.score,
        topic: best.topic.id,
      );
    }
    return _knowledgeLine('knowledge_none', style, best?.score ?? 0);
  }

  PercyReply _answerTopic(
    KnowledgeTopic topic,
    PercyStyle style,
    double confidence,
  ) => PercyReply(
    say: knowledge!.answer(topic, style.lang, style.politeness),
    outcome: TurnOutcome.knowledge,
    intent: PercyIntent.askQuestion,
    confidence: confidence,
    topic: topic.id,
  );

  /// A line that suggests three example questions.
  PercyReply _knowledgeLine(String key, PercyStyle style, double confidence) {
    final ideas = knowledge?.suggestions(style.lang) ?? const <String>[];
    return PercyReply(
      say: responses.dialogue(key, style.lang, style.politeness, {
        'suggestions': responses.joinOr(
          ideas.take(3).map((s) => '“$s”').toList(),
          style.lang,
          style.politeness,
        ),
      }),
      outcome: key == 'knowledge_none'
          ? TurnOutcome.fallback
          : TurnOutcome.declined,
      intent: PercyIntent.askQuestion,
      confidence: confidence,
    );
  }

  /// The same spoken request has a different safe target while a described
  /// image is open. This avoids relying on the classifier alone for the
  /// overlap between document reading and text discovered in an image.
  PercyIntent? _contextualIntent(PercyIntent? intent, PercyEnvironment env) {
    if (env.screenId == Ids.describe && intent == PercyIntent.read) {
      return PercyIntent.readImageText;
    }
    if (env.screenId != Ids.describe && intent == PercyIntent.readImageText) {
      return PercyIntent.read;
    }
    return intent;
  }

  // ── Acting ─────────────────────────────────────────────────────────────

  static const Set<PercyIntent> _movesScreen = {
    PercyIntent.openHome,
    PercyIntent.openLibrary,
    PercyIntent.openSettings,
    PercyIntent.back,
    PercyIntent.reportIssue,
  };

  Future<PercyReply> _act(
    PercyIntent intent,
    String text,
    PercyEnvironment env,
    PercyStyle style,
    TurnOutcome outcome, [
    double? confidence,
  ]) async {
    String line([Map<String, String> args = const {}]) =>
        responses.forIntent(intent, style.lang, style.politeness, args);

    switch (intent) {
      case PercyIntent.greeting || PercyIntent.thanks:
        return PercyReply(
          say: line(),
          outcome: TurnOutcome.chat,
          intent: intent,
          confidence: confidence,
        );
      case PercyIntent.goodbye:
        return PercyReply(
          say: line(),
          action: const EndSession(),
          outcome: outcome,
          intent: intent,
          confidence: confidence,
        );
      case PercyIntent.yes || PercyIntent.no:
        return PercyReply(
          say: responses.dialogue(
            'nothing_asked',
            style.lang,
            style.politeness,
          ),
          outcome: TurnOutcome.chat,
          intent: intent,
          confidence: confidence,
        );
      case PercyIntent.cancel:
        return PercyReply(
          say: responses.dialogue(
            'nothing_to_cancel',
            style.lang,
            style.politeness,
          ),
          outcome: TurnOutcome.chat,
          intent: intent,
          confidence: confidence,
        );
      case PercyIntent.whereAmI:
        return PercyReply(
          action: const TellWhereAmI(),
          outcome: outcome,
          intent: intent,
          confidence: confidence,
        );
      case PercyIntent.openItem:
        return _openItem(text, env, style, outcome, confidence);
      case PercyIntent.moreDetail:
        return _action(Ids.describeMore, env, style, outcome, intent, confidence);
      case PercyIntent.readImageText:
        return _action(
          Ids.describeReadText,
          env,
          style,
          outcome,
          intent,
          confidence,
        );
      case PercyIntent.setSpeed:
        final speed = PercySlots.speed(text);
        if (speed == null) return _fallback(env, style, intent, confidence ?? 0);
        return PercyReply(
          action: SetSpeed(speed),
          outcome: outcome,
          intent: intent,
          confidence: confidence,
        );
      case PercyIntent.askQuestion:
        // Confirmed "did you mean …?" for a question: answer it.
        return _askedQuestion(text, intent, IntentScore(intent.label, 1), style) ??
            _knowledgeLine('knowledge_none', style, confidence ?? 0);
      case PercyIntent.outOfScope:
        return _fallback(env, style, intent, confidence ?? 0);
      default:
        final nav = intent.navIntent!;
        if (!env.supports(nav)) {
          return PercyReply(
            say: responses.dialogue('not_here', style.lang, style.politeness),
            outcome: TurnOutcome.notAvailable,
            intent: intent,
            confidence: confidence,
          );
        }
        final ack = switch (style.talk) {
          PercyTalk.brief => false,
          PercyTalk.normal => _movesScreen.contains(intent),
          PercyTalk.chatty => true,
        };
        return PercyReply(
          say: ack ? line() : '',
          action: RunIntent(nav),
          outcome: outcome,
          intent: intent,
          confidence: confidence,
        );
    }
  }

  PercyReply _action(
    String actionId,
    PercyEnvironment env,
    PercyStyle style,
    TurnOutcome outcome,
    PercyIntent intent,
    double? confidence,
  ) {
    if (!env.supportsAction(actionId)) {
      return PercyReply(
        say: responses.dialogue('not_here', style.lang, style.politeness),
        outcome: TurnOutcome.notAvailable,
        intent: intent,
        confidence: confidence,
      );
    }
    return PercyReply(
      action: RunAction(actionId),
      outcome: outcome,
      intent: intent,
      confidence: confidence,
    );
  }

  Future<PercyReply> _openItem(
    String text,
    PercyEnvironment env,
    PercyStyle style,
    TurnOutcome outcome,
    double? confidence,
  ) async {
    PercyReply say(String key, [Map<String, String> args = const {}]) =>
        PercyReply(
          say: responses.dialogue(key, style.lang, style.politeness, args),
          outcome: key == 'library_empty'
              ? TurnOutcome.notAvailable
              : TurnOutcome.asked,
          intent: PercyIntent.openItem,
          confidence: confidence,
        );

    final items = await env.libraryItems();
    if (items.isEmpty) return say('library_empty');

    final title = PercySlots.titleWords(text);
    final ordinal = PercySlots.ordinal(text);
    final onlyOrdinal =
        title.isEmpty ||
        title.split(' ').every(PercySlots.ordinals.containsKey);
    if (onlyOrdinal && ordinal != null) {
      // "Ang huli" = the most recently opened; otherwise by position.
      final item = PercySlots.at(items, ordinal < 0 ? 0 : ordinal);
      if (item != null) return _open(item, style, outcome, confidence);
    }
    if (title.isEmpty || onlyOrdinal) {
      // Missing slot: which document?
      final options = items.take(PercyConfig.maxChoices).toList();
      _pending = _ChooseDocument(_clock(), options);
      return say('which_document', {
        'options': responses.joinOr(
          [for (final i in options) i.title],
          style.lang,
          style.politeness,
        ),
      });
    }
    final ranked = LibraryView.rankByTitle(
      items,
      title,
      floor: PercyConfig.titleMatch,
    );
    if (ranked.isEmpty) {
      _pending = _OfferLibrary(_clock());
      return say('no_match', {'title': title});
    }
    final clear =
        ranked.length == 1 || ranked[0].score >= ranked[1].score + 0.15;
    if (clear) return _open(ranked.first.item, style, outcome, confidence);
    final options = [
      for (final r in ranked.take(PercyConfig.maxChoices)) r.item,
    ];
    _pending = _ChooseDocument(_clock(), options);
    return say('which', {
      'options': responses.joinOr(
        [for (final i in options) i.title],
        style.lang,
        style.politeness,
      ),
    });
  }

  PercyReply _open(
    LibraryItem item,
    PercyStyle style,
    TurnOutcome outcome, [
    double? confidence,
    bool play = false,
  ]) => PercyReply(
    say: style.talk == PercyTalk.brief
        ? ''
        : responses.forIntent(
            PercyIntent.openItem,
            style.lang,
            style.politeness,
            {'title': item.title},
          ),
    action: OpenDocument(item, play: play),
    outcome: outcome,
    intent: PercyIntent.openItem,
    confidence: confidence,
  );

  /// "Buksan / basahin / ituloy ang <title>" naming a Library document: open
  /// it (reading at once for "basahin"), or ask which of several; null when
  /// the sentence names no document.
  Future<PercyReply?> _titleRequest(
    String text,
    PercyEnvironment env,
    PercyStyle style,
  ) async {
    final cmd = Understanding.titleCommand(text);
    if (cmd == null || cmd.last) return null;
    final title = PercySlots.titleWords(text);
    if (title.isEmpty) return null;
    final items = await env.libraryItems();
    final ranked = LibraryView.rankByTitle(
      items,
      title,
      floor: PercyConfig.titleMatch,
    );
    if (ranked.isEmpty) return null;
    final play = cmd.verb == TitleVerb.read;
    final clear =
        ranked.length == 1 || ranked[0].score >= ranked[1].score + 0.15;
    if (clear) {
      return _open(ranked.first.item, style, TurnOutcome.acted, null, play);
    }
    final options = [
      for (final r in ranked.take(PercyConfig.maxChoices)) r.item,
    ];
    _pending = _ChooseDocument(_clock(), options, play: play);
    return PercyReply(
      say: responses.dialogue('which', style.lang, style.politeness, {
        'options': responses.joinOr(
          [for (final i in options) i.title],
          style.lang,
          style.politeness,
        ),
      }),
      outcome: TurnOutcome.asked,
      intent: PercyIntent.openItem,
    );
  }

  LibraryItem? _pickOption(String text, List<LibraryItem> options) {
    final ordinal = PercySlots.ordinal(text);
    final title = PercySlots.titleWords(text);
    final onlyOrdinal =
        title.isEmpty ||
        title.split(' ').every(PercySlots.ordinals.containsKey);
    if (ordinal != null && onlyOrdinal) return PercySlots.at(options, ordinal);
    if (title.isEmpty) return null;
    final ranked = LibraryView.rankByTitle(options, title, floor: 0.6);
    return ranked.isEmpty ? null : ranked.first.item;
  }

  PercyReply _declined(
    PercyStyle style,
    TurnOutcome outcome, [
    PercyIntent? intent,
    double? confidence,
  ]) => PercyReply(
    say: responses.dialogue('declined', style.lang, style.politeness),
    outcome: outcome,
    intent: intent,
    confidence: confidence,
  );

  PercyReply _fallback(
    PercyEnvironment env,
    PercyStyle style,
    PercyIntent? intent,
    double confidence,
  ) {
    final ideas = responses.suggestions(env.screenId, style.lang);
    return PercyReply(
      say: responses.dialogue('fallback', style.lang, style.politeness, {
        'suggestions': responses.joinOr(
          ideas.take(3).map((s) => '“$s”').toList(),
          style.lang,
          style.politeness,
        ),
      }),
      outcome: TurnOutcome.fallback,
      intent: intent,
      confidence: confidence,
    );
  }

  /// Yes (true), no / cancel (false) or neither (null): the classifier when
  /// it is fairly sure, else the app's own yes/no words.
  static bool? _yesNo(String text, IntentPrediction prediction) {
    final top = prediction.top;
    final fromModel = top.intent?.answer;
    if (fromModel != null && top.probability >= PercyConfig.answerThreshold) {
      return fromModel;
    }
    final clean = PercyText.preprocess(text);
    if (yesWords.any((w) => PercyText.preprocess(w) == clean)) return true;
    if (noWords.any((w) => PercyText.preprocess(w) == clean)) return false;
    return null;
  }
}
