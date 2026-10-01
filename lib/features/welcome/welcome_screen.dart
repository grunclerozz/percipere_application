import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ids.dart';
import '../../app/locale_provider.dart';
import '../../app/router.dart';
import '../../app/theme/app_palette.dart';
import '../../config/constants.dart';
import '../../core/accessibility/accessible_screen.dart';
import '../../core/accessibility/announcer.dart';
import '../../core/accessibility/command_bus.dart';
import '../../core/accessibility/focus_controller.dart';
import '../../core/accessibility/nav_intent.dart';
import '../../core/accessibility/navigation_mode.dart';
import '../../core/accessibility/screen_registration.dart';
import '../../core/gestures/gesture_surface.dart';
import '../../core/platform/system_settings.dart';
import '../../core/tts/tts_service.dart';
import '../../core/voice/voice_controller.dart';
import '../../core/widgets/live_speaking_zone.dart';
import '../../core/widgets/pill_button.dart';
import '../../l10n/app_localizations.dart';

/// Screen A — Welcome / navigation mode selection.
///
/// No Gesture Pad here: the whole screen is the gesture surface. Double-tap
/// chooses voice, swipe right chooses gestures, tap repeats. When no Filipino
/// voice is installed, swipe up opens Android's TTS settings.
class WelcomeScreen extends ConsumerWidget {
  /// Creates the Welcome screen.
  const WelcomeScreen({super.key});

  /// Screen id.
  static const String screenId = Ids.welcome;

  /// Action: choose voice navigation.
  static const String voiceAction = Ids.welcomeVoice;

  /// Action: choose gesture navigation.
  static const String gesturesAction = Ids.welcomeGestures;

  static ScreenRegistration _registration(WidgetRef ref) {
    final voice = ref.read(voiceControllerProvider.notifier);

    Future<void> choose(NavMode mode) async {
      await ref.read(navigationModeProvider.notifier).set(mode);
      // Choosing voice is when we ask for the microphone (with a spoken
      // explanation first), so the Android dialog never comes unannounced.
      if (mode == NavMode.voice) {
        await voice.ensureReady(requestPermission: true);
      }
      ref.read(routerProvider).go(AppRoutes.capture);
    }

    return ScreenRegistration(
      id: screenId,
      // "Say boses/galaw" is only offered once the mic is already allowed.
      prompt: (l) => voice.micGranted
          ? '${l.welcomeIntro} ${l.welcomeSayHint}'
          : l.welcomeIntro,
      autoListen: true,
      listOptions: false,
      includeModeHint: false,
      help: (l) => l.helpWelcome,
      actions: [
        A11yAction(
          id: voiceAction,
          label: (l) => l.navModeVoice,
          voiceSynonyms: const ['boses', 'pa-boses', 'voice'],
          confirmation: (l) => l.modeChosenVoice,
          onActivate: (_) => choose(NavMode.voice),
        ),
        A11yAction(
          id: gesturesAction,
          label: (l) => l.navModeGestures,
          voiceSynonyms: const ['galaw', 'pa-galaw', 'gestures', 'gesture'],
          confirmation: (l) => l.modeChosenGestures,
          onActivate: (_) => choose(NavMode.gestures),
        ),
      ],
      intentHandlers: {
        NavIntent.activate: (bus) => bus.activate(voiceAction),
        NavIntent.next: (bus) => bus.activate(gesturesAction),
        NavIntent.faster: (bus) => _openTtsSettings(ref, bus),
      },
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
  Widget build(BuildContext context, WidgetRef ref) {
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
                        const Spacer(flex: 3),
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
                          screenId: screenId,
                          fallback: l10n.welcomePrompt,
                        ),
                        const SizedBox(height: 24),
                        const Spacer(flex: 2),
                        PillButton(
                          label: l10n.navModeVoice,
                          focused: focused == voiceAction,
                          onPressed: () => bus.activate(voiceAction),
                        ),
                        const SizedBox(height: AppDimens.buttonGap),
                        PillButton(
                          label: l10n.navModeGestures,
                          variant: PillVariant.secondary,
                          focused: focused == gesturesAction,
                          onPressed: () => bus.activate(gesturesAction),
                        ),
                        const Spacer(flex: 4),
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
