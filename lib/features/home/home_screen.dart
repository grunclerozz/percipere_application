import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ids.dart';
import '../../app/router.dart';
import '../../config/constants.dart';
import '../../core/accessibility/accessible_screen.dart';
import '../../core/accessibility/command_bus.dart';
import '../../core/accessibility/focus_controller.dart';
import '../../core/accessibility/nav_intent.dart';
import '../../core/accessibility/screen_registration.dart';
import '../../core/widgets/gesture_pad_layout.dart';
import '../../core/widgets/guest_reminder_on_entry.dart';
import '../../core/widgets/live_speaking_zone.dart';
import '../../core/widgets/pill_button.dart';
import '../../core/widgets/small_link.dart';
import '../../l10n/app_localizations.dart';

/// Home: "Ano ang gusto mong gawin?" — read something new (Capture) or open
/// the Library (Aklatan). Where login, setup and guest mode lead, and where
/// Back from Capture and the Library returns to.
class HomeScreen extends ConsumerWidget {
  /// Creates Home.
  const HomeScreen({super.key});

  /// Screen id.
  static const String screenId = Ids.home;

  static ScreenRegistration _registration(WidgetRef ref) {
    return ScreenRegistration(
      id: screenId,
      title: (l) => l.screenHome,
      prompt: (l) => l.homePrompt,
      actions: [
        A11yAction(
          id: Ids.homeRead,
          label: (l) => l.homeRead,
          voiceSynonyms: const [
            'magbasa ng bago',
            'magbasa',
            'read something new',
            'bago',
          ],
          onActivate: (_) =>
              unawaited(ref.read(routerProvider).push(AppRoutes.capture)),
        ),
        A11yAction(
          id: Ids.homeLibrary,
          label: (l) => l.homeLibrary,
          voiceSynonyms: const ['aklatan', 'library', 'mga aklat'],
          onActivate: (bus) => bus.dispatch(NavIntent.library),
        ),
        A11yAction(
          id: Ids.homeSettings,
          label: (l) => l.captureSettings,
          voiceSynonyms: const ['settings', 'setting', 'ayos'],
          onActivate: (bus) => bus.dispatch(NavIntent.settings),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final focused = ref.watch(focusControllerProvider);
    final bus = ref.read(commandBusProvider);

    return AccessibleScreen(
      registration: _registration,
      child: GuestReminderOnEntry(
        screenId: screenId,
        moment: GuestReminderMoment.history,
        child: GesturePadLayout(
          padHint: l10n.gestureAreaHintMenu,
          content: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),
                    LiveSpeakingZone(
                      screenId: screenId,
                      fallback: l10n.homePrompt,
                    ),
                    const SizedBox(height: 12),
                    const Spacer(flex: 2),
                    PillButton(
                      label: l10n.homeRead,
                      focused: focused == Ids.homeRead,
                      onPressed: () => bus.activate(Ids.homeRead),
                    ),
                    const SizedBox(height: AppDimens.buttonGap),
                    PillButton(
                      label: l10n.homeLibrary,
                      variant: PillVariant.secondary,
                      focused: focused == Ids.homeLibrary,
                      onPressed: () => bus.activate(Ids.homeLibrary),
                    ),
                    const SizedBox(height: AppDimens.buttonGap),
                    SmallLink(
                      label: l10n.captureSettings,
                      icon: Icons.tune,
                      focused: focused == Ids.homeSettings,
                      onPressed: () => bus.activate(Ids.homeSettings),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
