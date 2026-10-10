import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import 'issue_report.dart';

/// The phone's copy of every report (`issue_reports`): saved before it is
/// sent, so none is ever lost.
class IssueReportRepository {
  /// Creates the repository.
  IssueReportRepository(this._db);

  final DatabaseExecutor _db;

  static IssueReport _from(Map<String, Object?> r) => IssueReport(
    id: r['id']! as String,
    ticketNo: r['ticket_no']! as String,
    type: IssueType.tryParse(r['type'] as String?) ?? IssueType.feedback,
    module: IssueModule.tryParse(r['module'] as String?) ?? IssueModule.other,
    severity: IssueSeverity.tryParse(r['severity'] as String?),
    description: r['description']! as String,
    email: r['email'] as String?,
    details: IssueDetails(
      appVersion: r['app_version']! as String,
      osVersion: r['os_version']! as String,
      deviceModel: r['device_model']! as String,
    ),
    sourceScreen: r['source_screen']! as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at']! as int),
    userId: r['user_id'] as String?,
    status: IssueSyncStatus.parse(r['sync_status'] as String?),
    serverId: r['server_id'] as String?,
  );

  /// Saves a new report as pending and returns it.
  Future<IssueReport> add({
    required String ticketNo,
    required IssueType type,
    required IssueModule module,
    required IssueSeverity? severity,
    required String description,
    required String? email,
    required IssueDetails details,
    required String sourceScreen,
    required DateTime createdAt,
    required String? userId,
  }) async {
    final id = const Uuid().v4();
    await _db.insert('issue_reports', {
      'id': id,
      'ticket_no': ticketNo,
      'user_id': userId,
      'type': type.server,
      'module': module.server,
      'severity': severity?.server,
      'description': description,
      'email': email,
      'app_version': details.appVersion,
      'os_version': details.osVersion,
      'device_model': details.deviceModel,
      'source_screen': sourceScreen,
      'created_at': createdAt.millisecondsSinceEpoch,
      'sync_status': IssueSyncStatus.pending.name,
    });
    return (await get(id))!;
  }

  /// One report, or null.
  Future<IssueReport?> get(String id) async {
    final rows = await _db.query(
      'issue_reports',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : _from(rows.single);
  }

  /// Whether [ticketNo] is already used here.
  Future<bool> ticketExists(String ticketNo) async => (await _db.query(
    'issue_reports',
    columns: ['id'],
    where: 'ticket_no = ?',
    whereArgs: [ticketNo],
  )).isNotEmpty;

  /// "Aking mga report": [userId]'s reports (or, with null, those written
  /// with no account), newest first.
  Future<List<IssueReport>> mine(String? userId) async => (await _db.query(
    'issue_reports',
    where: userId == null ? 'user_id IS NULL' : 'user_id = ?',
    whereArgs: userId == null ? null : [userId],
    orderBy: 'created_at DESC',
  )).map(_from).toList();

  /// Reports the web app doesn't have yet, oldest first.
  Future<List<IssueReport>> pending() async => (await _db.query(
    'issue_reports',
    where: 'sync_status = ?',
    whereArgs: [IssueSyncStatus.pending.name],
    orderBy: 'created_at ASC',
  )).map(_from).toList();

  /// The web app stored [id] as [serverId].
  Future<void> markSent(String id, String serverId) => _db.update(
    'issue_reports',
    {
      'sync_status': IssueSyncStatus.sent.name,
      'server_id': serverId,
      'last_error': null,
    },
    where: 'id = ?',
    whereArgs: [id],
  );

  /// A send failed; [refused] = the web app rejected it (it stays here as
  /// failed instead of being retried forever).
  Future<void> markAttempt(String id, String error, {bool refused = false}) =>
      _db.rawUpdate(
        'UPDATE issue_reports SET attempts = attempts + 1, last_error = ?, '
        'sync_status = ? WHERE id = ?',
        [
          error,
          refused ? IssueSyncStatus.failed.name : IssueSyncStatus.pending.name,
          id,
        ],
      );
}

/// Issue reports on this phone.
final issueReportRepositoryProvider = Provider<IssueReportRepository>(
  (ref) => IssueReportRepository(ref.watch(appDatabaseProvider).db),
);
