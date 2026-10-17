import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/locale_provider.dart';
import '../../l10n/app_localizations.dart';
import '../percy/percy_controller.dart';
import '../tts/tts_service.dart';
import '../voice/voice_activity.dart';
import '../voice/voice_controller.dart';
import 'action_registry.dart';
import 'announcer.dart';
import 'command_bus.dart';
import 'navigation_mode.dart';

/// App-level glue for the accessibility core. Sits above the router and:
///
/// - announces each screen when it becomes active;
/// - on the first screen of a launch, first explains (in English) if no
///   Filipino voice is installed, and notes TalkBack if it is on;
/// - keeps [talkBackProvider] in sync with the platform;
/// - re-checks voices when the app resumes (the user may have installed one);
/// - pauses voice listening while the app is in the background.
class AccessibilityHost extends ConsumerStatefulWidget {
  /// Wraps the app [child].
  const AccessibilityHost({super.key, required this.child});

  /// The app below the host (the router's output).
  final Widget child;

  @override
  ConsumerState<AccessibilityHost> createState() => _AccessibilityHostState();
}

class _AccessibilityHostState extends ConsumerState<AccessibilityHost>
    with WidgetsBindingObserver {
  bool _startupNoticesGiven = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Create the voice controller now so it follows speech from the start
    // (it re-arms listening whenever an announcement ends).
    ref.read(voiceControllerProvider);
    // One log line per change of what voice input is doing (also without
    // the developer overlay): loading / ready / speaking / listening /
    // processing.
    ref.listenManual(voiceActivityProvider, (previous, next) {
      if (previous != next) debugPrint('[VOICE STATE] ${next.name}');
    });
    ref.listenManual(activeScreenProvider, (previous, next) {
      // Same screen re-registering (e.g. its list changed): no re-announce.
      if (next == null || next.id == previous?.id) return;
      unawaited(_onScreenActive(next.id));
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final talkBack = MediaQuery.accessibleNavigationOf(context);
    scheduleMicrotask(() {
      if (mounted) ref.read(talkBackProvider.notifier).set(talkBack);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    ref.read(voiceControllerProvider.notifier).setAppActive(active);
    if (active) unawaited(_recheckVoices());
  }

  Future<void> _onScreenActive(String screenId) async {
    final bus = ref.read(commandBusProvider);
    final screen = bus.activeScreen;
    if (screen == null || screen.id != screenId) return;
    if (_startupNoticesGiven) {
      final announced = bus.announceScreen(screen);
      bus.noteVisit(screen.id);
      await announced;
      return;
    }
    // First screen of this launch: notices and the screen prompt are queued
    // in order, none interrupting the other.
    _startupNoticesGiven = true;
    final announcer = ref.read(announcerProvider.notifier);
    final voices = ref.read(voiceStatusProvider);
    final uiLocale = ref.read(appLocaleProvider);
    if (!voices.filipinoReady && uiLocale == AppLocales.filipino) {
      // Explains why prompts are in English, so it comes first — and is
      // itself in English, since Filipino can't be spoken yet.
      final en = lookupAppLocalizations(AppLocales.english);
      final hint = screenId == 'welcome'
          ? ' ${en.ttsFilipinoMissingSwipeUp}'
          : '';
      unawaited(
        announcer.say(
          '${en.ttsFilipinoMissing}$hint',
          languageTag: voices.englishTag,
        ),
      );
    }
    unawaited(bus.announceScreen(screen, interrupt: false));
    bus.noteVisit(screen.id);
    // Percy's model loads in the background now (in its own isolate), so
    // the first "Percy" answers without the loading delay.
    unawaited(
      ref.read(percyBrainProvider.future).then<void>(
        (_) {},
        onError: (Object e) => debugPrint('[PERCY] preload failed: $e'),
      ),
    );
    if (ref.read(talkBackProvider)) {
      await announcer.say(bus.strings.talkBackNotice, interrupt: false);
    }
  }

  Future<void> _recheckVoices() async {
    final becameReady = await ref.read(voiceStatusProvider.notifier).refresh();
    if (becameReady && mounted) {
      final bus = ref.read(commandBusProvider);
      await bus.say(bus.strings.filipinoVoiceReady);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
