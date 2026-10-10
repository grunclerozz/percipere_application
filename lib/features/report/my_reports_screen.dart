import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/ids.dart';
import '../../core/accessibility/accessible_screen.dart';
import '../../core/accessibility/command_bus.dart';
import '../../core/accessibility/focus_controller.dart';
import '../../core/accessibility/screen_registration.dart';
import '../../core/auth/session.dart';
import '../../core/report/issue_report.dart';
import '../../core/report/issue_report_repository.dart';
import '../../core/report/issue_report_sync.dart';
import '../../core/widgets/boxed_list.dart';
import '../../l10n/app_localizations.dart';
import '../auth/form_scaffold.dart';

/// "Aking mga report": the user's reports with ticket number, type, date
/// and status; choosing one reads its details aloud. Waiting reports are
/// tried again when the screen opens.
class MyReportsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const MyReportsScreen({super.key});

  @override
  ConsumerState<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends ConsumerState<MyReportsScreen> {
  List<IssueReport>? _reports;

  @override
  void initState() {
    super.initState();
    unawaited(_load(sync: true));
  }

  Future<void> _load({bool sync = false}) async {
    final repo = ref.read(issueReportRepositoryProvider);
    final userId = ref.read(currentAccountProvider)?.id;
    try {
      final first = await repo.mine(userId);
      if (!mounted) return;
      setState(() => _reports = first);
      if (!sync || first.every((r) => r.status != IssueSyncStatus.pending)) {
        return;
      }
      final sent = await ref.read(issueReportSyncProvider).sendPending();
      if (sent > 0 && mounted) {
        final again = await repo.mine(userId);
        if (mounted) setState(() => _reports = again);
      }
    } on Object catch (e) {
      debugPrint('[REPORT] list failed: $e');
      if (mounted) setState(() => _reports = const []);
    }
  }

  static String _date(DateTime when, AppLocalizations l) {
    try {
      return DateFormat.yMMMd(l.localeName).format(when);
    } on Object {
      return DateFormat.yMMMd('en').format(when);
    }
  }

  static String _row(IssueReport r, AppLocalizations l) => l.myReportsRow(
    r.ticketNo,
    r.type.label(l),
    _date(r.createdAt, l),
    r.status.label(l),
  );

  static String _details(IssueReport r, AppLocalizations l) => [
    l.reportTicketSpoken(IssueRules.spokenTicket(r.ticketNo)),
    '${l.reportLineType(r.type.label(l))}.',
    '${l.reportLineModule(r.module.label(l))}.',
    if (r.severity != null) '${l.reportLineSeverity(r.severity!.short(l))}.',
    '${l.reportLineDescription(r.description)}.',
    '${l.reportLineDate(_date(r.createdAt, l))}.',
    '${l.reportLineStatus(r.status.label(l))}.',
  ].join(' ');

  ScreenRegistration _registration(WidgetRef ref) {
    final reports = _reports ?? const <IssueReport>[];
    return ScreenRegistration(
      id: Ids.myReports,
      title: (l) => l.screenMyReports,
      prompt: (l) => reports.isEmpty
          ? l.myReportsEmpty
          : l.myReportsCount('${reports.length}'),
      help: (l) => l.helpChooseList,
      actions: [
        for (final r in reports)
          A11yAction(
            id: '${Ids.myReports}.${r.id}',
            label: (l) => _row(r, l),
            voiceSynonyms: [r.ticketNo.toLowerCase()],
            confirmation: (l) => '',
            onActivate: (bus) => bus.say(_details(r, bus.strings)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final focused = ref.watch(focusControllerProvider);
    final bus = ref.read(commandBusProvider);
    final reports = _reports;
    // Announced once the list is read (it is quick), so the first words
    // are right.
    if (reports == null) return const Scaffold();
    return AccessibleScreen(
      registration: _registration,
      dependencies: [reports],
      child: FormScaffold(
        screenId: Ids.myReports,
        title: l10n.screenMyReports,
        subtitle: reports.isEmpty
            ? l10n.myReportsEmpty
            : l10n.myReportsCount('${reports.length}'),
        padHint: l10n.helpChooseList,
        fill: true,
        child: BoxedList(
          items: [
            for (final r in reports)
              BoxedListItem('${Ids.myReports}.${r.id}', _row(r, l10n)),
          ],
          focused: focused,
          onTap: bus.activate,
        ),
      ),
    );
  }
}
