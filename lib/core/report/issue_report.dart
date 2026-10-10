import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../l10n/app_localizations.dart';
import '../auth/validators.dart';

/// What kind of report (page 1 of "Mag-report ng problema").
enum IssueType {
  /// Something is broken ("May sira").
  bug('Bug', ['bug', 'may sira', 'sira', 'sirang', 'problema', 'error']),

  /// An idea ("Mungkahi").
  feature('Feature Request', [
    'feature request',
    'feature',
    'mungkahi',
    'suggestion',
    'request',
  ]),

  /// Anything else ("Puna").
  feedback('General Feedback', [
    'general feedback',
    'feedback',
    'puna',
    'komento',
    'comment',
  ]);

  const IssueType(this.server, this.voice);

  /// The value the web app stores (`feedback_category`).
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
  ocr('OCR', ['ocr', 'pagbasa ng teksto', 'text reading', 'pagbasa']),

  /// The camera.
  camera('Camera', ['camera', 'kamera', 'litrato']),

  /// Voice commands.
  voiceCommands('Voice Commands', [
    'voice commands',
    'voice',
    'boses',
    'mga utos',
    'utos sa boses',
  ]),

  /// Login, register, password.
  accounts('Accounts', ['accounts', 'account', 'login', 'password']),

  /// The reading voice.
  tts('Text-to-Speech', [
    'text to speech',
    'tts',
    'nagbabasa',
    'boses na nagbabasa',
    'pagbabasa',
  ]),

  /// The Gesture Pad.
  gesturePad('Gestures', ['gesture pad', 'gesture', 'galaw', 'swipe']),

  /// Aklatan.
  library('Library', ['aklatan', 'library', 'aklat', 'libro']),

  /// Image description.
  maglarawan('Maglarawan', ['maglarawan', 'larawan', 'describe', 'image']),

  /// The voice assistant.
  percy('Percy', ['percy', 'assistant', 'katulong']),

  /// Anything else.
  other('Other', ['iba pa', 'iba', 'other', 'others']);

  const IssueModule(this.server, this.voice);

  /// The value the web app stores (`feedback_module`).
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
  low('Low', ['low', 'mababa', 'maliit']),

  /// Works, but wrong.
  medium('Medium', ['medium', 'katamtaman', 'katamtamang']),

  /// Doesn't work.
  high('High', ['high', 'mataas', 'hindi gumagana']),

  /// Crashes or loses data.
  critical('Critical', ['critical', 'kritikal', 'nag-crash', 'crash']);

  const IssueSeverity(this.server, this.voice);

  /// The value the web app stores (`feedback_severity`).
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

  /// The request body for the web app (`api/v1/feedback.php`).
  Map<String, Object?> toJson() => {
    'ticket_no': ticketNo,
    'type': type.server,
    'module': module.server,
    'severity': severity?.server,
    'description': description,
    'email': email,
    'app_version': details.appVersion,
    'os_version': details.osVersion,
    'device_model': details.deviceModel,
    'source_screen': sourceScreen,
    'created_at': createdAt.toUtc().toIso8601String(),
  };
}
