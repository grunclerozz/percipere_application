import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import 'validators.dart';

/// What kind of secret is being guessed; each has its own counter.
enum ThrottleKind {
  /// Password login.
  login,

  /// Security-question answer (forgot password).
  reset,
}

/// Lockout after repeated failures, per email, stored in SQLite so it
/// survives an app restart.
///
/// The first [freeAttempts] failures cost nothing; the next one locks for
/// [baseDelay], and every further failure doubles it (30 s, 60 s, 2 min, …,
/// at most [maxDelay]). A success clears the counter.
class LoginThrottle {
  /// Creates the throttle.
  LoginThrottle(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  /// Failures allowed before the first lockout.
  static const int freeAttempts = 5;

  /// First lockout.
  static const Duration baseDelay = Duration(seconds: 30);

  /// Longest lockout.
  static const Duration maxDelay = Duration(hours: 1);

  final DatabaseExecutor _db;
  final DateTime Function() _clock;

  static String _key(ThrottleKind kind, String email) =>
      '${kind.name}:${AuthRules.normalizeEmail(email)}';

  /// Lockout length after [failures] failures (zero below the limit).
  static Duration delayAfter(int failures) {
    if (failures < freeAttempts) return Duration.zero;
    final doublings = math.min(failures - freeAttempts, 20);
    final ms = baseDelay.inMilliseconds * math.pow(2, doublings);
    return Duration(
      milliseconds: math.min(ms.toInt(), maxDelay.inMilliseconds),
    );
  }

  /// Time left before [email] may try again; zero if it may try now.
  Future<Duration> remaining(ThrottleKind kind, String email) async {
    final rows = await _db.query(
      'login_attempts',
      columns: ['locked_until'],
      where: 'key = ?',
      whereArgs: [_key(kind, email)],
    );
    final until = rows.isEmpty ? null : rows.single['locked_until'] as int?;
    if (until == null) return Duration.zero;
    final left = until - _clock().millisecondsSinceEpoch;
    return left > 0 ? Duration(milliseconds: left) : Duration.zero;
  }

  /// Records a failure; returns the lockout it starts (zero if none).
  Future<Duration> recordFailure(ThrottleKind kind, String email) async {
    final key = _key(kind, email);
    final rows = await _db.query(
      'login_attempts',
      columns: ['failures'],
      where: 'key = ?',
      whereArgs: [key],
    );
    final failures = (rows.isEmpty ? 0 : rows.single['failures']! as int) + 1;
    final delay = delayAfter(failures);
    final now = _clock().millisecondsSinceEpoch;
    await _db.insert('login_attempts', {
      'key': key,
      'failures': failures,
      'locked_until': delay == Duration.zero
          ? null
          : now + delay.inMilliseconds,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return delay;
  }

  /// Failures so far for [email].
  Future<int> failures(ThrottleKind kind, String email) async {
    final rows = await _db.query(
      'login_attempts',
      columns: ['failures'],
      where: 'key = ?',
      whereArgs: [_key(kind, email)],
    );
    return rows.isEmpty ? 0 : rows.single['failures']! as int;
  }

  /// Clears the counter after a success.
  Future<void> reset(ThrottleKind kind, String email) => _db.delete(
    'login_attempts',
    where: 'key = ?',
    whereArgs: [_key(kind, email)],
  );
}

/// Login lockout.
final loginThrottleProvider = Provider<LoginThrottle>(
  (ref) => LoginThrottle(ref.watch(appDatabaseProvider).db),
);
