import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/env.dart';
import '../network/api_dio.dart';
import '../network/server_address.dart';

/// Why the web app refused a request (its `error.code`, see the dashboard's
/// `docs/api-contract.md`), or why it couldn't be reached.
enum AccountApiError {
  /// Wrong email or password.
  invalidCredentials,

  /// Waiting for an administrator.
  pendingApproval,

  /// Suspended in the dashboard.
  accountSuspended,

  /// The email belongs to another account.
  emailTaken,

  /// Rate limit or lockout; see [AccountApiException.retryAfter].
  tooManyAttempts,

  /// Token missing, expired or revoked.
  unauthorized,

  /// A field was refused; see [AccountApiException.fields].
  validationFailed,

  /// No connection to the web app (no internet, server off, timeout).
  offline,

  /// Anything else (server error, unexpected reply; the dashboard answers
  /// 501 to the email-code endpoints).
  server;

  static AccountApiError _fromCode(String? code) => switch (code) {
    'invalid_credentials' => invalidCredentials,
    'pending_approval' => pendingApproval,
    'account_suspended' => accountSuspended,
    'email_taken' => emailTaken,
    'too_many_attempts' => tooManyAttempts,
    'unauthorized' => unauthorized,
    'validation_failed' => validationFailed,
    _ => server,
  };
}

/// A refused or failed account request.
class AccountApiException implements Exception {
  /// Creates the exception.
  const AccountApiException(
    this.error, {
    this.retryAfter = Duration.zero,
    this.fields = const {},
    this.message = '',
  });

  /// What went wrong.
  final AccountApiError error;

  /// How long to wait ([AccountApiError.tooManyAttempts]).
  final Duration retryAfter;

  /// Refused fields → the server's (English) reason.
  final Map<String, String> fields;

  /// The server's English message (logs only; the app speaks its own words).
  final String message;

  @override
  String toString() => 'AccountApiException(${error.name}: $message)';
}

/// An account as the web app knows it.
@immutable
class ServerUser {
  /// Creates a user.
  const ServerUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.status,
  });

  /// Reads the API's `user` object.
  factory ServerUser.fromJson(Map<String, dynamic> json) => ServerUser(
    id: '${json['id']}',
    fullName: (json['full_name'] as String?) ?? '',
    email: (json['email'] as String?) ?? '',
    status: (json['status'] as String?) ?? '',
  );

  /// `app_users.user_id`, as text (stored in `users.server_id`).
  final String id;

  /// Full name.
  final String fullName;

  /// Email (lowercase).
  final String email;

  /// `active`, `suspended`, …
  final String status;
}

/// What the web app made of a new account.
enum RegisterStatus {
  /// Ready to log in.
  active,

  /// Waits for an administrator (or the reply didn't say): logging in may
  /// not work yet.
  pendingApproval;

  /// Reads the register reply's `status` (also under `user`); anything but
  /// `active` is treated as waiting.
  static RegisterStatus fromReply(Map<String, dynamic> data) {
    final user = data['user'];
    final status =
        data['status'] ?? (user is Map<String, dynamic> ? user['status'] : null);
    return status == 'active' ? active : pendingApproval;
  }
}

/// A signed-in session on the web app.
@immutable
class ServerSession {
  /// Creates a session.
  const ServerSession({required this.token, required this.user});

  /// Bearer token (kept only in secure storage).
  final String token;

  /// Who signed in.
  final ServerUser user;
}

/// Accounts on the web app (the dashboard's REST `api/v1/auth/*`). Every method throws
/// [AccountApiException]; nothing here touches the phone's database.
abstract interface class AccountApi {
  /// Creates an account. No email is sent: the reply says whether the
  /// account is active or waits for an administrator.
  Future<RegisterStatus> register({
    required String fullName,
    required String email,
    required String password,
  });

  /// Signs in.
  Future<ServerSession> login({
    required String email,
    required String password,
    required String device,
  });

