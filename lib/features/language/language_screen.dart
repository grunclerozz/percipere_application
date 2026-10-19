import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ids.dart';
import '../../app/locale_provider.dart';
import '../../app/router.dart';
import '../../config/constants.dart';
import '../../core/accessibility/accessible_screen.dart';
import '../../core/accessibility/action_registry.dart';
import '../../core/accessibility/announcer.dart';
import '../../core/accessibility/command_bus.dart';
import '../../core/accessibility/focus_controller.dart';
import '../../core/accessibility/nav_intent.dart';
import '../../core/accessibility/screen_registration.dart';
import '../../core/auth/session.dart';
import '../../core/db/daos/preferences_dao.dart';
import '../../core/gestures/gesture_surface.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/tts/tts_service.dart';
import '../../core/widgets/eye_logo.dart';
import '../../core/widgets/page_padding.dart';
import '../../core/widgets/pill_button.dart';
import '../../l10n/app_localizations.dart';

/// First launch, right after the loading screen and before the tutorial:
/// "Pumili ng wika. Choose a language." in both languages, spoken and on
/// screen.
///
/// Two options, Tagalog and English. Swipe left or right moves between them
/// (each is read aloud as it is highlighted), double-tap chooses the
/// highlighted one; or say "Tagalog" / "English", or press one of the two
/// large buttons (which carry proper labels for TalkBack). The choice is
/// confirmed in the chosen language, saved, and used for the whole app. With
/// no answer for [silence] the question is repeated once; after another
/// [silence] Tagalog is used. Asked once per device (Settings can change it).
class LanguageScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const LanguageScreen({super.key});

  /// Screen id.
  static const String screenId = Ids.language;

  /// Wait for an answer before repeating, and again before defaulting.
  static const Duration silence = Duration(seconds: 10);

  @override
  ConsumerState<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends ConsumerState<LanguageScreen> {
  bool _chosen = false;
  bool _repeated = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    ref.listenManual(activeScreenProvider, (previous, next) {
      if (next?.id == LanguageScreen.screenId &&
          previous?.id != LanguageScreen.screenId) {
        unawaited(_ask());
      }
    });
    // Moving the highlight is an answer in progress: wait again.
    ref.listenManual(focusControllerProvider, (previous, next) {
      if (next != null && !_chosen) _wait();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// The question, then how to answer, each in both languages.
  Future<void> _speakQuestion() async {
    _timer?.cancel();
    final announcer = ref.read(announcerProvider.notifier);
    final voices = ref.read(voiceStatusProvider);
    final fil = lookupAppLocalizations(AppLocales.filipino);
    final en = lookupAppLocalizations(AppLocales.english);
    if (voices.filipinoReady) {
      await announcer.say(
        '${fil.languagePromptFil} ${fil.languageGestureFil}',
        languageTag: voices.filipinoTag,
      );
    }
    if (!mounted || _chosen) return;
    await announcer.say(
      '${en.languagePromptEn} ${en.languageGestureEn}',
      languageTag: voices.englishTag,
      interrupt: !voices.filipinoReady,
    );
  }

  Future<void> _ask() async {
    await _speakQuestion();
    if (mounted && !_chosen) _wait();
  }

  void _wait() {
    _timer?.cancel();
    _timer = Timer(LanguageScreen.silence, () {
      if (!mounted || _chosen) return;
      if (_repeated) {
        unawaited(_choose(AppLocales.filipino));
      } else {
        _repeated = true;
        unawaited(_ask());
      }
    });
  }

  /// Saves [locale], confirms it in that language and moves on.
  Future<void> _choose(Locale locale) async {
    if (_chosen) return;
    _chosen = true;
    _timer?.cancel();
    // Read before awaiting: the screen may be gone afterwards.
    final router = ref.read(routerProvider);
    final announcer = ref.read(announcerProvider.notifier);
    final voices = ref.read(voiceStatusProvider);
    final tutorialSeen = ref.read(initialTutorialSeenProvider);
    final english = locale == AppLocales.english;
    try {
      await ref
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(locale: locale));
      await ref.read(userPrefsProvider).set(PrefKeys.languageChosen, true);
    } on Object catch (e) {
      debugPrint('Saving the language failed: $e');
    }
    final l = lookupAppLocalizations(locale);
    await announcer.say(
      english ? l.languageChosenEn : l.languageChosenFil,
      languageTag: english || !voices.filipinoReady
          ? voices.englishTag
          : voices.filipinoTag,
    );
    router.go(tutorialSeen ? AppRoutes.welcome : AppRoutes.tutorial);
  }

  static ScreenRegistration _registration(
    WidgetRef ref,
    Future<void> Function(Locale) choose,
    Future<void> Function() repeat,
  ) {
    return ScreenRegistration(
      id: LanguageScreen.screenId,
      // The bilingual question is spoken by the screen itself.
      prompt: (l) => '',
      listOptions: false,
      includeModeHint: false,
      autoListen: true,
      help: (l) => l.helpLanguage,
      actions: [
        A11yAction(
          id: Ids.languageTagalog,
          label: (l) => l.languageOptionTagalog,
          voiceSynonyms: const ['tagalog', 'filipino', 'pilipino'],
          confirmation: (_) => '',
          onActivate: (_) => choose(AppLocales.filipino),
        ),
        A11yAction(
          id: Ids.languageEnglish,
          label: (l) => l.languageOptionEnglish,
          voiceSynonyms: const ['english', 'ingles', 'inglés', 'ingles po'],
          confirmation: (_) => '',
          onActivate: (_) => choose(AppLocales.english),
        ),
      ],
      intentHandlers: {
        NavIntent.repeat: (_) => repeat(),
        // Nothing to go back to: say the question again.
        NavIntent.back: (_) => repeat(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final focused = ref.watch(focusControllerProvider);
    final bus = ref.read(commandBusProvider);
    final fil = lookupAppLocalizations(AppLocales.filipino);
    final en = lookupAppLocalizations(AppLocales.english);

    return AccessibleScreen(
      registration: (ref) => _registration(ref, _choose, () async {
        _repeated = true;
        await _ask();
      }),
      child: Scaffold(
        body: GestureSurface(
          child: SafeArea(
            child: PagePadding(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const EyeLogo(),
                  const Spacer(),
                  Semantics(
                    header: true,
                    child: Text(
                      '${fil.languagePromptFil}\n${en.languagePromptEn}',
                      style: textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${fil.languageGestureFil}\n${en.languageGestureEn}',
                    style: textTheme.titleMedium,
                  ),
                  const Spacer(),
                  PillButton(
                    label: l10n.languageOptionTagalog,
                    focused: focused == Ids.languageTagalog,
                    onPressed: () => bus.activate(Ids.languageTagalog),
                  ),
                  const SizedBox(height: AppDimens.buttonGap),
                  PillButton(
                    label: l10n.languageOptionEnglish,
                    variant: PillVariant.secondary,
                    focused: focused == Ids.languageEnglish,
                    onPressed: () => bus.activate(Ids.languageEnglish),
                  ),
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
