import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import 'account.dart';
import 'password_hasher.dart';
import 'validators.dart';

/// Registration failed because the email is already used on this device.
class EmailTakenException implements Exception {
  /// Creates the exception.
  const EmailTakenException();
}

/// Accounts in the `users` table: registration, password checks, security
/// questions, the guest profile and legacy PIN accounts.
///
/// Every change to a real (non-guest) account clears `synced`, so Phase 7's
/// sync knows what to send.
class AccountRepository {
  /// Creates the repository.
  AccountRepository(this._db, this._hasher);

  final Database _db;
  final PasswordHasher _hasher;

  static int get _now => DateTime.now().millisecondsSinceEpoch;

  static Account _from(Map<String, Object?> r) => Account(
    id: r['id']! as String,
    firstName: (r['first_name'] ?? r['display_name'])! as String,
    lastName: (r['last_name'] as String?) ?? '',
    email: r['email'] as String?,
    isGuest: r['is_guest'] == 1,
    isLegacy: r['secret_kind'] == 'pin',
    profilingCompleted: r['profiling_completed'] == 1,
    fingerprintEnabled: r['fingerprint_enabled'] == 1,
    securityQuestion: r['security_question'] as String?,
    synced: r['synced'] == 1,
    serverId: r['server_id'] as String?,
  );