  /// The signed-in user (checks the token and the account status).
  Future<ServerUser> me(String token);

  /// Ends [token]'s session.
  Future<void> logout(String token);
}

/// [AccountApi] over HTTP (dio).
class HttpAccountApi implements AccountApi {
  /// Creates the client for the web app at [baseUrl].
  HttpAccountApi(String baseUrl, {Dio? dio})
    : _dio = dio ?? apiDio(receive: const Duration(seconds: 20)) {
    _dio.options
      ..baseUrl = '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/api/v1/'
      ..contentType = Headers.jsonContentType
      ..responseType = ResponseType.json
      // Every status is read here: the body carries the error code.
      ..validateStatus = (_) => true;
  }

  final Dio _dio;

  Future<Map<String, dynamic>> _call(
    String method,
    String path, {
    Map<String, Object?>? body,
    String? token,
  }) async {
    final Response<dynamic> response;
    try {
      response = await _dio.request<dynamic>(
        path,
        data: body,
        options: Options(
          method: method,
          headers: {if (token != null) 'Authorization': 'Bearer $token'},
        ),
      );
    } on DioException catch (e) {
      // Only the kind of failure: never log bodies (they hold passwords).
      debugPrint('Account API $path: ${e.type.name}');
      throw AccountApiException(
        e.type == DioExceptionType.badResponse
            ? AccountApiError.server
            : AccountApiError.offline,
        message: e.type.name,
      );
    }
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      debugPrint('Account API $path: HTTP ${response.statusCode}, not JSON');
      throw AccountApiException(
        AccountApiError.server,
        message: 'HTTP ${response.statusCode}',
      );
    }
    // A success is the plain resource; a failure is {"error": {code, message,
    // fields?, retry_after?}} with the HTTP status.
    final error = data['error'];
    if (error is! Map) {
      final status = response.statusCode ?? 0;
      if (status >= 200 && status < 300) return data;
      throw AccountApiException(
        AccountApiError.server,
        message: 'HTTP $status',
      );
    }
    final fields = error['fields'];
    throw AccountApiException(
      AccountApiError._fromCode(error['code'] as String?),
      retryAfter: Duration(
        seconds: (error['retry_after'] as num?)?.toInt() ?? 0,
      ),
      fields: fields is Map
          ? {for (final e in fields.entries) '${e.key}': '${e.value}'}
          : const {},
      message: '${error['message'] ?? ''}',
    );
  }

  static ServerSession _session(Map<String, dynamic> data) => ServerSession(
    token: _read(() => data['token']! as String),
    user: _userOf(data),
  );

  static ServerUser _userOf(Map<String, dynamic> data) =>
      _read(() => ServerUser.fromJson(data['user']! as Map<String, dynamic>));

  /// A reply missing what it should hold is a server error, not a crash.
  static T _read<T>(T Function() read) {
    try {
      return read();
    } on Object {
      throw const AccountApiException(
        AccountApiError.server,
        message: 'unexpected reply',
      );
    }
  }

  @override
  Future<RegisterStatus> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final data = await _call(
      'POST',
      'auth/register',
      body: {'full_name': fullName, 'email': email, 'password': password},
    );
    return RegisterStatus.fromReply(data);
  }

  @override
  Future<ServerSession> login({
    required String email,
    required String password,
    required String device,
  }) async => _session(
    await _call(
      'POST',
      'auth/login',
      body: {'email': email, 'password': password, 'device': device},
    ),
  );

  @override
  Future<ServerUser> me(String token) async {
    return _userOf(await _call('GET', 'auth/me', token: token));
  }

  @override
  Future<void> logout(String token) =>
      _call('POST', 'auth/logout', token: token);
}

/// The web app's accounts, or null when accounts stay on the phone
/// ([Env.accountServer] off).
final accountApiProvider = Provider<AccountApi?>((ref) {
  final address = ref.watch(serverAddressProvider);
  return Env.accountServerAllowed && hasServer(address)
      ? HttpAccountApi(address)
      : null;
});
