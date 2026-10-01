import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ids.dart';
import '../../app/router.dart';
import '../../core/accessibility/accessible_screen.dart';
import '../../core/accessibility/screen_registration.dart';
import '../../l10n/app_localizations.dart';
import 'choice_layout.dart';

/// "Nais mo bang mag login sa iyong account?" with Login and Register
/// (mockups `login_confirmation` / `register_confirmation`). Shown after
/// logging out, and at launch when the session has expired ("stay logged
/// in" off).
class AuthChoiceScreen extends ConsumerWidget {
  /// Creates the screen; [expired] adds "your session ended" to the prompt.
  const AuthChoiceScreen({super.key, this.expired = false});

  /// The session expired (rather than the user logging out).
  final bool expired;

  ScreenRegistration _registration(WidgetRef ref) => ScreenRegistration(
    id: Ids.authChoice,
    title: (l) => l.screenLogin,
    prompt: (l) => expired
        ? '${l.sessionExpired} ${l.authChoiceQuestion}'
        : l.authChoiceQuestion,
    autoListen: true,
    help: (l) => l.helpChooseList,
    actions: [
      A11yAction(
        id: Ids.authChoiceLogin,
        label: (l) => l.actionLogin,
        voiceSynonyms: const ['login', 'log in', 'mag-login', 'oo'],
        onActivate: (_) =>
            unawaited(ref.read(routerProvider).push(AppRoutes.login)),
      ),
      A11yAction(
        id: Ids.authChoiceRegister,
        label: (l) => l.actionRegister,
        voiceSynonyms: const ['register', 'mag-register'],
        onActivate: (_) =>
            unawaited(ref.read(routerProvider).push(AppRoutes.register)),
      ),
    ],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return AccessibleScreen(
      registration: _registration,
      child: ChoiceLayout(
        screenId: Ids.authChoice,
        title: l10n.screenLogin,
        question: l10n.authChoiceQuestion,
        buttons: [
          ChoiceButton(Ids.authChoiceLogin, l10n.actionLogin, primary: true),
          ChoiceButton(Ids.authChoiceRegister, l10n.actionRegister),
        ],
      ),
    );
  }
}
