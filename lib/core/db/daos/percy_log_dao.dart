import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../app_database.dart';

/// One logged sentence said to Percy.
@immutable
class PercyLogEntry {
  /// Creates an entry.
  const PercyLogEntry({
    required this.text,
    required this.outcome,
    required this.at,
    this.userId,
    this.intent,
    this.confidence,
    this.screen,
    this.modelVersion,
  });

  /// Account (or guest) id; null before anyone logs in.
  final String? userId;

  /// What the user said (speech-to-text result).
  final String text;

  /// The intent Percy predicted or acted on.
  final String? intent;

  /// The classifier's confidence in [intent].
  final double? confidence;

  /// How the turn ended (`TurnOutcome.name`).
  final String outcome;

  /// The screen it was said on.
  final String? screen;

  /// Model version that classified it.
  final String? modelVersion;

  /// When.
  final DateTime at;
}

/// Percy's turn log (`percy_turns`), kept on the phone for retraining.
class PercyLogDao {
  /// Creates the DAO.
  PercyLogDao(this._db);

  final DatabaseExecutor _db;

  /// Columns of the dataset (`data/percy/intents.csv`).
  static const List<String> csvColumns = [
    'text',
    'intent',
    'author',
    'source',
    'notes',
  ];

  /// Saves one turn.
  Future<void> insert(PercyLogEntry e) => _db.insert('percy_turns', {
    'user_id': e.userId,
    'text': e.text,
    'intent': e.intent,
    'confidence': e.confidence,
    'outcome': e.outcome,
    'screen': e.screen,
    'model_version': e.modelVersion,
    'created_at': e.at.millisecondsSinceEpoch,
  });

  /// Every logged turn, oldest first.
  Future<List<PercyLogEntry>> all() async {
    final rows = await _db.query('percy_turns', orderBy: 'id');
    return [
      for (final r in rows)
        PercyLogEntry(
          userId: r['user_id'] as String?,
          text: r['text']! as String,
          intent: r['intent'] as String?,
          confidence: (r['confidence'] as num?)?.toDouble(),
          outcome: r['outcome']! as String,
          screen: r['screen'] as String?,
          modelVersion: r['model_version'] as String?,
          at: DateTime.fromMillisecondsSinceEpoch(r['created_at']! as int),
        ),
    ];
  }

  /// Number of logged turns.
  Future<int> count() async =>
      Sqflite.firstIntValue(
        await _db.rawQuery('SELECT COUNT(*) FROM percy_turns'),
      ) ??
      0;

  /// The log as CSV in the dataset format (`source = STT log`); outcome,
  /// confidence, screen and date go to `notes` so the team can check each
  /// row before adding it to the dataset.
  static String toCsv(List<PercyLogEntry> entries) {
    String cell(Object? v) {
      final s = v?.toString() ?? '';
      return RegExp(r'[",\n\r]').hasMatch(s)
          ? '"${s.replaceAll('"', '""')}"'
          : s;
    }

    final lines = [csvColumns.join(',')];
    for (final e in entries) {
      final notes = [
        'outcome=${e.outcome}',
        if (e.confidence != null)
          'confidence=${e.confidence!.toStringAsFixed(2)}',
        if (e.screen != null) 'screen=${e.screen}',
        if (e.modelVersion != null) 'model=${e.modelVersion}',
        'date=${e.at.toIso8601String()}',
      ].join('; ');
      lines.add(
        [e.text, e.intent ?? '', '', 'STT log', notes].map(cell).join(','),
      );
    }
    return '${lines.join('\n')}\n';
  }
}

/// Percy's turn log.
final percyLogDaoProvider = Provider<PercyLogDao>(
  (ref) => PercyLogDao(ref.watch(appDatabaseProvider).db),
);
