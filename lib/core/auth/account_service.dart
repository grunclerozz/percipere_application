import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'account.dart';
import 'account_api.dart';
import 'account_repository.dart';
import 'session_store.dart';

/// What a server login came to.
sealed class LoginOutcome {
  const LoginOutcome();
}

/// Logged in; [offline] when the web app couldn't be reached and the
/// password was checked against the copy kept on this phone.
class LoggedIn extends LoginOutcome {
  /// Creates the outcome.
  const LoggedIn(this.account, {this.offline = false});

  /// The local account (linked to the server account).
  final Account account;

  /// Checked on the phone, not on the server.
  final bool offline;
}

/// The email must be confirmed with the emailed code first: an account that
/// was never verified, or one that only existed on this phone and was just
/// [moved] to the web app.
class NeedsEmailCode extends LoginOutcome {
  /// Creates the outcome.
  const NeedsEmailCode(this.email, {this.moved = false, this.emailSent = true});

  /// The account's email.
  final String email;

  /// A phone-only account was just registered on the web app.
  final bool moved;

  /// Whether the code email went out.
  final bool emailSent;
}

/// Refused: wrong password, suspended, waiting for approval, locked
/// ([retryAfter]), no connection with no phone copy to fall back on, ….
class LoginRefused extends LoginOutcome {
  /// Creates the outcome.
  const LoginRefused(this.reason, {this.retryAfter = Duration.zero});

  /// Why.
  final AccountApiError reason;

  /// How long to wait ([AccountApiError.tooManyAttempts]).
  final Duration retryAfter;
}

/// What the web app says about a saved session.
enum SessionCheck {
  /// Still fine.
  ok,

  /// Suspended in the dashboard: log out.
  suspended,

  /// The token no longer works (expired, logged out elsewhere, password
  /// reset): it was forgotten; the phone stays logged in.
  tokenGone,

  /// Couldn't tell (offline, no token, accounts on the phone only).
  unknown,
}

/// Accounts on the web app, kept in step with the phone's own `users` rows.
///
/// The web app decides who may log in. Each server account has a local
/// account (settings, Library, fingerprint) linked by `users.server_id`;
/// the password is also kept on the phone as a salted hash, so a user who
/// logged in here before can still log in without internet. The sign-in
/// token lives only in secure storage.
class AccountService {
  /// Creates the service; [api] null means accounts stay on the phone.
  AccountService(this._api, this._repo, this._sessions, this._deviceLabel);

  final AccountApi? _api;
  final AccountRepository _repo;
  final SessionStore _sessions;
  final Future<String> Function() _deviceLabel;

  /// Whether accounts live on the web app.
  bool get usesServer => _api != null;

  AccountApi get _server => _api!;

  /// Logs in on the web app (see [LoginOutcome]).
  Future<LoginOutcome> login(String email, String password) async {
    try {
      final session = await _server.login(
        email: email,
        password: password,
        device: await _deviceLabel(),
      );
      return LoggedIn(await _keep(session, password));
    } on AccountApiException catch (e) {
      switch (e.error) {
        case AccountApiError.invalidCredentials:
          return await _moveToServer(email, password) ??
              const LoginRefused(AccountApiError.invalidCredentials);
        case AccountApiError.verifyEmail:
          // A fresh code; if one was sent a moment ago, that one still works.
          await _quietly(() => _server.resend(email));
          return NeedsEmailCode(email);
        case AccountApiError.offline:
          final local = await _repo.verifyPassword(email, password);
          if (local != null) return LoggedIn(local, offline: true);
          final known = await _repo.findByEmail(email);
          return LoginRefused(
            known == null
                ? AccountApiError.offline
                : AccountApiError.invalidCredentials,
          );
        default:
          return LoginRefused(e.error, retryAfter: e.retryAfter);
      }
    }
  }

  /// A phone-only account (made before the web app) whose password is right
  /// here: registered on the web app with the same name and password.
  Future<LoginOutcome?> _moveToServer(String email, String password) async {
    final local = await _repo.findByEmail(email);
    if (local == null || local.isGuest || local.serverId != null) return null;
    if (await _repo.verifyPassword(email, password) == null) return null;
    try {
      final sent = await _server.register(
        fullName: local.name,
        email: email,
        password: password,
      );
      return NeedsEmailCode(email, moved: true, emailSent: sent);
    } on AccountApiException catch (e) {
      // Already on the server (with another password): just a wrong password.
      if (e.error == AccountApiError.emailTaken) return null;
      return LoginRefused(e.error, retryAfter: e.retryAfter);
    }
  }

