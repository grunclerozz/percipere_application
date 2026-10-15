import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ids.dart';
import '../../app/router.dart';
import '../../core/accessibility/accessible_screen.dart';
import '../../core/accessibility/command_bus.dart';
import '../../core/accessibility/focus_controller.dart';
import '../../core/accessibility/screen_registration.dart';
import '../../core/auth/session.dart';
import '../../core/db/daos/preferences_dao.dart';
import '../../core/offline_voice/offline_voice_setup.dart';
import '../../core/tts/speech_language.dart';
import '../../core/widgets/boxed_list.dart';
import '../../l10n/app_localizations.dart';
import '../auth/form_scaffold.dart';

/// Where to go once the first-launch download is done or set aside.
@immutable
class OfflineVoiceNext {
  /// Creates the destination.
  const OfflineVoiceNext(this.location, {this.extra});

  /// Route to open.
  final String location;

  /// Its `extra`.
  final Object? extra;
}

/// First launch, before Welcome and the tutorial: "Pakihintay habang
/// dina-download namin ang mga boses at wika." Downloads the app's own
/// offline voices and command recognizer (sizes stated, progress spoken
/// about every 20 %), then says "Handa na. Gumagana na ang boses kahit
/// walang internet." and moves on. Without internet it says so once and
/// moves on; the download resumes by itself when the internet is back.
/// "Ituloy habang nagda-download" moves on at once (the download goes on).
class OfflineVoiceSetupScreen extends ConsumerStatefulWidget {
  /// Creates the screen; [next] is where the app goes afterwards.
  const OfflineVoiceSetupScreen({super.key, required this.next});

  /// Where to go afterwards.
  final OfflineVoiceNext next;

  @override
  ConsumerState<OfflineVoiceSetupScreen> createState() =>
      _OfflineVoiceSetupScreenState();
}

