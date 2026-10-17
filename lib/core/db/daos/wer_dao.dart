import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../algorithms/wer.dart';
import '../app_database.dart';

/// One scored sentence of a speech-recognition test (`wer_results`).
@immutable
class WerRecord {
  /// Creates a record.
  const WerRecord({
    required this.sessionId,
    required this.locale,
    required this.onDevice,
    required this.reference,
    required this.hypothesis,
    required this.result,
    required this.at,
  });

  /// The test run it belongs to.
  final String sessionId;

  /// Recognizer locale, e.g. `fil-PH`.
  final String locale;

  /// Whether the recognizer worked on the phone (no network).
  final bool onDevice;

  /// What the speaker was asked to say.
  final String reference;

  /// What the recognizer returned.
  final String hypothesis;

  /// S, D, I and N.
  final WerResult result;

  /// When.
  final DateTime at;
}

/// The Word Error Rate results kept for the study.
class WerDao {
  /// Creates the DAO.
  WerDao(this._db);

  final DatabaseExecutor _db;

  /// CSV columns.
  static const List<String> csvColumns = [
    'session',
    'locale',
    'on_device',
    'reference',
    'hypothesis',
    'substitutions',
    'deletions',
    'insertions',
    'reference_words',
    'wer',
    'date',
  ];

  /// Saves one scored sentence.
  Future<void> insert(WerRecord r) => _db.insert('wer_results', {
    'session_id': r.sessionId,
    'locale': r.locale,
    'on_device': r.onDevice ? 1 : 0,
    'reference': r.reference,
    'hypothesis': r.hypothesis,
    'substitutions': r.result.substitutions,
    'deletions': r.result.deletions,
    'insertions': r.result.insertions,
    'reference_words': r.result.referenceWords,
    'wer': r.result.wer,
    'created_at': r.at.millisecondsSinceEpoch,
  });

  /// Every saved sentence, oldest first.
  Future<List<WerRecord>> all() async {
    final rows = await _db.query('wer_results', orderBy: 'id');
    return [
      for (final r in rows)
        WerRecord(
          sessionId: r['session_id']! as String,
          locale: r['locale']! as String,
          onDevice: (r['on_device']! as int) == 1,
          reference: r['reference']! as String,
          hypothesis: r['hypothesis']! as String,
          result: WerResult(
            substitutions: r['substitutions']! as int,
            deletions: r['deletions']! as int,
            insertions: r['insertions']! as int,
            referenceWords: r['reference_words']! as int,
          ),
          at: DateTime.fromMillisecondsSinceEpoch(r['created_at']! as int),
        ),
    ];
  }

  /// Deletes all saved results.
  Future<void> clear() => _db.delete('wer_results');

  /// The results as CSV, with a summary row of the pooled rate
  /// (total errors / total reference words) at the end.
  static String toCsv(List<WerRecord> records) {
    String cell(Object? v) {
      final s = v?.toString() ?? '';
      return RegExp(r'[",\n\r]').hasMatch(s)
          ? '"${s.replaceAll('"', '""')}"'
          : s;
    }

    final lines = [csvColumns.join(',')];
    var errors = 0;
    var words = 0;
    for (final r in records) {
      errors += r.result.errors;
      words += r.result.referenceWords;
      lines.add(
        [
          r.sessionId,
          r.locale,
          r.onDevice ? 'yes' : 'no',
          r.reference,
          r.hypothesis,
          r.result.substitutions,
          r.result.deletions,
          r.result.insertions,
          r.result.referenceWords,
          r.result.wer.toStringAsFixed(4),
          r.at.toIso8601String(),
        ].map(cell).join(','),
      );
    }
    if (records.isNotEmpty) {
      final pooled = words == 0 ? 0 : errors / words;
      lines.add(
        [
          'TOTAL',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          words,
          pooled.toStringAsFixed(4),
          '',
        ].map(cell).join(','),
      );
    }
    return '${lines.join('\n')}\n';
  }
}

/// The WER results table.
final werDaoProvider = Provider<WerDao>(
  (ref) => WerDao(ref.watch(appDatabaseProvider).db),
);
