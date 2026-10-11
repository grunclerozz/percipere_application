// Report an issue: ticket numbers, validation, which pages are asked
// (severity only for bugs), and the request body.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/report/issue_report.dart';
import 'package:percipere_app/features/report/report_flow.dart';

void main() {
  group('ticket number', () {
    test('PRC-YYYYMMDD-XXXX with no 0, O, 1 or I', () {
      final when = DateTime(2026, 3, 7, 22, 5);
      final random = Random(1);
      for (var i = 0; i < 500; i++) {
        final t = IssueRules.ticketNumber(when, random);
        expect(t, matches(RegExp(r'^PRC-20260307-[A-Z2-9]{4}$')));
        expect(t.substring(13), isNot(matches(RegExp('[01OI]'))));
        expect(IssueRules.isTicket(t), isTrue);
      }
    });

    test('different each time; the format check refuses look-alikes', () {
      final when = DateTime(2026, 10, 11);
      final seen = {for (var i = 0; i < 50; i++) IssueRules.ticketNumber(when)};
      expect(seen.length, greaterThan(45));
      expect(IssueRules.isTicket('PRC-20261011-K7QM'), isTrue);
      expect(IssueRules.isTicket('PRC-20261011-K7Q0'), isFalse);
      expect(IssueRules.isTicket('PRC-20261011-KIQM'), isFalse);
      expect(IssueRules.isTicket('PRC-2026101-K7QM'), isFalse);
      expect(IssueRules.isTicket('prc-20261011-K7QM'), isFalse);
    });

    test('spoken one character at a time', () {
      expect(
        IssueRules.spokenTicket('PRC-20261011-K7QM'),
        'P R C, 2 0 2 6 1 0 1 1, K 7 Q M',
      );
    });
  });

  group('validation', () {
    test('description: 10 to 1000 characters (spaces around ignored)', () {
      expect(
        IssueRules.checkDescription('  short  '),
        DescriptionProblem.tooShort,
      );
      expect(
        IssueRules.checkDescription('123456789'),
        DescriptionProblem.tooShort,
      );
      expect(IssueRules.checkDescription('1234567890'), isNull);
      expect(IssueRules.checkDescription('a' * 1000), isNull);
      expect(
        IssueRules.checkDescription('a' * 1001),
        DescriptionProblem.tooLong,
      );
    });

    test('email: empty is allowed, otherwise a real address', () {
      expect(IssueRules.isValidEmail(''), isTrue);
      expect(IssueRules.isValidEmail('juan@example.com'), isTrue);
      expect(IssueRules.isValidEmail('juan@'), isFalse);
      expect(IssueRules.isValidEmail('juan example.com'), isFalse);
    });
  });

  group('pages', () {
    test('severity is asked only for bugs', () {
      expect(ReportFlow.questions(IssueType.bug), [
        ReportPage.type,
        ReportPage.module,
        ReportPage.severity,
        ReportPage.description,
        ReportPage.email,
        ReportPage.review,
      ]);
      for (final t in [IssueType.feature, IssueType.feedback, null]) {
        expect(ReportFlow.questions(t), isNot(contains(ReportPage.severity)));
      }
      const feature = ReportDraft(type: IssueType.feature);
      expect(
        ReportFlow.next(ReportPage.module, feature),
        ReportPage.description,
      );
      expect(
        ReportFlow.previous(ReportPage.description, feature),
        ReportPage.module,
      );
      const bug = ReportDraft(type: IssueType.bug);
      expect(ReportFlow.next(ReportPage.module, bug), ReportPage.severity);
      expect(
        ReportFlow.previous(ReportPage.description, bug),
        ReportPage.severity,
      );
    });

    test('back from the first page leaves; progress counts the pages', () {
      expect(ReportFlow.previous(ReportPage.type, const ReportDraft()), isNull);
      expect(ReportFlow.progress(ReportPage.email, IssueType.bug), (5, 6));
      expect(ReportFlow.progress(ReportPage.email, IssueType.feature), (4, 5));
    });

    test('editing from the review returns to it; a new Bug type asks the '
        'severity first', () {
      const feature = ReportDraft(
        type: IssueType.bug,
        module: IssueModule.camera,
      );
      expect(
        ReportFlow.next(ReportPage.module, feature, editing: true),
        ReportPage.review,
      );
      expect(
        ReportFlow.next(ReportPage.type, feature, editing: true),
        ReportPage.severity,
      );
      expect(
        ReportFlow.next(
          ReportPage.type,
          feature.copyWith(severity: IssueSeverity.low),
          editing: true,
        ),
        ReportPage.review,
      );
    });

    test('a severity chosen for a bug is dropped when the type changes', () {
      const draft = ReportDraft(
        type: IssueType.bug,
        severity: IssueSeverity.high,
      );
      expect(draft.effectiveSeverity, IssueSeverity.high);
      final feature = draft.copyWith(type: IssueType.feature);
      expect(feature.effectiveSeverity, isNull);
      expect(
        draft.copyWith(type: IssueType.feature, clearSeverity: true).severity,
        isNull,
      );
      expect(const ReportDraft().isEmpty, isTrue);
      expect(draft.isEmpty, isFalse);
    });
  });

  test('the request body has the fields the web app expects, and nothing '
      'else', () {
    final report = IssueReport(
      id: 'local-1',
      ticketNo: 'PRC-20261011-K7QM',
      type: IssueType.feature,
      module: IssueModule.maglarawan,
      severity: null,
      description: 'Sana mas mahaba ang paglalarawan.',
      email: null,
      details: const IssueDetails(
        appVersion: '0.1.1+2',
        osVersion: 'Android 14 (SDK 34)',
        deviceModel: 'Google Pixel 7',
      ),
      sourceScreen: 'describe',
      createdAt: DateTime.utc(2026, 10, 11, 1, 30),
    );
    expect(report.toJson(), {
      'ticket_no': 'PRC-20261011-K7QM',
      'type': {'code': 'feature', 'label': 'Feature Request'},
      'module': {'code': 'maglarawan', 'label': 'Maglarawan'},
      'severity': null,
      'description': 'Sana mas mahaba ang paglalarawan.',
      'email': null,
      'reporter': {'kind': 'guest', 'display_name': null},
      'app_version': '0.1.1+2',
      'os_version': 'Android 14 (SDK 34)',
      'device_model': 'Google Pixel 7',
      'source_screen': 'describe',
      'created_at': '2026-10-11T01:30:00.000Z',
    });
    // The labels the web app stores and shows.
    expect(IssueModule.values.map((m) => m.server), [
      'OCR',
      'Camera',
      'Voice Commands',
      'Accounts',
      'Text-to-Speech',
      'Gestures',
      'Library',
      'Maglarawan',
      'Percy',
      'Other',
    ]);
  });

  test('a bug of a signed-in account: codes and labels, severity, account', () {
    final report = IssueReport(
      id: 'local-2',
      ticketNo: 'PRC-20261011-AB23',
      type: IssueType.bug,
      module: IssueModule.voiceCommands,
      severity: IssueSeverity.critical,
      description: 'Nag-crash ang app kapag nagsalita ako',
      email: 'juan@example.com',
      details: const IssueDetails(
        appVersion: '0.1.1+2',
        osVersion: 'Android 14 (SDK 34)',
        deviceModel: 'Test Tablet',
      ),
      sourceScreen: 'home',
      createdAt: DateTime.utc(2026, 10, 11, 1, 30),
      userId: 'u-1',
    );
    final json = report.toJson();
    expect(json['type'], {'code': 'bug', 'label': 'Bug'});
    expect(json['module'], {'code': 'voice_commands', 'label': 'Voice Commands'});
    expect(json['severity'], {'code': 'critical', 'label': 'Critical'});
    expect(json['reporter'], {'kind': 'account', 'display_name': null});
    expect(json['email'], 'juan@example.com');
  });

  test('every code follows the dashboard contract: lowercase, digits, _', () {
    final pattern = RegExp(r'^[a-z0-9_]{1,40}$');
    for (final code in [
      ...IssueType.values.map((t) => t.code),
      ...IssueModule.values.map((m) => m.code),
      ...IssueSeverity.values.map((s) => s.code),
    ]) {
      expect(code, matches(pattern));
    }
    expect(IssueType.values.map((t) => t.code), ['bug', 'feature', 'feedback']);
    expect(IssueModule.values.map((m) => m.code), [
      'ocr',
      'camera',
      'voice_commands',
      'accounts',
      'text_to_speech',
      'gestures',
      'library',
      'maglarawan',
      'percy',
      'other',
    ]);
    expect(IssueSeverity.values.map((s) => s.code), [
      'low',
      'medium',
      'high',
      'critical',
    ]);
  });
}
