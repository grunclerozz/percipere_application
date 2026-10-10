import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ids.dart';
import '../../app/router.dart';
import '../../app/theme/app_palette.dart';
import '../../core/accessibility/accessible_screen.dart';
import '../../core/accessibility/action_registry.dart';
import '../../core/accessibility/announcer.dart';
import '../../core/accessibility/command_bus.dart';
import '../../core/accessibility/focus_controller.dart';
import '../../core/accessibility/haptics.dart';
import '../../core/accessibility/nav_intent.dart';
import '../../core/accessibility/screen_registration.dart';
import '../../core/db/daos/library_dao.dart';
import '../../core/describe/image_prep.dart';
import '../../core/library/library_models.dart';
import '../../core/library/library_service.dart';
import '../../core/library/library_view.dart';
import '../../core/tts/reading_rate.dart';
import '../../core/tts/speech_language.dart';
import '../../core/voice/command_matcher.dart';
import '../../core/voice/voice_controller.dart';
import '../../core/widgets/boxed_list.dart';
import '../../core/widgets/gesture_pad_layout.dart';
import '../../l10n/app_localizations.dart';
import 'favorites_screen.dart';
import 'library_actions.dart';

/// Details of one library item, like an Apple Books book page: cover, title,
/// progress, time left, and the actions — Ituloy/Basahin first, so
/// double-tapping twice from the Library resumes reading.
class ItemDetailsScreen extends ConsumerStatefulWidget {
  /// Creates the details of item [itemId].
  const ItemDetailsScreen({super.key, required this.itemId});

  /// Screen id.
  static const String screenId = Ids.libraryItem;

  /// `library_items.id`.
  final String itemId;

  @override
  ConsumerState<ItemDetailsScreen> createState() => _ItemDetailsScreenState();
}

class _ItemDetailsScreenState extends ConsumerState<ItemDetailsScreen> {
  LibraryItem? _item;
  int _favoriteCount = 0;
  List<LibraryCollection> _collections = const [];
  Set<String> _memberOf = const {};
  bool _loaded = false;

