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

  /// Pre-6B text size multiplier (read only, converted to [textSize]).
  static const String textScale = 'ui.textScale';

  /// Text size in sp.
  static const String textSize = 'ui.textSize';

  /// Text color id (`TextColors`), or null for the theme default.
  static const String textColor = 'ui.textColor';

  /// Start reading new documents automatically.
  static const String autoRead = 'reader.autoRead';

  /// Keep listening for commands while a document is read aloud.
  static const String listenWhileReading = 'voice.listenWhileReading';

  /// `ask`, `allowed` or `declined`: detailed image descriptions.
  static const String describeConsent = 'describe.consent';

  /// Percy's politeness: `'po'` or `'casual'`.
  static const String percyPoliteness = 'percy.politeness';

  /// Percy's talkativeness: `'brief'`, `'normal'` or `'chatty'`.
  static const String percyTalk = 'percy.talk';

  /// Keep Percy's turn log for retraining (bool).
  static const String percyLogging = 'percy.logging';

  /// Developer option: the ElevenLabs Percy instead of the self-built one.
  static const String percyElevenLabs = 'percy.elevenLabs';

  /// True once the Maglarawan explanation has been read to this user.
  static const String describeIntroSeen = 'describe.introSeen';

  /// Keep the session between launches.
  static const String stayLoggedIn = 'account.stayLoggedIn';

  /// Profiling steps finished (JSON list of step names).
  static const String setupDone = 'setup.done';

  /// Profiling step to resume at (step name).
  static const String setupStep = 'setup.step';

  /// Answer to "can you see some text?" (profiling).
  static const String setupSeesText = 'setup.seesText';

  /// Guest reminder given after the first save to history.
  static const String guestReminderHistory = 'guest.reminder.history';

  /// Guest reminder given in Settings.
  static const String guestReminderSettings = 'guest.reminder.settings';

  /// How many times a guest was warned about downloaded books (0, 1 at the
  /// first download, 2 after the follow-up in the Library).
  static const String guestReminderDownload = 'guest.reminder.download';

  /// Device scope: the microphone was already requested on Welcome.
  static const String micAsked = 'mic.askedOnWelcome';

  /// Font family name.
  static const String font = 'ui.font';

  /// Color theme name.
  static const String palette = 'ui.palette';

  /// Haptics on/off.
  static const String haptics = 'haptics.enabled';

  /// `'brief'`, `'normal'` or `'detailed'`.
  static const String verbosity = 'speech.verbosity';

  /// Times each screen was opened, `{screenId: count}` (per user).
  static const String screenVisits = 'speech.screenVisits';

  /// The controls tutorial was finished or skipped on this device.
  static const String tutorialDone = 'tutorial.done';

  /// Camera auto-capture on/off.
  static const String autoCapture = 'camera.autoCapture';

  /// Device scope, pre-6B only: id of the logged-in PIN profile. The
  /// session now lives in secure storage; read once to migrate it.
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