class _OfflineVoiceSetupScreenState
    extends ConsumerState<OfflineVoiceSetupScreen> {
  static const String _continue = '${Ids.offlineVoice}.continue';
  static const String _retry = '${Ids.offlineVoice}.retry';
  static const String _status = '${Ids.offlineVoice}.status';

  bool _sizeSaid = false;
  int _lastStep = 0;
  bool _left = false;

  @override
  void initState() {
    super.initState();
    // Online by definition while downloading: Google's network Filipino
    // voice may speak until ours is installed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(networkFilipinoProvider.notifier).set(true);
      unawaited(ref.read(userPrefsProvider).set(
        PrefKeys.offlineVoiceSetupShown,
        true,
      ));
      unawaited(_start());
    });
    ref.listenManual(offlineVoiceProvider, _onChange);
  }

  @override
  void dispose() {
    // The provider may outlive the screen; it must not stay allowed.
    if (!_left) _releaseNetworkVoice();
    super.dispose();
  }

  void _releaseNetworkVoice() {
    try {
      ref.read(networkFilipinoProvider.notifier).set(false);
    } on Object catch (e) {
      debugPrint('[OFFLINE VOICE] network voice flag: $e');
    }
  }

  Future<void> _start() async {
    final state = ref.read(offlineVoiceProvider);
    if (state.status == OfflineVoiceStatus.ready) {
      await _say((l) => l.offlineVoiceReady);
      return _leave();
    }
    if (state.status != OfflineVoiceStatus.unavailable) {
      unawaited(ref.read(offlineVoiceProvider.notifier).ensure());
    } else {
      return _leave();
    }
  }

  Future<void> _say(String Function(AppLocalizations l) text) {
    final bus = ref.read(commandBusProvider);
    return bus.say(text(bus.strings), screenId: Ids.offlineVoice);
  }

  void _onChange(OfflineVoiceState? previous, OfflineVoiceState next) {
    if (_left || !mounted) return;
    switch (next.status) {
      case OfflineVoiceStatus.downloading:
        if (!_sizeSaid && next.total > 0) {
          _sizeSaid = true;
          unawaited(
            _say((l) => l.offlineVoiceSize('${next.totalMegabytes}')),
          );
        }
        // About every 20 %: 20, 40, 60, 80.
        final step = next.percent ~/ 20;
        if (step > _lastStep && step < 5) {
          _lastStep = step;
          unawaited(_say((l) => l.offlineVoiceProgress('${step * 20}')));
        }
      case OfflineVoiceStatus.ready:
        if (previous?.status != OfflineVoiceStatus.ready) {
          unawaited(_finish((l) => l.offlineVoiceReady));
        }
      case OfflineVoiceStatus.waitingForInternet:
        // Said by a voice that works offline (no network voice now).
        _releaseNetworkVoice();
        unawaited(_finish((l) => l.offlineVoiceNoInternet));
      case OfflineVoiceStatus.lowStorage:
        final mb = ((next.neededBytes ?? 0) / 1000000).ceil();
        unawaited(_finish((l) => l.offlineVoiceLowStorage('$mb')));
      case OfflineVoiceStatus.failed:
        unawaited(_finish((l) => l.offlineVoiceFailed));
      case OfflineVoiceStatus.idle ||
          OfflineVoiceStatus.checking ||
          OfflineVoiceStatus.unavailable:
        break;
    }
    setState(() {});
  }

  Future<void> _finish(String Function(AppLocalizations l) text) async {
    if (_left) return;
    _left = true;
    await _say(text);
    if (!mounted) return;
    _go();
  }

  Future<void> _leave() async {
    if (_left) return;
    _left = true;
    _go();
  }

  void _go() {
    _releaseNetworkVoice();
    ref
        .read(routerProvider)
        .go(widget.next.location, extra: widget.next.extra);
  }

  String _statusLine(AppLocalizations l, OfflineVoiceState state) =>
      switch (state.status) {
        OfflineVoiceStatus.downloading => l.offlineVoiceStatusDownloading(
          '${state.percent}',
        ),
        OfflineVoiceStatus.ready => l.offlineVoiceReady,
        OfflineVoiceStatus.waitingForInternet => l.offlineVoiceNoInternet,
        OfflineVoiceStatus.failed => l.offlineVoiceFailed,
        OfflineVoiceStatus.lowStorage => l.offlineVoiceLowStorage(
          '${((state.neededBytes ?? 0) / 1000000).ceil()}',
        ),
        _ => l.offlineVoiceStatusChecking,
      };

  ScreenRegistration _registration(WidgetRef ref) {
    final state = ref.read(offlineVoiceProvider);
    return ScreenRegistration(
      id: Ids.offlineVoice,
      title: (l) => l.screenOfflineVoice,
      prompt: (l) => l.offlineVoiceWait,
      whereAmI: (l) => _statusLine(l, ref.read(offlineVoiceProvider)),
      help: (l) => l.helpChooseList,
      listOptions: false,
      includeModeHint: false,
      actions: [
        A11yAction(
          id: _status,
          label: (l) => _statusLine(l, ref.read(offlineVoiceProvider)),
          confirmation: (l) => '',
          onActivate: (bus) =>
              bus.say(_statusLine(bus.strings, ref.read(offlineVoiceProvider))),
        ),
        A11yAction(
          id: _continue,
          label: (l) => l.offlineVoiceContinue,
          voiceSynonyms: const ['ituloy', 'continue', 'laktawan', 'skip'],
          confirmation: (l) => l.offlineVoiceContinueDone,
          onActivate: (bus) => _leave(),
        ),
        if (state.status == OfflineVoiceStatus.failed ||
            state.status == OfflineVoiceStatus.lowStorage)
          A11yAction(
            id: _retry,
            label: (l) => l.offlineVoiceRetry,
            voiceSynonyms: const ['subukan ulit', 'try again', 'ulitin'],
            confirmation: (l) => '',
            onActivate: (bus) async {
              _left = false;
              await ref.read(offlineVoiceProvider.notifier).ensure();
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final focused = ref.watch(focusControllerProvider);
    final state = ref.watch(offlineVoiceProvider);
    final bus = ref.read(commandBusProvider);
    final registration = _registration(ref);
    final downloading = state.status == OfflineVoiceStatus.downloading;
    return AccessibleScreen(
      registration: _registration,
      dependencies: [state.status, state.percent ~/ 5],
      child: FormScaffold(
        screenId: Ids.offlineVoice,
        title: l10n.screenOfflineVoice,
        subtitle: l10n.offlineVoiceWait,
        padHint: l10n.helpChooseList,
        fill: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label: _statusLine(l10n, state),
              value: downloading ? '${state.percent}%' : null,
              child: ExcludeSemantics(
                child: LinearProgressIndicator(
                  value: downloading ? state.percent / 100 : null,
                  minHeight: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: BoxedList(
                items: [
                  for (final a in registration.actions)
                    BoxedListItem(a.id, a.label(l10n)),
                ],
                focused: focused,
                onTap: bus.activate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
