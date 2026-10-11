// The app's account and report clients against a running dashboard (REST
// routes under /api/v1). Skipped unless PERCIPERE_LIVE_API is set. The
// dashboard must run on a SCRATCH database in dev-mail mode
// (`MAIL_DRIVER log`, see the dashboard's docs/testing/README.md): emailed
// codes are then read from the Apache error log, PERCIPERE_MAIL_LOG
// (default C:/xampp/apache/logs/error.log).
//
//   PERCIPERE_LIVE_API=http://localhost/website/percipere_web/percipere_dashboard \
//   flutter test test_live/accounts_reports_live_test.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/auth/account_api.dart';
import 'package:percipere_app/core/report/issue_report.dart';
import 'package:percipere_app/core/report/issue_report_api.dart';

void main() {
  final base = Platform.environment['PERCIPERE_LIVE_API'];
  final logPath =
      Platform.environment['PERCIPERE_MAIL_LOG'] ??
      'C:/xampp/apache/logs/error.log';
  final skip = base == null ? 'set PERCIPERE_LIVE_API to run this' : false;

  /// The last code "emailed" to [email] (dev mail goes to the error log).
  String codeFor(String email) {
    final lines = File(logPath).readAsLinesSync().reversed;
    for (final line in lines) {
      final m = RegExp('DEV mail to ${RegExp.escape(email)}: code (\\d{6})')
          .firstMatch(line);
      if (m != null) return m.group(1)!;
    }
    fail('no code for $email in $logPath');
  }

  IssueReport report(String ticket, {String? userId}) =>
      IssueReport(
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

    test('register, verify, me, logout, login, wrong password', () async {
      expect(
        await accounts.register(
          fullName: 'Live Tester',
          email: email,
          password: password,
        ),
        isTrue,
        reason: 'the code email "went out"',
      );
      final session = await accounts.verify(
        email: email,
        code: codeFor(email),
        device: 'Live Test',
      );
      expect(session, isNotNull);
      expect(session!.token, hasLength(64));
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

    test('a bad email and a taken email are refused with their reasons',
        () async {
      await expectLater(
        accounts.register(fullName: 'X', email: 'nope', password: 'short'),
        throwsA(
          isA<AccountApiException>()
              .having((e) => e.error, 'error', AccountApiError.validationFailed)
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
    });

    test('forgot password: the emailed code sets a new password', () async {
      // The server waits 60 s between emailed codes, as the app does.
      try {
        await accounts.forgotPassword(email);
      } on AccountApiException catch (e) {
        expect(e.error, AccountApiError.tooManyAttempts);
        await Future<void>.delayed(e.retryAfter + const Duration(seconds: 2));
        await accounts.forgotPassword(email);
      }
      final session = await accounts.resetPassword(
        email: email,
        code: codeFor(email),
        password: 'New-Pass-456',
        device: 'Live Test',
      );
      expect(session.user.email, email);
      final login = await accounts.login(
        email: email,
        password: 'New-Pass-456',
        device: 'd',
      );
      expect(login.token, hasLength(64));
      await expectLater(
        accounts.resetPassword(
          email: email,
          code: '000000',
          password: 'Another-789',
          device: 'd',
        ),
        throwsA(
          isA<AccountApiException>().having(
            (e) => e.error,
            'error',
            AccountApiError.invalidCode,
          ),
        ),
      );
    });

    test('a report reaches the dashboard, once, and a refused one says so',
        () async {
      final ticket = IssueRules.ticketNumber(DateTime.now());
      final first = await reports.send(report(ticket));
      expect(first.status, 'open');
      final second = await reports.send(report(ticket));
      expect(second.serverId, first.serverId, reason: 'the same ticket');

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
    });

    test('a server that is not there: reports retry later, accounts offline',
        () async {
      final nobody = HttpIssueReportApi('http://127.0.0.1:9');
      await expectLater(
        nobody.send(report(IssueRules.ticketNumber(DateTime.now()))),
        throwsA(
          isA<IssueSendException>().having((e) => e.refused, 'refused', false),
        ),
      );
      await expectLater(
        HttpAccountApi('http://127.0.0.1:9').login(
          email: email,
          password: password,
          device: 'd',
        ),
        throwsA(
          isA<AccountApiException>().having(
            (e) => e.error,
            'error',
            AccountApiError.offline,
          ),
        ),
      );
    });
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
