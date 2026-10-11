import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ids.dart';
import '../../app/locale_provider.dart';
import '../../app/router.dart';
import '../../app/theme/app_palette.dart';
import '../../config/constants.dart';
import '../../core/accessibility/accessible_screen.dart';
import '../../core/accessibility/action_registry.dart';
import '../../core/accessibility/announcer.dart';
import '../../core/accessibility/command_bus.dart';
import '../../core/accessibility/focus_controller.dart';
import '../../core/accessibility/haptics.dart';
import '../../core/accessibility/nav_intent.dart';
import '../../core/accessibility/screen_registration.dart';
import '../../core/auth/session.dart';
import '../../core/db/daos/library_dao.dart';
import '../../core/db/daos/preferences_dao.dart';
import '../../core/gestures/gesture_surface.dart';
import '../../core/library/library_models.dart';
import '../../core/library/library_view.dart';
import '../../core/tts/speech_language.dart';
import '../../core/voice/command_matcher.dart';
import '../../core/voice/voice_controller.dart';
import '../../core/widgets/gesture_pad_layout.dart';
import '../../l10n/app_localizations.dart';
import 'library_actions.dart';
import 'library_controller.dart';

/// The Library (Aklatan): the user's documents and the admin books on
/// shelves, like Apple Books.
///
/// Swipe right/left moves between the items of a shelf, swipe up/down
/// between shelves, double-tap opens an item's details. Each item is
/// announced in one short line. Voice: "ituloy ang …" resumes, "buksan ang …"
/// opens the details, "hanapin …" searches, "gumawa ng koleksyon …" makes a
/// collection.
class LibraryScreen extends ConsumerStatefulWidget {
  /// Creates the Library.
  const LibraryScreen({super.key});

  /// Screen id.
  static const String screenId = Ids.library;

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  int _shelf = 0;
  int _index = -1;

  /// Collection whose options are showing (swipe up on a collection tile).
  LibraryCollection? _optionsFor;

  final TextEditingController _search = TextEditingController();
  final Map<String, GlobalKey> _keys = {};