  /// One account, or null.
  Future<Account?> get(String id) async {
    final rows = await _db.query('users', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _from(rows.single);
  }

  /// The account using [email], or null.
  Future<Account?> findByEmail(String email) async {
    final rows = await _db.query(
      'users',
      where: 'email = ? COLLATE NOCASE',
      whereArgs: [AuthRules.normalizeEmail(email)],
    );
    return rows.isEmpty ? null : _from(rows.single);
  }

  /// The account linked to web app account [serverId], or null.
  Future<Account?> findByServerId(String serverId) async {
    final rows = await _db.query(
      'users',
      where: 'server_id = ? AND is_guest = 0',
      whereArgs: [serverId],
      limit: 1,
    );
    return rows.isEmpty ? null : _from(rows.single);
  }

  /// Whether [email] is used by an account other than [exceptId].
  Future<bool> emailTaken(String email, {String? exceptId}) async {
    final a = await findByEmail(email);
    return a != null && a.id != exceptId;
  }

  /// Creates an account; the password is stored only as a salted hash.
  /// Throws [EmailTakenException] if the email is already used here.
  Future<Account> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    final clean = AuthRules.normalizeEmail(email);
    if (await emailTaken(clean)) throw const EmailTakenException();
    final secret = await _hasher.hash(password);
    final id = const Uuid().v4();
    final now = _now;
    final first = firstName.trim();
    final last = lastName.trim();
    try {
      await _db.insert('users', {
        'id': id,
        'display_name': [first, last].where((s) => s.isNotEmpty).join(' '),
        'first_name': first,
        'last_name': last,
        'email': clean,
        'secret_kind': secret.kind,
        'secret_hash': secret.hash,
        'secret_salt': secret.salt,
        'created_at': now,
        'updated_at': now,
      });
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) throw const EmailTakenException();
      rethrow;
    }
    return (await get(id))!;
  }

  /// The account for [email] if [password] is right; otherwise null.
  /// Legacy and guest accounts have no password.
  Future<Account?> verifyPassword(String email, String password) async {
    final rows = await _db.query(
      'users',
      where: 'email = ? COLLATE NOCASE AND is_guest = 0',
      whereArgs: [AuthRules.normalizeEmail(email)],
    );
    if (rows.isEmpty) return null;
    final r = rows.single;
    final ok = await _hasher.verify(
      password,
      StoredSecret(
        kind: r['secret_kind']! as String,
        salt: r['secret_salt']! as String,
        hash: r['secret_hash']! as String,
      ),
    );
    return ok ? _from(r) : null;
  }

  /// Sets a new password for [id].
  Future<void> setPassword(String id, String password) async {
    final secret = await _hasher.hash(password);
    await _change(id, {
      'secret_kind': secret.kind,
      'secret_hash': secret.hash,
      'secret_salt': secret.salt,
    });
  }

  /// Sets the security question and its (normalized, hashed) answer.
  Future<void> setSecurityAnswer(
    String id,
    SecurityQuestion question,
    String answer,
  ) async {
    final secret = await _hasher.hash(AuthRules.normalizeAnswer(answer));
    await _change(id, {
      'security_question': question.name,
      'security_answer_hash': '${secret.kind}\$${secret.hash}',
      'security_answer_salt': secret.salt,
    });
  }

  /// Whether [answer] matches the security answer of [id].
  Future<bool> verifySecurityAnswer(String id, String answer) async {
    final rows = await _db.query(
      'users',
      columns: ['security_answer_hash', 'security_answer_salt'],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return false;
    final stored = rows.single['security_answer_hash'] as String?;
    final salt = rows.single['security_answer_salt'] as String?;
    if (stored == null || salt == null) return false;
    final split = stored.indexOf(r'$');
    if (split < 0) return false;
    return _hasher.verify(
      AuthRules.normalizeAnswer(answer),
      StoredSecret(
        kind: stored.substring(0, split),
        salt: salt,
        hash: stored.substring(split + 1),
      ),
    );
  }

  /// Records a login.
  Future<void> markLogin(String id) => _db.update(
    'users',
    {'last_login_at': _now},
    where: 'id = ?',
    whereArgs: [id],
  );

  /// Marks the guided setup completed (or not, for "Ulitin ang setup").
  Future<void> setProfilingCompleted(String id, bool done) =>
      _change(id, {'profiling_completed': done ? 1 : 0});

  /// Turns fingerprint login on or off.
  Future<void> setFingerprint(String id, bool enabled) =>
      _change(id, {'fingerprint_enabled': enabled ? 1 : 0});

  /// Records that the web app has this version of [id] (Phase 7).
  Future<void> markSynced(String id, String serverId) => _db.update(
    'users',
    {'synced': 1, 'server_id': serverId},
    where: 'id = ?',
    whereArgs: [id],
  );

  /// Real accounts the web app doesn't have yet. Guests are never synced.
  Future<List<Account>> unsynced() async => (await _db.query(
    'users',
    where: "synced = 0 AND is_guest = 0 AND secret_kind != 'pin'",
  )).map(_from).toList();

  Future<void> _change(String id, Map<String, Object?> values) => _db.update(
    'users',
    {...values, 'updated_at': _now, 'synced': 0},
    where: 'id = ?',
    whereArgs: [id],
  );

  // ── Guest ─────────────────────────────────────────────────────────────────

  /// The device's guest profile, created on first use and reused after.
  Future<Account> guest({required String name}) async {
    final rows = await _db.query('users', where: 'is_guest = 1', limit: 1);
    if (rows.isNotEmpty) return _from(rows.single);
    final id = const Uuid().v4();
    final now = _now;
    await _db.insert('users', {
      'id': id,
      'display_name': name,
      'first_name': name,
      'last_name': '',
      'secret_kind': 'none',
      'secret_hash': '',
      'secret_salt': '',
      'is_guest': 1,
      'created_at': now,
      'updated_at': now,
    });
    return (await get(id))!;
  }

  /// Moves the guest's preferences, Library (documents, downloads, progress,
  /// favorites, collections) and issue reports to [accountId], then
  /// deletes the guest profile. The account's own preferences are replaced
  /// by the guest's (it was just created from them anyway).
  Future<void> migrateGuest(
    String guestId,
    String accountId,
  ) => _db.transaction((txn) async {
    // The whole Library moves: documents, downloaded books and progress,
    // favorites (they follow their items) and collections.
    for (final table in [
      'library_items',
      'library_collections',
      'issue_reports',
    ]) {
      await txn.update(
        table,
        {'user_id': accountId},
        where: 'user_id = ?',
        whereArgs: [guestId],
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await txn.rawInsert(
      'INSERT OR REPLACE INTO preferences (user_id, key, value, updated_at) '
      'SELECT ?, key, value, updated_at FROM preferences WHERE user_id = ?',
      [accountId, guestId],
    );
    await txn.delete('preferences', where: 'user_id = ?', whereArgs: [guestId]);
    await txn.delete(
      'users',
      where: 'id = ? AND is_guest = 1',
      whereArgs: [guestId],
    );
  });

  // ── Legacy PIN accounts (migration only) ──────────────────────────────────

  /// Old name + PIN accounts that haven't set an email and password yet.
  Future<List<Account>> legacyAccounts() async => (await _db.query(
    'users',
    where: "secret_kind = 'pin'",
    orderBy: 'COALESCE(last_login_at, created_at) DESC',
  )).map(_from).toList();

  /// Whether [pin] is the old PIN of legacy account [id].
  Future<bool> verifyLegacyPin(String id, String pin) async {
    final rows = await _db.query(
      'users',
      columns: ['secret_hash', 'secret_salt'],
      where: "id = ? AND secret_kind = 'pin'",
      whereArgs: [id],
    );
    if (rows.isEmpty) return false;
    final r = rows.single;
    return LegacyPinHash.hash(pin, r['secret_salt']! as String) ==
        r['secret_hash'];
  }

  /// Turns legacy account [id] into an email + password account, keeping
  /// its settings and history. Throws [EmailTakenException].
  Future<Account> upgradeLegacy(
    String id, {
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    final clean = AuthRules.normalizeEmail(email);
    if (await emailTaken(clean, exceptId: id)) {
      throw const EmailTakenException();
    }
    final secret = await _hasher.hash(password);
    final first = firstName.trim();
    final last = lastName.trim();
    await _change(id, {
      'display_name': [first, last].where((s) => s.isNotEmpty).join(' '),
      'first_name': first,
      'last_name': last,
      'email': clean,
      'secret_kind': secret.kind,
      'secret_hash': secret.hash,
      'secret_salt': secret.salt,
    });
    return (await get(id))!;
  }
}

/// How Phase 6 hashed 4-digit PINs (salted SHA-256, 10 000 rounds). Kept
/// only to let legacy accounts prove who they are once, when upgrading.
abstract final class LegacyPinHash {
  /// Hash of [pin] with [salt].
  static String hash(String pin, String salt) {
    var bytes = utf8.encode('$salt:$pin');
    for (var i = 0; i < 10000; i++) {
      bytes = Uint8List.fromList(sha256.convert(bytes).bytes);
    }
    return base64Encode(bytes);
  }
}

/// Accounts.
final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(
    ref.watch(appDatabaseProvider).db,
    ref.watch(passwordHasherProvider),
  ),
);
