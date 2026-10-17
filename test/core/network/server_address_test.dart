// The web app's address: typed text is cleaned and checked; plain http:// is
// refused for hosts the build did not allow; the HTTP clients refuse it too
// (Dart's HTTP client ignores Android's own cleartext setting).

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/config/env.dart';
import 'package:percipere_app/core/network/api_dio.dart';
import 'package:percipere_app/core/network/server_address.dart';

class _Ok implements HttpClientAdapter {
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return ResponseBody.fromString('{}', 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('ServerAddressRules.check', () {
    test('https is fine; slashes and /api/v1 on the end are cleaned', () {
      expect(
        ServerAddressRules.check('  https://admin.example.ph/dash/  ').address,
        'https://admin.example.ph/dash',
      );
      expect(
        ServerAddressRules.check('https://admin.example.ph/dash/api/v1/')
            .address,
        'https://admin.example.ph/dash',
      );
    });

    test('not an address', () {
      for (final text in [
        'percipere',
        'ftp://192.168.1.61/x',
        'https://',
        'https://a.b/x?y=1',
        'https://user:pw@a.b/x',
      ]) {
        expect(
          ServerAddressRules.check(text).problem,
          ServerAddressProblem.notAnAddress,
          reason: text,
        );
      }
      expect(
        ServerAddressRules.check('   ').problem,
        ServerAddressProblem.empty,
      );
    });

    test('plain http only on private networks and localhost', () {
      for (final host in [
        '192.168.1.61',
        '10.0.0.5',
        '172.16.0.1',
        '172.31.255.1',
        '127.0.0.1',
        'localhost',
      ]) {
        expect(Env.allowsCleartext(host), isTrue, reason: host);
      }
      for (final host in [
        '172.15.0.1',
        '172.32.0.1',
        '192.169.1.1',
        '11.0.0.1',
        '8.8.8.8',
        '300.1.1.1',
        'example.com',
        'abc.trycloudflare.com',
      ]) {
        expect(Env.allowsCleartext(host), isFalse, reason: host);
      }
      final ok = ServerAddressRules.check('http://192.168.1.61/dash');
      expect(ok.address, 'http://192.168.1.61/dash');
      final bad = ServerAddressRules.check('http://x.trycloudflare.com');
      expect(bad.address, isNull);
      expect(bad.problem, ServerAddressProblem.cleartextNotAllowed);
      expect(
        ServerAddressRules.check('https://x.trycloudflare.com').address,
        'https://x.trycloudflare.com',
      );
    });
  });

  group('CleartextGuard', () {
    Dio client(bool Function(String) allows, _Ok adapter) => Dio()
      ..httpClientAdapter = adapter
      ..interceptors.add(CleartextGuard(enforce: true, allows: allows));

    test('http to the allowed host goes through; any other does not', () async {
      final adapter = _Ok();
      final dio = client((h) => h == '192.168.1.61', adapter);
      await dio.get<dynamic>('http://192.168.1.61/dash/api/v1/health');
      expect(adapter.calls, 1);
      await expectLater(
        dio.get<dynamic>('http://192.168.1.99/dash/api/v1/health'),
        throwsA(
          isA<DioException>().having(
            (e) => e.error,
            'error',
            'cleartext_not_allowed',
          ),
        ),
      );
      expect(adapter.calls, 1, reason: 'nothing was sent');
    });

    test('https is never blocked', () async {
      final adapter = _Ok();
      final dio = client((_) => false, adapter);
      await dio.get<dynamic>('https://admin.example.ph/api/v1/health');
      expect(adapter.calls, 1);
    });
  });
}
