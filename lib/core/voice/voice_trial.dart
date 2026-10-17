import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../accessibility/nav_intent.dart';
import 'command_matcher.dart';

/// The room a reliability round is run in.
enum TrialRoom {
  /// A quiet room.
  quiet,

  /// A noisy room (TV, people talking, a fan).
  noisy,
}

/// One command of the reliability test: what the tester says and what it
/// must run.
@immutable
class TrialCommand {
  /// Creates a test command.
  const TrialCommand(this.phrase, this.intent);

  /// What to say.
  final String phrase;

  /// The command it must match.
  final NavIntent intent;

  /// The expected command's name, as in the CSV.
  String get expected => intent.name;
}

/// The repeatable voice reliability test (developer build, Settings →
/// Pagsusuri ng boses): 20 everyday commands, said one by one, each up to
/// [maxAttempts] times, logged to a CSV file on the tablet
/// ([VoiceTrialLog]). Run once in a quiet and once in a noisy room.
abstract final class VoiceTrial {
  /// Tries per command before it counts as failed.
  static const int maxAttempts = 3;

  /// The 20 commands, in order.
  static const List<TrialCommand> commands = [
    TrialCommand('susunod', NavIntent.next),
    TrialCommand('nakaraan', NavIntent.previous),
    TrialCommand('ulitin', NavIntent.repeat),
    TrialCommand('bumalik', NavIntent.back),
    TrialCommand('itigil', NavIntent.stopSpeech),
    TrialCommand('i-pause', NavIntent.pause),
    TrialCommand('ituloy', NavIntent.resume),
    TrialCommand('bilisan', NavIntent.faster),
    TrialCommand('bagalan', NavIntent.slower),
    TrialCommand('palakihin', NavIntent.textBigger),
    TrialCommand('paliitin', NavIntent.textSmaller),
    TrialCommand('buksan ang aklatan', NavIntent.library),
    TrialCommand('settings', NavIntent.settings),
    TrialCommand('tulong', NavIntent.help),
    TrialCommand('home', NavIntent.home),
    TrialCommand('camera', NavIntent.camera),
    TrialCommand('mag-upload', NavIntent.upload),
    TrialCommand('basahin', NavIntent.read),
    TrialCommand('mag-report', NavIntent.report),
    TrialCommand('kausapin si percy', NavIntent.assistant),
  ];

  /// The name of what [result] would run (`?` after it when the app would
  /// ask back), or empty for nothing.
  static String matchedName(MatchResult result) => switch (result) {
    Matched(:final target) => targetName(target),
    Ambiguous(:final target) => '${targetName(target)}?',
    NoMatch() => '',
  };

  /// A command target's name (an intent's name, or a screen action id).
  static String targetName(CommandTarget target) => switch (target) {
    ActionTarget(:final actionId) => actionId,
    ValueTarget(:final value) => value is Enum ? value.name : '$value',
  };

  /// Whether [result] runs [command] without asking back.
  static bool isCorrect(TrialCommand command, MatchResult result) =>
      result is Matched && result.target == ValueTarget(command.intent);
}

/// One command of a round, after its last attempt.
@immutable
class TrialRow {
  /// Creates a row.
  const TrialRow({
    required this.at,
    required this.room,
    required this.number,
    required this.command,
    required this.heard,
    required this.matched,
    required this.correct,
    required this.attempts,
    required this.responseMs,
    required this.listenMs,
    required this.totalMs,
    required this.engine,
    required this.noisy,
    required this.confidence,
  });

  /// When the command finished.
  final DateTime at;

  /// The round's room.
  final TrialRoom room;

  /// 1-based position in the round.
  final int number;

  /// What had to be said.
  final TrialCommand command;

  /// What was recognized in the last attempt (empty: nothing heard).
  final String heard;

  /// What it matched ([VoiceTrial.matchedName]).
  final String matched;

  /// It ran the right command.
  final bool correct;

  /// Attempts used (1 = first try).
  final int attempts;

  /// From the end of the user's speech to the command being known, last
  /// attempt (ms; −1 unknown).
  final int responseMs;

  /// From the microphone opening to the result, last attempt (ms; −1
  /// unknown).
  final int listenMs;

  /// From the first attempt's start to the last attempt's result (ms).
  final int totalMs;

  /// `offline` (the app's own recognizer), `android-device`,
  /// `android-online` or `none`.
  final String engine;

  /// The app judged the room noisy (or the result uncertain).
  final bool noisy;

  /// The recognizer's confidence, 0..1; −1 when it doesn't say.
  final double confidence;
}

/// The reliability test's CSV file (app documents, `voice-trials.csv`):
/// rows are appended round after round, so quiet and noisy rounds end up in
/// one file. It stays on the tablet until the tester shares it.
abstract final class VoiceTrialLog {
  /// The file's column names.
  static const List<String> columns = [
    'timestamp',
    'room',
    'number',
    'expected_phrase',
    'expected_command',
    'recognized_text',
    'matched_command',
    'correct',
    'attempts',
    'response_ms',
    'listen_ms',
    'total_ms',
    'engine',
    'noisy_detected',
    'confidence',
  ];

  /// The CSV header line.
  static String get header => columns.join(',');

  /// [row] as one CSV line.
  static String line(TrialRow row) => [
    row.at.toIso8601String(),
    row.room.name,
    '${row.number}',
    _quote(row.command.phrase),
    row.command.expected,
    _quote(row.heard),
    _quote(row.matched),
    row.correct ? '1' : '0',
    '${row.attempts}',
    '${row.responseMs}',
    '${row.listenMs}',
    '${row.totalMs}',
    row.engine,
    row.noisy ? '1' : '0',
    row.confidence < 0 ? '' : row.confidence.toStringAsFixed(2),
  ].join(',');

  static String _quote(String value) =>
      '"${value.replaceAll('"', '""').replaceAll(RegExp(r'[\r\n]+'), ' ')}"';

  /// The file, in the app's documents folder.
  static Future<File> file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'voice-trials.csv'));
  }

  /// Appends [row] to [target] (written with a header if new).
  static Future<void> append(File target, TrialRow row) async {
    final exists = await target.exists() && await target.length() > 0;
    await target.writeAsString(
      '${exists ? '' : '$header\n'}${line(row)}\n',
      mode: FileMode.append,
      flush: true,
    );
  }
}

/// Hands the CSV file to the tester (the share sheet); replaced in tests.
final voiceTrialSharerProvider = Provider<Future<void> Function(String path)>(
  (ref) => (path) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], subject: 'Percipere voice test'),
    );
  },
);
