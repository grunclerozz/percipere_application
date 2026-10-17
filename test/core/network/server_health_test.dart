// "Test connection": GET {address}/api/v1/health and the exact reason when it
// fails.

import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/config/env.dart';
import 'package:percipere_app/core/network/api_dio.dart';
import 'package:percipere_app/core/network/server_health.dart';
import 'package:percipere_app/features/settings/server_connection_test.dart';
import 'package:percipere_app/l10n/app_localizations.dart';

/// Answers per URL with a scripted reply or error.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);

  final Object Function(Uri uri) handler;
  final List<Uri> calls = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options.uri);
    final r = handler(options.uri);
    if (r is ResponseBody) return r;
    if (r is DioException) {
      throw DioException(requestOptions: options, type: r.type, error: r.error);
    }
    throw StateError('bad script');
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(String body, [int status = 200]) => ResponseBody.fromString(
  body,
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

ResponseBody _html(int status) => ResponseBody.fromString(
  '<html>nope</html>',
  status,
  headers: {
    Headers.contentTypeHeader: ['text/html'],
  },
);

Future<ServerHealth> _check(
  Object Function(Uri) handler, {
  String address = 'http://192.168.1.5/dash',
  bool online = true,
  _Adapter? adapter,
}) {
  final a = adapter ?? _Adapter(handler);
  final dio = Dio()
    ..httpClientAdapter = a
    ..interceptors.add(CleartextGuard(enforce: true));
  return ServerHealthChecker(
    dio: dio,
    isOnline: () async => online,
  ).check(address);
}

void main() {
  test('ok: the health reply with status ok', () async {
    final adapter = _Adapter(
      (_) => _json('{"status":"ok","time":"2026-10-17T10:00:00+08:00"}'),
    );
    final h = await _check((_) => 0, adapter: adapter);
    expect(h.status, ServerHealthStatus.ok);
    expect(h.serverTime, '2026-10-17T10:00:00+08:00');
    expect(
      adapter.calls.single.toString(),
      'http://192.168.1.5/dash/api/v1/health',
    );
  });

  test('trailing slash on the address is fine', () async {
    final adapter = _Adapter((_) => _json('{"status":"ok"}'));
    await _check(
      (_) => 0,
      address: 'http://192.168.1.5/dash/',
      adapter: adapter,
    );
    expect(adapter.calls.single.path, '/dash/api/v1/health');
  });

  test('no server address set', () async {
    final h = await _check((_) => 0, address: Env.noServer);
    expect(h.status, ServerHealthStatus.notConfigured);
  });

  test('404 on both forms: wrong address', () async {
    final adapter = _Adapter((_) => _html(404));
    final h = await _check((_) => 0, adapter: adapter);
    expect(h.status, ServerHealthStatus.wrongAddress);
    expect(adapter.calls.last.path, '/dash/api/v1/index.php/health');
  });

  test('without mod_rewrite the index.php form is used', () async {
    final h = await _check(
      (uri) => uri.path.endsWith('index.php/health')
          ? _json('{"status":"ok"}')
          : _html(404),
    );
    expect(h.status, ServerHealthStatus.ok);
  });

  test('a page that is not the Percipere API: wrong address', () async {
    final h = await _check((_) => _html(200));
    expect(h.status, ServerHealthStatus.wrongAddress);
  });

  test('HTTP 500 (database down): server down', () async {
    final h = await _check(
      (_) => _json('{"error":{"code":"server_error"}}', 500),
    );
    expect(h.status, ServerHealthStatus.serverDown);
  });

  test('connection refused: server down', () async {
    final h = await _check(
      (_) => DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.connectionError,
        error: const SocketException(
          'Connection refused',
          osError: OSError('Connection refused', 111),
        ),
      ),
    );
    expect(h.status, ServerHealthStatus.serverDown);
  });

  test('host not found: wrong address', () async {
    final h = await _check(
      (_) => DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.connectionError,
        error: const SocketException('Failed host lookup: nope.local'),
      ),
      address: 'https://nope.local/dash',
    );
    expect(h.status, ServerHealthStatus.wrongAddress);
  });

  test('no route to the machine while online: unreachable', () async {
    final h = await _check(
      (_) => DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.connectionError,
        error: const SocketException('Network is unreachable'),
      ),
    );
    expect(h.status, ServerHealthStatus.unreachable);
  });

  test('tablet offline: no network', () async {
    final h = await _check(
      (_) => DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.connectionError,
        error: const SocketException('Network is unreachable'),
      ),
      online: false,
    );
    expect(h.status, ServerHealthStatus.noNetwork);
  });

  test('timeout while online: timeout; offline: no network', () async {
    DioException t(_) => DioException(
      requestOptions: RequestOptions(),
      type: DioExceptionType.connectionTimeout,
    );
    expect((await _check(t)).status, ServerHealthStatus.timeout);
    expect(
      (await _check(t, online: false)).status,
      ServerHealthStatus.noNetwork,
    );
  });

  test('plain http to a public host is blocked', () async {
    final h = await _check(
      (_) => _json('{"status":"ok"}'),
      address: 'http://abc.trycloudflare.com',
    );
    expect(h.status, ServerHealthStatus.httpBlocked);
  });

  test('every status has a spoken message in both languages', () {
    for (final l in [
      lookupAppLocalizations(const Locale('fil')),
      lookupAppLocalizations(const Locale('en')),
    ]) {
      final texts = {
        for (final s in ServerHealthStatus.values)
          serverHealthMessage(l, ServerHealth(s)),
      };
      expect(texts, hasLength(ServerHealthStatus.values.length));
      expect(texts.every((t) => t.isNotEmpty), isTrue);
    }
  });
}
