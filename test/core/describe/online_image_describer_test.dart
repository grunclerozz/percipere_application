// Online first, ML Kit as the fallback, against a scripted fake server.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/describe/image_describer.dart';
import 'package:percipere_app/core/describe/vision_availability.dart';
import 'package:percipere_app/core/network/image_description_repository.dart';
import 'package:percipere_app/l10n/app_localizations.dart';

import '../../helpers/fakes.dart';

const _base = 'http://10.0.2.2/website/percipere_dashboard';
const _offline = 'May pagkain at plato sa larawan. Mukhang may mesa din.';
const _online = 'May bote ng gamot sa gitna ng mesa.';

/// The dashboard, scripted: `/health` and `/describe`.
class _Server implements HttpClientAdapter {
  /// What `/health` sends as JSON (null = a plain 404).
  Map<String, Object?>? health = {'status': 'ok', 'vision_enabled': true};

  /// Status of `/describe`.
  int describeStatus = 200;

  /// How long `/describe` takes to answer.
  Duration describeDelay = Duration.zero;

  /// Requests seen, e.g. `GET /api/v1/health`.
  final List<String> calls = [];

  /// The form fields of the last `/describe`.
  Map<String, String> lastFields = {};

  ResponseBody _json(Object body, int status) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add('${options.method} ${options.uri.path.replaceFirst('/website/percipere_dashboard', '')}');
    if (options.uri.path.endsWith('/api/v1/health')) {
      final h = health;
      return h == null ? _json({}, 404) : _json(h, 200);
    }
    if (options.uri.path.endsWith('/api/v1/describe')) {
      final data = options.data;
      if (data is FormData) {
        lastFields = {for (final f in data.fields) f.key: f.value};
      }
      if (describeDelay > Duration.zero) {
        await Future<void>.delayed(describeDelay);
      }
      return describeStatus == 200
          ? _json({
              'description': _online,
              'source': 'gemini',
              'model': 'gemini-3.5-flash-lite',
            }, 200)
          : _json({
              'error': {'code': 'x', 'message': 'no'},
            }, describeStatus);
    }
    return _json({}, 404);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  final fil = lookupAppLocalizations(const Locale('fil'));
  final en = lookupAppLocalizations(const Locale('en'));

  late _Server server;
  late FakeImageLabeler labeler;
  late FakeImagePrep prep;
  var internet = true;
  var consent = true;
  var now = DateTime(2026, 10, 19, 9);

  OnlineImageDescriber build({
    Duration timeout = const Duration(seconds: 2),
  }) {
    final dio = Dio()..httpClientAdapter = server;
    return OnlineImageDescriber(
      fallback: MlKitImageDescriber(labeler),
      repository: HttpImageDescriptionRepository(_base, dio),
      availability: VisionAvailability(
        baseUrl: _base,
        dio: dio,
        isOnline: () async => internet,
        clock: () => now,
      ),
      prep: prep,
      consent: () => consent,
      timeout: timeout,
    );
  }

  setUp(() {
    server = _Server();
    labeler = FakeImageLabeler();
    prep = FakeImagePrep();
    internet = true;
    consent = true;
    now = DateTime(2026, 10, 19, 9);
  });

  test('success: the server describes it, ML Kit is not asked', () async {
    final result = await build().describe('photo.jpg', fil);
    expect(result.online, isTrue);
    expect(result.text, _online);
    expect(labeler.labeled, isEmpty);
    expect(server.calls, ['GET /api/v1/health', 'POST /api/v1/describe']);
    expect(server.lastFields['lang'], 'fil');
    expect(prep.uploads, 1);
  });

  test('the app language goes to the server', () async {
    await build().describe('photo.jpg', en);
    expect(server.lastFields['lang'], 'en');
  });

  test('timeout: ML Kit answers at once', () async {
    server.describeDelay = const Duration(milliseconds: 400);
    final result = await build(
      timeout: const Duration(milliseconds: 50),
    ).describe('photo.jpg', fil);
    expect(result.online, isFalse);
    expect(result.text, _offline);
    expect(labeler.labeled, ['photo.jpg']);
  });

  test('vision_enabled false: ML Kit, and /describe is never called', () async {
    server.health = {'status': 'ok', 'vision_enabled': false};
    final result = await build().describe('photo.jpg', fil);
    expect(result.online, isFalse);
    expect(result.text, _offline);
    expect(server.calls, ['GET /api/v1/health']);
    expect(prep.uploads, 0);
  });

  test('an older server without the field counts as false', () async {
    server.health = {'status': 'ok'};
    final result = await build().describe('photo.jpg', fil);
    expect(result.online, isFalse);
    expect(server.calls, ['GET /api/v1/health']);
  });

  test('health not answering counts as false', () async {
    server.health = null;
    final result = await build().describe('photo.jpg', fil);
    expect(result.online, isFalse);
    expect(result.text, _offline);
  });

  for (final status in [429, 503, 504, 500, 415]) {
    test('$status from /describe: ML Kit', () async {
      server.describeStatus = status;
      final result = await build().describe('photo.jpg', fil);
      expect(result.online, isFalse);
      expect(result.text, _offline);
      expect(labeler.labeled, ['photo.jpg']);
    });
  }

  test('no internet: ML Kit and no request at all', () async {
    internet = false;
    final result = await build().describe('photo.jpg', fil);
    expect(result.online, isFalse);
    expect(result.text, _offline);
    expect(server.calls, isEmpty);
  });

  test('no consent: nothing leaves the phone', () async {
    consent = false;
    final result = await build().describe('photo.jpg', fil);
    expect(result.online, isFalse);
    expect(result.text, _offline);
    expect(server.calls, isEmpty);
    expect(prep.uploads, 0);
  });

  test('the health answer is reused for 60 seconds', () async {
    final describer = build();
    await describer.describe('a.jpg', fil);
    await describer.describe('b.jpg', fil);
    expect(server.calls.where((c) => c.contains('health')), hasLength(1));

    now = now.add(const Duration(seconds: 61));
    await describer.describe('c.jpg', fil);
    expect(server.calls.where((c) => c.contains('health')), hasLength(2));
  });

  test('an unreadable picture still fails like before', () async {
    consent = false;
    labeler.fail = true;
    await expectLater(
      build().describe('bad.jpg', fil),
      throwsA(isA<StateError>()),
    );
  });
}
