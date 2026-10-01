import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ids.dart';
import '../../app/router.dart';
import '../../core/accessibility/accessible_screen.dart';
import '../../core/accessibility/command_bus.dart';
import '../../core/accessibility/focus_controller.dart';
import '../../core/accessibility/haptics.dart';
import '../../core/accessibility/nav_intent.dart';
import '../../core/accessibility/screen_registration.dart';
import '../../core/auth/account_repository.dart';
import '../../core/auth/account_sync_repository.dart';
import '../../core/auth/session.dart';
import '../../core/auth/validators.dart';
import '../../core/widgets/pill_button.dart';
import '../../l10n/app_localizations.dart';
import 'form_scaffold.dart';
import 'voice_form.dart';

/// An old name + PIN account (logged in, or just claimed) sets an email and
/// password, keeping its settings and history. Same form as Register, with
/// the old name filled in.
class UpgradeAccountScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const UpgradeAccountScreen({super.key});

  @override
  ConsumerState<UpgradeAccountScreen> createState() =>
      _UpgradeAccountScreenState();
}

class _UpgradeAccountScreenState extends ConsumerState<UpgradeAccountScreen> {
  late final VoiceField _first = VoiceField(
    id: 'upgrade.firstName',
    kind: FieldKind.name,
    label: (l) => l.fieldFirstName,
    prompt: (l) => l.askFirstName,
    initial: ref.read(currentAccountProvider)?.firstName ?? '',
  );
  late final VoiceField _last = VoiceField(
    id: 'upgrade.lastName',
    kind: FieldKind.name,
    label: (l) => l.fieldLastName,
    prompt: (l) => l.askLastName,
  );
  late final VoiceField _email = VoiceField(
    id: 'upgrade.email',
    kind: FieldKind.email,
    label: (l) => l.fieldEmail,
    prompt: (l) => l.askEmail,
  );
  late final VoiceField _password = VoiceField(
    id: 'upgrade.password',
    kind: FieldKind.password,
    label: (l) => l.fieldPassword,
    prompt: (l) => l.askNewPassword,
  );
  late final VoiceForm _form = VoiceForm(
    ref: ref,
    fields: [_first, _last, _email, _password],
    onSubmit: _submit,
  );
  bool _busy = false;

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _submit(CommandBus bus) async {
    final account = ref.read(currentAccountProvider);
    if (_busy || account == null) return;
    final l = bus.strings;
    final missing = [
      for (final f in _form.fields)
        if (f.isEmpty) f,
    ];
    if (missing.isNotEmpty) {
      return reportInvalid(
        _form,
        missing.first,
        l.formMissing(missing.map((f) => f.label(l)).join(', ')),
        bus,
        ref,
      );
    }
    if (!AuthRules.isValidEmail(_email.value)) {
      return reportInvalid(_form, _email, l.emailInvalid, bus, ref);
    }
    if (!AuthRules.isValidPassword(_password.value)) {
      return reportInvalid(
        _form,
        _password,
        l.passwordTooShort(_password.value.length),
        bus,
        ref,
      );
    }
    final repo = ref.read(accountRepositoryProvider);
    if (await repo.emailTaken(_email.value, exceptId: account.id)) {
      return reportInvalid(_form, _email, l.emailTaken, bus, ref);
    }
    setState(() => _busy = true);
    try {
      final upgraded = await repo.upgradeLegacy(
        account.id,
        firstName: _first.value,
        lastName: _last.value,
        email: _email.value,
        password: _password.value,
      );
      await ref.read(currentAccountProvider.notifier).refresh();
      await ref.read(accountSyncRepositoryProvider).enqueue(upgraded);
      unawaited(ref.read(hapticsProvider).confirm());
      await bus.say(l.upgradeDone, protect: true);
      if (mounted) ref.read(routerProvider).go(AppRoutes.securityQuestion);
    } on EmailTakenException {
      if (mounted) await reportInvalid(_form, _email, l.emailTaken, bus, ref);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  ScreenRegistration _registration(WidgetRef ref) => ScreenRegistration(
    id: Ids.upgradeAccount,
    title: (l) => l.screenUpgradeAccount,
    prompt: (l) => '${l.upgradeIntro} ${_form.focusStart(l)}',
    autoListen: true,
    listOptions: false,
    includeModeHint: false,
    help: (l) => l.helpForm,
    onUtterance: _form.onUtterance,
    actions: _form.actions(Ids.upgradeSubmit),
    intentHandlers: {
      ..._form.intents(),
      // Leaving means logging out of the old account.
      NavIntent.back: (bus) => bus.offer(bus.strings.upgradeLeave, () async {
        await ref.read(currentAccountProvider.notifier).logout();
        ref.read(routerProvider).go(AppRoutes.welcome);
      }),
    },
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final focusedId = ref.watch(focusControllerProvider);
    final bus = ref.read(commandBusProvider);
    final focused = _form.fields.where((f) => f.id == focusedId).firstOrNull;

    return AccessibleScreen(
      registration: _registration,
      child: FormScaffold(
        screenId: Ids.upgradeAccount,
        title: l10n.screenUpgradeAccount,
        subtitle: focused?.prompt(l10n) ?? l10n.upgradeIntro,
        child: VoiceFormView(
          form: _form,
          rows: [
            [_first, _last],
            [_email],
            [_password],
          ],
          submitId: Ids.upgradeSubmit,
          submit: PillButton(
            label: l10n.actionSubmit,
            focused: focusedId == Ids.upgradeSubmit,
            onPressed: _busy ? null : () => bus.activate(Ids.upgradeSubmit),
          ),
        ),
      ),
    );
  }
}
