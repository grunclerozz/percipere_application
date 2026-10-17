import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ids.dart';
import '../../app/router.dart';
import '../../config/tutorial_config.dart';
import '../../core/accessibility/accessible_screen.dart';
import '../../core/accessibility/action_registry.dart';
import '../../core/accessibility/announcer.dart';
import '../../core/accessibility/command_bus.dart';
import '../../core/accessibility/haptics.dart';
import '../../core/accessibility/nav_intent.dart';
import '../../core/accessibility/screen_registration.dart';
import '../../core/auth/account.dart';
import '../../core/auth/session.dart';
import '../../core/db/daos/preferences_dao.dart';
import '../../core/gestures/gesture_surface.dart';
import '../../core/tts/speech_language.dart';
import '../../core/voice/command_matcher.dart';
import '../../core/voice/voice_controller.dart';
import '../../core/widgets/live_speaking_zone.dart';
import '../../core/widgets/page_padding.dart';
import '../../core/widgets/small_link.dart';
import '../../l10n/app_localizations.dart';

/// Whether [account] already finished or skipped the tutorial: a guest per
/// device, a registered account per account. (The first launch, before any
/// account, uses the device scope: `initialTutorialSeenProvider`.)
Future<bool> tutorialSeen(PreferencesDao prefs, Account account) async {
  final scope = account.isGuest ? PreferencesDao.deviceScope : account.id;
  return await prefs.get(PrefKeys.tutorialDone, userId: scope) == true;
}

/// One step of the tutorial.
enum TutorialStep {
  /// Percy introduces itself (who, how to call, examples, offline).
  percy,

  /// What this is; double-tap to start, two-finger swipe right to skip.
  intro,

  /// Practice: swipe right (next option).
  swipeRight,

  /// Practice: swipe left (previous option).
  swipeLeft,

  /// Practice: double-tap (choose).
  doubleTap,

  /// Practice: single tap (hear it again).
  tap,

  /// Practice: two-finger swipe right (back).
  back,

  /// Practice: three-finger tap (help).
  help,

  /// Practice: press and hold (talk).
  longPress,

  /// Practice: say "tulong" (only when the microphone is allowed).
  say,

  /// Voice mode, talking while reading, and questions; double-tap on.
  voiceInfo,

  /// Summary; double-tap to finish.
  done,
}

/// Controls tutorial ("Pag-aaral ng mga kontrol"): explains and lets the
/// user practise each gesture and a voice command before using the app.
///
/// Starts with Percy introducing itself. Shown once on the first launch, after
/// the loading screen and before Welcome (a new user must learn the controls
/// before they can register or log in; it needs no account). Replayed from
/// Settings ("Paano gamitin ang app") or by saying "paano gamitin" anywhere
/// ([replay] true: finishing goes back instead of to Welcome). The whole
/// screen is the gesture surface. Skipped by saying "laktawan", the
/// "Laktawan" button, or a two-finger swipe right (asked first after the
/// introduction).
///
/// Skip rule (first launch only): until Percy's introduction has been spoken
/// (at least [TutorialConfig.firstStepMinSpoken]) skipping is ignored, and
/// the button is hidden; after [TutorialConfig.firstStepTimeout] it is
/// allowed anyway so a failed voice never traps the user. A replay can skip
/// at once. Moving past the first step waits for the same moment.
class TutorialScreen extends ConsumerStatefulWidget {
  /// Creates the tutorial.
  const TutorialScreen({super.key, this.replay = false});

  /// Opened again by the user (not the first launch).
  final bool replay;

  /// Screen id.
  static const String screenId = Ids.tutorial;

  /// Wrong tries on a step before the tutorial moves on by itself.
  static const int maxTries = 3;