  /// Registers on the web app; returns whether the code email went out.
  /// Throws [AccountApiException].
  Future<bool> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) => _server.register(
    fullName: [
      firstName.trim(),
      lastName.trim(),
    ].where((s) => s.isNotEmpty).join(' '),
    email: email,
    password: password,
  );

  /// Checks the emailed code and links (or creates) the local account.
  /// Returns null when the account now waits for an administrator.
  /// Throws [AccountApiException].
  Future<Account?> verifyEmail({
    required String email,
    required String code,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    final session = await _server.verify(
      email: email,
      code: code,
      device: await _deviceLabel(),
    );
    if (session == null) return null;
    return _keep(session, password, firstName: firstName, lastName: lastName);
  }

  /// Emails a new registration code. Throws [AccountApiException].
  Future<void> resendCode(String email) => _server.resend(email);

  /// Emails a code for a new password. Throws [AccountApiException].
  Future<void> forgotPassword(String email) => _server.forgotPassword(email);

  /// Sets a new password with the emailed code and returns the (linked)
  /// local account. Throws [AccountApiException].
  Future<Account> resetPassword({
    required String email,
    required String code,
    required String password,
  }) async {
    final session = await _server.resetPassword(
      email: email,
      code: code,
      password: password,
      device: await _deviceLabel(),
    );
    return _keep(session, password);
  }

  /// Ends [account]'s web session (best effort: logging out never waits on
  /// the network) and forgets the token.
  Future<void> signOut(Account account) async {
    final token = await _sessions.readApiToken(account.id);
    if (token == null) return;
    await _sessions.writeApiToken(account.id, null);
    final api = _api;
    if (api != null) {
      unawaited(
        _quietly(() => api.logout(token).timeout(const Duration(seconds: 5))),
      );
    }
  }

  /// Asks the web app whether [account]'s session still stands.
  Future<SessionCheck> check(Account account) async {
    final api = _api;
    if (api == null || account.isGuest) return SessionCheck.unknown;
    final token = await _sessions.readApiToken(account.id);
    if (token == null) return SessionCheck.unknown;
    try {
      await api.me(token);
      return SessionCheck.ok;
    } on AccountApiException catch (e) {
      switch (e.error) {
        case AccountApiError.accountSuspended:
          return SessionCheck.suspended;
        case AccountApiError.unauthorized:
          await _sessions.writeApiToken(account.id, null);
          return SessionCheck.tokenGone;
        default:
          return SessionCheck.unknown;
      }
    }
  }

  /// Finds (or creates) the local account for [session], keeps [password]
  /// for offline login, links it and stores the token.
  Future<Account> _keep(
    ServerSession session,
    String password, {
    String? firstName,
    String? lastName,
  }) async {
    final user = session.user;
    var account =
        await _repo.findByServerId(user.id) ??
        await _repo.findByEmail(user.email);
    if (account == null) {
      final (first, last) = firstName != null
          ? (firstName, lastName ?? '')
          : splitName(user.fullName);
      account = await _repo.register(
        firstName: first,
        lastName: last,
        email: user.email,
        password: password,
      );
    } else {
      await _repo.setPassword(account.id, password);
    }
    await _repo.markSynced(account.id, user.id);
    await _sessions.writeApiToken(account.id, session.token);
    return (await _repo.get(account.id))!;
  }

  /// "Juan dela Cruz" → ("Juan", "dela Cruz"); the web app keeps one name.
  static (String, String) splitName(String fullName) {
    final clean = fullName.trim().replaceAll(RegExp(r'\s+'), ' ');
    final space = clean.indexOf(' ');
    return space < 0
        ? (clean, '')
        : (clean.substring(0, space), clean.substring(space + 1));
  }

  static Future<void> _quietly(Future<void> Function() call) async {
    try {
      await call();
    } on Object catch (e) {
      debugPrint('Account API (ignored): $e');
    }
  }
}

/// The phone's model and Android version, sent with each login so the
/// dashboard can tell devices apart ("samsung SM-X200, Android 14").
Future<String> androidDeviceLabel() async {
  try {
    final info = await DeviceInfoPlugin().androidInfo;
    final label =
        '${info.manufacturer} ${info.model}, '
        'Android ${info.version.release}';
    return label.length > 100 ? label.substring(0, 100) : label;
  } on Object catch (e) {
    debugPrint('Device info failed: $e');
    return 'Android';
  }
}

/// How the device is named to the web app (tests override it).
final deviceLabelProvider = Provider<Future<String> Function()>(
  (ref) => androidDeviceLabel,
);

/// Accounts on the web app and the phone.
final accountServiceProvider = Provider<AccountService>(
  (ref) => AccountService(
    ref.watch(accountApiProvider),
    ref.watch(accountRepositoryProvider),
    ref.watch(sessionStoreProvider),
    ref.watch(deviceLabelProvider),
  ),
);