  /// Choosing a collection to add the item to.
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    ref.listenManual(activeScreenProvider, (previous, next) {
      final id = ItemDetailsScreen.screenId;
      if (next?.id != id || previous?.id == id) return;
      // Back from the Reader or a list: progress may have changed. The first
      // action (Ituloy/Basahin) is focused, so double-tap resumes reading.
      unawaited(_load());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _picking) return;
        final focus = ref.read(focusControllerProvider.notifier);
        if (ref.read(focusControllerProvider) == null) focus.focus(_idContinue);
      });
    });
  }

  AppLocalizations get _l => ref.read(speechLanguageProvider).strings;
  CommandBus get _bus => ref.read(commandBusProvider);
  LibraryDao get _dao => ref.read(libraryDaoProvider);
  LibraryActions get _actions => ref.read(libraryActionsProvider);

  Future<void> _load() async {
    final item = await _dao.get(widget.itemId);
    if (item != null) {
      unawaited(_dao.clearNew(item.id)); // Viewing the details clears "Bago".
    }
    final favorites = item == null
        ? const <Favorite>[]
        : await _dao.favorites(item.id);
    final collections = await _dao.collections(item?.userId);
    final memberOf = item == null
        ? const <String>{}
        : await _dao.collectionsOf(item.id);
    if (!mounted) return;
    setState(() {
      _item = item;
      _favoriteCount = favorites.length;
      _collections = collections;
      _memberOf = memberOf;
      _loaded = true;
    });
  }

  // ── Wording ───────────────────────────────────────────────────────────────

  String _byline(LibraryItem i, AppLocalizations l) {
    if (i.isBook) {
      final author = i.author ?? '';
      return author.isEmpty
          ? (i.format == LibraryFormat.epub ? l.formatEpub : l.sourcePdf)
          : author;
    }
    return switch (i.source) {
      LibrarySource.camera => l.sourceCamera,
      LibrarySource.description => l.sourceDescription,
      _ => switch (i.format) {
        LibraryFormat.pdf => l.sourcePdf,
        LibraryFormat.docx => l.sourceDocx,
        _ => l.sourceImage,
      },
    };
  }

  String _progress(LibraryItem i, AppLocalizations l) {
    if (i.finished) return l.detailsFinished;
    if (!i.inProgress) return l.detailsNotStarted;
    return l.detailsProgress(i.percent.floor());
  }

  String? _timeLeft(LibraryItem i, AppLocalizations l) {
    final minutes = LibraryView.minutesLeft(i, ref.read(readingRateProvider));
    if (minutes == null) return null;
    if (i.finished) return null;
    return minutes < 1
        ? l.detailsLessThanMinute
        : l.detailsMinutesLeft(minutes);
  }

  String _intro(LibraryItem i, AppLocalizations l) => [
    l.libraryItemTitleType(i.title, _byline(i, l)),
    _progress(i, l),
    ?_timeLeft(i, l),
    if (i.isBook && (i.description ?? '').isNotEmpty) i.description!,
    if (i.isBook && i.unavailable) l.libraryUnavailableWord,
  ].join(' ');

  bool _hasChapters(LibraryItem i) =>
      i.chapters.length > 1 || (i.isBook && i.format == LibraryFormat.epub);

  String _continueLabel(LibraryItem i, AppLocalizations l) =>
      i.inProgress ? l.actContinue : l.actRead;

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _read(LibraryItem item, {bool fromStart = false}) =>
      _actions.open(item, fromStart: fromStart);

  Future<void> _favorites(LibraryItem item) async {
    unawaited(
      ref
          .read(routerProvider)
          .push<Object?>(AppRoutes.favorites, extra: FavoritesArgs(item.id)),
    );
  }

  Future<void> _chapters(LibraryItem item) async {
    var current = item;
    if (current.isBook && current.chapters.isEmpty) {
      // The chapters are only known once the book has been read once.
      final result = await ref
          .read(libraryServiceProvider)
          .prepareToRead(current);
      if (!mounted) return;
      if (result != BookResult.ready) {
        unawaited(ref.read(hapticsProvider).error());
        return _bus.say(
          result == BookResult.offline
              ? _l.libraryNeedsInternet
              : _l.bookFailed,
        );
      }
      current = await _dao.get(item.id) ?? current;
    }
    if (!mounted) return;
    unawaited(
      ref
          .read(routerProvider)
          .push<Object?>(AppRoutes.chapters, extra: current.id),
    );
  }

  Future<void> _addToCollection(LibraryItem item) async {
    if (_collections.isEmpty) {
      return _bus.say(_l.collectionPickNone);
    }
    setState(() => _picking = true);
    await _bus.ask(_l.collectionPickIntro(item.title), split: true);
  }

  Future<void> _toggleMembership(
    LibraryItem item,
    LibraryCollection c,
    CommandBus bus,
  ) async {
    final l = _l;
    if (_memberOf.contains(c.id)) {
      await _dao.removeFromCollection(c.id, item.id);
      await _load();
      await bus.say(l.collectionItemRemoved(item.title, c.name));
    } else {
      await _dao.addToCollection(c.id, item.id);
      await _load();
      await bus.say(l.collectionAdded(item.title, c.name));
    }
    unawaited(ref.read(hapticsProvider).confirm());
  }

  Future<void> _download(LibraryItem item) async {
    await _actions.download(item);
    if (mounted) await _load();
  }

  Future<void> _removeDownload(LibraryItem item) async {
    await _actions.removeDownload(item);
    if (mounted) await _load();
  }

  Future<void> _setFinished(LibraryItem item, bool finished) async {
    await _actions.setFinished(item, finished: finished);
    if (mounted) await _load();
  }

  Future<void> _rename(LibraryItem item, CommandBus bus) async {
    await ref
        .read(announcerProvider.notifier)
        .say(_l.historyRenamePrompt, protect: true);
    final said = await ref.read(voiceControllerProvider.notifier).dictate();
    if (!mounted) return;
    final title = said?.trim();
    if (title == null || title.isEmpty) return bus.say(_l.voiceNothingHeard);
    await _dao.rename(item.id, title);
    await _load();
    await bus.say(_l.historyRenamed(title));
  }

  Future<void> _delete(LibraryItem item, CommandBus bus) =>
      bus.offer(_l.historyDeleteConfirm(item.title), () async {
        await ref.read(libraryServiceProvider).deleteItem(item);
        await deleteThumbnail(item.coverPath);
        unawaited(ref.read(hapticsProvider).confirm());
        await _bus.say(_l.historyDeleted(item.title));
        if (mounted && ref.read(routerProvider).canPop()) {
          ref.read(routerProvider).pop();
        }
      });

  /// "idagdag sa [koleksyon]" while the details are open.
  Future<bool> _onUtterance(String text, CommandBus bus) async {
    final item = _item;
    if (item == null) return false;
    final words = CommandMatcher.tokens(text);
    final prefix = words.length > 2 && words[0] == 'idagdag' && words[1] == 'sa'
        ? 2
        : words.length > 2 && words[0] == 'add' && words[1] == 'to'
        ? 2
        : 0;
    if (prefix == 0) return false;
    final wanted = words.skip(prefix).join(' ');
    // "idagdag sa koleksyon" is the action itself, not a collection's name.
    if (wanted == 'koleksyon' || wanted == 'collection') return false;
    final c = _collections
        .where((c) => CommandMatcher.normalize(c.name) == wanted)
        .firstOrNull;
    if (c == null) {
      await bus.say(
        _l.libraryNotFound(text.trim().split(RegExp(r'\s+')).skip(2).join(' ')),
      );
      return true;
    }
    if (!_memberOf.contains(c.id)) await _toggleMembership(item, c, bus);
    return true;
  }

  // ── Registration ──────────────────────────────────────────────────────────

  static const String _idContinue = 'item.continue';
  static const String _idFromStart = 'item.fromStart';
  static const String _idFavorites = 'item.favorites';
  static const String _idChapters = 'item.chapters';
  static const String _idCollection = 'item.collection';
  static const String _idDownload = 'item.download';
  static const String _idRemoveDownload = 'item.removeDownload';
  static const String _idFinished = 'item.finished';
  static const String _idRename = 'item.rename';
  static const String _idDelete = 'item.delete';

  List<A11yAction> _actionsFor(LibraryItem item) {
    if (_picking) {
      return [
        for (final c in _collections)
          A11yAction(
            id: 'item.pick.${c.id}',
            label: (l) =>
                _memberOf.contains(c.id) ? l.collectionPickIn(c.name) : c.name,
            voiceSynonyms: [c.name],
            confirmation: (_) => c.name,
            onActivate: (bus) => _toggleMembership(item, c, bus),
          ),
      ];
    }
    return [
      A11yAction(
        id: _idContinue,
        label: (l) => _continueLabel(item, l),
        voiceSynonyms: const ['ituloy', 'basahin', 'continue', 'read'],
        onActivate: (_) => _read(item),
      ),
      A11yAction(
        id: _idFromStart,
        label: (l) => l.actFromStart,
        voiceSynonyms: const [
          'mula sa simula',
          'basahin mula sa simula',
          'from the beginning',
          'start over',
        ],
        onActivate: (_) => _read(item, fromStart: true),
      ),
      A11yAction(
        id: _idFavorites,
        label: (l) => l.actFavorites,
        voiceSynonyms: const ['mga paborito', 'paborito', 'favorites'],
        onActivate: (_) => _favorites(item),
      ),
      if (_hasChapters(item))
        A11yAction(
          id: _idChapters,
          label: (l) => l.actChapters,
          voiceSynonyms: const ['mga kabanata', 'kabanata', 'chapters'],
          onActivate: (_) => _chapters(item),
        ),
      A11yAction(
        id: _idCollection,
        label: (l) => l.actAddToCollection,
        voiceSynonyms: const [
          'idagdag sa koleksyon',
          'koleksyon',
          'add to collection',
        ],
        onActivate: (_) => _addToCollection(item),
      ),
      if (item.isBook && !item.downloaded)
        A11yAction(
          id: _idDownload,
          label: (l) => item.fileSize == null
              ? l.actDownload
              : l.actDownloadSized(LibraryActions.sizeLabel(item.fileSize!, l)),
          voiceSynonyms: const ['i-download', 'download', 'idownload'],
          onActivate: (_) => _download(item),
        ),
      if (item.isBook && item.downloaded)
        A11yAction(
          id: _idRemoveDownload,
          label: (l) => l.actRemoveDownload,
          voiceSynonyms: const ['alisin ang download', 'remove download'],
          onActivate: (_) => _removeDownload(item),
        ),
      A11yAction(
        id: _idFinished,
        label: (l) => item.finished ? l.actMarkUnfinished : l.actMarkFinished,
        voiceSynonyms: const [
          'markahan bilang tapos na',
          'tapos na',
          'mark as finished',
          'finished',
        ],
        onActivate: (_) => _setFinished(item, !item.finished),
      ),
      if (!item.isBook) ...[
        A11yAction(
          id: _idRename,
          label: (l) => l.optRename,
          voiceSynonyms: const ['palitan ang pangalan', 'palitan', 'rename'],
          confirmation: (_) => '',
          onActivate: (bus) => _rename(item, bus),
        ),
        A11yAction(
          id: _idDelete,
          label: (l) => l.optDelete,
          voiceSynonyms: const ['burahin', 'delete', 'tanggalin'],
          confirmation: (_) => '',
          onActivate: (bus) => _delete(item, bus),
        ),
      ],
    ];
  }

  ScreenRegistration _registration(WidgetRef ref) {
    final item = _item!;
    return ScreenRegistration(
      id: ItemDetailsScreen.screenId,
      title: (l) => l.screenItemDetails,
      // "Add it to which collection?" — how to choose only if no answer.
      prompt: (l) => _picking
          ? Announcer.splitAtQuestion(l.collectionPickIntro(item.title)).$1
          : _intro(item, l),
      followUp: (l) => _picking
          ? Announcer.splitAtQuestion(l.collectionPickIntro(item.title)).$2 ??
                ''
          : '',
      listOptions: false,
      includeModeHint: false,
      help: (l) => l.helpItemDetails,
      onUtterance: _onUtterance,
      freeTextPrefixes: const ['idagdag sa', 'add to'],
      actions: _actionsFor(item),
      intentHandlers: {
        if (_picking)
          NavIntent.back: (bus) async {
            setState(() => _picking = false);
            await bus.say(_l.screenItemDetails);
          },
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final focused = ref.watch(focusControllerProvider);
    if (!_loaded) return const Scaffold();
    final item = _item;
    if (item == null) {
      // The item was deleted: nothing to show.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ref.read(routerProvider).canPop()) {
          ref.read(routerProvider).pop();
        }
      });
      return const Scaffold();
    }
    final p = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final actions = _actionsFor(item);
    final time = _timeLeft(item, l10n);

    return AccessibleScreen(
      registration: _registration,
      dependencies: [
        _picking,
        item.id,
        item.title,
        item.percent,
        item.finished,
        item.downloaded,
        item.chapters.length,
        _favoriteCount,
        _memberOf.length,
        _collections.length,
      ],
      child: GesturePadLayout(
        padHint: l10n.helpItemDetails,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SmallCover(item: item, palette: p),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleLarge,
                        ),
                        Text(
                          _byline(item, l10n),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _progress(item, l10n),
                          style: textTheme.bodyMedium,
                        ),
                        if (time != null)
                          Text(time, style: textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (item.isBook && (item.description ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                item.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 10),
            Expanded(
              child: BoxedList(
                items: [
                  for (final a in actions) BoxedListItem(a.id, a.label(l10n)),
                ],
                focused: focused,
                onTap: _bus.activate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallCover extends StatelessWidget {
  const _SmallCover({required this.item, required this.palette});

  final LibraryItem item;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final path = item.coverPath;
    final t = Theme.of(context).textTheme;
    return SizedBox(
      width: 84,
      height: 112,
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: path != null && File(path).existsSync()
              ? Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  cacheWidth: 200,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                )
              : ColoredBox(
                  color: palette.primary,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        item.title,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: t.labelLarge?.copyWith(
                          color: palette.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
