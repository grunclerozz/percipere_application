import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ids.dart';
import '../../app/router.dart';
import '../../config/constants.dart';
import '../../core/accessibility/accessible_screen.dart';
import '../../core/accessibility/command_bus.dart';
import '../../core/accessibility/focus_controller.dart';
import '../../core/accessibility/haptics.dart';
import '../../core/accessibility/nav_intent.dart';
import '../../core/accessibility/screen_registration.dart';
import '../../core/tts/speech_language.dart';
import '../../core/widgets/gesture_pad_layout.dart';
import '../../core/widgets/pill_button.dart';
import '../../l10n/app_localizations.dart';
import 'account_repository.dart';
import 'pin_input.dart';

/// Logging in: choose a profile (swipe + double-tap, or say the name), then
/// enter its PIN (gestures, keypad or voice).
class LoginScreen extends ConsumerStatefulWidget {
  /// Creates the login screen.
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  List<Account>? _profiles;
  Account? _chosen;
  late final PinEntry _pin = PinEntry(onComplete: _onPin);

  AppLocalizations get _l => ref.read(speechLanguageProvider).strings;
  CommandBus get _bus => ref.read(commandBusProvider);

  @override
  void initState() {
    super.initState();
    unawaited(
      ref.read(accountRepositoryProvider).list().then((p) {
        if (mounted) setState(() => _profiles = p);
      }),
    );
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _choose(Account a) async {
    setState(() => _chosen = a);
    _pin.clear();
    await _bus.say(_l.loginAskPin(a.name));
  }

  Future<void> _onPin(String pin) async {
    final a = _chosen!;
    if (!await ref.read(accountRepositoryProvider).verify(a.id, pin)) {
      unawaited(ref.read(hapticsProvider).error());
      return _bus.say(_l.loginWrongPin);
    }
    await ref.read(currentAccountProvider.notifier).login(a);
    unawaited(ref.read(hapticsProvider).confirm());
    await _bus.say(_l.accountLoggedIn(a.name), protect: true);
    if (mounted) ref.read(routerProvider).pop();
  }

  ScreenRegistration _registration(WidgetRef ref) {
    final chosen = _chosen;
    final profiles = _profiles ?? const [];
    return ScreenRegistration(
      id: Ids.login,
      title: (l) => l.screenLogin,
      prompt: (l) => chosen != null
          ? l.loginAskPin(chosen.name)
          : profiles.isEmpty
          ? l.loginNoProfiles
          : l.loginChooseProfile,
      includeModeHint: chosen == null,
      help: chosen != null ? (l) => l.helpPin : null,
      onUtterance: chosen == null
          ? null
          : (text, bus) => _pin.takeSpoken(text, bus, _l),
      actions: chosen != null
          ? const []
          : [
              for (final a in profiles)
                A11yAction(
                  id: 'login.${a.id}',
                  label: (_) => a.name,
                  confirmation: (_) => '',
                  onActivate: (_) => _choose(a),
                ),
            ],
      intentHandlers: chosen != null
          ? {
              ..._pin.intents(ref, () => _l),
              // Back from the PIN goes back to choosing a profile.
              NavIntent.back: (bus) {
                setState(() => _chosen = null);
                return bus.say(bus.strings.loginChooseProfile);
              },
            }
          : const {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final focused = ref.watch(focusControllerProvider);
    final bus = ref.read(commandBusProvider);
    final profiles = _profiles;
    if (profiles == null) return const Scaffold();
    final chosen = _chosen;

    return AccessibleScreen(
      registration: _registration,
      dependencies: [chosen?.id, profiles.length],
      child: GesturePadLayout(
        padHint: chosen != null ? l10n.helpPin : l10n.gestureAreaHintMenu,
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(l10n.screenLogin, style: textTheme.titleLarge),
              ),
              const SizedBox(height: 12),
              Text(
                chosen != null
                    ? l10n.loginAskPin(chosen.name)
                    : profiles.isEmpty
                    ? l10n.loginNoProfiles
                    : l10n.loginChooseProfile,
                style: textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              if (chosen == null)
                for (final a in profiles) ...[
                  PillButton(
                    label: a.name,
                    variant: PillVariant.secondary,
                    focused: focused == 'login.${a.id}',
                    onPressed: () => bus.activate('login.${a.id}'),
                  ),
                  const SizedBox(height: AppDimens.buttonGap),
                ]
              else
                PinPad(
                  entry: _pin,
                  onDigit: (d) {
                    tickFor(ref);
                    unawaited(_pin.add(d, bus, _l));
                  },
                  onDelete: () => unawaited(_pin.deleteLast(bus, _l)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
