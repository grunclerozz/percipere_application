import 'dart:convert';

import 'package:sqflite/sqflite.dart';

/// Preference keys. Values are JSON-encoded.
abstract final class PrefKeys {
  /// `'voice'` or `'gestures'`.
  static const String navigationMode = 'nav.mode';

  /// True while prompts fall back to English for lack of a Filipino voice.
  static const String ttsFilipinoFallback = 'tts.filipinoFallback';

  /// Reading speed multiplier (1.0 = normal).
  static const String readingRate = 'tts.readingRate';

  /// Voice pitch (1.0 = normal).
  static const String pitch = 'tts.pitch';

  /// `'fil'` or `'en'`.
  static const String locale = 'ui.locale';

  /// `'auto'`, `'filipino'` or `'english'`.
  static const String documentVoice = 'doc.voice';

  /// In-app text size multiplier.
  static const String textScale = 'ui.textScale';

  /// Font family name.
  static const String font = 'ui.font';

  /// Color theme name.
  static const String palette = 'ui.palette';

  /// Haptics on/off.
  static const String haptics = 'haptics.enabled';

  /// `'brief'`, `'normal'` or `'detailed'`.
  static const String verbosity = 'speech.verbosity';

  /// Camera auto-capture on/off.
  static const String autoCapture = 'camera.autoCapture';

  /// Device scope: id of the logged-in profile, or null.
  static const String currentUser = 'account.currentUser';
}

/// Reads and writes the `preferences` table.
///
/// [deviceScope] holds settings made before any account exists (e.g. the
/// navigation mode chosen on the Welcome screen).
class PreferencesDao {
  /// Creates the DAO over an open database.
  PreferencesDao(this._db);

  /// Scope for device-level (pre-login) preferences.
  static const String deviceScope = 'device';

  final DatabaseExecutor _db;

  /// Returns the decoded value for [key], or null.
  Future<Object?> get(String key, {String userId = deviceScope}) async {
    final rows = await _db.query(
      'preferences',
      columns: ['value'],
      where: 'user_id = ? AND key = ?',
      whereArgs: [userId, key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return jsonDecode(rows.single['value']! as String);
  }

  /// Stores [value] (JSON-encodable) for [key].
  Future<void> set(
    String key,
    Object? value, {
    String userId = deviceScope,
  }) async {
    await _db.insert('preferences', {
      'user_id': userId,
      'key': key,
      'value': jsonEncode(value),
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// All decoded values for [userId].
  Future<Map<String, Object?>> getAll({String userId = deviceScope}) async {
    final rows = await _db.query(
      'preferences',
      columns: ['key', 'value'],
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return {
      for (final r in rows)
        r['key']! as String: jsonDecode(r['value']! as String),
    };
  }

  /// Deletes [key].
  Future<void> remove(String key, {String userId = deviceScope}) async {
    await _db.delete(
      'preferences',
      where: 'user_id = ? AND key = ?',
      whereArgs: [userId, key],
    );
  }
}
