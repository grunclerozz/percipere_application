import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/ids.dart';
import '../../app/router.dart';
import '../../app/theme/app_palette.dart';
import '../../config/constants.dart';
import '../../core/accessibility/accessible_screen.dart';
import '../../core/accessibility/announcer.dart';
import '../../core/accessibility/command_bus.dart';
import '../../core/accessibility/focus_controller.dart';
import '../../core/accessibility/haptics.dart';
import '../../core/accessibility/nav_intent.dart';
import '../../core/accessibility/screen_registration.dart';
import '../../core/auth/session.dart';
import '../../core/db/daos/documents_dao.dart';
import '../../core/gestures/gesture_surface.dart';
import '../../core/tts/speech_language.dart';
import '../../core/voice/command_matcher.dart';
import '../../core/voice/voice_controller.dart';
import '../../core/widgets/gesture_pad_layout.dart';
import '../../l10n/app_localizations.dart';
import '../reader/reader_controller.dart';

/// Reading History: saved documents, newest (or most recently reopened)
/// first.
///
/// Swipe right/left moves between documents ("Paunawa sa Barangay, Word,
/// Okt 1, 2026"); double-tap opens one where it was left off. Swipe up opens
/// its options (Buksan, Palitan ang pangalan, Burahin); two-finger swipe
/// down leaves the options. Say "hanapin" and a word to search, "ipakita
/// lahat" to clear it. Renaming is by dictation; deleting asks first.
class HistoryScreen extends ConsumerStatefulWidget {
  /// Creates Reading History.
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  List<DocumentRecord> _docs = const [];
  String _query = '';
  bool _loaded = false;

  /// Document whose options are showing, if any.
  DocumentRecord? _optionsFor;

  final TextEditingController _search = TextEditingController();

  static const List<String> _searchWords = [
    'hanapin',
    'maghanap',
    'search',
    'find',
  ];
  static const List<String> _showAllWords = [
    'ipakita lahat',
    'lahat',
    'show all',
  ];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  DocumentsDao get _dao => ref.read(documentsDaoProvider);
  AppLocalizations get _l => ref.read(speechLanguageProvider).strings;
  CommandBus get _bus => ref.read(commandBusProvider);

  Future<void> _load() async {
    final docs = await _dao.list(
      userId: ref.read(currentAccountProvider)?.id,
      query: _query,
    );
    if (!mounted) return;
    setState(() {
      _docs = docs;
      _loaded = true;
      if (_optionsFor != null && !docs.any((d) => d.id == _optionsFor!.id)) {
        _optionsFor = null;
      }
    });
  }

  static String _docId(DocumentRecord d) => 'history.doc.${d.id}';

  String _source(DocumentRecord d, AppLocalizations l) =>
      switch (d.sourceType) {
        'camera' => l.sourceCamera,
        'pdf' => l.sourcePdf,
        'docx' => l.sourceDocx,
        _ => l.sourceImage,
      };

  String _date(DocumentRecord d, AppLocalizations l) =>
      DateFormat.yMMMd(l.localeName).format(d.lastOpenedAt ?? d.createdAt);

  String _describe(DocumentRecord d, AppLocalizations l) =>
      l.historyItem(d.title, _source(d, l), _date(d, l));

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _open(DocumentRecord d) async {
    setState(() => _optionsFor = null);
    await ref
        .read(routerProvider)
        .push(AppRoutes.reader, extra: HistorySource(d.id));
    // Back from the Reader: titles, order and positions may have changed.
    if (mounted) await _load();
  }

  Future<void> _showOptions(CommandBus bus) async {
    final id = ref.read(focusControllerProvider);
    final doc = _docs.where((d) => _docId(d) == id).firstOrNull;
    if (doc == null) {
      unawaited(ref.read(hapticsProvider).error());
      return bus.say(_l.nothingFocused);
    }
    setState(() => _optionsFor = doc);
    await bus.say(_l.historyOptions(doc.title));
  }

  Future<void> _closeOptions(CommandBus bus) async {
    final doc = _optionsFor;
    setState(() => _optionsFor = null);
    if (doc != null) {
      ref.read(focusControllerProvider.notifier).focus(_docId(doc));
      await bus.say(_describe(doc, _l));
    }
  }

  Future<void> _rename(DocumentRecord d, CommandBus bus) async {
    await ref
        .read(announcerProvider.notifier)
        .say(_l.historyRenamePrompt, protect: true);
    final said = await ref.read(voiceControllerProvider.notifier).dictate();
    if (!mounted) return;
    final title = said?.trim();
    if (title == null || title.isEmpty) {
      return bus.say(_l.voiceNothingHeard);
    }
    await _dao.rename(d.id, title);
    setState(() => _optionsFor = null);
    await _load();
    await bus.say(_l.historyRenamed(title));
  }

  Future<void> _delete(DocumentRecord d, CommandBus bus) =>
      bus.offer(_l.historyDeleteConfirm(d.title), () async {
        await _dao.delete(d.id);
        unawaited(ref.read(hapticsProvider).confirm());
        if (!mounted) return;
        setState(() => _optionsFor = null);
        await _load();
        await _bus.say(_l.historyDeleted(d.title));
      });

