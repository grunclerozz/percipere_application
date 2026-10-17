import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../app/ids.dart';
import '../../config/wer_phrases.dart';
import '../../core/accessibility/accessible_screen.dart';
import '../../core/accessibility/command_bus.dart';
import '../../core/accessibility/focus_controller.dart';
import '../../core/accessibility/screen_registration.dart';
import '../../core/algorithms/wer.dart';
import '../../core/db/daos/wer_dao.dart';
import '../../core/percy/percy_log_export.dart';
import '../../core/voice/voice_controller.dart';
import '../../core/widgets/boxed_list.dart';
import '../../l10n/app_localizations.dart';
import '../auth/form_scaffold.dart';

/// Hidden developer screen (`PERCIPERE_DEV` builds): the evaluator reads a
/// reference sentence, the app listens once, and the Word Error Rate
/// `(S + D + I) / N` of what it heard is saved and can be exported as CSV.
class WerTestScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const WerTestScreen({super.key});

  @override
  ConsumerState<WerTestScreen> createState() => _WerTestScreenState();
}

class _WerTestScreenState extends ConsumerState<WerTestScreen> {
  static const String _next = '${Ids.werTest}.next';
  static const String _listen = '${Ids.werTest}.listen';
  static const String _export = '${Ids.werTest}.export';
  static const String _clear = '${Ids.werTest}.clear';

  final String _session = DateTime.now().millisecondsSinceEpoch.toString();
  int _index = 0;
  bool _busy = false;
  int _done = 0;
  String? _lastLine;

  String get _reference =>
      werReferencePhrases[_index % werReferencePhrases.length];

  Future<void> _nextPhrase(CommandBus bus) async {
    setState(() {
      _index = (_index + 1) % werReferencePhrases.length;
      _lastLine = null;
    });
    await bus.say(bus.strings.werSay(_reference));
  }

  Future<void> _listenOnce(CommandBus bus) async {
    if (_busy) return;
    setState(() => _busy = true);
    final l = bus.strings;
    try {
      await bus.say(l.werSay(_reference));
      if (!mounted) return;
      final probe = await ref.read(voiceControllerProvider.notifier).probe();
      if (!mounted) return;
      final heard = probe?.text ?? '';
      final result = wordErrorRate(_reference, heard);
      await ref
          .read(werDaoProvider)
          .insert(
            WerRecord(
              sessionId: _session,
              locale: probe?.plan.localeId ?? '',
              onDevice: probe?.plan.onDevice ?? false,
              reference: _reference,
              hypothesis: heard,
              result: result,
              at: DateTime.now(),
            ),
          );
      if (!mounted) return;
      final line = l.werResult(
        heard.isEmpty ? '-' : heard,
        '${(result.wer * 100).round()}',
        '${result.substitutions}',
        '${result.deletions}',
        '${result.insertions}',
      );
      setState(() {
        _done++;
        _lastLine = line;
      });
      await bus.say(line);
    } on Object catch (e, stack) {
      debugPrint('[WER] test failed: $e\n$stack');
      if (mounted) await bus.say(l.werFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportCsv(CommandBus bus) async {
    final l = bus.strings;
    try {
      final records = await ref.read(werDaoProvider).all();
      if (records.isEmpty) return await bus.say(l.werEmpty);
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().toIso8601String().substring(0, 10);
      final file = File(p.join(dir.path, 'wer-results-$stamp.csv'));
      await file.writeAsString(WerDao.toCsv(records), flush: true);
      await bus.say(l.percyExportDone);
      await ref.read(percyCsvSharerProvider)(file.path);
    } on Object catch (e, stack) {
      debugPrint('[WER] export failed: $e\n$stack');
      await bus.say(l.percyExportFailed);
    }
  }

  ScreenRegistration _registration(WidgetRef ref) => ScreenRegistration(
    id: Ids.werTest,
    title: (l) => l.screenWerTest,
    prompt: (l) => '${l.werIntro} ${l.werSay(_reference)}',
    help: (l) => l.helpChooseList,
    actions: [
      A11yAction(
        id: _listen,
        label: (l) => l.werListen,
        voiceSynonyms: const ['makinig', 'listen', 'subukan'],
        confirmation: (l) => '',
        onActivate: _listenOnce,
      ),
      A11yAction(
        id: _next,
        label: (l) => l.werNext,
        voiceSynonyms: const ['susunod na pangungusap', 'next phrase'],
        confirmation: (l) => '',
        onActivate: _nextPhrase,
      ),
      if (_lastLine != null)
        A11yAction(
          id: '${Ids.werTest}.result',
          label: (l) => _lastLine!,
          confirmation: (l) => '',
          onActivate: (bus) => bus.say(_lastLine!),
        ),
      A11yAction(
        id: _export,
        label: (l) => l.werExport,
        voiceSynonyms: const ['i-export', 'export'],
        confirmation: (l) => '',
        onActivate: _exportCsv,
      ),
      A11yAction(
        id: _clear,
        label: (l) => l.werClear,
        voiceSynonyms: const ['burahin lahat', 'clear all'],
        confirmation: (l) => '',
        onActivate: (bus) => bus.offer(bus.strings.werClearConfirm, () async {
          await ref.read(werDaoProvider).clear();
          if (!mounted) return;
          setState(() {
            _done = 0;
            _lastLine = null;
          });
          await bus.say(bus.strings.werCleared);
        }),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final focused = ref.watch(focusControllerProvider);
    final bus = ref.read(commandBusProvider);
    final registration = _registration(ref);
    return AccessibleScreen(
      registration: _registration,
      dependencies: [_index, _lastLine, _done],
      child: FormScaffold(
        screenId: Ids.werTest,
        title: l10n.screenWerTest,
        subtitle: l10n.werSay(_reference),
        padHint: l10n.helpChooseList,
        fill: true,
        child: BoxedList(
          items: [
            for (final a in registration.actions)
              BoxedListItem(a.id, a.label(l10n)),
          ],
          focused: focused,
          onTap: bus.activate,
        ),
      ),
    );
  }
}
