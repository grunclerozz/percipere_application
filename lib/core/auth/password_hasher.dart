import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A stored secret: how it was made, the salt and the hash (both base64).
class StoredSecret {
  /// Creates a stored secret.
  const StoredSecret({
    required this.kind,
    required this.salt,
    required this.hash,
  });

  /// `pbkdf2-sha256:<iterations>` (or `pin` for legacy PINs).
  final String kind;

  /// Random per-secret salt, base64.
  final String salt;

  /// Derived key, base64.
  final String hash;
}

/// Salted, slow password hashing: PBKDF2-HMAC-SHA256 with a 16-byte random
/// salt. Passwords are never stored or logged in plain text; only the
/// derived key leaves this class.
///
/// The iteration count is stored with each hash ([StoredSecret.kind]), so it
/// can be raised later without breaking existing accounts.
class PasswordHasher {
  /// Creates a hasher. Tests use fewer [iterations] and no isolate.
  const PasswordHasher({
    this.iterations = defaultIterations,
    this.useIsolate = true,
  });

  /// Iterations for new hashes.
  static const int defaultIterations = 100000;

  /// Salt length in bytes.
  static const int saltBytes = 16;

  /// Derived key length in bytes.
  static const int keyBytes = 32;

  static const String _prefix = 'pbkdf2-sha256:';

  /// Iterations for new hashes.
  final int iterations;

  /// Hash on a background isolate (keeps the UI and speech responsive).
  final bool useIsolate;

  /// Hashes [secret] with a new random salt.
  Future<StoredSecret> hash(String secret) async {
    final random = Random.secure();
    final salt = base64Encode([
      for (var i = 0; i < saltBytes; i++) random.nextInt(256),
    ]);
    final key = await _derive(secret, salt, iterations);
    return StoredSecret(kind: '$_prefix$iterations', salt: salt, hash: key);
  }

  /// Whether [secret] matches a hash made by [hash].
  Future<bool> verify(String secret, StoredSecret stored) async {
    final n = iterationsOf(stored.kind);
    if (n == null) return false;
    final key = await _derive(secret, stored.salt, n);
    return _constantTimeEquals(key, stored.hash);
  }

  /// Iterations encoded in [kind], or null if it isn't a PBKDF2 hash.
  static int? iterationsOf(String kind) => kind.startsWith(_prefix)
      ? int.tryParse(kind.substring(_prefix.length))
      : null;

  Future<String> _derive(String secret, String salt, int n) {
    if (!useIsolate) return Future.value(pbkdf2(secret, salt, n));
    return Isolate.run(() => pbkdf2(secret, salt, n));
  }

  /// PBKDF2-HMAC-SHA256 (RFC 8018) of [secret] with base64 [salt]; returns
  /// the base64 derived key ([keyBytes] long — a single block).
  static String pbkdf2(String secret, String salt, int iterations) {
    final hmac = Hmac(sha256, utf8.encode(secret));
    final saltBytes = base64Decode(salt);
    // Block 1: U1 = HMAC(P, S || INT(1)).
    final first = Uint8List(saltBytes.length + 4)
      ..setAll(0, saltBytes)
      ..[saltBytes.length + 3] = 1;
    var u = hmac.convert(first).bytes;
    final out = Uint8List.fromList(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < out.length; j++) {
        out[j] ^= u[j];
      }
    }
    return base64Encode(out);
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}

/// The app's password hasher (tests override it with a fast one).
final passwordHasherProvider = Provider<PasswordHasher>(
  (ref) => const PasswordHasher(),
);
