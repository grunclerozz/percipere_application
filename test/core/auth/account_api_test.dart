// HttpAccountApi: requests go to {base}/api/v1/*.php as JSON, the token as
// a Bearer header; replies and error codes (docs/API.md in the dashboard)
// become ServerSession / AccountApiException; no connection = offline.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/auth/account_api.dart';

/// Answers each request from [reply]; remembers what was sent.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.reply);

  final (int, Object?) Function(RequestOptions) reply;
  final List<RequestOptions> sent = [];
  final List<Object?> bodies = [];
  Object? throwError;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    sent.add(options);
    bodies.add(options.data);
    final error = throwError;
    if (error != null) throw error;
    final (status, body) = reply(options);
    return ResponseBody.fromString(
      body is String ? body : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [
          body is String ? 'text/html' : 'application/json; charset=utf-8',
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _user = {
  'id': 7,
  'full_name': 'Juan Dela Cruz',
  'email': 'juan@example.com',
  'phone': null,
  'status': 'active',
};

(HttpAccountApi, _Adapter) _api((int, Object?) Function(RequestOptions) r) {
  final adapter = _Adapter(r);
  final dio = Dio()..httpClientAdapter = adapter;
  return (HttpAccountApi('http://192.168.1.61/dash/', dio: dio), adapter);
}

void main() {
  test('login: JSON to api/v1/login.php, session read back', () async {
    final (api, adapter) = _api(
      (_) => (200, {'ok': true, 'token': 'a' * 64, 'user': _user}),
    );
    final session = await api.login(
      email: 'juan@example.com',
      password: 'lihim1234',
      device: 'Tablet',
    );
    expect(session.token, 'a' * 64);
    expect(session.user.id, '7');
    expect(session.user.fullName, 'Juan Dela Cruz');
    final sent = adapter.sent.single;
    expect(sent.uri.toString(), 'http://192.168.1.61/dash/api/v1/login.php');
    expect(sent.method, 'POST');
    expect(adapter.bodies.single, {
      'email': 'juan@example.com',
      'password': 'lihim1234',
      'device': 'Tablet',
    });
    expect(sent.headers.containsKey('Authorization'), isFalse);
  });

  test(
    'error replies become their codes, with retry time and fields',
    () async {
      final cases = {
        'invalid_credentials': AccountApiError.invalidCredentials,
        'verify_email': AccountApiError.verifyEmail,
        'pending_approval': AccountApiError.pendingApproval,
        'account_suspended': AccountApiError.accountSuspended,
        'email_taken': AccountApiError.emailTaken,
        'invalid_code': AccountApiError.invalidCode,
        'unauthorized': AccountApiError.unauthorized,
        'email_unavailable': AccountApiError.emailUnavailable,
        'something_new': AccountApiError.server,
      };
      for (final MapEntry(:key, :value) in cases.entries) {
        final (api, _) = _api(
          (_) => (403, {'ok': false, 'code': key, 'error': 'x'}),
        );
        await expectLater(
          api.login(email: 'a@b.co', password: 'p', device: 'd'),
          throwsA(
            isA<AccountApiException>().having((e) => e.error, key, value),
          ),
        );
      }

      final (api, _) = _api(
        (_) => (
          429,
          {
            'ok': false,
            'code': 'too_many_attempts',
            'error': 'wait',
            'retry_after': 900,
          },
        ),
      );
      await expectLater(
        api.login(email: 'a@b.co', password: 'p', device: 'd'),
        throwsA(
          isA<AccountApiException>()
              .having((e) => e.error, 'error', AccountApiError.tooManyAttempts)
              .having((e) => e.retryAfter, 'wait', const Duration(minutes: 15)),
        ),
      );

      final (api2, _) = _api(
        (_) => (
          422,
          {
            'ok': false,
            'code': 'validation_failed',
            'error': 'Check',
            'fields': {'email': 'Enter a valid email address.'},
          },
        ),
      );
      await expectLater(
        api2.register(fullName: 'A', email: 'bad', password: 'p'),
        throwsA(
          isA<AccountApiException>().having((e) => e.fields, 'fields', {
            'email': 'Enter a valid email address.',
          }),
        ),
      );
    },
  );

  test('no connection → offline; an HTML page → server error', () async {
    final (api, adapter) = _api((_) => (200, {'ok': true}));
    adapter.throwError = DioException.connectionError(
      requestOptions: RequestOptions(),
      reason: 'refused',
    );
    await expectLater(
      api.me('t' * 64),
      throwsA(
        isA<AccountApiException>().having(
          (e) => e.error,
          'error',
          AccountApiError.offline,
        ),
      ),
    );

    final (api2, _) = _api((_) => (500, '<html>Something went wrong</html>'));
    await expectLater(
      api2.me('t' * 64),
      throwsA(
        isA<AccountApiException>().having(
          (e) => e.error,
          'error',
          AccountApiError.server,
        ),
      ),
    );
  });

  test('me and logout send the Bearer token', () async {
    final (api, adapter) = _api(
      (o) => (
        200,
        o.path.endsWith('me.php') ? {'ok': true, 'user': _user} : {'ok': true},
      ),
    );
    final user = await api.me('b' * 64);
    expect(user.email, 'juan@example.com');
    await api.logout('b' * 64);
    expect(adapter.sent.map((o) => o.method), ['GET', 'POST']);
    for (final o in adapter.sent) {
      expect(o.headers['Authorization'], 'Bearer ${'b' * 64}');
    }
  });

  test('verify: a token signs in; pending approval returns null', () async {
    final (api, _) = _api(
      (_) => (
        200,
        {'ok': true, 'status': 'active', 'token': 'c' * 64, 'user': _user},
      ),
    );
    expect(
      (await api.verify(
        email: 'juan@example.com',
        code: '123456',
        device: 'd',
      ))?.token,
      'c' * 64,
    );
    final (api2, _) = _api(
      (_) => (200, {'ok': true, 'status': 'pending_approval'}),
    );
    expect(
      await api2.verify(email: 'juan@example.com', code: '123456', device: 'd'),
      isNull,
    );
  });

  test('register reports whether the email went out; reset sends all '
      'fields to password_reset.php', () async {
    final (api, adapter) = _api(
      (o) => (
        200,
        o.path.contains('register')
            ? {'ok': true, 'email_sent': false}
            : {'ok': true, 'token': 'd' * 64, 'user': _user},
      ),
    );
    expect(
      await api.register(fullName: 'Juan', email: 'j@x.co', password: 'p'),
      isFalse,
    );
    await api.resetPassword(
      email: 'j@x.co',
      code: '123456',
      password: 'bago12345',
      device: 'Tablet',
    );
    expect(adapter.sent.last.path, 'password_reset.php');
    expect(adapter.bodies.last, {
      'email': 'j@x.co',
      'code': '123456',
      'password': 'bago12345',
      'device': 'Tablet',
    });
  });
}
