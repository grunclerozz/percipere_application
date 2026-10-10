import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_store.dart';
import 'issue_report_api.dart';
import 'issue_report_repository.dart';

/// Sends the reports saved on the phone that the web app doesn't have yet.
/// A report is only marked sent once the web app has it; with no
/// connection it stays pending for the next try, and a report the web app
/// refuses stays on the phone as failed. Nothing is ever deleted.
class IssueReportSync {
  /// Creates the sender.
  IssueReportSync(this._api, this._repo, this._sessions);

  final IssueReportApi? _api;
  final IssueReportRepository _repo;
  final SessionStore _sessions;
  Future<int>? _running;

  /// Sends every pending report, oldest first; returns how many went out.
  /// Stops at the first connection problem. Calls made while one runs share
  /// it.
  Future<int> sendPending() =>
      _running ??= _send().whenComplete(() => _running = null);

  Future<int> _send() async {
    final api = _api;
    if (api == null) return 0;
    var sent = 0;
    for (final report in await _repo.pending()) {
      final userId = report.userId;
      final token = userId == null
          ? null
          : await _sessions.readApiToken(userId);
      try {
        final receipt = await api.send(report, token: token);
        await _repo.markSent(report.id, receipt.serverId);
        sent++;
      } on IssueSendException catch (e) {
        debugPrint('[REPORT] ${report.ticketNo} not sent: ${e.reason}');
        await _repo.markAttempt(report.id, e.reason, refused: e.refused);
        if (!e.refused) break; // offline / server down: try again later
      }
    }
    if (sent > 0) debugPrint('[REPORT] sent $sent report(s)');
    return sent;
  }
}

/// The report sender.
final issueReportSyncProvider = Provider<IssueReportSync>(
  (ref) => IssueReportSync(
    ref.watch(issueReportApiProvider),
    ref.watch(issueReportRepositoryProvider),
    ref.watch(sessionStoreProvider),
  ),
);

/// Fires when the phone's connection comes back (tests override it).
final connectionRestoredProvider = Provider<Stream<void>>((ref) {
  try {
    return Connectivity().onConnectivityChanged
        .where((results) => results.any((r) => r != ConnectivityResult.none))
        .map((_) {});
  } on Object catch (e) {
    debugPrint('Connectivity unavailable: $e');
    return const Stream<void>.empty();
  }
});

/// Sends waiting reports when the app starts, when it comes back to the
/// front and when the connection returns.
class IssueReportSyncHost extends ConsumerStatefulWidget {
  /// Wraps [child].
  const IssueReportSyncHost({super.key, required this.child});

  /// The app.
  final Widget child;

  @override
  ConsumerState<IssueReportSyncHost> createState() =>
      _IssueReportSyncHostState();
}

class _IssueReportSyncHostState extends ConsumerState<IssueReportSyncHost>
    with WidgetsBindingObserver {
  StreamSubscription<void>? _connection;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connection = ref
        .read(connectionRestoredProvider)
        .listen((_) => _sync(), onError: (Object _) {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_connection?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _sync();
  }

  void _sync() {
    if (!mounted) return;
    unawaited(
      ref.read(issueReportSyncProvider).sendPending().catchError((Object e) {
        debugPrint('[REPORT] sync failed: $e');
        return 0;
      }),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
