import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/ids.dart';
import '../../app/router.dart';
import '../../config/constants.dart';
import '../../core/accessibility/accessible_screen.dart';
import '../../core/accessibility/action_registry.dart';
import '../../core/accessibility/command_bus.dart';
import '../../core/accessibility/focus_controller.dart';
import '../../core/accessibility/haptics.dart';
import '../../core/accessibility/nav_intent.dart';
import '../../core/accessibility/screen_registration.dart';
import '../../core/auth/session.dart';
import '../../core/auth/validators.dart';
import '../../core/report/issue_report.dart';
import '../../core/report/issue_report_api.dart';
import '../../core/report/issue_report_repository.dart';
import '../../core/report/issue_report_sync.dart';
import '../../core/voice/command_matcher.dart';
import '../../core/voice/voice_commands.dart';
import '../../core/voice/voice_controller.dart';
import '../../core/widgets/boxed_list.dart';
import '../../core/widgets/pill_button.dart';
import '../../core/widgets/small_link.dart';
import '../../l10n/app_localizations.dart';
import '../auth/form_scaffold.dart';
import 'report_flow.dart';

/// "Mag-report ng problema": one question per page — type, part of the
/// app, severity (bugs only), what happened (dictated or typed, read back),
/// email, review — then the ticket. Every page works by voice, gestures and
/// touch like the setup. The report is saved on the phone first and sent to
/// the web app when there is a connection (`IssueReportSync`).
class ReportIssueScreen extends ConsumerStatefulWidget {
  /// Creates the flow, opened from screen [sourceScreen].
  const ReportIssueScreen({super.key, this.sourceScreen = ''});

  /// Id of the screen the user was on (sent with the report).
  final String sourceScreen;

  @override
  ConsumerState<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends ConsumerState<ReportIssueScreen> {
  ReportPage _page = ReportPage.type;
  ReportDraft _draft = const ReportDraft();
  bool _editing = false;
  bool _introduced = false;
  bool _busy = false;
  IssueReport? _saved;
  IssueDetails? _details;
  late final String? _accountEmail;
  late final String? _accountId;
  final TextEditingController _description = TextEditingController();
  final TextEditingController _email = TextEditingController();

  CommandBus get _bus => ref.read(commandBusProvider);

  String get _screenId => '${Ids.reportIssue}.${_page.name}';

  String _id(String part) => '$_screenId.$part';

  @override
  void initState() {
    super.initState();
    final account = ref.read(currentAccountProvider);
    _accountId = account?.id;
    _accountEmail = account?.isGuest == false ? account?.email : null;
    _email.text = _accountEmail ?? '';
    unawaited(_loadDetails());
    // The email page asks "Gamitin ang email na ito?" once it is showing.
    ref.listenManual(activeScreenProvider, (previous, next) {
      if (next?.id == '${Ids.reportIssue}.${ReportPage.email.name}' &&
          previous?.id != next?.id) {
        scheduleMicrotask(_askEmail);
      }
    });
  }

  Future<void> _loadDetails() async {
    try {
      final details = await ref.read(issueDetailsProvider)();
      if (mounted) setState(() => _details = details);
    } on Object catch (e) {
      debugPrint('[REPORT] details failed: $e');
    }
  }

  @override
  void dispose() {
    _description.dispose();
    _email.dispose();
    super.dispose();
  }

  // ── Moving between pages ─────────────────────────────────────────────────

  void _go(ReportPage page) {
    if (!mounted) return;
    setState(() {
      _introduced = true;
      if (page == ReportPage.review) _editing = false;
      _page = page;
    });
  }

  void _answered(ReportDraft draft) {
    final next = ReportFlow.next(_page, draft, editing: _editing);
    setState(() => _draft = draft);
    _go(next);
  }

  Future<void> _back(CommandBus bus) async {
    if (_page == ReportPage.ticket) return _leave();
    if (_editing && _page != ReportPage.review) return _go(ReportPage.review);
    final previous = ReportFlow.previous(_page, _draft);
    if (previous != null) return _go(previous);
    return _cancel(bus);
  }

  void _leave() {
    final router = ref.read(routerProvider);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(AppRoutes.home);
    }
  }

