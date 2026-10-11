import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../l10n/app_localizations.dart';
import '../auth/validators.dart';

/// What kind of report (page 1 of "Mag-report ng problema").
enum IssueType {
  /// Something is broken ("May sira").
  bug('bug', 'Bug', ['bug', 'may sira', 'sira', 'sirang', 'problema', 'error']),

  /// An idea ("Mungkahi").
  feature('feature', 'Feature Request', [
    'feature request',
    'feature',
    'mungkahi',
    'suggestion',
    'request',
  ]),

  /// Anything else ("Puna").
  feedback('feedback', 'General Feedback', [
    'general feedback',
    'feedback',
    'puna',
    'komento',
    'comment',
  ]);

  const IssueType(this.code, this.server, this.voice);

  /// The app's code for it, sent with the label (`type.code`).
  final String code;

  /// The English label the web app stores and shows (`feedback_category`).
  final String server;

  /// Words that choose it by voice, besides its label.
  final List<String> voice;

  /// "May sira (Bug)".
  String label(AppLocalizations l) => switch (this) {
    bug => l.reportTypeBug,
    feature => l.reportTypeFeature,
    feedback => l.reportTypeFeedback,
  };

  /// Parses a stored value, or null.
  static IssueType? tryParse(String? server) =>
      values.where((t) => t.server == server).firstOrNull;
}

/// Which part of the app (page 2).
enum IssueModule {
  /// Reading text from photos and files.
  ocr('ocr', 'OCR', ['ocr', 'pagbasa ng teksto', 'text reading', 'pagbasa']),

  /// The camera.
  camera('camera', 'Camera', ['camera', 'kamera', 'litrato']),

  /// Voice commands.
  voiceCommands('voice_commands', 'Voice Commands', [
    'voice commands',
    'voice',
    'boses',
    'mga utos',
    'utos sa boses',
  ]),

  /// Login, register, password.
  accounts('accounts', 'Accounts', [
    'accounts',
    'account',
    'login',
    'password',
  ]),

  /// The reading voice.
  tts('text_to_speech', 'Text-to-Speech', [
    'text to speech',
    'tts',
    'nagbabasa',
    'boses na nagbabasa',
    'pagbabasa',
  ]),

  /// The Gesture Pad.
  gesturePad('gestures', 'Gestures', [
    'gesture pad',
    'gesture',
    'galaw',
    'swipe',
  ]),

  /// Aklatan.
  library('library', 'Library', ['aklatan', 'library', 'aklat', 'libro']),

  /// Image description.
  maglarawan('maglarawan', 'Maglarawan', [
    'maglarawan',
    'larawan',
    'describe',
    'image',
  ]),

  /// The voice assistant.
  percy('percy', 'Percy', ['percy', 'assistant', 'katulong']),

  /// Anything else.
  other('other', 'Other', ['iba pa', 'iba', 'other', 'others']);

  const IssueModule(this.code, this.server, this.voice);

  /// The app's code for it, sent with the label (`module.code`).
  final String code;

  /// The English label the web app stores and shows (`feedback_module`).
  final String server;

  /// Words that choose it by voice, besides its label.
  final List<String> voice;

  /// "Aklatan (Library)".
  String label(AppLocalizations l) => switch (this) {
    ocr => l.reportModuleOcr,
    camera => l.reportModuleCamera,
    voiceCommands => l.reportModuleVoice,
    accounts => l.reportModuleAccounts,
    tts => l.reportModuleTts,
    gesturePad => l.reportModuleGestures,
    library => l.reportModuleLibrary,
    maglarawan => l.reportModuleMaglarawan,
    percy => l.reportModulePercy,
    other => l.reportModuleOther,
  };

  /// Parses a stored value, or null.
  static IssueModule? tryParse(String? server) =>
      values.where((m) => m.server == server).firstOrNull;
}

/// How bad a bug is (page 3, bugs only).
enum IssueSeverity {
  /// A minor annoyance.
  low('low', 'Low', ['low', 'mababa', 'maliit']),

  /// Works, but wrong.
  medium('medium', 'Medium', ['medium', 'katamtaman', 'katamtamang']),

