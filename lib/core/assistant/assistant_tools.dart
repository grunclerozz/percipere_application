import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ids.dart';
import '../../app/locale_provider.dart';
import '../../app/router.dart';
import '../../app/theme/theme_settings.dart';
import '../../features/reader/reader_controller.dart';
import '../../l10n/app_localizations.dart';
import '../accessibility/action_registry.dart';
import '../accessibility/command_bus.dart';
import '../accessibility/focus_controller.dart';
import '../accessibility/nav_intent.dart';
import '../accessibility/screen_registration.dart';
import '../auth/session.dart';
import '../db/daos/library_dao.dart';
import '../library/library_models.dart';
import '../settings/settings_controller.dart';
import '../tts/reading_rate.dart';
import '../tts/speech_language.dart';
import '../voice/command_matcher.dart';
import 'assistant_controller.dart';
import 'reader_snapshot.dart';

/// A tool call the app can't carry out; [message] goes back to Percy.
class AssistantToolError implements Exception {
  /// Creates the error.
  const AssistantToolError(this.message);

  /// What to tell the agent.
  final String message;

  @override
  String toString() => 'AssistantToolError($message)';
}

/// Percy's client tools, answered by the app through the command bus, so
/// whatever Percy does is exactly what the user could do by gesture, voice
/// or tap. Names and parameters match `assistant/agent_config/tools.json`
/// (checked by a test).
class AssistantTools {
  /// Creates the tools for one call.
  AssistantTools(this._ref, this._assistant);

  final Ref _ref;
  final AssistantController _assistant;

  /// Every tool this class answers.
  static const Set<String> names = {
    'get_screen',
    'go_to',
    'choose_option',
    'list_library',
    'open_document',
    'read_document',
    'scan_document',
    'upload_document',
    'get_document_text',
    'reading_settings',
    'save_favorite',
    'describe_controls',
  };

  /// Longest document text sent to Percy.
  static const int maxDocumentChars = 6000;

  /// Said after a hand-over so Percy closes the call.
  static const String _handoverNote =
      'Say ONE short sentence to the user, then call end_call. '
      'The app takes over when the call ends.';

  CommandBus get _bus => _ref.read(commandBusProvider);
  AppLocalizations get _l => _ref.read(speechLanguageProvider).strings;

  /// Runs tool [name] with [params]; returns the text for Percy.
  Future<String> run(String name, Map<String, Object?> params) =>
      switch (name) {
        'get_screen' => _screen(),
        'go_to' => _goTo(_text(params, 'destination')),
        'choose_option' => _choose(_text(params, 'option')),
        'list_library' => _library(),
        'open_document' => _open(
          _text(params, 'title'),
          startReading: params['start_reading'] == true,
        ),
        'read_document' => _read(),
        'scan_document' => _handOver(
          () => _bus.dispatch(NavIntent.camera),
          'The camera will open and guide the user by voice.',
        ),
        'upload_document' => _handOver(
          () => _bus.dispatch(NavIntent.upload),
          "The phone's file picker will open.",
        ),
        'get_document_text' => _documentText(),
        'reading_settings' => _settings(_text(params, 'change')),
        'save_favorite' => _favorite(),
        'describe_controls' => _controls(),
        _ => Future.error(AssistantToolError('Unknown tool "$name".')),
      };

  static String _text(Map<String, Object?> params, String key) {
    final value = params[key]?.toString().trim() ?? '';
    if (value.isEmpty) throw AssistantToolError('Missing "$key".');
    return value;
  }

  // ── Where am I ─────────────────────────────────────────────────────────

  Future<String> _screen() async {
    final screen = _bus.activeScreen;
    if (screen == null) return 'No screen is open yet.';
    final l = _l;
    final (:asked, then: _) = _bus.entryParts(screen);
    final options = [for (final a in screen.focusables) _label(a, l)];
    final focusedId = _ref.read(focusControllerProvider);
    final focused = screen.focusables
        .where((a) => a.id == focusedId)
        .firstOrNull;
    final reader = screen.id == Ids.reader
        ? _ref.read(readerSnapshotProvider)
        : null;
    return [
      'Screen: $asked',
      if (options.isNotEmpty) 'Options: ${options.join(', ')}.',
      if (focused != null) 'Focused: ${_label(focused, l)}.',
      if (reader != null)
        'Document: ${reader.title ?? 'untitled'}, sentence '
            '${math.min(reader.sentence + 1, reader.sentenceCount)} of '
            '${reader.sentenceCount}, ${reader.playing ? 'being read aloud' : 'paused'}.',
    ].join('\n');
  }