  Future<void> _cancel(CommandBus bus) async {
    final l = bus.strings;
    if (_draft.isEmpty && _page == ReportPage.type) {
      await bus.say(l.reportCancelled);
      return _leave();
    }
    return bus.offer(l.reportCancelConfirm, () async {
      await bus.say(l.reportCancelled);
      if (mounted) _leave();
    });
  }

  // ── Description ──────────────────────────────────────────────────────────

  /// Exact command phrases are commands; anything else is an answer.
  static bool _isCommand(String text, ScreenRegistration? screen) {
    final said = CommandMatcher.normalize(text);
    bool same(String phrase) => CommandMatcher.normalize(phrase) == said;
    for (final list in globalVoiceCommands.values) {
      if (list.any(same)) return true;
    }
    for (final a in screen?.actions ?? const <A11yAction>[]) {
      if (a.voiceSynonyms.any(same)) return true;
    }
    return false;
  }

  Future<bool> _onDescription(String text, CommandBus bus) async {
    if (_isCommand(text, bus.activeScreen)) return false;
    await _heard(text, bus);
    return true;
  }

  Future<void> _heard(String text, CommandBus bus) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    setState(() => _description.text = clean);
    final l = bus.strings;
    await bus.offer(
      l.reportHeard(clean),
      () => _descriptionDone(bus),
      onDecline: () async {
        setState(_description.clear);
        await bus.say(l.reportSayAgain);
      },
    );
  }

  Future<void> _speakDescription(CommandBus bus) async {
    final heard = await ref.read(voiceControllerProvider.notifier).dictate();
    if (!mounted || heard == null || heard.trim().isEmpty) return;
    if (_isCommand(heard, bus.activeScreen)) return bus.handleUtterance(heard);
    await _heard(heard, bus);
  }

  Future<void> _descriptionDone(CommandBus bus) async {
    final l = bus.strings;
    final text = _description.text.trim();
    final problem = IssueRules.checkDescription(text);
    if (problem != null) {
      unawaited(ref.read(hapticsProvider).error());
      return bus.say(switch (problem) {
        DescriptionProblem.tooShort => l.reportDescriptionShort,
        DescriptionProblem.tooLong => l.reportDescriptionLong,
      });
    }
    _answered(_draft.copyWith(description: text));
  }

  // ── Email ────────────────────────────────────────────────────────────────

  Future<void> _askEmail() async {
    if (!mounted || _page != ReportPage.email) return;
    final l = _bus.strings;
    final email = _email.text.trim();
    if (email.isEmpty) return;
    await _bus.offer(
      l.reportAskEmailUse(email),
      () => _emailDone(_bus),
      onDecline: () async {
        setState(_email.clear);
        await _bus.say(l.reportAskEmail);
      },
    );
  }

  Future<bool> _onEmail(String text, CommandBus bus) async {
    if (_isCommand(text, bus.activeScreen)) return false;
    await _emailHeard(text, bus);
    return true;
  }

  Future<void> _emailHeard(String text, CommandBus bus) async {
    final email = AuthRules.spokenEmail(text);
    setState(() => _email.text = email);
    final l = bus.strings;
    if (!AuthRules.isValidEmail(email)) {
      unawaited(ref.read(hapticsProvider).error());
      return bus.say(l.reportEmailInvalid);
    }
    await bus.say(l.reportEmailValue(email));
  }

  Future<void> _speakEmail(CommandBus bus) async {
    final heard = await ref.read(voiceControllerProvider.notifier).dictate();
    if (!mounted || heard == null || heard.trim().isEmpty) return;
    if (_isCommand(heard, bus.activeScreen)) return bus.handleUtterance(heard);
    await _emailHeard(heard, bus);
  }

  Future<void> _emailDone(CommandBus bus) async {
    final email = _email.text.trim();
    if (!IssueRules.isValidEmail(email)) {
      unawaited(ref.read(hapticsProvider).error());
      return bus.say(bus.strings.reportEmailInvalid);
    }
    _answered(_draft.copyWith(email: AuthRules.normalizeEmail(email)));
  }

  Future<void> _skipEmail(CommandBus bus) async {
    setState(_email.clear);
    _answered(_draft.copyWith(email: ''));
  }

  // ── Sending ──────────────────────────────────────────────────────────────

  Future<void> _send(CommandBus bus) async {
    if (_busy) return;
    final type = _draft.type;
    final module = _draft.module;
    if (type == null || module == null) return _go(ReportPage.type);
    setState(() => _busy = true);
    unawaited(bus.say(bus.strings.reportSending));
    try {
      final repo = ref.read(issueReportRepositoryProvider);
      final now = DateTime.now();
      var ticket = IssueRules.ticketNumber(now);
      while (await repo.ticketExists(ticket)) {
        ticket = IssueRules.ticketNumber(now);
      }
      final details = _details ?? await ref.read(issueDetailsProvider)();
      final saved = await repo.add(
        ticketNo: ticket,
        type: type,
        module: module,
        severity: _draft.effectiveSeverity,
        description: _draft.description,
        email: _draft.email.isEmpty ? null : _draft.email,
        details: details,
        sourceScreen: widget.sourceScreen,
        createdAt: now,
        userId: _accountId,
      );
      // Saved first; then one try to send (a connection problem only
      // leaves it pending for the next try).
      try {
        await ref
            .read(issueReportSyncProvider)
            .sendPending()
            .timeout(const Duration(seconds: 20), onTimeout: () => 0);
      } on Object catch (e) {
        debugPrint('[REPORT] send failed: $e');
      }
      final latest = await repo.get(saved.id) ?? saved;
      if (!mounted) return;
      unawaited(ref.read(hapticsProvider).confirm());
      setState(() => _saved = latest);
      _go(ReportPage.ticket);
    } on Object catch (e) {
      // Saving on the phone failed: the answers stay, so "ipadala" can be
      // tried again.
      debugPrint('[REPORT] save failed: $e');
      if (mounted) {
        unawaited(ref.read(hapticsProvider).error());
        await bus.say(bus.strings.reportSaveFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Text for pages ───────────────────────────────────────────────────────

  String _progress(AppLocalizations l) {
    final (n, total) = ReportFlow.progress(_page, _draft.type);
    return n <= 0 ? '' : l.setupProgress(n, total);
  }

  String _question(AppLocalizations l) => switch (_page) {
    ReportPage.type => l.reportAskType,
    ReportPage.module => l.reportAskModule,
    ReportPage.severity => l.reportAskSeverity,
    ReportPage.description => l.reportAskDescription,
    ReportPage.email =>
      _email.text.trim().isEmpty ? l.reportAskEmail : l.reportEmailWhy,
    ReportPage.review => l.reportAskReview,
    ReportPage.edit => l.reportAskEdit,
    ReportPage.ticket => l.reportTicketTitle,
  };

  static String _date(DateTime when, AppLocalizations l) {
    try {
      return DateFormat.yMMMd(l.localeName).add_jm().format(when);
    } on Object {
      return DateFormat.yMMMd('en').add_jm().format(when);
    }
  }

  /// The review lines: answers (each opens its page to change it).
  List<(ReportPage, String)> _reviewLines(AppLocalizations l) => [
    (ReportPage.type, l.reportLineType(_draft.type?.label(l) ?? '')),
    (ReportPage.module, l.reportLineModule(_draft.module?.label(l) ?? '')),
    if (_draft.effectiveSeverity != null)
      (
        ReportPage.severity,
        l.reportLineSeverity(_draft.effectiveSeverity!.short(l)),
      ),
    (ReportPage.description, l.reportLineDescription(_draft.description)),
    (
      ReportPage.email,
      l.reportLineEmail(_draft.email.isEmpty ? l.reportNoEmail : _draft.email),
    ),
  ];

  String _detailsLine(AppLocalizations l, DateTime when) {
    final d = _details;
    return l.reportLineDetails(
      d?.appVersion ?? '',
      d?.osVersion ?? '',
      d?.deviceModel ?? '',
      widget.sourceScreen,
      _date(when, l),
    );
  }

  /// The ticket, as shown and read aloud.
  List<String> _ticketLines(AppLocalizations l) {
    final r = _saved;
    if (r == null) return const [];
    final short = r.description.length > 80
        ? '${r.description.substring(0, 80)}…'
        : r.description;
    return [
      l.reportTicketLine(r.ticketNo),
      l.reportLineType(r.type.label(l)),
      l.reportLineModule(r.module.label(l)),
      if (r.severity != null) l.reportLineSeverity(r.severity!.short(l)),
      l.reportLineDescription(short),
      l.reportLineDate(_date(r.createdAt, l)),
      l.reportLineStatus(r.status.label(l)),
    ];
  }

  String _ticketSpeech(AppLocalizations l) {
    final r = _saved;
    if (r == null) return '';
    return [
      l.reportThanks,
      l.reportTicketSpoken(IssueRules.spokenTicket(r.ticketNo)),
      ..._ticketLines(l).skip(1).map((s) => '$s.'),
      if (r.status != IssueSyncStatus.sent) l.reportSavedOffline,
    ].join(' ');
  }

  // ── Registration ─────────────────────────────────────────────────────────

  A11yAction _option(
    String id,
    L10nText label,
    List<String> voice,
    void Function() choose,
  ) => A11yAction(
    id: id,
    label: label,
    voiceSynonyms: voice,
    onActivate: (_) => choose(),
  );

  A11yAction get _cancelAction => A11yAction(
    id: _id('cancel'),
    label: (l) => l.actionCancelReport,
    voiceSynonyms: const ['kanselahin', 'cancel', 'itigil ang report'],
    confirmation: (l) => '',
    onActivate: _cancel,
  );

  List<A11yAction> _actions() => switch (_page) {
    ReportPage.type => [
      for (final t in IssueType.values)
        _option(_id(t.name), t.label, t.voice, () {
          final keep = t == IssueType.bug;
          _answered(_draft.copyWith(type: t, clearSeverity: !keep));
        }),
      _cancelAction,
    ],
    ReportPage.module => [
      for (final m in IssueModule.values)
        _option(
          _id(m.name),
          m.label,
          m.voice,
          () => _answered(_draft.copyWith(module: m)),
        ),
      _cancelAction,
    ],
    ReportPage.severity => [
      for (final s in IssueSeverity.values)
        _option(
          _id(s.name),
          s.label,
          s.voice,
          () => _answered(_draft.copyWith(severity: s)),
        ),
      _cancelAction,
    ],
    ReportPage.description => [
      A11yAction(
        id: _id('speak'),
        label: (l) => l.actionSpeak,
        voiceSynonyms: const ['magsalita', 'speak', 'dictate'],
        confirmation: (l) => '',
        onActivate: _speakDescription,
      ),
      A11yAction(
        id: _id('next'),
        label: (l) => l.actionNext,
        voiceSynonyms: const ['susunod', 'next', 'tapos na', 'done'],
        confirmation: (l) => '',
        onActivate: _descriptionDone,
      ),
      _cancelAction,
    ],
    ReportPage.email => [
      A11yAction(
        id: _id('next'),
        label: (l) => l.actionNext,
        voiceSynonyms: const ['susunod', 'next', 'gamitin', 'tapos na', 'done'],
        confirmation: (l) => '',
        onActivate: _emailDone,
      ),
      A11yAction(
        id: _id('speak'),
        label: (l) => l.actionSpeak,
        voiceSynonyms: const ['magsalita', 'speak'],
        confirmation: (l) => '',
        onActivate: _speakEmail,
      ),
      if (_accountEmail == null)
        A11yAction(
          id: _id('skip'),
          label: (l) => l.actionSkip,
          voiceSynonyms: const ['laktawan', 'skip', 'wala'],
          onActivate: _skipEmail,
        ),
      _cancelAction,
    ],
    ReportPage.review => [
      A11yAction(
        id: _id('send'),
        label: (l) => l.actionSendReport,
        voiceSynonyms: const ['ipadala', 'send', 'submit', 'isumite'],
        confirmation: (l) => '',
        onActivate: _send,
      ),
      A11yAction(
        id: _id('edit'),
        label: (l) => l.actionEditReport,
        voiceSynonyms: const ['baguhin', 'edit', 'palitan'],
        confirmation: (l) => '',
        onActivate: (_) => _go(ReportPage.edit),
      ),
      for (final (i, part) in _reviewParts.indexed)
        A11yAction(
          id: _id('line$i'),
          label: (l) => _reviewLines(l)[i].$2,
          confirmation: (l) => '',
          onActivate: (_) => _editPart(part),
        ),
      _cancelAction,
    ],
    ReportPage.edit => [
      for (final part in _reviewParts)
        _option(
          _id(part.name),
          (l) => _partLabel(part, l),
          _partVoice(part),
          () => _editPart(part),
        ),
      _cancelAction,
    ],
    ReportPage.ticket => [
      A11yAction(
        id: _id('repeat'),
        label: (l) => l.actionRepeatTicket,
        voiceSynonyms: const ['ulitin', 'repeat', 'ulit'],
        confirmation: (l) => '',
        onActivate: (bus) => bus.say(_ticketSpeech(bus.strings)),
      ),
      A11yAction(
        id: _id('done'),
        label: (l) => l.actionDone,
        voiceSynonyms: const ['tapos na', 'done', 'okay', 'sige'],
        onActivate: (_) => _leave(),
      ),
    ],
  };

  List<ReportPage> get _reviewParts => [
    ReportPage.type,
    ReportPage.module,
    if (_draft.effectiveSeverity != null) ReportPage.severity,
    ReportPage.description,
    ReportPage.email,
  ];

  static String _partLabel(ReportPage part, AppLocalizations l) =>
      switch (part) {
        ReportPage.type => l.reportPartType,
        ReportPage.module => l.reportPartModule,
        ReportPage.severity => l.reportPartSeverity,
        ReportPage.description => l.reportPartDescription,
        _ => l.reportPartEmail,
      };

  static List<String> _partVoice(ReportPage part) => switch (part) {
    ReportPage.type => const ['uri', 'type'],
    ReportPage.module => const ['bahagi', 'module', 'part'],
    ReportPage.severity => const ['kalala', 'severity'],
    ReportPage.description => const ['nangyari', 'description', 'paglalarawan'],
    _ => const ['email'],
  };

  void _editPart(ReportPage part) {
    _editing = true;
    if (part == ReportPage.description) {
      _description.text = _draft.description;
    }
    if (part == ReportPage.email) _email.text = _draft.email;
    _go(part);
  }

  ScreenRegistration _registration(WidgetRef ref) {
    final page = _page;
    final text = page == ReportPage.description || page == ReportPage.email;
    final firstEntry = page == ReportPage.type && !_introduced;
    return ScreenRegistration(
      id: _screenId,
      title: (l) =>
          page == ReportPage.ticket ? l.reportTicketTitle : l.screenReportIssue,
      prompt: (l) => switch (page) {
        ReportPage.review => [
          ..._reviewLines(l).map((line) => '${line.$2}.'),
          _detailsLine(l, DateTime.now()),
          l.reportPrivacy,
          l.reportAskReview,
        ].join(' '),
        ReportPage.ticket => _ticketSpeech(l),
        ReportPage.email => [
          _progress(l),
          if (_email.text.trim().isEmpty)
            l.reportAskEmail
          else
            l.reportEmailWhy,
          if (_email.text.trim().isEmpty) l.reportPrivacy,
        ].join(' '),
        ReportPage.edit => l.reportAskEdit,
        _ => [
          if (firstEntry) l.reportIntro,
          _progress(l),
          _question(l),
        ].join(' '),
      },
      followUp: page == ReportPage.description
          ? (l) => l.reportDescriptionHint
          : null,
      listOptions: !text && page != ReportPage.review,
      includeModeHint: false,
      autoListen: true,
      help: (l) => text ? l.helpReportText : l.helpReport,
      onUtterance: switch (page) {
        ReportPage.description => _onDescription,
        ReportPage.email => _onEmail,
        _ => null,
      },
      hasUnsavedInput: page == ReportPage.type ? () => !_draft.isEmpty : null,
      actions: _actions(),
      intentHandlers: {
        if (page != ReportPage.type) NavIntent.back: _back,
        if (page == ReportPage.description) NavIntent.listen: _speakDescription,
        if (page == ReportPage.email) NavIntent.listen: _speakEmail,
      },
    );
  }

  // ── Layout ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final focused = ref.watch(focusControllerProvider);
    final bus = ref.read(commandBusProvider);
    final theme = Theme.of(context).textTheme;

    Widget pill(String part, String label, {bool primary = false}) => Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.buttonGap),
      child: PillButton(
        label: label,
        variant: primary ? PillVariant.primary : PillVariant.secondary,
        focused: focused == _id(part),
        onPressed: _busy ? null : () => bus.activate(_id(part)),
      ),
    );
    Widget cancelLink() => SmallLink(
      label: l10n.actionCancelReport,
      icon: Icons.close,
      focused: focused == _id('cancel'),
      onPressed: () => bus.activate(_id('cancel')),
    );
    Widget progress() => Text(
      _progress(l10n),
      textAlign: TextAlign.center,
      style: theme.bodyMedium,
    );
    Widget note(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, textAlign: TextAlign.center, style: theme.bodySmall),
    );

    final Widget child;
    var fill = true;
    switch (_page) {
      case ReportPage.type ||
          ReportPage.module ||
          ReportPage.severity ||
          ReportPage.edit:
        final actions = _actions().where((a) => a.id != _id('cancel'));
        child = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_page != ReportPage.edit) progress(),
            const SizedBox(height: 8),
            Expanded(
              child: BoxedList(
                items: [
                  for (final a in actions) BoxedListItem(a.id, a.label(l10n)),
                ],
                focused: focused,
                onTap: bus.activate,
              ),
            ),
            const SizedBox(height: 8),
            cancelLink(),
          ],
        );
      case ReportPage.description:
        fill = false;
        child = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            progress(),
            const SizedBox(height: 8),
            TextField(
              controller: _description,
              minLines: 3,
              maxLines: 5,
              maxLength: IssueRules.maxDescription,
              textCapitalization: TextCapitalization.sentences,
              style: theme.bodyLarge,
              decoration: InputDecoration(
                labelText: l10n.fieldDescription,
                hintText: l10n.reportDescriptionHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            pill('speak', l10n.actionSpeak),
            pill('next', l10n.actionNext, primary: true),
            cancelLink(),
          ],
        );
      case ReportPage.email:
        fill = false;
        child = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            progress(),
            const SizedBox(height: 8),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              style: theme.bodyLarge,
              decoration: InputDecoration(
                labelText: l10n.fieldEmail,
                border: const OutlineInputBorder(),
              ),
            ),
            note('${l10n.reportEmailWhy} ${l10n.reportPrivacy}'),
            pill('next', l10n.actionNext, primary: true),
            pill('speak', l10n.actionSpeak),
            if (_accountEmail == null) pill('skip', l10n.actionSkip),
            cancelLink(),
          ],
        );
      case ReportPage.review:
        final lines = _reviewLines(l10n);
        child = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: BoxedList(
                items: [
                  for (final (i, line) in lines.indexed)
                    BoxedListItem(_id('line$i'), line.$2),
                ],
                focused: focused,
                onTap: bus.activate,
              ),
            ),
            note('${_detailsLine(l10n, DateTime.now())} ${l10n.reportPrivacy}'),
            pill('send', l10n.actionSendReport, primary: true),
            pill('edit', l10n.actionEditReport),
          ],
        );
      case ReportPage.ticket:
        child = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Semantics(
                container: true,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final line in _ticketLines(l10n))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(line, style: theme.bodyLarge),
                        ),
                      if (_saved?.status != IssueSyncStatus.sent)
                        note(l10n.reportSavedOffline),
                    ],
                  ),
                ),
              ),
            ),
            pill('repeat', l10n.actionRepeatTicket),
            pill('done', l10n.actionDone, primary: true),
          ],
        );
    }

    return AccessibleScreen(
      registration: _registration,
      dependencies: [_page, _draft, _saved, _busy, _details],
      child: FormScaffold(
        screenId: _screenId,
        title: _page == ReportPage.ticket
            ? l10n.reportTicketTitle
            : l10n.screenReportIssue,
        subtitle: _question(l10n),
        padHint: _page == ReportPage.description || _page == ReportPage.email
            ? l10n.helpReportText
            : l10n.helpReport,
        fill: fill,
        child: child,
      ),
    );
  }
}
