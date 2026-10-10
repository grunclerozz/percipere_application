import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'percy_intent.dart';
import 'percy_text.dart';

/// One intent and how likely it is.
@immutable
class IntentScore {
  /// Creates a score.
  const IntentScore(this.label, this.probability);

  /// Model label (`open_home`, …).
  final String label;

  /// Probability, 0–1.
  final double probability;

  /// The intent, or null for a label the app doesn't know.
  PercyIntent? get intent => PercyIntent.fromLabel(label);

  @override
  String toString() => '$label ${probability.toStringAsFixed(2)}';
}

/// A classification: intents best first.
@immutable
class IntentPrediction {
  /// Creates a prediction.
  const IntentPrediction(this.ranked, {this.elapsed = Duration.zero});

  /// Every intent, most likely first.
  final List<IntentScore> ranked;

  /// How long it took.
  final Duration elapsed;

  /// The most likely intent.
  IntentScore get top => ranked.first;

  /// The [n] most likely intents.
  List<IntentScore> topN(int n) => ranked.take(n).toList();
}

/// Something that turns a sentence into intents. Percy's dialogue manager
/// only depends on this, so another model (e.g. a neural network, later)
/// can replace the current one.
abstract interface class IntentModel {
  /// Model version (date + dataset size).
  String get version;

  /// Classifies [text] (raw, as heard).
  IntentPrediction predict(String text);
}

/// Percy's intent classifier, exported by `scripts/percy/train.py`:
/// TF-IDF features (word 1–2-grams + per-word char 3–5-grams, each block
/// L2-normalized) and either multinomial Logistic Regression
/// (softmax(W·x + b)) or Multinomial Naive Bayes
/// (softmax(log P(f|c)·x + log P(c))). Pure Dart.
class IntentClassifier implements IntentModel {
  IntentClassifier._({
    required this.type,
    required this.version,
    required this.labels,
    required this._vocabulary,
    required this._isWord,
    required this._idf,
    required this._weights,
    required this._bias,
  });

  /// Reads a `model.json` document.
  factory IntentClassifier.fromJson(Map<String, Object?> json) {
    if (json['format'] != 'percy-intent-model') {
      throw const FormatException('not a Percy intent model');
    }
    final type = json['type'] as String;
    List<double> doubles(Object? v) => [
      for (final x in v! as List) (x as num).toDouble(),
    ];
    final vocab = (json['vocabulary']! as List).cast<String>();
    final (weights, bias) = switch (type) {
      'logreg' => (json['weights'], json['bias']),
      'multinomial_nb' => (json['log_prob'], json['log_prior']),
      _ => throw FormatException('unknown model type "$type"'),
    };
    return IntentClassifier._(
      type: type,
      version: json['version'] as String? ?? '?',
      labels: (json['labels']! as List).cast<String>(),
      vocabulary: {for (var i = 0; i < vocab.length; i++) vocab[i]: i},
      isWord: [for (final f in vocab) f.startsWith('w:')],
      idf: doubles(json['idf']),
      weights: [for (final row in weights! as List) doubles(row)],
      bias: doubles(bias),
    );
  }

  /// Parses `model.json` text (call through `compute` for the app's
  /// bundled model: it is about a megabyte).
  static IntentClassifier parse(String source) => IntentClassifier.fromJson(
    (jsonDecode(source) as Map).cast<String, Object?>(),
  );

  /// `logreg` or `multinomial_nb`.
  final String type;

  @override
  final String version;

  /// Intent labels, in the order of the model's rows.
  final List<String> labels;

  final Map<String, int> _vocabulary;
  final List<bool> _isWord;
  final List<double> _idf;
  final List<List<double>> _weights;
  final List<double> _bias;

  /// The TF-IDF vector of [clean] text, as feature index → value.
  Map<int, double> features(String clean) {
    final counts = <int, int>{};
    void add(String key) {
      final i = _vocabulary[key];
      if (i != null) counts[i] = (counts[i] ?? 0) + 1;
    }

    for (final g in PercyText.wordFeatures(clean)) {
      add('w:$g');
    }
    for (final g in PercyText.charFeatures(clean)) {
      add('c:$g');
    }
    final x = <int, double>{};
    for (final word in [true, false]) {
      final block = {
        for (final e in counts.entries)
          if (_isWord[e.key] == word) e.key: e.value * _idf[e.key],
      };
      var norm = 0.0;
      for (final v in block.values) {
        norm += v * v;
      }
      norm = math.sqrt(norm);
      if (norm == 0) continue;
      for (final e in block.entries) {
        x[e.key] = e.value / norm;
      }
    }
    return x;
  }

  @override
  IntentPrediction predict(String text) {
    final watch = Stopwatch()..start();
    final x = features(PercyText.preprocess(text));
    final scores = List<double>.generate(labels.length, (k) {
      final row = _weights[k];
      var s = _bias[k];
      for (final e in x.entries) {
        s += row[e.key] * e.value;
      }
      return s;
    });
    final top = scores.reduce(math.max);
    final exps = [for (final s in scores) math.exp(s - top)];
    final total = exps.reduce((a, b) => a + b);
    final ranked = [
      for (var k = 0; k < labels.length; k++)
        IntentScore(labels[k], exps[k] / total),
    ]..sort((a, b) => b.probability.compareTo(a.probability));
    watch.stop();
    return IntentPrediction(ranked, elapsed: watch.elapsed);
  }
}
