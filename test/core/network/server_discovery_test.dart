// Finding the dashboard on the local Wi-Fi, against a fake network.

import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/accessibility/announcer.dart';
import 'package:percipere_app/core/db/daos/preferences_dao.dart';
import 'package:percipere_app/core/network/api_dio.dart';
import 'package:percipere_app/core/network/server_address.dart';
import 'package:percipere_app/core/network/server_connection.dart';
import 'package:percipere_app/core/network/server_discovery.dart';

import '../../helpers/fakes.dart';

const _dir = '/website/percipere_dashboard';
const _built = 'http://10.0.2.2$_dir';

class _FakeNetwork implements LocalNetwork {
  _FakeNetwork({this.wifi = true, this.own = const ['192.168.1.50']});

  bool wifi;
  List<String> own;

  @override
  Future<bool> onWifi() async => wifi;

  @override
  Future<List<String>> ownAddresses() async => own;
}

/// Answers "ok" only for [live]; every probe is recorded.
class _FakeLan {
  _FakeLan(this.live);

  final Set<String> live;
  final List<String> asked = [];
  int inFlight = 0;
  int maxInFlight = 0;

  /// Makes every probe take this long.
  Duration delay = Duration.zero;

  Future<bool> probe(String url) async {
    asked.add(url);
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    inFlight--;
    return live.contains(url);
  }
}

ServerDiscovery _discovery(
  _FakeLan lan,
  _FakeNetwork net, {
  int parallel = 32,
  Duration budget = const Duration(seconds: 5),
}) => ServerDiscovery(
  probe: lan.probe,
  network: net,
  parallel: parallel,
  budget: budget,
);

