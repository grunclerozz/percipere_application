// Percy's classifier in Dart must give what the Python trainer computed:
// same preprocessing, same top intent, probabilities within 0.01
// (scripts/percy/test_vectors.json, written by train.py).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/config/percy_config.dart';
import 'package:percipere_app/core/percy/intent_classifier.dart';
import 'package:percipere_app/core/percy/percy_intent.dart';
import 'package:percipere_app/core/percy/percy_text.dart';

void main() {
  late IntentClassifier model;
  late Map<String, Object?> vectors;

  setUpAll(() {
    model = IntentClassifier.parse(
      File(PercyConfig.modelAsset).readAsStringSync(),
    );
    vectors = (jsonDecode(
      File('scripts/percy/test_vectors.json').readAsStringSync(),
    ) as Map).cast<String, Object?>();
  });

  test('the vectors were made from the bundled model', () {
    expect(vectors['model_version'], model.version);
    expect(vectors['labels'], model.labels);
  });

  test('every model label is a Percy intent; only rule-only intents are '
      'missing from the model (until the next retrain)', () {
    for (final label in model.labels) {
      expect(PercyIntent.fromLabel(label), isNotNull, reason: label);
    }
    final missing = PercyIntent.values
        .where((i) => !model.labels.contains(i.label))
        .toSet();
    expect(missing, PercyIntent.ruleOnly);
  });

  test('preprocessing matches Python', () {
    for (final v
        in (vectors['vectors']! as List).cast<Map<String, Object?>>()) {
      expect(
        PercyText.preprocess(v['text'] as String),
        v['clean'],
        reason: v['text'] as String,
      );
    }
  });

  test('predictions match Python (top intent, probabilities ±0.01)', () {
    final labels = (vectors['labels']! as List).cast<String>();
    for (final v
        in (vectors['vectors']! as List).cast<Map<String, Object?>>()) {
      final text = v['text'] as String;
      final p = model.predict(text);
      expect(p.top.label, v['intent'], reason: text);
      expect(
        p.top.probability,
        closeTo(v['probability'] as num, 0.01),
        reason: text,
      );
      final expected = (v['probabilities']! as List).cast<num>();
      for (final s in p.ranked) {
        expect(
          s.probability,
          closeTo(expected[labels.indexOf(s.label)], 0.01),
          reason: '$text / ${s.label}',
        );
      }
    }
  });

  test('probabilities sum to 1', () {
    final p = model.predict('buksan mo ang library');
    final sum = p.ranked.fold<double>(0, (a, s) => a + s.probability);
    expect(sum, closeTo(1, 1e-9));
  });

  test('a prediction takes under 20 ms', () {
    model.predict('warm up');
    final watch = Stopwatch()..start();
    const runs = 200;
    for (var i = 0; i < runs; i++) {
      model.predict('pakibasa mo nga po yung huling dokumento');
    }
    final perCall = watch.elapsedMicroseconds / runs / 1000;
    expect(perCall, lessThan(20));
  });

  group('preprocessing', () {
    test('lowercase, accents, punctuation, wake word', () {
      expect(
        PercyText.preprocess('Percy, BUKSAN mo ang Library!'),
        'buksan mo ang library',
      );
      expect(PercyText.preprocess('hey percy pakibilisan'), 'pakibilisan');
      expect(PercyText.preprocess('I-cancel mo na'), 'icancel mo na');
      expect(PercyText.preprocess('Señor  “Niño”'), 'senor nino');
    });

    test('negation words are kept', () {
      expect(
        PercyText.preprocess('Hindi, huwag na! Ayoko. No, not that'),
        'hindi huwag na ayoko no not that',
      );
    });

    test('char n-grams are per padded word', () {
      expect(PercyText.charFeatures('ab'), [' ab', 'ab ', ' ab ']);
      expect(PercyText.wordFeatures('a b c'), ['a', 'b', 'c', 'a b', 'b c']);
    });
  });
}
