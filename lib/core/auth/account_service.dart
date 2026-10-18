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

/// What registering on the web app came to.
class RegisterResult {
  /// Creates the result.
  const RegisterResult(this.status, this.account);

  /// What the web app said about the new account.
  final RegisterStatus status;

  /// The logged-in local account; null when the login after registering
  /// didn't work (waiting for approval, no connection).
  final Account? account;

  /// Whether the user is logged in.
  bool get loggedIn => account != null;
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
  /// here: registered on the web app with the same name and password, then
  /// logged in (or refused, e.g. while it waits for an administrator).
  Future<LoginOutcome?> _moveToServer(String email, String password) async {
    final local = await _repo.findByEmail(email);
    if (local == null || local.isGuest || local.serverId != null) return null;
    if (await _repo.verifyPassword(email, password) == null) return null;
    try {
      await _server.register(
        fullName: local.name,
        email: email,
        password: password,
      );
      final session = await _server.login(
        email: email,
        password: password,
        device: await _deviceLabel(),
      );
      return LoggedIn(await _keep(session, password));
    } on AccountApiException catch (e) {
      // Already on the server (with another password): just a wrong password.
      if (e.error == AccountApiError.emailTaken) return null;
      return LoginRefused(e.error, retryAfter: e.retryAfter);
    }
  }

  /// Registers on the web app and tries to log in right away: an active
  /// account is logged in; one waiting for approval is tried too, and
  /// [RegisterResult.account] stays null when that doesn't work (yet).
  /// Throws [AccountApiException] when the registration itself is refused.
  Future<RegisterResult> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    final status = await _server.register(
      fullName: [
        firstName.trim(),
        lastName.trim(),
      ].where((s) => s.isNotEmpty).join(' '),
      email: email,
      password: password,
    );
    Account? account;
    try {
      final session = await _server.login(
        email: email,
        password: password,
        device: await _deviceLabel(),
      );
      account = await _keep(
        session,
        password,
        firstName: firstName.trim(),
        lastName: lastName.trim(),
      );
    } on AccountApiException catch (e) {
      debugPrint('Login after register: ${e.error.name}');
    }
    return RegisterResult(status, account);
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
