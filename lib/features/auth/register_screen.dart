import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ids.dart';
import '../../app/router.dart';
import '../../core/accessibility/accessible_screen.dart';
import '../../core/accessibility/command_bus.dart';
import '../../core/accessibility/focus_controller.dart';
import '../../core/accessibility/haptics.dart';
import '../../core/accessibility/screen_registration.dart';
import '../../core/auth/account_api.dart';
import '../../core/auth/account_repository.dart';
import '../../core/auth/account_service.dart';
import '../../core/auth/biometrics.dart';
import '../../core/auth/session.dart';
import '../../core/auth/validators.dart';
import '../../core/widgets/pill_button.dart';
import '../../l10n/app_localizations.dart';
import 'form_scaffold.dart';
import 'server_error_text.dart';
import 'voice_form.dart';

/// Register: First Name, Last Name, Email Address, Password, then Submit.
///
/// Each field is asked by voice ("Ano ang iyong email address?") and can be
/// dictated or typed; values are read back (the password only by length).
/// Submit with a double-tap on the Gesture Pad or "submit" / "tapos na".
/// A guest who registers keeps their settings and history.
///
/// With web app accounts the account is created on the server (no email, no
/// code) and the user is logged in right away. An account that waits for an
/// administrator is tried too; when that doesn't work yet, the user is told
/// to try logging in and goes back to Welcome.
class RegisterScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  late final VoiceField _first = VoiceField(
    id: 'register.firstName',
    kind: FieldKind.name,
    label: (l) => l.fieldFirstName,
    prompt: (l) => l.askFirstName,
  );
  late final VoiceField _last = VoiceField(
    id: 'register.lastName',
    kind: FieldKind.name,
    label: (l) => l.fieldLastName,
    prompt: (l) => l.askLastName,
  );
  late final VoiceField _email = VoiceField(
    id: 'register.email',
    kind: FieldKind.email,
    label: (l) => l.fieldEmail,
    prompt: (l) => l.askEmail,
  );
  late final VoiceField _password = VoiceField(
    id: 'register.password',
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
  void initState() {
    super.initState();
    focusFirstFieldWhenActive(ref, Ids.register, () => _form);
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _submit(CommandBus bus) async {
    if (_busy) return;
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
    if (await repo.emailTaken(_email.value)) {
      return reportInvalid(_form, _email, l.emailTaken, bus, ref);
    }

    setState(() => _busy = true);
    unawaited(bus.say(l.registerWorking));
    final service = ref.read(accountServiceProvider);
    if (service.usesServer) {
      try {
        return await _registerOnServer(service, bus);
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
    try {
      final account = await repo.register(
        firstName: _first.value,
        lastName: _last.value,
        email: _email.value,
        password: _password.value,
      );
      if (!mounted) return;
      await ref
          .read(currentAccountProvider.notifier)
          .completeRegistration(account);
      unawaited(ref.read(hapticsProvider).confirm());
      await bus.say(l.registerDone(account.firstName), protect: true);
      if (mounted) ref.read(routerProvider).go(AppRoutes.securityQuestion);
    } on EmailTakenException {
      if (mounted) await reportInvalid(_form, _email, l.emailTaken, bus, ref);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _registerOnServer(AccountService service, CommandBus bus) async {
    final l = bus.strings;
    final email = AuthRules.normalizeEmail(_email.value);
    try {
      final result = await service.register(
        firstName: _first.value,
        lastName: _last.value,
        email: email,
        password: _password.value,
      );
      if (!mounted) return;
      final router = ref.read(routerProvider);
      final account = result.account;
      if (account == null) {
        // Created, but the login didn't work (yet): never get stuck here.
        unawaited(ref.read(hapticsProvider).confirm());
        await bus.say(l.registerCreatedTryLogin, protect: true);
        if (mounted) router.go(AppRoutes.login);
        return;
      }
      await ref
          .read(currentAccountProvider.notifier)
          .completeRegistration(account);
      unawaited(ref.read(hapticsProvider).confirm());
      await bus.say(l.registerDone(account.firstName), protect: true);
      final fingerprint = await ref.read(biometricsProvider).available();
      if (mounted) {
        router.go(fingerprint ? AppRoutes.fingerprintOffer : AppRoutes.setup);
      }
    } on AccountApiException catch (e) {
      if (!mounted) return;
      if (e.error == AccountApiError.emailTaken) {
        return reportInvalid(_form, _email, l.emailTakenServer, bus, ref);
      }
      unawaited(ref.read(hapticsProvider).error());
      await bus.say(serverErrorText(e, l));
    } on Object catch (e) {
      debugPrint('Register failed: $e');
      if (mounted) await bus.say(l.serverProblem);
    }
  }

  ScreenRegistration _registration(WidgetRef ref) => ScreenRegistration(
    id: Ids.register,
    title: (l) => l.screenRegister,
    prompt: (l) => '${l.formIntro} ${_form.focusStart(l)}',
    autoListen: true,
    listOptions: false,
    includeModeHint: false,
    help: (l) => l.helpForm,
    onUtterance: _form.onUtterance,
    hasUnsavedInput: () => _form.hasInput,
    actions: _form.actions(Ids.registerSubmit),
    intentHandlers: _form.intents(),
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
        screenId: Ids.register,
        title: l10n.screenRegister,
        subtitle: focused?.prompt(l10n) ?? l10n.formSubmitHint,
        child: VoiceFormView(
          form: _form,
          rows: [
            [_first, _last],
            [_email],
            [_password],
          ],
          submitId: Ids.registerSubmit,
          submit: PillButton(
            label: l10n.actionSubmit,
            focused: focusedId == Ids.registerSubmit,
            onPressed: _busy ? null : () => bus.activate(Ids.registerSubmit),
          ),
        ),
      ),
    );
  }
}
