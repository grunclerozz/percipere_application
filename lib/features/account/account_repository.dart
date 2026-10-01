import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../core/db/daos/preferences_dao.dart';
import '../../core/settings/settings_controller.dart';

/// A local profile.
@immutable
class Account {
  /// Creates an account.
  const Account({required this.id, required this.name, this.email});

  /// `users.id` (UUID).
  final String id;

  /// Display name.
  final String name;

  /// Optional email (for sync with the web app, Phase 7).
  final String? email;

  @override
  bool operator ==(Object other) =>
      other is Account &&
      other.id == id &&
      other.name == name &&
      other.email == email;

  @override
  int get hashCode => Object.hash(id, name, email);
}

/// PIN hashing: salted SHA-256, iterated. PINs never leave the device and
/// are never stored in clear.
abstract final class PinHash {
  /// Hash rounds (slows guessing if the database is copied).
  static const int rounds = 10000;

  /// A new random salt.
  static String newSalt() {
    final random = Random.secure();
    return base64Encode([for (var i = 0; i < 16; i++) random.nextInt(256)]);
  }

  /// Hash of [pin] with [salt].
  static String hash(String pin, String salt) {
    var bytes = utf8.encode('$salt:$pin');
    for (var i = 0; i < rounds; i++) {
      bytes = Uint8List.fromList(sha256.convert(bytes).bytes);
    }
    return base64Encode(bytes);
  }
}

/// Local profiles in the `users` table.
class AccountRepository {
  /// Creates the repository.
  AccountRepository(this._db);

  final DatabaseExecutor _db;

  static Account _from(Map<String, Object?> r) => Account(
    id: r['id']! as String,
    name: r['display_name']! as String,
    email: r['email'] as String?,
  );

  /// All profiles, most recently used first.
  Future<List<Account>> list() async => (await _db.query(
    'users',
    orderBy: 'COALESCE(last_login_at, created_at) DESC',
  )).map(_from).toList();

  /// One profile, or null.
  Future<Account?> get(String id) async {
    final rows = await _db.query('users', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _from(rows.single);
  }

  /// Creates a profile with a hashed [pin].
  Future<Account> create({
    required String name,
    String? email,
    required String pin,
  }) async {
    final id = const Uuid().v4();
    final salt = PinHash.newSalt();
    final now = DateTime.now().millisecondsSinceEpoch;
    final cleanEmail = email?.trim();
    await _db.insert('users', {
      'id': id,
      'display_name': name.trim(),
      'email': cleanEmail == null || cleanEmail.isEmpty ? null : cleanEmail,
      'secret_hash': PinHash.hash(pin, salt),
      'secret_salt': salt,
      'created_at': now,
      'updated_at': now,
    });
    return (await get(id))!;
  }

  /// Whether [pin] is right for profile [id].
  Future<bool> verify(String id, String pin) async {
    final rows = await _db.query(
      'users',
      columns: ['secret_hash', 'secret_salt'],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return false;
    final r = rows.single;
    return PinHash.hash(pin, r['secret_salt']! as String) == r['secret_hash'];
  }

  /// Records a login.
  Future<void> markLogin(String id) => _db.update(
    'users',
    {'last_login_at': DateTime.now().millisecondsSinceEpoch},
    where: 'id = ?',
    whereArgs: [id],
  );
}

/// Local profiles.
final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(ref.watch(appDatabaseProvider).db),
);

/// The profile logged in at startup. Set by `bootstrap()`.
final initialAccountProvider = Provider<Account?>((ref) => null);

/// The logged-in profile, or null (the device's own settings are used).
/// Logging in/out switches which settings are active.
class CurrentAccount extends Notifier<Account?> {
  @override
  Account? build() => ref.read(initialAccountProvider);

  PreferencesDao get _prefs => PreferencesDao(ref.read(appDatabaseProvider).db);

  /// Logs [account] in and switches to its settings.
  Future<void> login(Account account) async {
    await ref.read(accountRepositoryProvider).markLogin(account.id);
    await _prefs.set(PrefKeys.currentUser, account.id);
    await ref.read(settingsProvider.notifier).switchScope(account.id);
    state = account;
  }

  /// Logs out and returns to the device's settings.
  Future<void> logout() async {
    await _prefs.remove(PrefKeys.currentUser);
    await ref
        .read(settingsProvider.notifier)
        .switchScope(PreferencesDao.deviceScope);
    state = null;
  }
}

/// Logged-in profile.
final currentAccountProvider = NotifierProvider<CurrentAccount, Account?>(
  CurrentAccount.new,
);
