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

    test('plain http only to a host the build allows (none in tests)', () {
      expect(Env.allowsCleartext('192.168.1.61'), isFalse);
      final check = ServerAddressRules.check('http://192.168.1.61/dash');
      expect(check.address, isNull);
      expect(check.problem, ServerAddressProblem.cleartextNotAllowed);
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