  @override
  ConsumerState<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends ConsumerState<TutorialScreen> {
  TutorialStep _step = TutorialStep.percy;
  int _wrong = 0;
  bool _finishing = false;

  /// Skipping is possible (always in a replay; on the first launch once the
  /// introduction was heard, or after the safety timeout).
  late bool _skipAllowed = widget.replay;
  bool _watching = false;
  Timer? _skipTimeout;

  AppLocalizations get _l => ref.read(speechLanguageProvider).strings;
  CommandBus get _bus => ref.read(commandBusProvider);

  /// The gesture (as an intent) each practice step waits for.
  static const Map<TutorialStep, NavIntent> _expected = {
    TutorialStep.percy: NavIntent.activate,
    TutorialStep.intro: NavIntent.activate,
    TutorialStep.swipeRight: NavIntent.next,
    TutorialStep.swipeLeft: NavIntent.previous,
    TutorialStep.doubleTap: NavIntent.activate,
    TutorialStep.tap: NavIntent.repeat,
    TutorialStep.back: NavIntent.back,
    TutorialStep.help: NavIntent.help,
    TutorialStep.longPress: NavIntent.listen,
    TutorialStep.voiceInfo: NavIntent.activate,
    TutorialStep.done: NavIntent.activate,
  };

  static const List<String> _skipWords = [
    'laktawan',
    'lampasan',
    'skip',
    'skip tutorial',
  ];

  static const List<String> _sayWords = ['tulong', 'help'];

  String _text(TutorialStep step, AppLocalizations l) => switch (step) {
    TutorialStep.percy => l.tutorialPercy,
    TutorialStep.intro => l.tutorialIntro,
    TutorialStep.swipeRight => l.tutorialSwipeRight,
    TutorialStep.swipeLeft => l.tutorialSwipeLeft,
    TutorialStep.doubleTap => l.tutorialDoubleTap,
    TutorialStep.tap => l.tutorialTap,
    TutorialStep.back => l.tutorialBack,
    TutorialStep.help => l.tutorialHelp,
    TutorialStep.longPress => l.tutorialLongPress,
    TutorialStep.say => l.tutorialSay,
    TutorialStep.voiceInfo => l.tutorialVoiceInfo,
    TutorialStep.done => l.tutorialDone,
  };

  @override
  void initState() {
    super.initState();
    if (_skipAllowed) return;
    _skipTimeout = Timer(
      TutorialConfig.firstStepTimeout,
      () => _allowSkip(
        'safety timeout after '
        '${TutorialConfig.firstStepTimeout.inSeconds}s',
      ),
    );
    // The host announces the screen (title + Percy's introduction) as soon
    // as it becomes the active one; wait until that speech has ended.
    ref.listenManual(activeScreenProvider, (previous, next) {
      if (_watching || next?.id != TutorialScreen.screenId) return;
      _watching = true;
      unawaited(_awaitFirstStep());
    });
  }

  @override
  void dispose() {
    _skipTimeout?.cancel();
    super.dispose();
  }

  Future<void> _awaitFirstStep() async {
    // Let the host queue the entry announcement first.
    await Future<void>.delayed(Duration.zero);
    if (!mounted || _skipAllowed) return;
    // Counts as heard only if the speech lasted at least firstStepMinSpoken.
    var longEnough = false;
    final minTimer = Timer(
      TutorialConfig.firstStepMinSpoken,
      () => longEnough = true,
    );
    await ref.read(announcerProvider.notifier).idle();
    minTimer.cancel();
    if (!mounted || _skipAllowed) return;
    if (longEnough) {
      _allowSkip('first step heard');
    } else {
      // Failed or cut off: not heard. The safety timeout opens it.
      debugPrint(
        '[TUTORIAL] first step ended in under '
        '${TutorialConfig.firstStepMinSpoken.inSeconds}s: speech failed or '
        'was interrupted; skipping stays off until the timeout',
      );
    }
  }

  void _allowSkip(String reason) {
    if (!mounted || _skipAllowed) return;
    _skipTimeout?.cancel();
    debugPrint('[TUTORIAL] skip allowed: $reason');
    setState(() => _skipAllowed = true);
  }

  // ── Steps ─────────────────────────────────────────────────────────────────

  Future<void> _onIntent(NavIntent intent) async {
    if (_finishing) return;
    final expected = _expected[_step];
    if (intent == expected) {
      // The first step must be heard before moving on (its end is when
      // skipping opens, and the next step talks about skipping).
      if (_step == TutorialStep.percy && !_skipAllowed) return;
      return _correct(intent);
    }
    switch (intent) {
      case NavIntent.back:
        // Two fingers right: skip (asked first, except on the intro).
        if (!_skipAllowed) return;
        if (_step == TutorialStep.percy || _step == TutorialStep.intro) {
          return _finish(skipped: true);
        }
        return _bus.offer(
          _l.tutorialSkipQuestion,
          () => _finish(skipped: true),
          onDecline: _sayStep,
        );
      case NavIntent.repeat:
      case NavIntent.help:
        // Tap = hear it again; three fingers = help: both repeat the step.
        return _sayStep();
      case NavIntent.listen:
        // Talking is always allowed ("laktawan", "ulitin"…).
        return ref.read(voiceControllerProvider.notifier).listenNow();
      case NavIntent.stopSpeech:
        return _bus.stopSpeech();
      default:
        return _wrongTry();
    }
  }

  Future<void> _correct(NavIntent intent) async {
    unawaited(ref.read(hapticsProvider).confirm());
    final l = _l;
    final praise = _step.index.isEven ? l.tutorialGood : l.tutorialGoodAlt;
    switch (_step) {
      case TutorialStep.percy:
      case TutorialStep.intro:
        return _advance();
      case TutorialStep.done:
        return _finish(skipped: false);
      case TutorialStep.voiceInfo:
        return _advance();
      case TutorialStep.longPress:
        return _advance(praise: praise);
      default:
        return _advance(praise: praise);
    }
  }

  Future<void> _wrongTry() async {
    unawaited(ref.read(hapticsProvider).error());
    // Step one is not left before it has been heard (not even by too many
    // wrong tries).
    if (_step == TutorialStep.percy && !_skipAllowed) return;
    _wrong++;
    if (_wrong >= TutorialScreen.maxTries) {
      return _advance(praise: _l.tutorialMovingOn);
    }
    await _bus.say('${_l.tutorialWrong} ${_text(_step, _l)}');
  }

  Future<void> _advance({String? praise}) async {
    var next = TutorialStep.values[_step.index + 1];
    String? note;
    if (next == TutorialStep.say && !await _micReady()) {
      note = _l.tutorialNoMic;
      next = TutorialStep.voiceInfo;
    }
    if (!mounted) return;
    setState(() {
      _step = next;
      _wrong = 0;
    });
    final l = _l;
    await _bus.say([?praise, ?note, _text(next, l)].join(' '));
    if (!mounted) return;
    if (next == TutorialStep.say && _step == TutorialStep.say) {
      // Listen for the practice word even in gesture mode.
      await ref.read(voiceControllerProvider.notifier).listenNow();
    }
  }

  /// Whether the microphone can be used; asks (with its explanation) the
  /// first time, so Welcome doesn't ask again.
  Future<bool> _micReady() async {
    final voice = ref.read(voiceControllerProvider.notifier);
    if (voice.micGranted) return true;
    final prefs = ref.read(userPrefsProvider);
    try {
      await prefs.set(PrefKeys.micAsked, true);
    } on Object catch (e) {
      debugPrint('Saving micAsked failed: $e');
    }
    try {
      return await voice.ensureReady(requestPermission: true);
    } on Object catch (e) {
      debugPrint('Microphone for the tutorial failed: $e');
      return false;
    }
  }

  Future<void> _sayStep() => _bus.say(_text(_step, _l));

  Future<void> _finish({required bool skipped}) async {
    if (_finishing || (skipped && !_skipAllowed)) return;
    _finishing = true;
    try {
      final account = ref.read(currentAccountProvider);
      final scope = account == null || account.isGuest
          ? PreferencesDao.deviceScope
          : account.id;
      await ref
          .read(userPrefsProvider)
          .set(PrefKeys.tutorialDone, true, userId: scope);
    } on Object catch (e) {
      debugPrint('Saving tutorialDone failed: $e');
    }
    if (skipped) await _bus.say(_l.tutorialSkipped, protect: true);
    if (!mounted) return;
    final router = ref.read(routerProvider);
    if (widget.replay && router.canPop()) {
      router.pop();
    } else {
      final account = ref.read(currentAccountProvider);
      router.go(
        account == null ? AppRoutes.welcome : AppRoutes.landing(account),
      );
    }
  }

  // ── Voice ─────────────────────────────────────────────────────────────────

  Future<bool> _onUtterance(String text, CommandBus bus) async {
    final said = CommandMatcher.normalize(text);
    if (_skipWords.any((w) => said == w || said.startsWith('$w '))) {
      // Ignored (not an error) until the first step has been heard.
      if (!_skipAllowed) return true;
      await _finish(skipped: true);
      return true;
    }
    if (_step == TutorialStep.say) {
      final words = said.split(' ');
      if (_sayWords.any(words.contains)) {
        await _correct(NavIntent.help);
      } else {
        await _wrongTry();
      }
      return true;
    }
    return false;
  }

  ScreenRegistration _registration(WidgetRef ref) => ScreenRegistration(
    id: TutorialScreen.screenId,
    title: (l) => l.screenTutorial,
    prompt: (l) => _text(_step, l),
    listOptions: false,
    includeModeHint: false,
    help: (l) => _text(_step, l),
    onUtterance: _onUtterance,
    freeTextPrefixes: const [],
    beforeBack: null,
    actions: [
      if (_skipAllowed)
        A11yAction(
          id: Ids.tutorialSkip,
          label: (l) => l.tutorialSkip,
          voiceSynonyms: _skipWords,
          focusable: false,
          confirmation: (_) => '',
          onActivate: (_) => _finish(skipped: true),
        ),
    ],
    intentHandlers: {
      for (final intent in const [
        NavIntent.next,
        NavIntent.previous,
        NavIntent.activate,
        NavIntent.repeat,
        NavIntent.back,
        NavIntent.help,
        NavIntent.listen,
        NavIntent.stopSpeech,
        NavIntent.faster,
        NavIntent.slower,
        NavIntent.nextParagraph,
        NavIntent.previousParagraph,
        // Practice first: the voice assistant can wait.
        NavIntent.assistant,
      ])
        intent: (_) => _onIntent(intent),
    },
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return AccessibleScreen(
      registration: _registration,
      dependencies: [_skipAllowed],
      child: Scaffold(
        body: GestureSurface(
          child: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: PagePadding(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            l10n.screenTutorial,
                            style: textTheme.headlineMedium,
                          ),
                        ),
                        const Spacer(),
                        LiveSpeakingZone(
                          screenId: TutorialScreen.screenId,
                          fallback: _text(_step, l10n),
                          subtitleLines: 6,
                        ),
                        const Spacer(),
                        if (_skipAllowed)
                          SmallLink(
                            label: l10n.tutorialSkip,
                            icon: Icons.skip_next,
                            focused: false,
                            onPressed: () => _bus.activate(Ids.tutorialSkip),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
