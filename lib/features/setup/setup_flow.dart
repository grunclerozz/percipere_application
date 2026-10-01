import 'package:flutter/foundation.dart';

/// The steps of the guided setup, in order.
enum SetupStep {
  /// 1. Voice or gestures.
  navMode,

  /// "Nakakakita ka ba ng kahit kaunting teksto sa screen?" (part of 2).
  seesText,

  /// 2. Text size.
  textSize,

  /// 3. Text color.
  textColor,

  /// 4. Voice language.
  voiceLanguage,

  /// 5. Speed.
  speed,

  /// 6. Tone (pitch).
  pitch,

  /// 7. Theme.
  theme,

  /// 8. Vibration.
  vibration,

  /// 9. Auto-read documents.
  autoRead,

  /// 10. Summary.
  summary;

  /// Parses a stored name, or null.
  static SetupStep? tryParse(Object? name) {
    for (final s in values) {
      if (s.name == name) return s;
    }
    return null;
  }

  /// Steps that only matter to someone who can see some text.
  bool get needsSight => this == textSize || this == textColor;
}

/// Why the setup is running.
enum SetupMode {
  /// After registering / first guest visit / first login of an account
  /// that never finished it. Only steps not done yet are asked.
  firstRun,

  /// "Ulitin ang setup" from Settings: every step, then back to Settings.
  redo,
}

/// Which steps to ask and where the user is: the pure logic behind the
/// profiling screens (skip, back, resume, jump from the summary).
@immutable
class SetupFlow {
  /// Creates a flow at [index] of [plan].
  const SetupFlow({
    required this.plan,
    this.index = 0,
    this.seesText,
    this.fromSummary = false,
  });

  /// The steps for this user: all of them, the guest's short list, or the
  /// ones not done yet. Always ends with the summary.
  factory SetupFlow.start({
    required bool guest,
    required SetupMode mode,
    Set<SetupStep> done = const {},
    SetupStep? resumeAt,
    bool? seesText,
  }) {
    final List<SetupStep> plan;
    // "Ulitin ang setup" asks everything, guests included (their first run
    // is the short list; the full setup is available from Settings).
    if (mode == SetupMode.redo) {
      plan = SetupStep.values;
    } else if (guest) {
      plan = guestPlan;
    } else {
      plan = [
        for (final s in SetupStep.values)
          // "Can you see text?" is asked again whenever a sight step is.
          if (s == SetupStep.summary ||
              !done.contains(s) ||
              (s == SetupStep.seesText &&
                  (!done.contains(SetupStep.textSize) ||
                      !done.contains(SetupStep.textColor))))
            s,
      ];
    }
    var flow = SetupFlow(plan: plan, seesText: seesText);
    final at = resumeAt == null ? -1 : plan.indexOf(resumeAt);
    if (at > 0) flow = flow._at(at);
    return flow;
  }

  /// Guests: Steps 1, 4, 5 and the summary; defaults for the rest.
  static const List<SetupStep> guestPlan = [
    SetupStep.navMode,
    SetupStep.voiceLanguage,
    SetupStep.speed,
    SetupStep.summary,
  ];

  /// Steps to ask, in order.
  final List<SetupStep> plan;

  /// Position in [plan].
  final int index;

  /// Answer to "can you see some text?" (null until asked). No → Steps 2–3
  /// are skipped and keep their defaults.
  final bool? seesText;

  /// The current step was opened from the summary: confirming returns
  /// there.
  final bool fromSummary;

  /// The current step.
  SetupStep get step => plan[index];

  /// Whether [s] is skipped for this user.
  bool hidden(SetupStep s) => s.needsSight && seesText == false;

  /// Steps that get a number ("Hakbang 3 ng 10"): the sight question shares
  /// the number of the text size step that follows it.
  List<SetupStep> get _numbered => [
    for (final s in plan)
      if (s != SetupStep.seesText || !plan.contains(SetupStep.textSize)) s,
  ];

  /// 1-based step number.
  int get number {
    final s = step == SetupStep.seesText && plan.contains(SetupStep.textSize)
        ? SetupStep.textSize
        : step;
    return _numbered.indexOf(s) + 1;
  }

  /// How many numbered steps there are.
  int get total => _numbered.length;

  /// Whether this is the first step.
  bool get isFirst => index == 0;

  /// Steps shown in the summary (the ones in this plan, not hidden).
  List<SetupStep> get summaryItems => [
    for (final s in plan)
      if (s != SetupStep.summary && s != SetupStep.seesText && !hidden(s)) s,
  ];

  SetupFlow _at(int i, {bool fromSummary = false, bool? seesText}) => SetupFlow(
    plan: plan,
    index: i,
    seesText: seesText ?? this.seesText,
    fromSummary: fromSummary,
  );

  /// After confirming or skipping the current step. A step opened from the
  /// summary returns to it.
  SetupFlow next() {
    if (fromSummary) return _at(plan.indexOf(SetupStep.summary));
    var i = index + 1;
    while (i < plan.length - 1 && hidden(plan[i])) {
      i++;
    }
    return _at(i.clamp(0, plan.length - 1));
  }

  /// Back one step (values already chosen are kept). Null on the first.
  SetupFlow? back() {
    if (fromSummary) return _at(plan.indexOf(SetupStep.summary));
    var i = index - 1;
    while (i > 0 && hidden(plan[i])) {
      i--;
    }
    return i < 0 ? null : _at(i);
  }

  /// Answers "can you see some text?" and moves on: to the text steps on
  /// yes, past them on no.
  SetupFlow answerSeesText(bool sees) {
    final f = SetupFlow(
      plan: plan,
      index: index,
      seesText: sees,
      fromSummary: fromSummary,
    );
    if (sees && fromSummary && plan.contains(SetupStep.textSize)) {
      return f._at(plan.indexOf(SetupStep.textSize), fromSummary: true);
    }
    return f.next();
  }

  /// From the summary: open [s] (returns to the summary afterwards). If it
  /// is a sight step skipped earlier, the sight question is asked first.
  SetupFlow jumpTo(SetupStep s) {
    var target = s;
    if (s.needsSight &&
        seesText == false &&
        plan.contains(SetupStep.seesText)) {
      target = SetupStep.seesText;
    }
    final i = plan.indexOf(target);
    return i < 0 ? this : _at(i, fromSummary: true);
  }
}
