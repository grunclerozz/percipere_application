import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ids.dart';
import '../../app/router.dart';
import '../../core/accessibility/accessible_screen.dart';
import '../../core/accessibility/action_registry.dart';
import '../../core/accessibility/command_bus.dart';
import '../../core/accessibility/focus_controller.dart';
import '../../core/accessibility/haptics.dart';
import '../../core/accessibility/nav_intent.dart';
import '../../core/accessibility/screen_registration.dart';
import '../../core/db/daos/library_dao.dart';
import '../../core/library/library_models.dart';
import '../../core/tts/speech_language.dart';
import '../../core/widgets/boxed_list.dart';
import '../../core/widgets/gesture_pad_layout.dart';
import '../../l10n/app_localizations.dart';
import '../reader/reader_controller.dart';

/// Opens the favorites list of an item.
@immutable
class FavoritesArgs {
  /// Favorites of [itemId]. With [forReader] the chosen favorite is returned
  /// to the Reader (which jumps there) instead of opening a new Reader.
  const FavoritesArgs(this.itemId, {this.forReader = false});

  /// `library_items.id`.
  final String itemId;

  /// Opened from inside the Reader.
  final bool forReader;
}

/// The favorites of one item, in reading order. Each is read as its chapter
/// and first words ("Kabanata 3: Sa isang madilim na gubat…"). Double-tap or
/// "pumunta dito" jumps there and continues reading; swipe up for the
/// options (Pumunta dito, Burahin).
class FavoritesScreen extends ConsumerStatefulWidget {
  /// Creates the list for [args].
  const FavoritesScreen({super.key, required this.args});

  /// Screen id.
  static const String screenId = Ids.favorites;

  /// What to show.
  final FavoritesArgs args;

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  LibraryItem? _item;
  List<Favorite> _favorites = const [];
  bool _loaded = false;
  Favorite? _optionsFor;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    ref.listenManual(activeScreenProvider, (previous, next) {
      if (next?.id == FavoritesScreen.screenId &&
          previous?.id != FavoritesScreen.screenId) {
        unawaited(_load());
      }
    });
  }

  AppLocalizations get _l => ref.read(speechLanguageProvider).strings;
  LibraryDao get _dao => ref.read(libraryDaoProvider);

  Future<void> _load() async {
    final item = await _dao.get(widget.args.itemId);
    final favorites = item == null
        ? const <Favorite>[]
        : await _dao.favorites(item.id);
    if (!mounted) return;
    setState(() {
      _item = item;
      _favorites = favorites;
      _loaded = true;
      if (_optionsFor != null &&
          !favorites.any((f) => f.id == _optionsFor!.id)) {
        _optionsFor = null;
      }
    });
  }

  String _chapterName(Favorite f, AppLocalizations l) {
    final item = _item;
    if (item != null && f.chapterIndex < item.chapters.length) {
      final title = item.chapters[f.chapterIndex].title;
      if (title.isNotEmpty) return title;
    }
    return l.chapterFallback(f.chapterIndex + 1);
  }

  String _line(Favorite f, AppLocalizations l) {
    final multi = (_item?.chapters.length ?? 0) > 1;
    return multi ? l.favoriteLine(_chapterName(f, l), f.label) : f.label;
  }

  Future<void> _goTo(Favorite f) async {
    final router = ref.read(routerProvider);
    if (widget.args.forReader) {
      router.pop(f);
      return;
    }
    unawaited(
      router.push(
        AppRoutes.reader,
        extra: ItemSource(
          f.itemId,
          chapter: f.chapterIndex,
          sentence: f.sentenceIndex,
        ),
      ),
    );
  }

  Future<void> _showOptions(CommandBus bus) async {
    final id = ref.read(focusControllerProvider);
    final fav = _favorites.where((f) => 'fav.${f.id}' == id).firstOrNull;
    if (fav == null) {
      unawaited(ref.read(hapticsProvider).error());
      return bus.say(_l.nothingFocused);
    }
    setState(() => _optionsFor = fav);
    await bus.say(_l.favoriteOptions);
  }

  Future<void> _delete(Favorite f, CommandBus bus) =>
      bus.offer(_l.favoriteDeleteConfirm(f.label), () async {
        await _dao.deleteFavorite(f.id);
        unawaited(ref.read(hapticsProvider).confirm());
        if (!mounted) return;
        setState(() => _optionsFor = null);
        await _load();
        await bus.say(_l.favoriteDeleted);
      });

  ScreenRegistration _registration(WidgetRef ref) {
    final item = _item;
    final options = _optionsFor;
    return ScreenRegistration(
      id: FavoritesScreen.screenId,
      title: (l) => l.screenFavorites,
      prompt: (l) => _favorites.isEmpty
          ? l.favoritesEmpty(item?.title ?? '')
          : l.favoritesIntro(item?.title ?? '', _favorites.length),
      listOptions: false,
      includeModeHint: false,
      help: (l) => l.helpFavorites,
      actions: options != null
          ? [
              A11yAction(
                id: 'fav.goto',
                label: (l) => l.optGoHere,
                voiceSynonyms: const ['pumunta dito', 'pumunta', 'go here'],
                onActivate: (_) => _goTo(options),
              ),
              A11yAction(
                id: 'fav.delete',
                label: (l) => l.optDelete,
                voiceSynonyms: const ['burahin', 'delete', 'tanggalin'],
                confirmation: (_) => '',
                onActivate: (bus) => _delete(options, bus),
              ),
            ]
          : [
              for (final f in _favorites)
                A11yAction(
                  id: 'fav.${f.id}',
                  label: (l) => _line(f, l),
                  voiceSynonyms: [f.label],
                  confirmation: (_) => f.label,
                  onActivate: (_) => _goTo(f),
                ),
            ],
      intentHandlers: {
        NavIntent.faster: options == null
            ? _showOptions
            : (bus) => bus.notAvailable(),
        if (options != null)
          NavIntent.back: (bus) async {
            setState(() => _optionsFor = null);
            await bus.say(_l.screenFavorites);
          },
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final focused = ref.watch(focusControllerProvider);
    final textTheme = Theme.of(context).textTheme;
    if (!_loaded) return const Scaffold();
    final options = _optionsFor;

    return AccessibleScreen(
      registration: _registration,
      dependencies: [options?.id, for (final f in _favorites) f.id],
      child: GesturePadLayout(
        padHint: l10n.helpFavorites,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(l10n.screenFavorites, style: textTheme.titleLarge),
            ),
            const SizedBox(height: 4),
            Text(_item?.title ?? '', style: textTheme.bodyMedium),
            const SizedBox(height: 10),
            Expanded(
              child: _favorites.isEmpty
                  ? Center(
                      child: Text(
                        l10n.favoritesEmpty(_item?.title ?? ''),
                        textAlign: TextAlign.center,
                        style: textTheme.bodyLarge,
                      ),
                    )
                  : BoxedList(
                      items: options != null
                          ? [
                              BoxedListItem('fav.goto', l10n.optGoHere),
                              BoxedListItem('fav.delete', l10n.optDelete),
                            ]
                          : [
                              for (final f in _favorites)
                                BoxedListItem('fav.${f.id}', _line(f, l10n)),
                            ],
                      focused: focused,
                      onTap: ref.read(commandBusProvider).activate,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
