import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'percy_clips.dart';
import 'percy_responses.dart';
import 'percy_text.dart';

/// One thing Percy can explain: the questions that ask for it and the answer.
@immutable
class KnowledgeTopic {
  /// Creates a topic.
  const KnowledgeTopic({
    required this.id,
    required this.title,
    required this.questions,
    required this.answer,
  });

  /// Stable id (`percy_abilities`, `library_download`, …).
  final String id;

  /// A short phrase per language that fits "Is this what you ask: …?".
  final Map<String, String> title;

  /// Example questions (Filipino, English, Taglish, speech-recognition spellings).
  final List<String> questions;

  /// `{lang: {politeness: [lines]}}`, like the entries of `responses.json`.
  final Map<String, Map<String, List<String>>> answer;
}

/// A topic and how well a question fits it (0–1).
@immutable
class KnowledgeHit {
  /// Creates a hit.
  const KnowledgeHit(this.topic, this.score);

  /// The topic.
  final KnowledgeTopic topic;

  /// Best cosine similarity to one of the topic's questions.
  final double score;

  @override
  String toString() => '${topic.id} ${score.toStringAsFixed(2)}';
}

/// Percy's offline question answering (`assets/percy/knowledge.json`).
///
/// Retrieval is our own TF-IDF + cosine similarity: every example question
/// is a document; the user's question is scored against all of them and a
/// topic scores as its best question (`docs/thesis/algorithms.md`). No AI
/// service, no network.
class KnowledgeBase {
  KnowledgeBase._(this.topics, this._suggestions) {
    final df = <String, int>{};
    final docs = <(int, Map<String, int>)>[];
    for (var t = 0; t < topics.length; t++) {
      for (final q in topics[t].questions) {
        final counts = _counts(q);
        docs.add((t, counts));
        for (final f in counts.keys) {
          df[f] = (df[f] ?? 0) + 1;
        }
      }
    }
    final n = docs.length;
    for (final e in df.entries) {
      _idf[e.key] = math.log((1 + n) / (1 + e.value)) + 1;
    }
    for (var d = 0; d < docs.length; d++) {
      final (topic, counts) = docs[d];
      _docTopic.add(topic);
      final vector = _vector(counts);
      for (final e in vector.entries) {
        (_index[e.key] ??= []).add((d, e.value));
      }
    }
  }

  /// Reads a `knowledge.json` document.
  factory KnowledgeBase.parse(String source) {
    final json = (jsonDecode(source) as Map).cast<String, Object?>();
    Map<String, Map<String, List<String>>> answer(Object? raw) => {
      for (final lang in (raw! as Map).entries)
        '${lang.key}': {
          for (final p in (lang.value as Map).entries)
            '${p.key}': [for (final l in p.value as List) '$l'],
        },
    };
    final topics = [
      for (final raw in json['topics']! as List)
        KnowledgeTopic(
          id: (raw as Map)['id'] as String,
          title: {
            for (final e in (raw['title'] as Map).entries) '${e.key}': '${e.value}',
          },
          questions: [for (final q in raw['questions'] as List) '$q'],
          answer: answer(raw['answer']),
        ),
    ];
    final s = (json['suggestions'] as Map?) ?? const {};
    return KnowledgeBase._(topics, {
      for (final e in s.entries) '${e.key}': [for (final x in e.value as List) '$x'],
    });
  }

  /// All topics.
  final List<KnowledgeTopic> topics;

  final Map<String, List<String>> _suggestions;
  final Map<String, double> _idf = {};
  late final double _unknownIdf = math.log(1 + _docTopic.length) + 1;
  final List<int> _docTopic = [];

  /// Feature → (document, weight) of the L2-normalized TF-IDF vectors.
  final Map<String, List<(int, double)>> _index = {};

  /// Words that carry no meaning for a question (politeness, wake word).
  static const Set<String> _fillers = {
    'po', 'opo', 'nga', 'naman', 'please', 'ba', 'percy', 'persi', 'percey', //
    'hey', 'hi', 'hello',
    // Function words: they appear in almost every question and say nothing
    // about the topic.
    'the', 'a', 'an', 'is', 'of', 'to', 'i', 'it', 'my', 'in', 'on', 'and', //
    'or', 'be', //
    'ang', 'ng', 'sa', 'na', 'mga', 'ay', 'at', 'ni', 'nang',
  };

  /// Speech-recognition and texting spellings mapped to one word.
  static const Map<String, String> _spelling = {
    'anu': 'ano', 'pano': 'paano', 'mu': 'mo', 'pra': 'para', 'pede': 'pwede', //
    'pwde': 'pwede', 'nah': 'na', 'kta': 'kita', 'ung': 'ang', 'yung': 'ang',
    'iyong': 'ang', 'yong': 'ang', 'sayo': 'iyo', 'saiyo': 'iyo',
  };