  @override
  void initState() {
    super.initState();
    unawaited(_start());
    ref.listenManual(activeScreenProvider, (previous, next) {
      // Back from the details or the Reader: progress and shelves may differ.
      if (next?.id == Ids.library && previous?.id != Ids.library) {
        unawaited(_controller.reload());
      }
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  AppLocalizations get _l => ref.read(speechLanguageProvider).strings;
  CommandBus get _bus => ref.read(commandBusProvider);
  LibraryController get _controller =>
      ref.read(libraryControllerProvider.notifier);
  LibraryState get _state => ref.read(libraryControllerProvider);
  LibraryActions get _actions => ref.read(libraryActionsProvider);

  Future<void> _start() async {
    await _controller.load();
    if (!mounted) return;
    // The catalog is fetched in the background; the shelves are usable now.
    unawaited(_refreshCatalog());
  }

  Future<void> _refreshCatalog() async {
    final diff = await _controller.refreshCatalog();
    if (!mounted || diff == null) return;
    final l = _l;
    // After the screen's own announcement, queued behind it.
    final announcer = ref.read(announcerProvider.notifier);
    await announcer.idle();
    if (!mounted || ref.read(activeScreenProvider)?.id != Ids.library) return;
    if (diff.added.isNotEmpty) {
      await announcer.say(l.libraryNewBooks, interrupt: false);
    }
    for (final title in diff.removed) {
      await announcer.say(l.bookRemovedNotice(title), interrupt: false);
    }
    if (diff.updated.isNotEmpty) {
      final item = _state.items
          .where((i) => i.isBook && i.updateAvailable)
          .firstOrNull;
      if (item != null && mounted) await _actions.offerUpdate(item);
    }
    await _guestFollowUp();
  }

  /// A guest who was warned at the first download hears the reminder once
  /// more here (never while reading), and then never again.
  Future<void> _guestFollowUp() async {
    final account = ref.read(currentAccountProvider);
    if (account == null || !account.isGuest || !mounted) return;
    final prefs = ref.read(userPrefsProvider);
    final count = await prefs.get(
      PrefKeys.guestReminderDownload,
      userId: account.id,
    );
    if (count != 1 || !mounted) return;
    await prefs.set(PrefKeys.guestReminderDownload, 2, userId: account.id);
    unawaited(
      _bus.offer(
        '${_l.guestDownloadWarning} ${_l.guestDocumentsStayHere}',
        () => unawaited(ref.read(routerProvider).push(AppRoutes.register)),
      ),
    );
  }

  // ── Wording ───────────────────────────────────────────────────────────────

  String _typeOf(LibraryItem i, AppLocalizations l) {
    if (i.isBook) {
      return i.format == LibraryFormat.epub ? l.formatEpub : l.sourcePdf;
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

  /// "Florante at Laura, ni Francisco Balagtas, 45 porsiyento, huling binasa
  /// kahapon."
  String _line(LibraryItem i, AppLocalizations l) {
    final head = i.isBook && (i.author ?? '').isNotEmpty
        ? l.libraryItemTitleAuthor(i.title, i.author!)
        : l.libraryItemTitleType(i.title, _typeOf(i, l));
    final parts = <String>[
      head,
      if (i.finished)
        l.libraryFinishedWord
      else if (i.inProgress)
        l.libraryPercent(math.max(1, i.percent.floor()))
      else
        l.libraryNotStartedWord,
      if (i.lastOpenedAt != null)
        l.libraryLastRead(LibraryActions.whenLabel(i.lastOpenedAt!, l)),
      if (i.downloaded) l.libraryDownloadedWord,
      if (i.unavailable) l.libraryUnavailableWord,
    ];
    final line = '${parts.where((p) => p.isNotEmpty).join(', ')}.';
    return i.isNew ? '${l.libraryNewLabel}. $line' : line;
  }

  String _shelfTitle(Shelf s, AppLocalizations l) => switch (s.kind) {
    ShelfKind.controls => l.shelfControls,
    ShelfKind.continueReading => l.shelfContinue,
    ShelfKind.documents => l.shelfDocuments,
    ShelfKind.collections => l.shelfCollections,
    ShelfKind.books => s.title ?? l.shelfBooks,
    ShelfKind.results => s.title ?? l.shelfResults,
  };

  String _emptyMessage(Shelf s, AppLocalizations l) => switch (s.kind) {
    ShelfKind.continueReading => l.emptyContinue,
    ShelfKind.documents => l.emptyDocuments,
    ShelfKind.collections => l.emptyCollections,
    ShelfKind.books => l.emptyBooks,
    ShelfKind.results =>
      _state.filter.kind == LibraryFilterKind.collection && _state.query.isEmpty
          ? l.emptyCollection
          : l.emptyResults,
    ShelfKind.controls => '',
  };

  String _filterName(LibraryFilter f, AppLocalizations l) => switch (f.kind) {
    LibraryFilterKind.all => l.filterAll,
    LibraryFilterKind.documents => l.filterDocuments,
    LibraryFilterKind.books => l.filterBooks,
    LibraryFilterKind.downloaded => l.filterDownloaded,
    LibraryFilterKind.finished => l.filterFinished,
    LibraryFilterKind.favorites => l.filterFavorites,
    LibraryFilterKind.collection => f.collection?.name ?? '',
  };

  // ── Ids ───────────────────────────────────────────────────────────────────

  static const String _search_ = 'library.search';
  static const String _filter_ = 'library.filter';
  static const String _newCollection_ = 'library.newCollection';

  String _itemId(int shelf, LibraryItem i) => 'library.$shelf.${i.id}';
  String _collectionId(LibraryCollection c) => 'library.collection.${c.id}';

  String? _idAt(List<Shelf> shelves, int shelf, int index) {
    if (shelf < 0 || shelf >= shelves.length) return null;
    final s = shelves[shelf];
    if (index < 0 || index >= s.length) return null;
    return switch (s.kind) {
      ShelfKind.controls => const [_search_, _filter_, _newCollection_][index],
      ShelfKind.collections => _collectionId(s.collections[index]),
      _ => _itemId(shelf, s.items[index]),
    };
  }

  String _lineAt(List<Shelf> shelves, int shelf, int index) {
    final l = _l;
    final s = shelves[shelf];
    switch (s.kind) {
      case ShelfKind.controls:
        return switch (index) {
          0 => l.libSearch,
          1 => '${l.libFilter}: ${_filterName(_state.filter, l)}',
          _ => l.libNewCollection,
        };
      case ShelfKind.collections:
        final c = s.collections[index];
        return l.libraryCollectionLine(c.name, c.itemCount);
      default:
        return _line(s.items[index], l);
    }
  }

  // ── Movement ──────────────────────────────────────────────────────────────

  void _focus(List<Shelf> shelves) {
    final id = _idAt(shelves, _shelf, _index);
    ref.read(focusControllerProvider.notifier).focus(id);
    if (id != null) _scrollTo(id);
  }

  void _scrollTo(String id) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[id]?.currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 200),
        );
      }
    });
  }

  Future<void> _moveItem(int delta) async {
    final shelves = _state.shelves;
    if (shelves.isEmpty) return;
    _shelf = _shelf.clamp(0, shelves.length - 1);
    final s = shelves[_shelf];
    if (s.length == 0) return _bus.say(_emptyMessage(s, _l));
    final next = _index + delta;
    if (next < 0 || next >= s.length) {
      unawaited(ref.read(hapticsProvider).error());
      return _bus.say(_l.libraryEdgeSide);
    }
    _index = next;
    setState(() {});
    _focus(shelves);
    unawaited(ref.read(hapticsProvider).tick());
    await _bus.say(_lineAt(shelves, _shelf, _index));
  }

  Future<void> _moveShelf(int delta) async {
    final shelves = _state.shelves;
    final next = _shelf + delta;
    if (next < 0 || next >= shelves.length) {
      unawaited(ref.read(hapticsProvider).error());
      return _bus.say(delta < 0 ? _l.libraryEdgeTop : _l.libraryEdgeBottom);
    }
    _shelf = next;
    final s = shelves[next];
    _index = s.length > 0 ? 0 : -1;
    setState(() {});
    _focus(shelves);
    unawaited(ref.read(hapticsProvider).tick());
    final l = _l;
    final head = l.shelfAnnounce(_shelfTitle(s, l), s.length);
    if (s.kind == ShelfKind.controls) {
      return _bus.say('$head. ${_lineAt(shelves, next, 0)}');
    }
    await _bus.say(
      s.length == 0
          ? '${_shelfTitle(s, l)}. ${_emptyMessage(s, l)}'
          : '$head. ${_lineAt(shelves, next, 0)}',
    );
  }

  Future<void> _options(CommandBus bus) async {
    final id = ref.read(focusControllerProvider);
    final collection = _state.collections
        .where((c) => _collectionId(c) == id)
        .firstOrNull;
    if (collection == null) return bus.notAvailable();
    setState(() => _optionsFor = collection);
    await bus.say(_l.collectionOptions(collection.name));
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _openDetails(LibraryItem item) async {
    // Not awaited: the Library reloads when it becomes active again.
    unawaited(
      ref.read(routerProvider).push(AppRoutes.libraryItem, extra: item.id),
    );
  }

  Future<void> _applyFilter(LibraryFilter filter, {bool speak = true}) async {
    await _controller.setFilter(filter);
    _search.clear();
    if (!mounted) return;
    _shelf = 0;
    _index = -1;
    setState(() => _optionsFor = null);
    if (speak) {
      final l = _l;
      await _bus.say(
        filter.kind == LibraryFilterKind.collection
            ? l.collectionOpened(
                filter.collection!.name,
                _state.visibleItems.length,
              )
            : l.filterChanged(
                _filterName(filter, l),
                _state.visibleItems.length,
              ),
      );
    }
  }

  Future<void> _cycleFilter(CommandBus bus) async {
    final cycle = _controller.cycle;
    final i = cycle.indexOf(_state.filter);
    await _applyFilter(cycle[(i + 1) % cycle.length]);
  }

  Future<void> _applySearch(String query) async {
    _controller.setQuery(query);
    _search.text = query.trim();
    _shelf = 0;
    _index = -1;
    setState(() {});
    final l = _l;
    final n = _state.visibleItems.length;
    if (query.trim().isEmpty) return _bus.say(l.historyShowAll);
    await _bus.say(
      n == 0
          ? l.historyNoResults(query.trim())
          : l.historyResults(n, query.trim()),
    );
    if (n > 0) {
      await _moveShelf(1);
    }
  }

  Future<void> _dictateSearch(CommandBus bus) async {
    await ref
        .read(announcerProvider.notifier)
        .say(_l.librarySearchPrompt, protect: true);
    final said = await ref.read(voiceControllerProvider.notifier).dictate();
    if (!mounted) return;
    if (said == null || said.trim().isEmpty) {
      return bus.say(_l.voiceNothingHeard);
    }
    await _applySearch(said);
  }

  Future<void> _newCollection(CommandBus bus, [String? name]) async {
    var title = name?.trim();
    if (title == null || title.isEmpty) {
      await ref
          .read(announcerProvider.notifier)
          .say(_l.collectionNamePrompt, protect: true);
      title = (await ref.read(voiceControllerProvider.notifier).dictate())
          ?.trim();
      if (!mounted) return;
    }
    if (title == null || title.isEmpty) return bus.say(_l.voiceNothingHeard);
    final c = await _controller.createCollection(title);
    unawaited(ref.read(hapticsProvider).confirm());
    if (mounted) await _bus.say(_l.collectionCreated(c.name));
  }

  Future<void> _renameCollection(LibraryCollection c, CommandBus bus) async {
    await ref
        .read(announcerProvider.notifier)
        .say(_l.collectionNamePrompt, protect: true);
    final said = await ref.read(voiceControllerProvider.notifier).dictate();
    if (!mounted) return;
    final name = said?.trim();
    if (name == null || name.isEmpty) return bus.say(_l.voiceNothingHeard);
    await _controller.renameCollection(c, name);
    if (!mounted) return;
    setState(() => _optionsFor = null);
    ref.read(focusControllerProvider.notifier).focus(_collectionId(c));
    await _bus.say(_l.collectionRenamed(name));
  }

  Future<void> _deleteCollection(LibraryCollection c, CommandBus bus) =>
      bus.offer(_l.collectionDeleteConfirm(c.name), () async {
        await _controller.deleteCollection(c);
        unawaited(ref.read(hapticsProvider).confirm());
        if (!mounted) return;
        setState(() => _optionsFor = null);
        await _bus.say(_l.collectionDeleted(c.name));
      });

  // ── Voice ─────────────────────────────────────────────────────────────────

  static const List<List<String>> _resumeWords = [
    ['ituloy', 'ang'],
    ['ituloy'],
    ['continue'],
    ['resume'],
  ];
  static const List<List<String>> _openWords = [
    ['buksan', 'ang'],
    ['buksan'],
    ['open'],
  ];
  static const List<List<String>> _searchWords = [
    ['hanapin', 'ang'],
    ['hanapin'],
    ['maghanap', 'ng'],
    ['search'],
    ['find'],
  ];
  static const List<List<String>> _createWords = [
    ['gumawa', 'ng', 'koleksyon', 'na'],
    ['gumawa', 'ng', 'koleksyon'],
    ['create', 'a', 'collection'],
    ['create', 'collection'],
    ['new', 'collection'],
  ];
  static const List<List<String>> _addWords = [
    ['idagdag', 'sa'],
    ['add', 'to'],
  ];
  static const List<List<String>> _filterWords = [
    ['salain'],
    ['filter'],
    ['ipakita', 'ang'],
    ['show'],
  ];
  static const List<String> _showAll = ['ipakita lahat', 'show all'];

  /// The words after the first matching prefix of [text], or null.
  static String? _after(String text, List<List<String>> prefixes) {
    final words = CommandMatcher.tokens(text);
    final raw = text.trim().split(RegExp(r'\s+'));
    for (final prefix in prefixes) {
      if (words.length < prefix.length) continue;
      var match = true;
      for (var i = 0; i < prefix.length; i++) {
        if (words[i] != prefix[i]) {
          match = false;
          break;
        }
      }
      if (match && raw.length >= prefix.length) {
        return raw.skip(prefix.length).join(' ').trim();
      }
    }
    return null;
  }

  Future<bool> _onUtterance(String text, CommandBus bus) async {
    final said = CommandMatcher.normalize(text);
    if (_showAll.any((w) => CommandMatcher.normalize(w) == said)) {
      await _applyFilter(LibraryFilter.all, speak: false);
      await _applySearch('');
      return true;
    }
    final create = _after(text, _createWords);
    if (create != null) {
      await _newCollection(bus, create);
      return true;
    }
    final search = _after(text, _searchWords);
    if (search != null && search.isNotEmpty) {
      await _applySearch(search);
      return true;
    }
    final resume = _after(text, _resumeWords);
    if (resume != null && resume.isNotEmpty) {
      return _byTitle(resume, bus, (item) async {
        await bus.say(_l.libraryOpening(item.title));
        await _actions.open(item);
      });
    }
    final open = _after(text, _openWords);
    if (open != null && open.isNotEmpty) {
      return _byTitle(open, bus, _openDetails);
    }
    final add = _after(text, _addWords);
    if (add != null && add.isNotEmpty) {
      return _addToCollection(add, bus);
    }
    final filter = _after(text, _filterWords);
    final wanted = filter != null && filter.isNotEmpty ? filter : text;
    final f = _filterNamed(wanted);
    if (f != null) {
      await _applyFilter(f);
      return true;
    }
    return false;
  }

  /// How this screen's free-text voice commands begin, and the filter names
  /// it reads (a collection may be called "Susunod"): a partial result that
  /// is only one of these waits for the final result.
  List<String> get _freeTextPrefixes {
    final en = lookupAppLocalizations(AppLocales.english);
    final fil = lookupAppLocalizations(AppLocales.filipino);
    return [
      for (final list in [
        _resumeWords,
        _openWords,
        _searchWords,
        _createWords,
        _addWords,
        _filterWords,
      ])
        for (final words in list) words.join(' '),
      ..._showAll,
      'magdagdag ng bagong aklat',
      'simulate new book',
      for (final f in _controller.cycle) ...[
        _filterName(f, fil),
        _filterName(f, en),
      ],
    ];
  }

  LibraryFilter? _filterNamed(String name) {
    final l = _l;
    final wanted = CommandMatcher.normalize(name);
    if (wanted.isEmpty) return null;
    for (final f in _controller.cycle) {
      if (CommandMatcher.normalize(_filterName(f, l)) == wanted) return f;
    }
    // Spoken in the other language too.
    final other = _l.localeName == 'fil'
        ? lookupAppLocalizations(AppLocales.english)
        : lookupAppLocalizations(AppLocales.filipino);
    for (final f in _controller.cycle) {
      if (f.kind == LibraryFilterKind.collection) continue;
      if (CommandMatcher.normalize(_filterName(f, other)) == wanted) return f;
    }
    return null;
  }

  Future<bool> _byTitle(
    String title,
    CommandBus bus,
    Future<void> Function(LibraryItem item) then,
  ) async {
    final item = LibraryView.findByTitle(_state.items, title);
    if (item == null) {
      // Maybe a collection: "buksan ang koleksyon X" / just its name.
      final c = _state.collections
          .where(
            (c) =>
                CommandMatcher.normalize(c.name) ==
                CommandMatcher.normalize(title),
          )
          .firstOrNull;
      if (c != null) {
        await _applyFilter(
          LibraryFilter(LibraryFilterKind.collection, collection: c),
        );
        return true;
      }
      unawaited(ref.read(hapticsProvider).error());
      await bus.say(_l.libraryNotFound(title));
      return true;
    }
    await then(item);
    return true;
  }

  Future<bool> _addToCollection(String name, CommandBus bus) async {
    final id = ref.read(focusControllerProvider);
    final shelves = _state.shelves;
    LibraryItem? item;
    if (id != null && _shelf < shelves.length && _index >= 0) {
      final s = shelves[_shelf];
      if (s.kind != ShelfKind.collections && s.kind != ShelfKind.controls) {
        item = s.items.elementAtOrNull(_index);
      }
    }
    if (item == null) {
      await bus.say(_l.nothingFocused);
      return true;
    }
    final wanted = CommandMatcher.normalize(name);
    final c = _state.collections
        .where((c) => CommandMatcher.normalize(c.name) == wanted)
        .firstOrNull;
    if (c == null) {
      await bus.say(_l.libraryNotFound(name));
      return true;
    }
    await ref.read(libraryDaoProvider).addToCollection(c.id, item.id);
    await _controller.reload();
    unawaited(ref.read(hapticsProvider).confirm());
    if (mounted) await bus.say(_l.collectionAdded(item.title, c.name));
    return true;
  }

  // ── Registration ──────────────────────────────────────────────────────────

  ScreenRegistration _registration(WidgetRef ref) {
    final state = _state;
    final shelves = state.shelves;
    final options = _optionsFor;
    return ScreenRegistration(
      id: LibraryScreen.screenId,
      title: (l) => l.screenLibrary,
      prompt: (l) => l.libraryPrompt,
      listOptions: false,
      includeModeHint: false,
      help: (l) => l.helpLibrary,
      onUtterance: _onUtterance,
      freeTextPrefixes: _freeTextPrefixes,
      actions: options != null
          ? [
              A11yAction(
                id: 'library.collection.open',
                label: (l) => l.optOpen,
                voiceSynonyms: const ['buksan', 'open'],
                onActivate: (_) => _applyFilter(
                  LibraryFilter(
                    LibraryFilterKind.collection,
                    collection: options,
                  ),
                ),
              ),
              A11yAction(
                id: 'library.collection.rename',
                label: (l) => l.optRename,
                voiceSynonyms: const ['palitan', 'rename', 'pangalan'],
                confirmation: (_) => '',
                onActivate: (bus) => _renameCollection(options, bus),
              ),
              A11yAction(
                id: 'library.collection.delete',
                label: (l) => l.optDelete,
                voiceSynonyms: const ['burahin', 'delete', 'tanggalin'],
                confirmation: (_) => '',
                onActivate: (bus) => _deleteCollection(options, bus),
              ),
            ]
          : [
              A11yAction(
                id: _search_,
                label: (l) => l.libSearch,
                voiceSynonyms: const ['hanapin', 'search'],
                confirmation: (_) => '',
                onActivate: _dictateSearch,
              ),
              A11yAction(
                id: _filter_,
                label: (l) => l.libFilter,
                voiceSynonyms: const ['salain', 'filter'],
                confirmation: (_) => '',
                onActivate: _cycleFilter,
              ),
              A11yAction(
                id: _newCollection_,
                label: (l) => l.libNewCollection,
                voiceSynonyms: const ['gumawa ng koleksyon', 'new collection'],
                confirmation: (_) => '',
                onActivate: (bus) => _newCollection(bus),
              ),
              for (var s = 0; s < shelves.length; s++)
                if (shelves[s].kind == ShelfKind.collections)
                  for (final c in shelves[s].collections)
                    A11yAction(
                      id: _collectionId(c),
                      label: (l) =>
                          l.libraryCollectionLine(c.name, c.itemCount),
                      voiceSynonyms: [c.name],
                      confirmation: (_) => c.name,
                      onActivate: (_) => _applyFilter(
                        LibraryFilter(
                          LibraryFilterKind.collection,
                          collection: c,
                        ),
                      ),
                    )
                else if (shelves[s].kind != ShelfKind.controls)
                  for (final item in shelves[s].items)
                    A11yAction(
                      id: _itemId(s, item),
                      label: (l) => _line(item, l),
                      confirmation: (_) => item.title,
                      onActivate: (_) => _openDetails(item),
                    ),
            ],
      intentHandlers: {
        // While a collection's options show, the usual focus movement applies.
        if (options == null) ...{
          NavIntent.next: (bus) => _moveItem(1),
          NavIntent.previous: (bus) => _moveItem(-1),
        },
        NavIntent.faster: options == null
            ? (bus) async {
                // Swipe up: the shelf above, or the options of a collection.
                final id = ref.read(focusControllerProvider);
                if (id != null && id.startsWith('library.collection.')) {
                  return _options(bus);
                }
                return _moveShelf(-1);
              }
            : (bus) => bus.notAvailable(),
        NavIntent.slower: (bus) =>
            options == null ? _moveShelf(1) : bus.notAvailable(),
        if (options != null)
          NavIntent.back: (bus) async {
            ref
                .read(focusControllerProvider.notifier)
                .focus(_collectionId(options));
            setState(() => _optionsFor = null);
            await bus.say(_l.libraryPrompt);
          },
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  GlobalKey _key(String id) => _keys.putIfAbsent(id, GlobalKey.new);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(libraryControllerProvider);
    final focused = ref.watch(focusControllerProvider);
    final p = context.palette;
    final textTheme = Theme.of(context).textTheme;

    // Register only once the lists are known, so the announcement is right.
    if (!state.loaded) return const Scaffold();

    final shelves = state.shelves;
    return AccessibleScreen(
      registration: _registration,
      dependencies: [
        _optionsFor?.id,
        state.filter.kind,
        state.filter.collection?.id,
        state.query,
        for (final s in shelves)
          for (final i in s.items)
            '${i.id}:${i.title}:${i.percent}:${i.finished}:${i.isNew}:${i.downloaded}',
        for (final c in state.collections) '${c.id}:${c.name}:${c.itemCount}',
      ],
      child: GesturePadLayout(
        padHint: l10n.helpLibrary,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(l10n.screenLibrary, style: textTheme.titleLarge),
            ),
            const SizedBox(height: 8),
            _Controls(
              search: _search,
              focused: focused,
              filterLabel: _filterName(state.filter, l10n),
              filters: [
                for (final f in _controller.cycle) (f, _filterName(f, l10n)),
              ],
              active: state.filter,
              keyFor: _key,
              onSearch: _applySearch,
              onFilter: _applyFilter,
              onNewCollection: () => _bus.activate(_newCollection_),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: shelves.length - 1,
                itemBuilder: (context, i) {
                  final shelfIndex = i + 1; // 0 = the controls above
                  final s = shelves[shelfIndex];
                  return _ShelfRow(
                    title: _shelfTitle(s, l10n),
                    shelf: s,
                    empty: _emptyMessage(s, l10n),
                    focused: focused,
                    idOf: (item) => _itemId(shelfIndex, item),
                    collectionId: _collectionId,
                    keyFor: _key,
                    line: (item) => _line(item, l10n),
                    collectionLine: (c) =>
                        l10n.libraryCollectionLine(c.name, c.itemCount),
                    onItem: _openDetails,
                    onCollection: (c) => _bus.activate(_collectionId(c)),
                    typeOf: (item) => _typeOf(item, l10n),
                    newLabel: l10n.libraryNewLabel,
                    palette: p,
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

class _Controls extends StatelessWidget {
  const _Controls({
    required this.search,
    required this.focused,
    required this.filterLabel,
    required this.filters,
    required this.active,
    required this.keyFor,
    required this.onSearch,
    required this.onFilter,
    required this.onNewCollection,
  });

  final TextEditingController search;
  final String? focused;
  final String filterLabel;
  final List<(LibraryFilter, String)> filters;
  final LibraryFilter active;
  final GlobalKey Function(String id) keyFor;
  final void Function(String query) onSearch;
  final void Function(LibraryFilter filter) onFilter;
  final VoidCallback onNewCollection;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.palette;
    BoxDecoration ring(bool on) => BoxDecoration(
      borderRadius: const BorderRadius.all(
        Radius.circular(AppDimens.panelRadius),
      ),
      border: Border.all(
        color: on ? p.focusRing : Colors.transparent,
        width: 3,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: DecoratedBox(
                key: keyFor('library.search'),
                decoration: ring(focused == 'library.search'),
                child: TextField(
                  controller: search,
                  decoration: InputDecoration(
                    hintText: l10n.libSearch,
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: onSearch,
                ),
              ),
            ),
            const SizedBox(width: 8),
            DecoratedBox(
              key: keyFor('library.newCollection'),
              decoration: ring(focused == 'library.newCollection'),
              child: Semantics(
                button: true,
                label: l10n.libNewCollection,
                excludeSemantics: true,
                onTap: onNewCollection,
                child: Listener(
                  onPointerDown: (e) =>
                      GestureSurface.claimPointer(context, e.pointer),
                  child: IconButton(
                    constraints: const BoxConstraints(
                      minWidth: AppDimens.minTouchTarget,
                      minHeight: AppDimens.minTouchTarget,
                    ),
                    icon: const Icon(Icons.create_new_folder_outlined),
                    onPressed: onNewCollection,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          key: keyFor('library.filter'),
          decoration: ring(focused == 'library.filter'),
          child: SizedBox(
            height: AppDimens.minTouchTarget,
            child: Listener(
              onPointerDown: (e) =>
                  GestureSurface.claimPointer(context, e.pointer),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (f, name) in filters)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Semantics(
                          button: true,
                          selected: f == active,
                          label: name,
                          excludeSemantics: true,
                          onTap: () => onFilter(f),
                          child: ChoiceChip(
                            label: Text(name),
                            selected: f == active,
                            onSelected: (_) => onFilter(f),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ShelfRow extends StatelessWidget {
  const _ShelfRow({
    required this.title,
    required this.shelf,
    required this.empty,
    required this.focused,
    required this.idOf,
    required this.collectionId,
    required this.keyFor,
    required this.line,
    required this.collectionLine,
    required this.onItem,
    required this.onCollection,
    required this.typeOf,
    required this.newLabel,
    required this.palette,
  });

  final String title;
  final Shelf shelf;
  final String empty;
  final String? focused;
  final String Function(LibraryItem item) idOf;
  final String Function(LibraryCollection c) collectionId;
  final GlobalKey Function(String id) keyFor;
  final String Function(LibraryItem item) line;
  final String Function(LibraryCollection c) collectionLine;
  final void Function(LibraryItem item) onItem;
  final void Function(LibraryCollection c) onCollection;
  final String Function(LibraryItem item) typeOf;
  final String newLabel;
  final AppPalette palette;

  static const double tileWidth = 140;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final p = palette;
    final tiles = <Widget>[];
    if (shelf.kind == ShelfKind.collections) {
      for (final c in shelf.collections) {
        final id = collectionId(c);
        tiles.add(
          _TileFrame(
            key: keyFor(id),
            label: collectionLine(c),
            focused: focused == id,
            onTap: () => onCollection(c),
            child: _CollectionTile(collection: c, palette: p),
          ),
        );
      }
    } else {
      for (final item in shelf.items) {
        final id = idOf(item);
        tiles.add(
          _TileFrame(
            key: keyFor(id),
            label: line(item),
            focused: focused == id,
            onTap: () => onItem(item),
            child: _ItemTile(
              item: item,
              type: typeOf(item),
              newLabel: newLabel,
              palette: p,
            ),
          ),
        );
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                title,
                style: textTheme.titleMedium?.copyWith(color: p.heading),
              ),
            ),
          ),
          if (tiles.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(empty, style: textTheme.bodyMedium),
            )
          else
            SizedBox(
              height: 270,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: tiles,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TileFrame extends StatelessWidget {
  const _TileFrame({
    super.key,
    required this.label,
    required this.focused,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool focused;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Semantics(
        button: true,
        focused: focused,
        label: label,
        excludeSemantics: true,
        onTap: onTap,
        child: Listener(
          onPointerDown: (e) => GestureSurface.claimPointer(context, e.pointer),
          child: InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.all(
              Radius.circular(AppDimens.panelRadius),
            ),
            child: Container(
              width: _ShelfRow.tileWidth,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(
                  Radius.circular(AppDimens.panelRadius),
                ),
                border: Border.all(
                  color: focused ? p.focusRing : Colors.transparent,
                  width: 3,
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({
    required this.item,
    required this.type,
    required this.newLabel,
  });

  final LibraryItem item;
  final String type;
  final String newLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final path = item.coverPath;
    Widget cover;
    if (path != null && File(path).existsSync()) {
      cover = Image.file(
        File(path),
        fit: BoxFit.cover,
        cacheWidth: 280,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => _titleTile(p, textTheme),
      );
    } else {
      cover = _titleTile(p, textTheme);
    }
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            cover,
            if (item.isNew)
              Positioned(
                left: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  color: p.highlight,
                  child: Text(
                    newLabel,
                    style: textTheme.labelMedium?.copyWith(
                      color: p.onHighlight,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            if (item.downloaded)
              Positioned(
                right: 4,
                bottom: 4,
                child: Icon(Icons.download_done, color: p.onPrimary, size: 22),
              ),
          ],
        ),
      ),
    );
  }

  /// No picture: the title in large text on a tile in the theme's colors.
  Widget _titleTile(AppPalette p, TextTheme t) => ColoredBox(
    color: p.primary,
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Center(
        child: Text(
          item.title,
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: t.titleMedium?.copyWith(
            color: p.onPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.type,
    required this.newLabel,
    required this.palette,
  });

  final LibraryItem item;
  final String type;
  final String newLabel;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final percent = item.finished ? 100 : item.percent.floor();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: _Cover(item: item, type: type, newLabel: newLabel),
        ),
        const SizedBox(height: 4),
        Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          (item.author ?? '').isNotEmpty ? item.author! : type,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.bodySmall,
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: percent / 100,
                minHeight: 6,
                color: palette.primary,
                backgroundColor: palette.muted.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(width: 6),
            Text('$percent%', style: t.bodySmall),
          ],
        ),
      ],
    );
  }
}

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({required this.collection, required this.palette});

  final LibraryCollection collection;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ColoredBox(
                color: palette.secondary,
                child: Center(
                  child: Icon(
                    Icons.folder_outlined,
                    size: 56,
                    color: palette.onSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          collection.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text('${collection.itemCount}', style: t.bodySmall),
      ],
    );
  }
}
