import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ids.dart';
import '../../app/router.dart';
import '../../core/accessibility/accessible_screen.dart';
import '../../core/accessibility/command_bus.dart';
import '../../core/accessibility/focus_controller.dart';
import '../../core/accessibility/screen_registration.dart';
import '../../core/db/daos/library_dao.dart';
import '../../core/library/library_models.dart';
import '../../core/tts/speech_language.dart';
import '../../core/widgets/boxed_list.dart';
import '../../core/widgets/gesture_pad_layout.dart';
import '../../l10n/app_localizations.dart';
import '../reader/reader_controller.dart';

/// The chapters of an EPUB (or a PDF with an outline). Double-tap a chapter to
/// start reading there.
class ChaptersScreen extends ConsumerStatefulWidget {
  /// Creates the chapter list of item [itemId].
  const ChaptersScreen({super.key, required this.itemId});

  /// Screen id.
  static const String screenId = Ids.chapters;

  /// `library_items.id`.
  final String itemId;

  @override
  ConsumerState<ChaptersScreen> createState() => _ChaptersScreenState();
}

class _ChaptersScreenState extends ConsumerState<ChaptersScreen> {
  LibraryItem? _item;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  AppLocalizations get _l => ref.read(speechLanguageProvider).strings;

  Future<void> _load() async {
    final item = await ref.read(libraryDaoProvider).get(widget.itemId);
    if (!mounted) return;
    setState(() {
      _item = item;
      _loaded = true;
    });
  }

  String _name(int index, AppLocalizations l) {
    final chapters = _item?.chapters ?? const [];
    final title = index < chapters.length ? chapters[index].title : '';
    return title.isEmpty ? l.chapterFallback(index + 1) : title;
  }

  String _line(int index, AppLocalizations l) =>
      l.chapterLine(index + 1, _name(index, l));

  Future<void> _open(int index) async {
    unawaited(
      ref
          .read(routerProvider)
          .push(
            AppRoutes.reader,
            extra: ItemSource(widget.itemId, chapter: index, sentence: 0),
          ),
    );
  }

  ScreenRegistration _registration(WidgetRef ref) {
    final chapters = _item?.chapters ?? const <ChapterInfo>[];
    return ScreenRegistration(
      id: ChaptersScreen.screenId,
      title: (l) => l.screenChapters,
      prompt: (l) => chapters.isEmpty
          ? l.chaptersNone
          : l.chaptersIntro(_item?.title ?? '', chapters.length),
      listOptions: false,
      includeModeHint: false,
      help: (l) => l.helpChapters,
      actions: [
        for (var i = 0; i < chapters.length; i++)
          A11yAction(
            id: 'chapter.$i',
            label: (l) => _line(i, l),
            voiceSynonyms: [
              _name(i, _l),
              'kabanata ${i + 1}',
              'chapter ${i + 1}',
            ],
            confirmation: (l) => _name(i, l),
            onActivate: (_) => _open(i),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final focused = ref.watch(focusControllerProvider);
    final textTheme = Theme.of(context).textTheme;
    if (!_loaded) return const Scaffold();
    final chapters = _item?.chapters ?? const <ChapterInfo>[];

    return AccessibleScreen(
      registration: _registration,
      dependencies: [chapters.length],
      child: GesturePadLayout(
        padHint: l10n.helpChapters,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(l10n.screenChapters, style: textTheme.titleLarge),
            ),
            const SizedBox(height: 4),
            Text(_item?.title ?? '', style: textTheme.bodyMedium),
            const SizedBox(height: 10),
            Expanded(
              child: chapters.isEmpty
                  ? Center(
                      child: Text(
                        l10n.chaptersNone,
                        textAlign: TextAlign.center,
                        style: textTheme.bodyLarge,
                      ),
                    )
                  : BoxedList(
                      items: [
                        for (var i = 0; i < chapters.length; i++)
                          BoxedListItem('chapter.$i', _line(i, l10n)),
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
