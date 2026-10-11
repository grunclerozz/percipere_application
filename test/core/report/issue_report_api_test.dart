// HttpIssueReportApi: POST {base}/api/v1/reports with the codes-and-labels body
// (docs/api-contract.md in the dashboard); 201 new and 200 repeated ticket are
// both "sent"; a 4xx other than 429 is refused for good, anything else is tried
// again later.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/report/issue_report.dart';
import 'package:percipere_app/core/report/issue_report_api.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.reply);

  final (int, Object?) Function(RequestOptions) reply;
  final List<RequestOptions> sent = [];
  Object? throwError;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    sent.add(options);
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

final _report = IssueReport(
  id: 'local-1',
  ticketNo: 'PRC-20261011-K7QM',
  type: IssueType.bug,
  module: IssueModule.camera,
  severity: IssueSeverity.high,
  description: 'Hindi bumubukas ang camera kapag pinindot ko',
  email: null,
  details: const IssueDetails(
    appVersion: '0.1.1+2',
    osVersion: 'Android 14 (SDK 34)',
    deviceModel: 'Test Tablet',
  ),
  sourceScreen: 'home',
  createdAt: DateTime.utc(2026, 10, 11, 2, 25),
);

(HttpIssueReportApi, _Adapter) _api((int, Object?) Function(RequestOptions) r) {
  final adapter = _Adapter(r);
  return (
    HttpIssueReportApi(
      'http://192.168.1.61/dash/',
      dio: Dio()..httpClientAdapter = adapter,
    ),
    adapter,
  );
}

Matcher _sendProblem({required bool refused}) => throwsA(
  isA<IssueSendException>().having((e) => e.refused, 'refused', refused),
);

void main() {
  test('POSTs the report to /api/v1/reports; a new ticket is 201', () async {
    final (api, adapter) = _api(
      (_) => (
        201,
        {
          'id': 57,
          'ticket_no': 'PRC-20261011-K7QM',
          'status': 'open',
          'linked': false,
        },
      ),
    );
    final receipt = await api.send(_report);
    expect(receipt.serverId, '57');
    expect(receipt.status, 'open');
    final sent = adapter.sent.single;
    expect(sent.method, 'POST');
    expect(sent.uri.toString(), 'http://192.168.1.61/dash/api/v1/reports');
    expect(sent.headers.containsKey('Authorization'), isFalse);
    expect(sent.data, _report.toJson());
    final body = sent.data as Map;
    expect(body['type'], {'code': 'bug', 'label': 'Bug'});
    expect(body['severity'], {'code': 'high', 'label': 'High'});
    expect(body['reporter'], {'kind': 'guest', 'display_name': null});
  });

  test('a repeated ticket (200, same id) counts as sent', () async {
    final (api, _) = _api(
      (_) =>
          (200, {'id': 57, 'ticket_no': 'PRC-20261011-K7QM', 'status': 'open'}),
    );
    expect((await api.send(_report)).serverId, '57');
  });

  test('the token links the report to the account', () async {
    final (api, adapter) = _api((_) => (201, {'id': 1, 'status': 'open'}));
    await api.send(_report, token: 'a' * 64);
    expect(adapter.sent.single.headers['Authorization'], 'Bearer ${'a' * 64}');
  });

  test(
    'a refused report is final; limits, errors and no connection retry',
    () async {
      for (final status in [400, 401, 413, 415, 422]) {
        final (api, _) = _api(
          (_) => (
            status,
            {
              'error': {'code': 'validation_failed', 'message': 'x'},
            },
          ),
        );
        await expectLater(api.send(_report), _sendProblem(refused: true));
      }
      for (final status in [429, 500, 502, 503]) {
        final (api, _) = _api(
          (_) => (
            status,
            {
              'error': {'code': 'too_many_attempts', 'message': 'x'},
            },
          ),
        );
        await expectLater(api.send(_report), _sendProblem(refused: false));
      }
      final (api, adapter) = _api((_) => (200, {}));
      adapter.throwError = DioException.connectionError(
        requestOptions: RequestOptions(),
        reason: 'refused',
      );
      await expectLater(api.send(_report), _sendProblem(refused: false));
    },
  );

  test(
    'the reason is the server\'s error code, never the report text',
    () async {
      final (api, _) = _api(
        (_) => (
          422,
          {
            'error': {'code': 'validation_failed', 'message': 'Check'},
          },
        ),
      );
      await expectLater(
        api.send(_report),
        throwsA(
          isA<IssueSendException>().having(
            (e) => e.reason,
            'reason',
            allOf('validation_failed', isNot(contains('camera'))),
          ),
        ),
      );
      final (api2, _) = _api((_) => (404, '<html>Not found</html>'));
      await expectLater(
        api2.send(_report),
        throwsA(
          isA<IssueSendException>().having(
            (e) => e.reason,
            'reason',
            'HTTP 404',
          ),
        ),
      );
    },
  );

  test('status: GET /reports/{ticket}; anything unreadable is null', () async {
    final (api, adapter) = _api(
      (_) => (200, {'ticket_no': 'PRC-20261011-K7QM', 'status': 'resolved'}),
    );
    expect(await api.status('PRC-20261011-K7QM'), ServerReportStatus.resolved);
    expect(adapter.sent.single.method, 'GET');
    expect(
      adapter.sent.single.uri.toString(),
      'http://192.168.1.61/dash/api/v1/reports/PRC-20261011-K7QM',
    );

    final (unknown, _) = _api((_) => (200, {'status': 'weird'}));
    expect(await unknown.status('PRC-20261011-K7QM'), isNull);
    final (missing, _) = _api(
      (_) => (
        404,
        {
          'error': {'code': 'not_found', 'message': 'x'},
        },
      ),
    );
    expect(await missing.status('PRC-20261011-K7QM'), isNull);
    final (down, downAdapter) = _api((_) => (200, {}));
    downAdapter.throwError = DioException.connectionError(
      requestOptions: RequestOptions(),
      reason: 'refused',
    );
    expect(await down.status('PRC-20261011-K7QM'), isNull);
  });
}
