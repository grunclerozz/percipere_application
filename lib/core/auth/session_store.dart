import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the login session lives between launches (Android Keystore-backed
/// encrypted storage). Holds account ids and the web app's sign-in tokens —
/// never a password.
abstract interface class SessionStore {
  /// The logged-in account id, or null.
  Future<String?> readUserId();

  /// Remembers [userId] as logged in.
  Future<void> writeUserId(String userId);

  /// Forgets the session (logout).
  Future<void> clearUserId();

  /// The account whose fingerprint login is on, or null.
  Future<String?> readFingerprintUserId();

  /// Sets (or clears, with null) the fingerprint account.
  Future<void> writeFingerprintUserId(String? userId);

  /// The web app's sign-in token of local account [userId], or null.
  Future<String?> readApiToken(String userId);

  /// Sets (or clears, with null) the web app's token of [userId].
  Future<void> writeApiToken(String userId, String? token);
}

/// [SessionStore] on `flutter_secure_storage`.
class SecureSessionStore implements SessionStore {
  /// Creates the store.
  const SecureSessionStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  static const String _userKey = 'session.userId';
  static const String _fingerprintKey = 'session.fingerprintUserId';

  static String _tokenKey(String userId) => 'api.token.$userId';

  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } on Object catch (e) {
      // Corrupted keystore entries (e.g. after a restore): act logged out.
      debugPrint('Secure storage read failed: $e');
      return null;
    }
  }

  @override
  Future<String?> readUserId() => _read(_userKey);

  @override
  Future<void> writeUserId(String userId) =>
      _storage.write(key: _userKey, value: userId);

  @override
  Future<void> clearUserId() => _storage.delete(key: _userKey);

  @override
  Future<String?> readFingerprintUserId() => _read(_fingerprintKey);

  @override
  Future<void> writeFingerprintUserId(String? userId) => userId == null
      ? _storage.delete(key: _fingerprintKey)
      : _storage.write(key: _fingerprintKey, value: userId);

  @override
  Future<String?> readApiToken(String userId) => _read(_tokenKey(userId));

  @override
  Future<void> writeApiToken(String userId, String? token) => token == null
      ? _storage.delete(key: _tokenKey(userId))
      : _storage.write(key: _tokenKey(userId), value: token);
}

/// In-memory [SessionStore] (tests).
class MemorySessionStore implements SessionStore {
  /// Creates an empty store, or one with a saved session.
  MemorySessionStore({this.userId, this.fingerprintUserId});

  /// Saved session.
  String? userId;

  /// Fingerprint account.
  String? fingerprintUserId;

  /// Web app tokens by local account id.
  final Map<String, String> apiTokens = {};

  @override
  Future<String?> readUserId() async => userId;

  @override
  Future<void> writeUserId(String userId) async => this.userId = userId;

  @override
  Future<void> clearUserId() async => userId = null;

  @override
  Future<String?> readFingerprintUserId() async => fingerprintUserId;

  @override
  Future<void> writeFingerprintUserId(String? userId) async =>
      fingerprintUserId = userId;

  @override
  Future<String?> readApiToken(String userId) async => apiTokens[userId];

  @override
  Future<void> writeApiToken(String userId, String? token) async =>
      token == null ? apiTokens.remove(userId) : apiTokens[userId] = token;
}

/// The session store.
final sessionStoreProvider = Provider<SessionStore>(
  (ref) => const SecureSessionStore(),
);