  static String _label(A11yAction a, AppLocalizations l) =>
      a.label(l).split('(').first.trim();

  // ── Moving around ──────────────────────────────────────────────────────

  Future<String> _goTo(String destination) async {
    final before = _bus.activeScreen?.id;
    switch (destination) {
      case 'home':
        await _bus.dispatch(NavIntent.home);
      case 'library':
        await _bus.dispatch(NavIntent.library);
      case 'settings':
        await _bus.dispatch(NavIntent.settings);
      case 'back':
        await _bus.dispatch(NavIntent.back);
      case 'new_document':
        final router = _ref.read(routerProvider);
        router.go(AppRoutes.home);
        unawaited(router.push(AppRoutes.capture));
      default:
        throw AssistantToolError('Unknown destination "$destination".');
    }
    await _screenChange(before);
    return 'Done. ${await _screen()}';
  }

  Future<String> _choose(String option) async {
    final screen = _bus.activeScreen;
    if (screen == null) throw const AssistantToolError('No screen is open.');
    final fil = lookupAppLocalizations(AppLocales.filipino);
    final en = lookupAppLocalizations(AppLocales.english);
    final phrases = [
      for (final a in screen.actions) ...[
        for (final label in {a.label(fil), a.label(en)}) ...[
          CommandPhrase(label, ActionTarget(a.id)),
          for (final part in label.split(RegExp('[()]')))
            if (part.trim().isNotEmpty)
              CommandPhrase(part.trim(), ActionTarget(a.id)),
        ],
        for (final s in a.voiceSynonyms) CommandPhrase(s, ActionTarget(a.id)),
      ],
    ];
    final target = switch (const CommandMatcher().match(option, phrases)) {
      Matched(:final target) || Ambiguous(:final target) => target,
      NoMatch() => null,
    };
    if (target is! ActionTarget) {
      final names = [for (final a in screen.focusables) _label(a, _l)];
      throw AssistantToolError(
        'There is no option "$option" here. Options: ${names.join(', ')}.',
      );
    }
    final id = target.actionId;
    final action = screen.action(id)!;
    // Camera and file picker take over the screen and the voice.
    if (id == Ids.captureCamera ||
        id == Ids.captureUpload ||
        id == Ids.describeSourceCamera ||
        id == Ids.describeSourceUpload) {
      return _handOver(
        () => _bus.activate(id),
        'Chose "${_label(action, _l)}".',
      );
    }
    final before = screen.id;
    await _bus.activate(id);
    await _screenChange(before, wait: const Duration(milliseconds: 800));
    return 'Chose "${_label(action, _l)}". ${await _screen()}';
  }

  /// Waits (briefly) for the screen to change after a navigation.
  Future<void> _screenChange(
    String? before, {
    Duration wait = const Duration(seconds: 2),
  }) async {
    const step = Duration(milliseconds: 100);
    for (var waited = Duration.zero; waited < wait; waited += step) {
      if (_ref.read(activeScreenProvider)?.id != before) return;
      await Future<void>.delayed(step);
    }
  }

  // ── The Library ────────────────────────────────────────────────────────

  Future<List<LibraryItem>> _items() =>
      _ref.read(libraryDaoProvider).list(_ref.read(currentAccountProvider)?.id);

  Future<String> _library() async {
    final items = await _items();
    if (items.isEmpty) return 'The Aklatan (library) is empty.';
    String line(LibraryItem i) => [
      '- ${i.title}',
      if (i.author != null && i.author!.isNotEmpty) ' by ${i.author}',
      ' (${i.format.name}, ',
      i.finished ? 'finished' : '${i.percent.round()}% read',
      ')',
    ].join();
    return [
      '${items.length} item(s) in the Aklatan, most recent first:',
      for (final i in items.take(15)) line(i),
      if (items.length > 15) '…and ${items.length - 15} more.',
    ].join('\n');
  }