  Future<void> _applySearch(String query, CommandBus bus) async {
    _query = query.trim();
    _search.text = _query;
    setState(() => _optionsFor = null);
    await _load();
    if (_query.isEmpty) return bus.say(_l.historyShowAll);
    await bus.say(
      _docs.isEmpty
          ? _l.historyNoResults(_query)
          : '${_l.historyResults(_docs.length, _query)} '
                '${_describe(_docs.first, _l)}',
    );
    if (_docs.isNotEmpty) {
      ref.read(focusControllerProvider.notifier).focus(_docId(_docs.first));
    }
  }

  /// "hanapin resibo" → search; "ipakita lahat" → clear.
  Future<bool> _onUtterance(String text, CommandBus bus) async {
    final words = CommandMatcher.tokens(text);
    if (words.isEmpty) return false;
    if (_showAllWords.any(
      (w) => CommandMatcher.normalize(text) == CommandMatcher.normalize(w),
    )) {
      await _applySearch('', bus);
      return true;
    }
    if (_searchWords.contains(words.first) && words.length > 1) {
      // Keep the user's own words (not normalized) for the query.
      final raw = text.trim().split(RegExp(r'\s+')).skip(1).join(' ');
      await _applySearch(raw, bus);
      return true;
    }
    return false;
  }

  // ── Registration ──────────────────────────────────────────────────────────

  ScreenRegistration _registration(WidgetRef ref) {
    final options = _optionsFor;
    return ScreenRegistration(
      id: Ids.history,
      title: (l) => l.screenHistory,
      prompt: (l) =>
          _docs.isEmpty ? l.historyEmpty : l.historyIntro(_docs.length),
      listOptions: false,
      includeModeHint: false,
      help: (l) => l.helpHistory,
      onUtterance: _onUtterance,
      actions: options != null
          ? [
              A11yAction(
                id: 'history.open',
                label: (l) => l.optOpen,
                voiceSynonyms: const ['buksan', 'open', 'basahin'],
                onActivate: (_) => _open(options),
              ),
              A11yAction(
                id: 'history.rename',
                label: (l) => l.optRename,
                voiceSynonyms: const ['palitan', 'rename', 'pangalan'],
                confirmation: (_) => '',
                onActivate: (bus) => _rename(options, bus),
              ),
              A11yAction(
                id: 'history.delete',
                label: (l) => l.optDelete,
                voiceSynonyms: const ['burahin', 'delete', 'tanggalin'],
                confirmation: (_) => '',
                onActivate: (bus) => _delete(options, bus),
              ),
            ]
          : [
              for (final d in _docs)
                A11yAction(
                  id: _docId(d),
                  label: (l) => _describe(d, l),
                  voiceSynonyms: [d.title],
                  confirmation: (_) => d.title,
                  onActivate: (_) => _open(d),
                ),
            ],
      intentHandlers: {
        NavIntent.faster: options == null
            ? _showOptions
            : (bus) => bus.notAvailable(),
        if (options != null) NavIntent.back: _closeOptions,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final focused = ref.watch(focusControllerProvider);
    final p = context.palette;
    final textTheme = Theme.of(context).textTheme;

    // Register only once the list is known, so the announcement is right.
    if (!_loaded) return const Scaffold();

    return AccessibleScreen(
      registration: _registration,
      dependencies: [
        _optionsFor?.id,
        for (final d in _docs) '${d.id}:${d.title}',
      ],
      child: GesturePadLayout(
        padHint: l10n.helpHistory,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(l10n.screenHistory, style: textTheme.titleLarge),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: l10n.historySearch,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (q) => _applySearch(q, _bus),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: !_loaded
                  ? const SizedBox.shrink()
                  : _docs.isEmpty
                  ? Center(
                      child: Text(
                        _query.isEmpty
                            ? l10n.historyEmpty
                            : l10n.historyNoResults(_query),
                        textAlign: TextAlign.center,
                        style: textTheme.bodyLarge,
                      ),
                    )
                  : ListView.separated(
                      itemCount: _docs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final d = _docs[i];
                        final isFocused =
                            focused == _docId(d) || _optionsFor?.id == d.id;
                        return Semantics(
                          button: true,
                          label: _describe(d, l10n),
                          excludeSemantics: true,
                          onTap: () => _open(d),
                          child: Listener(
                            onPointerDown: (e) =>
                                GestureSurface.claimPointer(context, e.pointer),
                            child: InkWell(
                              onTap: () => _open(d),
                              child: AnimatedContainer(
                                duration: AppDurations.fade,
                                padding: const EdgeInsets.all(14),
                                constraints: const BoxConstraints(
                                  minHeight: AppDimens.minTouchTarget,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(AppDimens.panelRadius),
                                  ),
                                  border: Border.all(
                                    color: isFocused ? p.focusRing : p.border,
                                    width: isFocused ? 3 : 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      d.title,
                                      style: textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: p.heading,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_source(d, l10n)} · ${_date(d, l10n)}',
                                      style: textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