  /// Words that make a sentence a question (not a command).
  static const Set<String> _questionWords = {
    'ano', 'anu', 'anong', 'paano', 'pano', 'pwede', 'puwede', 'sino', //
    'sinong', 'bakit', 'saan', 'nasaan', 'kailan', 'kailangan', 'kaya', //
    'magkano', 'ilan', 'alin', 'what', 'whats', 'how', 'who', 'why', //
    'where', 'when', 'which', 'can', 'could', 'do', 'does', 'are', 'is', //
    'will', 'tulungan', 'help', 'hindi', 'naliligaw', 'nakalimutan', //
    'gumagana', 'ligtas', 'tao', 'robot', 'nakikita', 'alam', 'naguluhan', //
    'naguguluhan', 'nawawala',
  };

  /// Whether [text] reads like a question: it has a question word. Only such
  /// sentences are answered without the classifier's say-so, so a command
  /// that shares words with a question ("lakihan ang text") stays a command.
  static bool looksLikeQuestion(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('?')) return true;
    return tokens(text).any(_questionWords.contains);
  }

  /// The words of [text], lowercase, accents folded, politeness removed.
  static List<String> tokens(String text) {
    final buffer = StringBuffer();
    for (final rune in text.toLowerCase().runes) {
      final ch = String.fromCharCode(rune);
      buffer.write(PercyText.fold[ch] ?? ch);
    }
    final cleaned = buffer
        .toString()
        .replaceAll(RegExp(r"['’]"), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    final words = [
      for (final w in cleaned.split(' '))
        if (w.isNotEmpty) _spelling[w] ?? w,
    ];
    final kept = [
      for (final w in words)
        if (!_fillers.contains(w)) w,
    ];
    return kept.isEmpty ? words : kept;
  }

  /// Raw feature counts: `w:` word 1–2-grams and `c:` char 3–4-grams.
  static Map<String, int> _counts(String text) {
    final words = tokens(text);
    final counts = <String, int>{};
    void add(String f) => counts[f] = (counts[f] ?? 0) + 1;
    for (var i = 0; i < words.length; i++) {
      add('w:${words[i]}');
      if (i + 1 < words.length) add('w:${words[i]} ${words[i + 1]}');
      final padded = ' ${words[i]} ';
      for (var n = 3; n <= 4; n++) {
        for (var j = 0; j + n <= padded.length; j++) {
          add('c:${padded.substring(j, j + n)}');
        }
      }
    }
    return counts;
  }

  /// TF-IDF with each block (words, characters) L2-normalized. A [query]
  /// feature no question has still counts in the norm (with the highest idf),
  /// so a question made mostly of unknown words scores low instead of
  /// matching on its one familiar word.
  Map<String, double> _vector(Map<String, int> counts, {bool query = false}) {
    final out = <String, double>{};
    for (final prefix in const ['w:', 'c:']) {
      final block = <String, double>{};
      var norm = 0.0;
      for (final e in counts.entries) {
        if (!e.key.startsWith(prefix)) continue;
        final idf = _idf[e.key];
        if (idf == null) {
          if (query) norm += math.pow(e.value * _unknownIdf, 2);
          continue;
        }
        final v = e.value * idf;
        block[e.key] = v;
        norm += v * v;
      }
      if (norm == 0) continue;
      norm = math.sqrt(norm);
      for (final e in block.entries) {
        out[e.key] = e.value / norm;
      }
    }
    return out;
  }

  /// Every topic with its score for [question], best first. The score is the
  /// mean of the word-block and character-block cosines (1 = same question).
  List<KnowledgeHit> rank(String question) {
    final query = _vector(_counts(question), query: true);
    final perDoc = <int, double>{};
    for (final e in query.entries) {
      final postings = _index[e.key];
      if (postings == null) continue;
      for (final (doc, w) in postings) {
        perDoc[doc] = (perDoc[doc] ?? 0) + e.value * w;
      }
    }
    final best = <int, double>{};
    for (final e in perDoc.entries) {
      final score = (e.value / 2).clamp(0.0, 1.0);
      final topic = _docTopic[e.key];
      if (score > (best[topic] ?? 0)) best[topic] = score;
    }
    return [
      for (final e in best.entries) KnowledgeHit(topics[e.key], e.value),
    ]..sort((a, b) => b.score.compareTo(a.score));
  }

  /// The answer to [topic] in [lang] and [politeness].
  String answer(
    KnowledgeTopic topic,
    String lang,
    PercyPoliteness politeness,
  ) {
    final byLang = topic.answer[lang] ?? topic.answer['fil'];
    final lines = byLang?[politeness.name] ?? byLang?['po'];
    return lines == null || lines.isEmpty ? '' : lines.first;
  }

  /// Example questions to suggest when nothing matched.
  List<String> suggestions(String lang) =>
      _suggestions[lang] ?? _suggestions['fil'] ?? const [];

  /// Every answer sentence without `{placeholders}`, as (language, sentence):
  /// the ones that can have a bundled voice clip (see
  /// `tool/percy_voice/generate_percy_voice.py`).
  Set<(String, String)> fixedSentences() {
    final found = <(String, String)>{};
    for (final topic in topics) {
      for (final lang in const ['fil', 'en']) {
        for (final lines in (topic.answer[lang] ?? const {}).values) {
          for (final line in lines) {
            for (final s in PercyClipKey.sentences(line)) {
              if (!s.contains('{') && RegExp(r'\w').hasMatch(s)) {
                found.add((lang, s));
              }
            }
          }
        }
      }
    }
    return found;
  }
}
