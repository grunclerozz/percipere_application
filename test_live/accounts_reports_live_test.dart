// The app's account and report clients against a running dashboard (REST
// routes under /api/v1). Skipped unless PERCIPERE_LIVE_API is set. The
// dashboard must run on a SCRATCH database. It sends no email codes any more,
// so a new account must come back "active" (no approval needed) for the
// login steps to work.
//
//   PERCIPERE_LIVE_API=http://localhost/website/percipere_dashboard \
//   flutter test test_live/accounts_reports_live_test.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/auth/account_api.dart';
import 'package:percipere_app/core/report/issue_report.dart';
import 'package:percipere_app/core/report/issue_report_api.dart';

void main() {
  final base = Platform.environment['PERCIPERE_LIVE_API'];
  final skip = base == null ? 'set PERCIPERE_LIVE_API to run this' : false;

  IssueReport report(String ticket, {String? userId}) => IssueReport(
    id: 'local-$ticket',
    ticketNo: ticket,
    type: IssueType.bug,
    module: IssueModule.library,
    severity: IssueSeverity.medium,
    description: 'Hindi bumubukas ang aklat kapag pinindot',
    email: null,
    details: const IssueDetails(
      appVersion: '0.1.1+2',
      osVersion: 'Android 14 (SDK 34)',
      deviceModel: 'Live Test',
    ),
    sourceScreen: 'library',
    createdAt: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
    userId: userId,
  );

  group('against the real dashboard', skip: skip, () {
    late HttpAccountApi accounts;
    late HttpIssueReportApi reports;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final email = 'live.$stamp@example.com';
    const password = 'Live-Pass-123';

    setUp(() {
      accounts = HttpAccountApi(base!);
      reports = HttpIssueReportApi(base);
    });

    test('register, login, me, logout, login, wrong password', () async {
      expect(
        await accounts.register(
          fullName: 'Live Tester',
          email: email,
          password: password,
        ),
        RegisterStatus.active,
      );
      final session = await accounts.login(
        email: email,
        password: password,
        device: 'Live Test',
      );
      expect(session.token, hasLength(64));
      expect(session.user.email, email);
      expect(session.user.fullName, 'Live Tester');

      expect((await accounts.me(session.token)).email, email);
      await accounts.logout(session.token);
      await expectLater(
        accounts.me(session.token),
        throwsA(
          isA<AccountApiException>().having(
            (e) => e.error,
            'error',
            AccountApiError.unauthorized,
          ),
        ),
      );

      final again = await accounts.login(
        email: email,
        password: password,
        device: 'Live Test',
      );
      expect(again.user.id, session.user.id);
      await expectLater(
        accounts.login(email: email, password: 'nope-nope-1', device: 'd'),
        throwsA(
          isA<AccountApiException>().having(
            (e) => e.error,
            'error',
            AccountApiError.invalidCredentials,
          ),
        ),
      );
    });

    test(
      'a bad email and a taken email are refused with their reasons',
      () async {
        await expectLater(
          accounts.register(fullName: 'X', email: 'nope', password: 'short'),
          throwsA(
            isA<AccountApiException>()
                .having(
                  (e) => e.error,
                  'error',
                  AccountApiError.validationFailed,
                )
                .having((e) => e.fields.keys, 'fields', contains('email')),
          ),
        );
        await expectLater(
          accounts.register(
            fullName: 'Someone Else',
            email: email,
            password: 'Other-Pass-123',
          ),
          throwsA(
            isA<AccountApiException>().having(
              (e) => e.error,
              'error',
              AccountApiError.emailTaken,
            ),
          ),
        );
      },
    );

    test(
      'a report reaches the dashboard, once, and a refused one says so',
      () async {
        final ticket = IssueRules.ticketNumber(DateTime.now());
        final first = await reports.send(report(ticket));
        expect(first.status, 'open');
        final second = await reports.send(report(ticket));
        expect(second.serverId, first.serverId, reason: 'the same ticket');

        // The status the dashboard shows is what the app asks for.
        expect(await reports.status(ticket), ServerReportStatus.open);
        expect(await reports.status('PRC-20200101-ZZZZ'), isNull);

        final login = await accounts.login(
          email: email,
          password: 'New-Pass-456',
          device: 'd',
        );
        final linkedTicket = IssueRules.ticketNumber(DateTime.now());
        final linked = await reports.send(
          report(linkedTicket, userId: 'u'),
          token: login.token,
        );
        expect(linked.serverId, isNot(first.serverId));

        await expectLater(
          reports.send(
            report(IssueRules.ticketNumber(DateTime.now())).copyShort(),
          ),
          throwsA(
            isA<IssueSendException>().having((e) => e.refused, 'refused', true),
          ),
        );
      },
    );

    test(
      'a server that is not there: reports retry later, accounts offline',
      () async {
        final nobody = HttpIssueReportApi('http://127.0.0.1:9');
        await expectLater(
          nobody.send(report(IssueRules.ticketNumber(DateTime.now()))),
          throwsA(
            isA<IssueSendException>().having(
              (e) => e.refused,
              'refused',
              false,
            ),
          ),
        );
        await expectLater(
          HttpAccountApi('http://127.0.0.1:9')
              .login(email: email, password: password, device: 'd'),
          throwsA(
            isA<AccountApiException>().having(
              (e) => e.error,
              'error',
              AccountApiError.offline,
            ),
          ),
        );
      },
    );
  });
}

extension on IssueReport {
  /// The same report with a description the dashboard refuses (under 10
  /// characters).
  IssueReport copyShort() => IssueReport(
    id: id,
    ticketNo: ticketNo,
    type: type,
    module: module,
    severity: severity,
    description: 'short',
    email: email,
    details: details,
    sourceScreen: sourceScreen,
    createdAt: createdAt,
  );
}