  Future<String> _open(String title, {required bool startReading}) async {
    final items = await _items();
    final wanted = CommandMatcher.normalize(title);
    LibraryItem? best;
    var bestScore = 0.0;
    for (final item in items) {
      final name = CommandMatcher.normalize(item.title);
      var score = CommandMatcher.similarity(name, wanted);
      if (wanted.isNotEmpty && name.contains(wanted)) {
        score = math.max(score, 0.9);
      }
      if (score > bestScore) {
        best = item;
        bestScore = score;
      }
    }
    if (best == null || bestScore < 0.55) {
      final titles = [for (final i in items.take(10)) i.title];
      throw AssistantToolError(
        titles.isEmpty
            ? 'The Aklatan is empty.'
            : 'No document matches "$title". Titles: ${titles.join('; ')}.',
      );
    }
    final item = best;
    _assistant.handOver(() async {
      unawaited(
        _ref
            .read(routerProvider)
            .push(AppRoutes.reader, extra: ItemSource(item.id)),
      );
      if (startReading) {
        await _whenReaderReady(() => _bus.dispatch(NavIntent.read));
      }
    });
    return 'Opening "${item.title}"${startReading ? ' and reading it aloud' : ''}. '
        '$_handoverNote';
  }

  Future<void> _whenReaderReady(Future<void> Function() then) async {
    for (var i = 0; i < 40; i++) {
      final s = _ref.read(readerSnapshotProvider);
      if (s != null && s.canRead) return then();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  // ── The open document ──────────────────────────────────────────────────

  ReaderSnapshot _openDocument() {
    final s = _ref.read(readerSnapshotProvider);
    if (s == null) {
      throw const AssistantToolError(
        'No document is open in the Reader. Use list_library and open_document.',
      );
    }
    return s;
  }

  Future<String> _read() async {
    final s = _openDocument();
    if (!s.canRead) {
      throw const AssistantToolError("The document isn't ready to read.");
    }
    return _handOver(
      () => _bus.dispatch(NavIntent.read),
      'Reading "${s.title ?? 'the document'}".',
    );
  }

  Future<String> _documentText() async {
    final s = _openDocument();
    if (s.text.trim().isEmpty) return 'The document has no readable text.';
    final cut = s.text.length > maxDocumentChars;
    return [
      'Title: ${s.title ?? 'untitled'}',
      cut ? s.text.substring(0, maxDocumentChars) : s.text,
      if (cut)
        '[Only the first $maxDocumentChars of ${s.text.length} characters are included.]',
    ].join('\n');
  }

  Future<String> _settings(String change) async {
    final settings = _ref.read(settingsProvider.notifier);
    final before = _ref.read(settingsProvider);
    switch (change) {
      case 'faster' || 'slower':
        final delta = change == 'faster' ? ReadingRate.step : -ReadingRate.step;
        final after = await settings.update(
          (s) => s.copyWith(readingRate: before.readingRate + delta),
        );
        final limit = after.readingRate == before.readingRate
            ? ' (the limit)'
            : '';
        return 'Reading speed is now ${ReadingRate.label(after.readingRate)}$limit.';
      case 'bigger_text' || 'smaller_text':
        final delta = change == 'bigger_text' ? TextSize.step : -TextSize.step;
        final after = await settings.update(
          (s) => s.copyWith(textSize: before.textSize + delta),
        );
        final limit = after.textSize == before.textSize ? ' (the limit)' : '';
        return 'Text size is now ${after.textSize.round()}$limit.';
      default:
        throw AssistantToolError('Unknown change "$change".');
    }
  }

  Future<String> _favorite() async {
    if (_bus.activeScreen?.id != Ids.reader) {
      throw const AssistantToolError('Open a document in the Reader first.');
    }
    await _bus.dispatch(NavIntent.favorite);
    return 'Saved a favorite at the current sentence.';
  }

  // ── Teaching the controls ──────────────────────────────────────────────

  Future<String> _controls() async {
    final screen = _bus.activeScreen;
    final l = _l;
    return [
      if (screen != null) (screen.help ?? (l) => l.helpGesturesMenu)(l),
      _bus.modeHint(l),
      l.assistantHowToCall,
    ].join('\n');
  }

  // ── Handing over ───────────────────────────────────────────────────────

  Future<String> _handOver(
    FutureOr<void> Function() action,
    String what,
  ) async {
    _assistant.handOver(action);
    return '$what $_handoverNote';
  }
}
