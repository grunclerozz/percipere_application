// Reports are saved on the phone first, then sent: pending → sent; with no
// connection they stay pending (never lost) and go out later; a report the
// web app refuses stays as failed. A signed-in user's token goes along.

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/auth/account_repository.dart';
import 'package:percipere_app/core/auth/session_store.dart';
import 'package:percipere_app/core/db/migrations.dart';
import 'package:percipere_app/core/report/issue_report.dart';
import 'package:percipere_app/core/report/issue_report_repository.dart';
import 'package:percipere_app/core/report/issue_report_sync.dart';

import 'package:percipere_app/l10n/app_localizations.dart';

import '../../helpers/fakes.dart';

void main() {
  late IssueReportRepository repo;
  late FakeIssueReportApi api;
  late MemorySessionStore sessions;
  late IssueReportSync sync;
  late AccountRepository accounts;

  setUp(() async {
    final db = await openTestDatabase();
    repo = IssueReportRepository(db.db);
    accounts = AccountRepository(db.db, TestEnv.testHasher);
    api = FakeIssueReportApi();
    sessions = MemorySessionStore();
    sync = IssueReportSync(api, repo, sessions);
  });

  Future<IssueReport> add(String ticket, {String? userId, int minute = 0}) =>
      repo.add(
        ticketNo: ticket,
        type: IssueType.bug,
        module: IssueModule.camera,
        severity: IssueSeverity.high,
        description: 'Hindi bumubukas ang camera.',
        email: null,
        details: TestEnv.testIssueDetails,
        sourceScreen: 'capture',
        createdAt: DateTime(2026, 10, 11, 9, minute),
        userId: userId,
      );

  test('schema 7 has the issue_reports table and its server status', () {
    expect(Migrations.latestVersion, 7);
  });

  test('pending → sent, oldest first, with the server id', () async {
    final a = await add('PRC-20261011-AAAA', minute: 1);
    final b = await add('PRC-20261011-BBBB', minute: 2);
    expect((await repo.pending()).map((r) => r.id), [a.id, b.id]);
    expect(await sync.sendPending(), 2);
    expect(api.received.keys, ['PRC-20261011-AAAA', 'PRC-20261011-BBBB']);
    final sent = await repo.get(a.id);
    expect(sent!.status, IssueSyncStatus.sent);
    expect(sent.serverId, '100');
    expect(await repo.pending(), isEmpty);
    expect(await sync.sendPending(), 0, reason: 'nothing left to send');
    expect(api.calls, 2);
  });

  test('offline: kept as pending, tried again later, nothing lost', () async {
    final a = await add('PRC-20261011-CCCC');
    api.offline = true;
    expect(await sync.sendPending(), 0);
    expect((await repo.get(a.id))!.status, IssueSyncStatus.pending);

    api.offline = false;
    expect(await sync.sendPending(), 1);
    expect((await repo.get(a.id))!.status, IssueSyncStatus.sent);
  });

  test('stops at the first connection problem (the rest wait)', () async {
    await add('PRC-20261011-DDDD', minute: 1);
    await add('PRC-20261011-EEEE', minute: 2);
    api.offline = true;
    await sync.sendPending();
    expect(api.calls, 1);
  });

  test('refused by the web app: kept on the phone as failed, not retried '
      'forever', () async {
    final a = await add('PRC-20261011-FFFF');
    api.refuse = true;
    await sync.sendPending();
    expect((await repo.get(a.id))!.status, IssueSyncStatus.failed);
    expect(await repo.pending(), isEmpty);
    expect(await repo.get(a.id), isNotNull);
  });

  test('a signed-in user\'s token goes along; a guest\'s report goes '
      'without one', () async {
    final user = await accounts.register(
      firstName: 'Ana',
      lastName: 'Cruz',
      email: 'ana@example.com',
      password: 'test-pass-123',
    );
    await sessions.writeApiToken(user.id, 'token-1');
    await add('PRC-20261011-GGGG', userId: user.id);
    await add('PRC-20261011-HHHH');
    await sync.sendPending();
    expect(api.tokens['PRC-20261011-GGGG'], 'token-1');
    expect(api.tokens['PRC-20261011-HHHH'], isNull);
  });

  test('two sends at once share one run (no double send)', () async {
    await add('PRC-20261011-JJJJ');
    final results = await Future.wait([sync.sendPending(), sync.sendPending()]);
    expect(results, [1, 1]);
    expect(api.calls, 1);
  });

  test('no web app configured: reports simply wait', () async {
    final a = await add('PRC-20261011-KKKK');
    expect(await IssueReportSync(null, repo, sessions).sendPending(), 0);
    expect((await repo.get(a.id))!.status, IssueSyncStatus.pending);
  });

  test('the dashboard\'s status is kept for sent reports; closed ones are '
      'not asked again', () async {
    final a = await add('PRC-20261011-SSSA', minute: 1);
    final b = await add('PRC-20261011-SSSB', minute: 2);
    await sync.sendPending();
    expect((await repo.get(a.id))!.serverStatus, ServerReportStatus.open);

    api.statuses['PRC-20261011-SSSA'] = ServerReportStatus.inProgress;
    api.statuses['PRC-20261011-SSSB'] = ServerReportStatus.closed;
    expect(await sync.refreshStatuses(), 2);
    expect((await repo.get(a.id))!.serverStatus, ServerReportStatus.inProgress);
    expect((await repo.get(b.id))!.serverStatus, ServerReportStatus.closed);

    api.statusCalls = 0;
    expect(await sync.refreshStatuses(), 0, reason: 'nothing changed');
    expect(api.statusCalls, 1, reason: 'the closed one is not asked again');
  });

  test('status: offline or no web app keeps what the phone has', () async {
    final a = await add('PRC-20261011-OFFA');
    await sync.sendPending();
    api.statuses['PRC-20261011-OFFA'] = ServerReportStatus.resolved;
    api.offline = true;
    expect(await sync.refreshStatuses(), 0);
    expect((await repo.get(a.id))!.serverStatus, ServerReportStatus.open);
    expect(await IssueReportSync(null, repo, sessions).refreshStatuses(), 0);
    api.offline = false;
    expect(await sync.refreshStatuses(), 1);
    expect((await repo.get(a.id))!.statusLabel(await _labels()), 'Naayos na');
  });

  test(
    'a report not sent yet shows the sending status, not the dashboard\'s',
    () async {
      final a = await add('PRC-20261011-PEND');
      expect(a.statusLabel(await _labels()), 'Naghihintay ipadala');
    },
  );

  test('"Aking mga report" lists one user\'s reports, newest first; a '
      'report outlives its account', () async {
    final user = await accounts.register(
      firstName: 'Ana',
      lastName: '',
      email: 'ana2@example.com',
      password: 'test-pass-123',
    );
    await add('PRC-20261011-LLLL', userId: user.id, minute: 1);
    await add('PRC-20261011-MMMM', userId: user.id, minute: 5);
    await add('PRC-20261011-NNNN', minute: 3);
    expect((await repo.mine(user.id)).map((r) => r.ticketNo), [
      'PRC-20261011-MMMM',
      'PRC-20261011-LLLL',
    ]);
    expect((await repo.mine(null)).single.ticketNo, 'PRC-20261011-NNNN');
    expect(await repo.ticketExists('PRC-20261011-LLLL'), isTrue);
    expect(await repo.ticketExists('PRC-20261011-ZZZZ'), isFalse);
  });
}

Future<AppLocalizations> _labels() =>
    AppLocalizations.delegate.load(const Locale('fil'));
