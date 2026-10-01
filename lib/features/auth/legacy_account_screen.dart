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
import '../../core/auth/account.dart';
import '../../core/auth/account_repository.dart';
import '../../core/auth/session.dart';
import '../../core/tts/speech_language.dart';
import '../../core/widgets/pill_button.dart';
import '../../l10n/app_localizations.dart';
import 'form_scaffold.dart';
import 'legacy_pin.dart';

/// Claiming an old name + PIN account (made before Phase 6B): choose it,
/// enter its old PIN once, then set an email and password
/// (`UpgradeAccountScreen`). Settings and history are kept.
class LegacyAccountScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const LegacyAccountScreen({super.key});

  @override
  ConsumerState<LegacyAccountScreen> createState() =>
      _LegacyAccountScreenState();
}

class _LegacyAccountScreenState extends ConsumerState<LegacyAccountScreen> {
  List<Account>? _accounts;
  Account? _chosen;
  late final PinEntry _pin = PinEntry(onComplete: _onPin);

  AppLocalizations get _l => ref.read(speechLanguageProvider).strings;
  CommandBus get _bus => ref.read(commandBusProvider);

  @override
  void initState() {
    super.initState();
    unawaited(
      ref.read(accountRepositoryProvider).legacyAccounts().then((a) {
        if (mounted) setState(() => _accounts = a);
      }),
    );
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _onPin(String pin) async {
    final a = _chosen!;
    if (!await ref.read(accountRepositoryProvider).verifyLegacyPin(a.id, pin)) {
      unawaited(ref.read(hapticsProvider).error());
      return _bus.say(_l.loginWrongPin);
    }
    await ref.read(currentAccountProvider.notifier).login(a);
    unawaited(ref.read(hapticsProvider).confirm());
    await _bus.say(_l.legacyClaimed(a.firstName), protect: true);
    if (mounted) ref.read(routerProvider).go(AppRoutes.upgradeAccount);
  }

  ScreenRegistration _registration(WidgetRef ref) {
    final chosen = _chosen;
    final accounts = _accounts ?? const [];
    if (chosen != null) {
      return ScreenRegistration(
        id: '${Ids.legacyAccount}.pin',
        title: (l) => l.screenLegacyAccount,
        prompt: (l) => l.loginAskPin(chosen.firstName),
        includeModeHint: false,
        autoListen: true,
        help: (l) => l.helpPin,
        onUtterance: (text, bus) => _pin.takeSpoken(text, bus, _l),
        intentHandlers: {
          ..._pin.intents(ref, () => _l),
          NavIntent.back: (_) => setState(() => _chosen = null),
        },
      );
    }
    return ScreenRegistration(
      id: Ids.legacyAccount,
      title: (l) => l.screenLegacyAccount,
      prompt: (l) => accounts.isEmpty ? l.legacyNone : l.legacyChoose,
      autoListen: true,
      help: (l) => l.helpChooseList,
      actions: [
        for (final a in accounts)
          A11yAction(
            id: 'legacy.${a.id}',
            label: (_) => a.firstName,
            confirmation: (_) => '',
            onActivate: (_) {
              _pin.clear();
              setState(() => _chosen = a);
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final focused = ref.watch(focusControllerProvider);
    final bus = ref.read(commandBusProvider);
    final accounts = _accounts;
    if (accounts == null) return const Scaffold();
    final chosen = _chosen;

    return AccessibleScreen(
      registration: _registration,
      dependencies: [chosen?.id, accounts.length],
      child: FormScaffold(
        screenId: chosen == null ? Ids.legacyAccount : '${Ids.legacyAccount}.pin',
        title: l10n.screenLegacyAccount,
        subtitle: chosen != null
            ? l10n.loginAskPin(chosen.firstName)
            : accounts.isEmpty
            ? l10n.legacyNone
            : l10n.legacyChoose,
        padHint: chosen != null ? l10n.helpPin : l10n.helpChooseList,
        child: chosen == null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final a in accounts) ...[
                    PillButton(
                      label: a.firstName,
                      variant: PillVariant.secondary,
                      focused: focused == 'legacy.${a.id}',
                      onPressed: () => bus.activate('legacy.${a.id}'),
                    ),
                    const SizedBox(height: AppDimens.buttonGap),
                  ],
                ],
              )
            : PinPad(
                entry: _pin,
                onDigit: (d) {
                  tickFor(ref);
                  unawaited(_pin.add(d, bus, _l));
                },
                onDelete: () => unawaited(_pin.deleteLast(bus, _l)),
              ),
      ),
    );
  }
}
