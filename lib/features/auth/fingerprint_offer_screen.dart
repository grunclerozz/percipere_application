import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ids.dart';
import '../../app/router.dart';
import '../../core/accessibility/accessible_screen.dart';
import '../../core/accessibility/command_bus.dart';
import '../../core/accessibility/haptics.dart';
import '../../core/accessibility/nav_intent.dart';
import '../../core/accessibility/screen_registration.dart';
import '../../core/auth/account_repository.dart';
import '../../core/auth/biometrics.dart';
import '../../core/auth/session.dart';
import '../../core/auth/session_store.dart';
import '../../l10n/app_localizations.dart';
import 'choice_layout.dart';

/// After registering (when the phone has a fingerprint enrolled): "Gusto mo
/// bang gamitin ang iyong fingerprint sa pag-login?" Oo checks the finger
/// once and turns fingerprint login on; Hindi skips. Then the guided setup.
/// Never offered to guests.
class FingerprintOfferScreen extends ConsumerWidget {
  /// Creates the screen.
  const FingerprintOfferScreen({super.key});

  static const String _yes = '${Ids.fingerprintOffer}.yes';
  static const String _no = '${Ids.fingerprintOffer}.no';

  static Future<void> _enable(WidgetRef ref, CommandBus bus) async {
    // Everything read up front: the screen may be gone after an await.
    final account = ref.read(currentAccountProvider);
    final router = ref.read(routerProvider);
    final haptics = ref.read(hapticsProvider);
    final repo = ref.read(accountRepositoryProvider);
    final sessions = ref.read(sessionStoreProvider);
    final session = ref.read(currentAccountProvider.notifier);
    final l = bus.strings;
    if (account == null || account.isGuest) return _next(ref);
    final result = await ref
        .read(biometricsProvider)
        .authenticate(l.fingerprintReason);
    if (result == BiometricResult.success) {
      await repo.setFingerprint(account.id, true);
      await sessions.writeFingerprintUserId(account.id);
      await session.refresh();
      unawaited(haptics.confirm());
      await bus.say(l.fingerprintOn, protect: true);
    } else {
      unawaited(haptics.error());
      await bus.say(l.fingerprintNotSet, protect: true);
    }
    router.go(AppRoutes.setup);
  }

  static void _next(WidgetRef ref) =>
      ref.read(routerProvider).go(AppRoutes.setup);

  ScreenRegistration _registration(WidgetRef ref) => ScreenRegistration(
    id: Ids.fingerprintOffer,
    title: (l) => l.screenFingerprint,
    prompt: (l) => l.fingerprintOffer,
    help: (l) => l.helpChooseList,
    autoListen: true,
    actions: [
      A11yAction(
        id: _yes,
        label: (l) => l.answerYes,
        voiceSynonyms: const ['oo', 'opo', 'yes', 'sige', 'gamitin'],
        confirmation: (_) => '',
        onActivate: (bus) => _enable(ref, bus),
      ),
      A11yAction(
        id: _no,
        label: (l) => l.answerNo,
        voiceSynonyms: const ['hindi', 'huwag', 'no', 'laktawan', 'skip'],
        confirmation: (l) => l.fingerprintSkipped,
        onActivate: (_) => _next(ref),
      ),
    ],
    intentHandlers: {
      // Same as "Hindi": the account is made; carry on to the setup.
      NavIntent.back: (bus) => bus.activate(_no),
    },
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return AccessibleScreen(
      registration: _registration,
      child: ChoiceLayout(
        screenId: Ids.fingerprintOffer,
        title: l10n.screenFingerprint,
        question: l10n.fingerprintOffer,
        buttons: [
          ChoiceButton(_yes, l10n.answerYes, primary: true),
          ChoiceButton(_no, l10n.answerNo),
        ],
      ),
    );
  }
}
