import 'package:flutter/foundation.dart';

import '../../core/report/issue_report.dart';

/// The pages of "Mag-report ng problema", in order.
enum ReportPage {
  /// 1. Bug, feature request or general feedback.
  type,

  /// 2. Which part of the app.
  module,

  /// 3. How bad (bugs only).
  severity,

  /// 4. What happened.
  description,

  /// 5. Email to reply to.
  email,

  /// 6. Review: send or edit.
  review,

  /// "Alin ang babaguhin?" (from the review).
  edit,

  /// 7. The ticket.
  ticket,
}

/// The answers so far.
@immutable
class ReportDraft {
  /// Creates a draft.
  const ReportDraft({
    this.type,
    this.module,
    this.severity,
    this.description = '',
    this.email = '',
  });

  /// Page 1.
  final IssueType? type;

  /// Page 2.
  final IssueModule? module;

  /// Page 3 (kept only for bugs).
  final IssueSeverity? severity;

  /// Page 4.
  final String description;

  /// Page 5 ('' = no email).
  final String email;

  /// Whether anything was answered (leaving then asks first).
  bool get isEmpty =>
      type == null &&
      module == null &&
      severity == null &&
      description.trim().isEmpty;

  /// The severity that counts: none unless it is a bug.
  IssueSeverity? get effectiveSeverity =>
      IssueRules.asksSeverity(type) ? severity : null;

  /// A copy with some answers changed; [clearSeverity] drops it.
  ReportDraft copyWith({
    IssueType? type,
    IssueModule? module,
    IssueSeverity? severity,
    bool clearSeverity = false,
    String? description,
    String? email,
  }) => ReportDraft(
    type: type ?? this.type,
    module: module ?? this.module,
    severity: clearSeverity ? null : (severity ?? this.severity),
    description: description ?? this.description,
    email: email ?? this.email,
  );
}

/// Page order: the severity page is only asked for bugs; edits from the
/// review return to the review.
abstract final class ReportFlow {
  /// The question pages for [type], in order.
  static List<ReportPage> questions(IssueType? type) => [
    ReportPage.type,
    ReportPage.module,
    if (IssueRules.asksSeverity(type)) ReportPage.severity,
    ReportPage.description,
    ReportPage.email,
    ReportPage.review,
  ];

  /// The page after [page] once it is answered. [editing]: the user came
  /// from the review to change one answer, so the review follows — except
  /// a new type of Bug, whose severity must be asked first.
  static ReportPage next(
    ReportPage page,
    ReportDraft draft, {
    bool editing = false,
  }) {
    if (editing) {
      final needsSeverity =
          page == ReportPage.type &&
          IssueRules.asksSeverity(draft.type) &&
          draft.severity == null;
      return needsSeverity ? ReportPage.severity : ReportPage.review;
    }
    final order = questions(draft.type);
    final i = order.indexOf(page);
    return i < 0 || i + 1 >= order.length ? ReportPage.review : order[i + 1];
  }

  /// The page before [page] ("bumalik"), or null on the first page.
  static ReportPage? previous(ReportPage page, ReportDraft draft) {
    if (page == ReportPage.edit || page == ReportPage.ticket) {
      return ReportPage.review;
    }
    final order = questions(draft.type);
    final i = order.indexOf(page);
    return i <= 0 ? null : order[i - 1];
  }

  /// "Hakbang 2 ng 6": [page]'s number and the total for [type].
  static (int, int) progress(ReportPage page, IssueType? type) {
    final order = questions(type);
    return (order.indexOf(page) + 1, order.length);
  }
}
