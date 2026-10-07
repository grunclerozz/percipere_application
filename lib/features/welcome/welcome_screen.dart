import 'dart:async';

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
import '../../core/accessibility/nav_intent.dart';
import '../../core/accessibility/screen_registration.dart';
import '../../core/auth/session.dart';
import '../../core/db/daos/preferences_dao.dart';
import '../../core/gestures/gesture_surface.dart';
import '../../core/platform/system_settings.dart';
import '../../core/tts/tts_service.dart';
import '../../core/voice/voice_controller.dart';
import '../../core/widgets/eye_logo.dart';
import '../../core/widgets/live_speaking_zone.dart';
import '../../core/widgets/pill_button.dart';
import '../../l10n/app_localizations.dart';

/// Screen A — Welcome: Login, Register, or "Subukan muna (Try first)".
///
/// No Gesture Pad here: the whole screen is the gesture surface. The
/// navigation mode isn't chosen yet, so voice and gestures both work:
/// swipe right/left moves between the buttons, double-tap presses the
/// focused one, tap repeats; or say "login", "register" or "subukan". On
/// first launch the microphone is requested right after the introduction.
/// When no Filipino voice is installed, swipe up opens Android's TTS
/// settings.
class WelcomeScreen extends ConsumerStatefulWidget {
  /// Creates the Welcome screen.
  const WelcomeScreen({super.key});

  /// Screen id.
  static const String screenId = Ids.welcome;

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(activeScreenProvider, (previous, next) {
      if (next?.id == WelcomeScreen.screenId &&
          previous?.id != WelcomeScreen.screenId) {
        unawaited(_askMicOnce());
      }
    });
  }

  /// First launch: once the introduction has been spoken, explain and ask
  /// for the microphone so "login" / "register" can be said right away.
  Future<void> _askMicOnce() async {
    final voice = ref.read(voiceControllerProvider.notifier);
    if (voice.micGranted) return;
    final prefs = ref.read(userPrefsProvider);
    if (await prefs.get(PrefKeys.micAsked) == true) return;
    await ref.read(announcerProvider.notifier).idle();
    if (!mounted || ref.read(activeScreenProvider)?.id != Ids.welcome) return;
    await prefs.set(PrefKeys.micAsked, true);
    if (await voice.ensureReady(requestPermission: true) && mounted) {
      final bus = ref.read(commandBusProvider);
      await bus.say(bus.strings.welcomeVoiceReady);
    }
  }

  static ScreenRegistration _registration(WidgetRef ref) {
    final voice = ref.read(voiceControllerProvider.notifier);

    Future<void> guest(CommandBus bus) async {
      // Read before awaiting: the screen may be gone afterwards.
      final router = ref.read(routerProvider);
      final session = ref.read(currentAccountProvider.notifier);
      final account = await session.startGuest(bus.strings.guestName);
      router.go(AppRoutes.landing(account));
    }

    return ScreenRegistration(
      id: WelcomeScreen.screenId,
      title: (l) => l.screenWelcome,
      // "Say login/register" is only offered once the mic is allowed.
      prompt: (l) =>
          '${l.welcomeAccountPrompt} '
          '${voice.micGranted ? l.welcomeHintVoice : l.welcomeHintGestures}',
      autoListen: true,
      listOptions: false,
      includeModeHint: false,
      help: (l) => l.helpWelcome,
      actions: [
        A11yAction(
          id: Ids.welcomeLogin,
          label: (l) => l.actionLogin,
          voiceSynonyms: const ['login', 'log in', 'mag-login', 'pumasok'],
          onActivate: (_) =>
              unawaited(ref.read(routerProvider).push(AppRoutes.login)),
        ),
        A11yAction(
          id: Ids.welcomeRegister,
          label: (l) => l.actionRegister,
          voiceSynonyms: const ['register', 'mag-register', 'magparehistro'],
          onActivate: (_) =>
              unawaited(ref.read(routerProvider).push(AppRoutes.register)),
        ),
        A11yAction(
          id: Ids.welcomeGuest,
          label: (l) => l.actionTryFirst,
          voiceSynonyms: const [
            'subukan',
            'subukan muna',
            'try first',
            'try',
            'guest',
          ],
          onActivate: guest,
        ),
      ],
      intentHandlers: {NavIntent.faster: (bus) => _openTtsSettings(ref, bus)},
    );
  }

  /// Swipe up: open TTS settings, but only while the Filipino voice is
  /// missing (the startup notice tells the user about it).
  static Future<void> _openTtsSettings(WidgetRef ref, CommandBus bus) async {
    final voices = ref.read(voiceStatusProvider);
    if (voices.filipinoReady) return bus.notAvailable();
    final en = lookupAppLocalizations(AppLocales.english);
    await ref
        .read(announcerProvider.notifier)
        .say(en.ttsOpeningSettings, languageTag: voices.englishTag);
    await ref.read(systemSettingsProvider).openTtsSettings();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final focused = ref.watch(focusControllerProvider);
    final bus = ref.read(commandBusProvider);

    return AccessibleScreen(
      registration: _registration,
      child: Scaffold(
        body: GestureSurface(
          child: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.pagePadding,
                      vertical: 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const EyeLogo(),
                        const Spacer(flex: 2),
                        Semantics(
                          header: true,
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: '${l10n.welcomeTitleLine1}\n'),
                                TextSpan(
                                  text: l10n.appName,
                                  style: TextStyle(
                                    color: context.palette.primary,
                                  ),
                                ),
                              ],
                            ),
                            style: textTheme.headlineLarge,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          l10n.welcomeSubtitle,
                          style: textTheme.titleMedium,
                        ),
                        const Spacer(flex: 2),
                        const SizedBox(height: 24),
                        LiveSpeakingZone(
                          screenId: WelcomeScreen.screenId,
                          fallback: l10n.welcomeHasAccount,
                        ),
                        const SizedBox(height: 24),
                        const Spacer(),
                        PillButton(
                          label: l10n.actionLogin,
                          focused: focused == Ids.welcomeLogin,
                          onPressed: () => bus.activate(Ids.welcomeLogin),
                        ),
                        const SizedBox(height: AppDimens.buttonGap),
                        PillButton(
                          label: l10n.actionRegister,
                          variant: PillVariant.secondary,
                          focused: focused == Ids.welcomeRegister,
                          onPressed: () => bus.activate(Ids.welcomeRegister),
                        ),
                        const SizedBox(height: AppDimens.buttonGap),
                        PillButton(
                          label: l10n.actionTryFirst,
                          variant: PillVariant.tertiary,
                          focused: focused == Ids.welcomeGuest,
                          onPressed: () => bus.activate(Ids.welcomeGuest),
                        ),
                        const Spacer(flex: 3),
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
