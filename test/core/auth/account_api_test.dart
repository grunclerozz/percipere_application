// HttpAccountApi: requests go to {base}/api/v1/auth/* as JSON, the token as
// a Bearer header; replies (the plain resource) and errors ({"error": {code,
// message, fields, retry_after}}, docs/api-contract.md in the dashboard)
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
  test('login: JSON to api/v1/auth/login, session read back', () async {
    final (api, adapter) = _api(
      (_) => (200, {'token': 'a' * 64, 'user': _user}),
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
    expect(sent.uri.toString(), 'http://192.168.1.61/dash/api/v1/auth/login');
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
        'pending_approval': AccountApiError.pendingApproval,
        'account_suspended': AccountApiError.accountSuspended,
        'email_taken': AccountApiError.emailTaken,
        'unauthorized': AccountApiError.unauthorized,
        'not_implemented': AccountApiError.server,
        'something_new': AccountApiError.server,
      };
      for (final MapEntry(:key, :value) in cases.entries) {
        final (api, _) = _api(
          (_) => (403, {'error': {'code': key, 'message': 'x'}}),
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
            'error': {
              'code': 'too_many_attempts',
              'message': 'wait',
              'retry_after': 900,
            },
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
            'error': {
              'code': 'validation_failed',
              'message': 'Check',
              'fields': {'email': 'Enter a valid email address.'},
            },
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
    final (api, adapter) = _api((_) => (200, {}));
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
        o.path.endsWith('auth/me') ? {'user': _user} : {},
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

  test('register reads the status of the new account and sends no email '
      'step', () async {
    final (api, adapter) = _api(
      (_) => (201, {'status': 'active', 'user': _user}),
    );
    expect(
      await api.register(fullName: 'Juan', email: 'j@x.co', password: 'p'),
      RegisterStatus.active,
    );
    expect(adapter.sent.single.path, 'auth/register');
    expect(adapter.bodies.single, {
      'full_name': 'Juan',
      'email': 'j@x.co',
      'password': 'p',
    });
    final (api2, _) = _api((_) => (201, {'status': 'pending_approval'}));
    expect(
      await api2.register(fullName: 'J', email: 'j@x.co', password: 'p'),
      RegisterStatus.pendingApproval,
    );
    final (api3, _) = _api((_) => (201, <String, Object?>{}));
    expect(
      await api3.register(fullName: 'J', email: 'j@x.co', password: 'p'),
      RegisterStatus.pendingApproval,
      reason: 'a reply without a status waits, so login is tried',
    );
  });

  test('the retired email-code endpoints (501) are a server error', () async {
    final (api, _) = _api(
      (_) => (501, {'error': {'code': 'not_implemented', 'message': 'x'}}),
    );
    await expectLater(
      api.register(fullName: 'J', email: 'j@x.co', password: 'p'),
      throwsA(
        isA<AccountApiException>().having(
          (e) => e.error,
          'error',
          AccountApiError.server,
        ),
      ),
    );
  });

  test('every call goes to its REST address with the right method', () async {
    final (api, adapter) = _api(
      (o) => (
        200,
        o.path.endsWith('auth/me')
            ? {'user': _user}
            : o.path.endsWith('auth/login')
            ? {'token': 'e' * 64, 'user': _user}
            : <String, Object?>{},
      ),
    );
    await api.register(fullName: 'J', email: 'j@x.co', password: 'p');
    await api.login(email: 'j@x.co', password: 'p', device: 'd');
    await api.me('t' * 64);
    await api.logout('t' * 64);
    expect([for (final o in adapter.sent) '${o.method} ${o.path}'], [
      'POST auth/register',
      'POST auth/login',
      'GET auth/me',
      'POST auth/logout',
    ]);
  });

  test('a 404 or 405 JSON error from an old server is a server error', () async {
    final (api, _) = _api(
      (_) => (404, {'error': {'code': 'not_found', 'message': 'x'}}),
    );
    await expectLater(
      api.me('t' * 64),
      throwsA(
        isA<AccountApiException>().having(
          (e) => e.error,
          'error',
          AccountApiError.server,
        ),
      ),
    );
  });

  test('a failure status without the error object is a server error', () async {
    final (api, _) = _api((_) => (500, {'message': 'oops'}));
    await expectLater(
      api.me('t' * 64),
      throwsA(
        isA<AccountApiException>().having(
          (e) => e.error,
          'error',
          AccountApiError.server,
        ),
      ),
    );
  });
}
