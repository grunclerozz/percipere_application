import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'percy_intent.dart';

/// How formally Percy talks.
enum PercyPoliteness {
  /// With "po" / "opo".
  po,

  /// Casual.
  casual,
}

/// How much Percy says around actions.
enum PercyTalk {
  /// Only what is needed (no acknowledgements before actions).
  brief,

  /// Short acknowledgements before moving to another screen.
  normal,

  /// Acknowledges every action and asks "anything else?".
  chatty,
}

/// Percy's persona and lines (`assets/percy/persona.json`,
/// `assets/percy/responses.json`). Variations are picked at random.
class PercyResponses {
  /// Creates the responses from the two decoded JSON documents.
  PercyResponses(this._persona, this._responses, {math.Random? random})
    : _random = random ?? math.Random();

  /// Parses the two files.
  factory PercyResponses.parse(
    String persona,
    String responses, {
    math.Random? random,
  }) => PercyResponses(
    (jsonDecode(persona) as Map).cast<String, Object?>(),
    (jsonDecode(responses) as Map).cast<String, Object?>(),
    random: random,
  );

  final Map<String, Object?> _persona;
  final Map<String, Object?> _responses;
  final math.Random _random;

  /// Percy's name.
  String get name => _persona['name'] as String? ?? 'Percy';

  /// Default politeness from the persona file.
  PercyPoliteness get defaultPoliteness => _persona['politeness'] == 'casual'
      ? PercyPoliteness.casual
      : PercyPoliteness.po;

  /// Default talkativeness from the persona file.
  PercyTalk get defaultTalk => PercyTalk.values.firstWhere(
    (t) => t.name == _persona['talkativeness'],
    orElse: () => PercyTalk.normal,
  );

  /// The greeting when a session starts.
  String greeting(String lang, PercyPoliteness p) =>
      _pick(_persona['greeting'], lang, p, const {});

  /// What Percy says for [intent] (may be empty).
  String forIntent(
    PercyIntent intent,
    String lang,
    PercyPoliteness p, [
    Map<String, String> args = const {},
  ]) => _pick(_section('intents')[intent.label], lang, p, args);

  /// A dialogue line: `confirm`, `fallback`, `not_here`, `which`, …
  String dialogue(
    String key,
    String lang,
    PercyPoliteness p, [
    Map<String, String> args = const {},
  ]) => _pick(_section('dialogue')[key], lang, p, args);

  /// How [intent] is named in "Ang ibig mo bang sabihin ay …?".
  String actionName(PercyIntent intent, String lang) {
    final entry = _section('actions')[intent.label];
    if (entry is Map) {
      return (entry[lang] ?? entry['fil'] ?? intent.label).toString();
    }
    return intent.label;
  }

  /// 2–3 things to say on [screenId].
  List<String> suggestions(String? screenId, String lang) {
    final all = _section('suggestions');
    final entry = all[screenId] ?? all['default'];
    if (entry is! Map) return const [];
    final list = entry[lang] ?? entry['fil'];
    return list is List ? list.map((e) => e.toString()).toList() : const [];
  }

  /// "a, b o c" in [lang].
  String joinOr(List<String> items, String lang, PercyPoliteness p) {
    if (items.isEmpty) return '';
    if (items.length == 1) return items.single;
    final or = dialogue('or', lang, p);
    return '${items.sublist(0, items.length - 1).join(', ')} $or ${items.last}';
  }

  Map<String, Object?> _section(String name) =>
      (_responses[name] as Map?)?.cast<String, Object?>() ?? const {};

  String _pick(
    Object? entry,
    String lang,
    PercyPoliteness p,
    Map<String, String> args,
  ) {
    if (entry is! Map) return '';
    final byLang = entry[lang] ?? entry['fil'];
    if (byLang is! Map) return '';
    final lines = byLang[p.name] ?? byLang['po'];
    if (lines is! List || lines.isEmpty) return '';
    var line = lines[_random.nextInt(lines.length)].toString();
    for (final e in args.entries) {
      line = line.replaceAll('{${e.key}}', e.value);
    }
    return line.trim();
  }

  @visibleForTesting
  /// Every response key the dialogue manager uses must exist.
  static const List<String> dialogueKeys = [
    'confirm',
    'fallback',
    'not_here',
    'which',
    'which_document',
    'no_match',
    'library_empty',
    'declined',
    'nothing_to_cancel',
    'nothing_asked',
    'more',
    'ended',
    'idle_end',
    'introduction',
    'or',
  ];
}