  /// Doesn't work.
  high('high', 'High', ['high', 'mataas', 'hindi gumagana']),

  /// Crashes or loses data.
  critical('critical', 'Critical', [
    'critical',
    'kritikal',
    'nag-crash',
    'crash',
  ]);

  const IssueSeverity(this.code, this.server, this.voice);

  /// The app's code for it, sent with the label (`severity.code`).
  final String code;

  /// The English label the web app stores and shows (`feedback_severity`).
  final String server;

  /// Words that choose it by voice, besides its label.
  final List<String> voice;

  /// "Mababa".
  String short(AppLocalizations l) => switch (this) {
    low => l.reportSeverityLow,
    medium => l.reportSeverityMedium,
    high => l.reportSeverityHigh,
    critical => l.reportSeverityCritical,
  };

  /// "Mababa: maliit na abala" (spoken with the option).
  String label(AppLocalizations l) => switch (this) {
    low => l.reportSeverityLowLong,
    medium => l.reportSeverityMediumLong,
    high => l.reportSeverityHighLong,
    critical => l.reportSeverityCriticalLong,
  };

  /// Parses a stored value, or null.
  static IssueSeverity? tryParse(String? server) =>
      values.where((s) => s.server == server).firstOrNull;
}

/// Whether the web app has the report yet.
enum IssueSyncStatus {
  /// Saved here, not sent yet (offline, or no web app configured).
  pending,

  /// The web app has it.
  sent,

  /// The web app refused it (it is kept here).
  failed;

  /// Parses a stored value ([pending] for anything unknown).
  static IssueSyncStatus parse(String? name) =>
      values.where((s) => s.name == name).firstOrNull ?? pending;

  /// "Naipadala" / "Naghihintay ipadala" / "Hindi naipadala".
  String label(AppLocalizations l) => switch (this) {
    pending => l.reportStatusPending,
    sent => l.reportStatusSent,
    failed => l.reportStatusFailed,
  };
}

/// What the dashboard says about a report it has (`status` of
/// `GET /api/v1/reports/{ticket_no}`).
enum ServerReportStatus {
  /// Received, nobody has started.
  open('open'),

  /// Someone is working on it.
  inProgress('in_progress'),

  /// Fixed or answered.
  resolved('resolved'),

  /// Closed (archived).
  closed('closed');

  const ServerReportStatus(this.code);

  /// The value in the API.
  final String code;

  /// Parses an API value, or null for anything unknown.
  static ServerReportStatus? tryParse(String? code) =>
      values.where((s) => s.code == code).firstOrNull;

  /// A finished report is not asked about again.
  bool get isFinal => this == closed;

  /// "Natanggap" / "Ginagawa" / "Naayos na" / "Sarado".
  String label(AppLocalizations l) => switch (this) {
    open => l.reportServerOpen,
    inProgress => l.reportServerInProgress,
    resolved => l.reportServerResolved,
    closed => l.reportServerClosed,
  };
}

/// The rules of a report: ticket numbers, limits, which pages apply.
abstract final class IssueRules {
  /// Shortest description.
  static const int minDescription = 10;

  /// Longest description.
  static const int maxDescription = 1000;

  /// Letters and digits of the ticket's last part: no 0/O or 1/I, which
  /// sound and look alike.
  static const String ticketAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static final RegExp _ticket = RegExp(
    r'^PRC-\d{8}-[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{4}$',
  );

  /// A new ticket number for [when]: `PRC-YYYYMMDD-XXXX`.
  static String ticketNumber(DateTime when, [Random? random]) {
    final r = random ?? Random.secure();
    final date =
        '${when.year.toString().padLeft(4, '0')}'
        '${when.month.toString().padLeft(2, '0')}'
        '${when.day.toString().padLeft(2, '0')}';
    final tail = List.generate(
      4,
      (_) => ticketAlphabet[r.nextInt(ticketAlphabet.length)],
    ).join();
    return 'PRC-$date-$tail';
  }

  /// Whether [ticket] has the ticket format.
  static bool isTicket(String ticket) => _ticket.hasMatch(ticket);

