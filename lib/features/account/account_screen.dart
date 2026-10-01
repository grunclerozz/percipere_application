import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ids.dart';
import '../../app/router.dart';
import '../../config/constants.dart';
import '../../core/accessibility/accessible_screen.dart';
import '../../core/accessibility/command_bus.dart';
import '../../core/accessibility/focus_controller.dart';
import '../../core/accessibility/screen_registration.dart';
import '../../core/widgets/gesture_pad_layout.dart';
import '../../core/widgets/live_speaking_zone.dart';
import '../../core/widgets/pill_button.dart';
import '../../l10n/app_localizations.dart';
import 'account_repository.dart';

/// Account: who is logged in, and create / log in / log out.
///
/// Everything works without an account (the phone's own settings are used).
/// A profile keeps its own settings and, from Phase 7, can sync with the web
/// admin app.
class AccountScreen extends ConsumerStatefulWidget {
  /// Creates the Account screen.
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool? _hasProfiles;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final profiles = await ref.read(accountRepositoryProvider).list();
    if (mounted) setState(() => _hasProfiles = profiles.isNotEmpty);
  }

  Future<void> _push(String route) async {
    await ref.read(routerProvider).push(route);
    if (mounted) await _refresh();
  }

  Future<void> _logout(CommandBus bus) async {
    await ref.read(currentAccountProvider.notifier).logout();
    await bus.say(bus.strings.accountLoggedOut);
  }

  ScreenRegistration _registration(WidgetRef ref) {
    final user = ref.read(currentAccountProvider);
    return ScreenRegistration(
      id: Ids.account,
      title: (l) => l.screenAccount,
      prompt: (l) =>
          user == null ? l.accountIntroGuest : l.accountIntroUser(user.name),
      actions: [
        if (user != null)
          A11yAction(
            id: Ids.accountLogout,
            label: (l) => l.accountLogout,
            voiceSynonyms: const ['logout', 'log out', 'lumabas'],
            confirmation: (_) => '',
            onActivate: _logout,
          )
        else ...[
          A11yAction(
            id: Ids.accountCreate,
            label: (l) => l.accountCreate,
            voiceSynonyms: const ['gumawa', 'bagong profile', 'create'],
            onActivate: (_) => _push(AppRoutes.createProfile),
          ),
          if (_hasProfiles ?? false)
            A11yAction(
              id: Ids.accountLogin,
              label: (l) => l.accountLogin,
              voiceSynonyms: const ['login', 'log in', 'pumasok'],
              onActivate: (_) => _push(AppRoutes.login),
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(currentAccountProvider);
    final focused = ref.watch(focusControllerProvider);
    final bus = ref.read(commandBusProvider);
    if (_hasProfiles == null) return const Scaffold();

    return AccessibleScreen(
      registration: _registration,
      dependencies: [user?.id, _hasProfiles],
      child: GesturePadLayout(
        padHint: l10n.gestureAreaHintMenu,
        content: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.screenAccount,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const Spacer(),
                  LiveSpeakingZone(
                    screenId: Ids.account,
                    fallback: user == null
                        ? l10n.accountIntroGuest
                        : l10n.accountIntroUser(user.name),
                  ),
                  const Spacer(),
                  if (user != null)
                    PillButton(
                      label: l10n.accountLogout,
                      focused: focused == Ids.accountLogout,
                      onPressed: () => bus.activate(Ids.accountLogout),
                    )
                  else ...[
                    PillButton(
                      label: l10n.accountCreate,
                      focused: focused == Ids.accountCreate,
                      onPressed: () => bus.activate(Ids.accountCreate),
                    ),
                    if (_hasProfiles!) ...[
                      const SizedBox(height: AppDimens.buttonGap),
                      PillButton(
                        label: l10n.accountLogin,
                        variant: PillVariant.secondary,
                        focused: focused == Ids.accountLogin,
                        onPressed: () => bus.activate(Ids.accountLogin),
                      ),
                    ],
                  ],
                  const Spacer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