void main() {
  group('ServerDiscovery.locate', () {
    test('the saved address answers: no scan', () async {
      final lan = _FakeLan({'http://192.168.1.20$_dir'});
      final result = await _discovery(
        lan,
        _FakeNetwork(),
      ).locate(saved: 'http://192.168.1.20$_dir', built: _built);
      expect(result.address, 'http://192.168.1.20$_dir');
      expect(result.scanned, isFalse);
      expect(lan.asked, ['http://192.168.1.20$_dir']);
    });

    test('the saved address is dead, API_BASE_URL answers', () async {
      final lan = _FakeLan({_built});
      final result = await _discovery(
        lan,
        _FakeNetwork(),
      ).locate(saved: 'http://192.168.1.20$_dir', built: _built);
      expect(result.address, _built);
      expect(result.scanned, isFalse);
      expect(lan.asked, ['http://192.168.1.20$_dir', _built]);
    });

    test('neither answers: the subnet is scanned, port 80', () async {
      final lan = _FakeLan({'http://192.168.1.77$_dir'});
      var started = 0;
      final result = await _discovery(lan, _FakeNetwork()).locate(
        saved: 'http://192.168.1.20$_dir',
        built: _built,
        onScanStart: () => started++,
      );
      expect(result.address, 'http://192.168.1.77$_dir');
      expect(result.scanned, isTrue);
      expect(started, 1);
    });

    test('port 8888 is tried too', () async {
      final lan = _FakeLan({'http://192.168.1.9:8888$_dir'});
      final result = await _discovery(
        lan,
        _FakeNetwork(),
      ).locate(built: _built);
      expect(result.address, 'http://192.168.1.9:8888$_dir');
    });

    test('mobile data only: nothing is scanned', () async {
      final lan = _FakeLan({'http://192.168.1.77$_dir'});
      var started = 0;
      final result = await _discovery(lan, _FakeNetwork(wifi: false)).locate(
        saved: 'http://192.168.1.20$_dir',
        built: _built,
        onScanStart: () => started++,
      );
      expect(result.address, isNull);
      expect(result.scanned, isFalse);
      expect(started, 0);
      expect(lan.asked, hasLength(2), reason: 'only the two known addresses');
    });

    test('nothing answers: null after the whole subnet was asked', () async {
      final lan = _FakeLan({});
      final result = await _discovery(
        lan,
        _FakeNetwork(),
      ).locate(built: _built);
      expect(result.address, isNull);
      expect(result.scanned, isTrue);
      // 253 hosts (not the tablet itself) on 2 ports, plus API_BASE_URL.
      expect(lan.asked, hasLength(1 + 253 * 2));
    });

    test('slow probes cannot hold the scan past its budget', () async {
      final lan = _FakeLan({})..delay = const Duration(seconds: 3);
      final watch = Stopwatch()..start();
      final found = await _discovery(
        lan,
        _FakeNetwork(),
        budget: const Duration(milliseconds: 200),
      ).scan();
      expect(found, isNull);
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('requests in flight stay at the limit', () async {
      final lan = _FakeLan({})..delay = const Duration(milliseconds: 1);
      await _discovery(lan, _FakeNetwork(), parallel: 10).scan();
      expect(lan.maxInFlight, lessThanOrEqualTo(10));
      expect(lan.maxInFlight, greaterThan(1));
    });

    test(
      'candidates: own address left out, port 80 first, every subnet',
      () async {
        final lan = _FakeLan({});
        final list = await _discovery(
          lan,
          _FakeNetwork(own: ['192.168.1.50', '10.0.0.4']),
        ).candidates();
        expect(list, hasLength(2 * 2 * 253));
        expect(list.first, 'http://192.168.1.1$_dir');
        expect(list, isNot(contains('http://192.168.1.50$_dir')));
        expect(list, contains('http://10.0.0.254:8888$_dir'));
        expect(
          list.indexOf('http://192.168.1.254$_dir'),
          lessThan(list.indexOf('http://192.168.1.1:8888$_dir')),
        );
      },
    );

    test('no private address: nothing to scan', () async {
      final lan = _FakeLan({});
      final result = await _discovery(
        lan,
        _FakeNetwork(own: const []),
      ).locate(built: _built);
      expect(result.address, isNull);
      expect(lan.asked, [_built]);
    });
  });

  group('ServerConnection', () {
    late TestEnv env;
    late ProviderContainer container;
    late _FakeLan lan;
    late _FakeNetwork net;
    var now = DateTime(2026, 10, 19, 9);

    late Provider<ServerConnection> provider;

    Future<void> setUpWith(Set<String> live, {bool wifi = true}) async {
      env = await TestEnv.create(tts: FakeTts());
      lan = _FakeLan(live);
      net = _FakeNetwork(wifi: wifi);
      now = DateTime(2026, 10, 19, 9);
      provider = Provider(
        (ref) => ServerConnection(
          ref,
          discovery: _discovery(lan, net),
          clock: () => now,
        ),
      );
      container = ProviderContainer(
        overrides: [
          ...env.overrides,
          initialServerAddressProvider.overrideWithValue(_built),
        ],
      );
      addTearDown(container.dispose);
      container.listen(announcerProvider, (_, _) {});
    }

    test('finding it elsewhere: saved, used, spoken', () async {
      await setUpWith({'http://192.168.1.77$_dir'});
      await container.read(provider).ensure();
      await pumpEventQueue();
      expect(container.read(serverAddressProvider), 'http://192.168.1.77$_dir');
      final saved = await PreferencesDao(env.database.db)
          .get(PrefKeys.serverAddress);
      expect(saved, 'http://192.168.1.77$_dir');
      expect(env.tts.transcript, contains('Hinahanap ang server'));
      expect(env.tts.transcript, isNot(contains('Hindi maabot')));
    });

    test('it answers where it was: nothing said, nothing changed', () async {
      await setUpWith({_built});
      await container.read(provider).ensure();
      await pumpEventQueue();
      expect(container.read(serverAddressProvider), _built);
      expect(env.tts.transcript, isNot(contains('Hinahanap')));
    });

    test(
      'nothing found: "Hindi maabot ang server", address unchanged',
      () async {
        await setUpWith({});
        await container.read(provider).ensure();
        await pumpEventQueue();
        expect(container.read(serverAddressProvider), _built);
        expect(env.tts.transcript, contains('Hindi maabot ang server'));
      },
    );

    test('not on Wi-Fi at startup: silent', () async {
      await setUpWith({}, wifi: false);
      await container.read(provider).ensure();
      await pumpEventQueue();
      expect(env.tts.transcript, isEmpty);
    });

    test('not on Wi-Fi after a failed call: says it can\'t reach', () async {
      await setUpWith({}, wifi: false);
      await container.read(provider).ensure(failedCall: true);
      await pumpEventQueue();
      expect(env.tts.transcript, contains('Hindi maabot ang server'));
    });

    test('after a miss, the next search waits for the cooldown', () async {
      await setUpWith({});
      final connection = container.read(provider);
      await connection.ensure(failedCall: true);
      final asked = lan.asked.length;
      await connection.ensure(failedCall: true);
      expect(lan.asked.length, asked, reason: 'too soon');
      now = now.add(const Duration(seconds: 31));
      await connection.ensure(failedCall: true);
      expect(lan.asked.length, greaterThan(asked));
    });

    test('a search in progress is not started twice', () async {
      await setUpWith({});
      lan.delay = const Duration(milliseconds: 1);
      final connection = container.read(provider);
      await Future.wait([connection.ensure(), connection.ensure()]);
      expect(lan.asked.length, 1 + 253 * 2);
    });

    test('it stops answering later: found again at the new place', () async {
      await setUpWith({'http://192.168.1.77$_dir'});
      final connection = container.read(provider);
      await connection.ensure();
      lan.live
        ..clear()
        ..add('http://192.168.1.88$_dir');
      await connection.ensure(failedCall: true);
      expect(container.read(serverAddressProvider), 'http://192.168.1.88$_dir');
    });
  });

  group('UnreachableReporter', () {
    tearDown(() => serverUnreachableHook = null);

    Dio dioWith(Object Function(RequestOptions) script) {
      final dio = Dio()..httpClientAdapter = _Script(script);
      dio.interceptors.add(UnreachableReporter());
      return dio;
    }

    test('a connection error tells the hook which address failed', () async {
      final failed = <Uri>[];
      serverUnreachableHook = failed.add;
      final dio = dioWith(
        (o) => DioException(
          requestOptions: o,
          type: DioExceptionType.connectionError,
        ),
      );
      await expectLater(
        dio.get<Object?>('http://192.168.1.20$_dir/api/v1/x'),
        throwsA(isA<DioException>()),
      );
      expect(failed.single.host, '192.168.1.20');
    });

    test('a timeout tells the hook too', () async {
      final failed = <Uri>[];
      serverUnreachableHook = failed.add;
      final dio = dioWith(
        (o) => DioException(
          requestOptions: o,
          type: DioExceptionType.connectionTimeout,
        ),
      );
      await expectLater(
        dio.get<Object?>('http://192.168.1.20$_dir/api/v1/x'),
        throwsA(isA<DioException>()),
      );
      expect(failed, hasLength(1));
    });

    test('an answer (even 500) means the server is there: no hook', () async {
      final failed = <Uri>[];
      serverUnreachableHook = failed.add;
      final dio = dioWith((o) => ResponseBody.fromString('{}', 500));
      await expectLater(
        dio.get<Object?>('http://192.168.1.20$_dir/api/v1/x'),
        throwsA(isA<DioException>()),
      );
      expect(failed, isEmpty);
    });

    test(
      'a request refused by the cleartext guard is not "unreachable"',
      () async {
        final failed = <Uri>[];
        serverUnreachableHook = failed.add;
        final dio = dioWith(
          (o) => DioException(
            requestOptions: o,
            type: DioExceptionType.connectionError,
            error: 'cleartext_not_allowed',
          ),
        );
        await expectLater(
          dio.get<Object?>('http://example.org/x'),
          throwsA(isA<DioException>()),
        );
        expect(failed, isEmpty);
      },
    );
  });
}

class _Script implements HttpClientAdapter {
  _Script(this.script);

  final Object Function(RequestOptions) script;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final r = script(options);
    if (r is ResponseBody) return r;
    throw r;
  }

  @override
  void close({bool force = false}) {}
}