  /// "P R C, 2 0 2 6 …": the ticket read character by character.
  static String spokenTicket(String ticket) =>
      ticket.replaceAll('-', ' ').split('').join(' ').replaceAll('   ', ', ');

  /// Whether the severity page is asked: only for bugs.
  static bool asksSeverity(IssueType? type) => type == IssueType.bug;

  /// Why [description] can't be sent, or null when it is fine.
  static DescriptionProblem? checkDescription(String description) {
    final length = description.trim().length;
    if (length < minDescription) return DescriptionProblem.tooShort;
    if (length > maxDescription) return DescriptionProblem.tooLong;
    return null;
  }

  /// Whether [email] may be used (empty = no email).
  static bool isValidEmail(String email) =>
      email.trim().isEmpty || AuthRules.isValidEmail(email);
}

/// What is wrong with a description.
enum DescriptionProblem {
  /// Under [IssueRules.minDescription] characters.
  tooShort,

  /// Over [IssueRules.maxDescription] characters.
  tooLong,
}

/// Details attached to every report automatically (shown on the review
/// page). Never document text, pictures, recordings or passwords.
@immutable
class IssueDetails {
  /// Creates the details.
  const IssueDetails({
    required this.appVersion,
    required this.osVersion,
    required this.deviceModel,
  });

  /// "0.1.1+2".
  final String appVersion;

  /// "Android 14 (SDK 34)".
  final String osVersion;

  /// "samsung SM-X200".
  final String deviceModel;
}

/// One saved report (`issue_reports` row).
@immutable
class IssueReport {
  /// Creates a report.
  const IssueReport({
    required this.id,
    required this.ticketNo,
    required this.type,
    required this.module,
    required this.severity,
    required this.description,
    required this.email,
    required this.details,
    required this.sourceScreen,
    required this.createdAt,
    this.userId,
    this.status = IssueSyncStatus.pending,
    this.serverId,
    this.serverStatus,
  });

  /// Local id (UUID).
  final String id;

  /// `PRC-YYYYMMDD-XXXX`.
  final String ticketNo;

  /// Kind of report.
  final IssueType type;

  /// Part of the app.
  final IssueModule module;

  /// Bugs only.
  final IssueSeverity? severity;

  /// What happened.
  final String description;

  /// Where to reply, or null.
  final String? email;

  /// App and phone details.
  final IssueDetails details;

  /// The screen the report was opened from.
  final String sourceScreen;

  /// When it was written.
  final DateTime createdAt;

  /// Local account that wrote it (null for a guest's report written before
  /// logging in, or none).
  final String? userId;

  /// Whether the web app has it.
  final IssueSyncStatus status;

  /// The web app's id, once sent.
  final String? serverId;

  /// What the dashboard says about it (`open`, `in_progress`, `resolved`,
  /// `closed`), once asked; null before.
  final ServerReportStatus? serverStatus;

  /// What to show and read as its status: the dashboard's word once the
  /// report is there ("Bukas", "Ginagawa", "Naayos na", "Sarado"), else
  /// whether it was sent.
  String statusLabel(AppLocalizations l) => status == IssueSyncStatus.sent
      ? (serverStatus?.label(l) ?? status.label(l))
      : status.label(l);

  /// The request body for `POST /api/v1/reports` (the dashboard's
  /// `docs/api-contract.md`): type, module and severity as `{code, label}`,
  /// and who sent it. The display name is left out on purpose: a signed-in
  /// report is linked to its account by the token.
  Map<String, Object?> toJson() => {
    'ticket_no': ticketNo,
    'type': {'code': type.code, 'label': type.server},
    'module': {'code': module.code, 'label': module.server},
    'severity': severity == null
        ? null
        : {'code': severity!.code, 'label': severity!.server},
    'description': description,
    'email': email,
    'reporter': {
      'kind': userId == null ? 'guest' : 'account',
      'display_name': null,
    },
    'app_version': details.appVersion,
    'os_version': details.osVersion,
    'device_model': details.deviceModel,
    'source_screen': sourceScreen,
    'created_at': createdAt.toUtc().toIso8601String(),
  };
}
