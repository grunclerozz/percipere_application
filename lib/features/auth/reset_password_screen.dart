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
import '../../core/auth/account_api.dart';
import '../../core/auth/account_service.dart';
import '../../core/auth/login_throttle.dart';
import '../../core/auth/session.dart';
import '../../core/auth/validators.dart';
import '../../core/widgets/pill_button.dart';
import '../../core/widgets/small_link.dart';
import '../../l10n/app_localizations.dart';
import 'form_scaffold.dart';
import 'verify_email_screen.dart';
import 'voice_form.dart';

/// Forgot password for web app accounts: the email → a code is emailed →
/// the code and a new password. The new password works at once, every
/// other device is logged out, and the user is logged in here.
/// (Accounts kept only on the phone use `ForgotPasswordScreen`'s security
/// question instead.)
class ResetPasswordScreen extends ConsumerStatefulWidget {
  /// Creates the screen, starting with [email] if the Login form had one.
  const ResetPasswordScreen({super.key, this.email});

  /// Email typed on Login, if any.
  final String? email;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  bool _codeSent = false;
  bool _busy = false;

  late final VoiceField _email = VoiceField(
    id: 'resetPassword.email',
    kind: FieldKind.email,
    label: (l) => l.fieldEmail,
    prompt: (l) => l.askEmail,
    initial: widget.email ?? '',
  );
  late final VoiceField _code = VoiceField(
    id: 'resetPassword.code',
    kind: FieldKind.code,
    label: (l) => l.fieldCode,
    prompt: (l) => l.askCode,
  );
  late final VoiceField _password = VoiceField(
    id: 'resetPassword.password',
    kind: FieldKind.password,
    label: (l) => l.fieldNewPassword,
    prompt: (l) => l.askNewPassword,
  );
  late final VoiceForm _emailForm = VoiceForm(
    ref: ref,
    fields: [_email],
    onSubmit: _sendCode,
  );
  late final VoiceForm _codeForm = VoiceForm(
    ref: ref,
    fields: [_code, _password],
    onSubmit: _reset,
  );

  VoiceForm get _form => _codeSent ? _codeForm : _emailForm;

  String get _screenId =>
      _codeSent ? '${Ids.resetPassword}.code' : Ids.resetPassword;

  @override
  void dispose() {
    _emailForm.dispose();
    _codeForm.dispose();
    super.dispose();
  }

  Future<void> _sendCode(CommandBus bus) async {
    if (_busy) return;
    final l = bus.strings;
    if (_email.isEmpty) {
      return reportInvalid(
        _form,
        _email,
        l.formMissing(l.fieldEmail),
        bus,
        ref,
      );
    }
    if (!AuthRules.isValidEmail(_email.value)) {
      return reportInvalid(_form, _email, l.emailInvalid, bus, ref);
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(accountServiceProvider)
          .forgotPassword(AuthRules.normalizeEmail(_email.value));
      if (!mounted) return;
      unawaited(ref.read(hapticsProvider).confirm());
      // The new screen state introduces itself (resetCodeSent + the code).
      setState(() => _codeSent = true);
    } on AccountApiException catch (e) {
      if (!mounted) return;
      unawaited(ref.read(hapticsProvider).error());
      await bus.say(serverErrorText(e, l));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset(CommandBus bus) async {
    if (_busy) return;
    final l = bus.strings;
    final missing = [
      for (final f in _codeForm.fields)
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
    if (!AuthRules.isValidCode(_code.value)) {
      return reportInvalid(_form, _code, l.codeFormat, bus, ref);
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
    setState(() => _busy = true);
    try {
      final email = AuthRules.normalizeEmail(_email.value);
      final account = await ref
          .read(accountServiceProvider)
          .resetPassword(
            email: email,
            code: _code.value,
            password: _password.value,
          );
      // A fresh password starts with a clean slate on this phone too.
      await ref.read(loginThrottleProvider).reset(ThrottleKind.login, email);
      if (!mounted) return;
      await ref.read(currentAccountProvider.notifier).login(account);
      unawaited(ref.read(hapticsProvider).confirm());
      await bus.say(l.resetDone, protect: true);
      if (mounted) ref.read(routerProvider).go(AppRoutes.landing(account));
    } on AccountApiException catch (e) {
      if (!mounted) return;
      switch (e.error) {
        case AccountApiError.invalidCode:
          _code.controller.clear();
          await reportInvalid(_form, _code, l.codeWrong, bus, ref);
        case AccountApiError.tooManyAttempts:
          _code.controller.clear();
          await reportInvalid(_form, _code, l.codeVoided, bus, ref);
        default:
          unawaited(ref.read(hapticsProvider).error());
          await bus.say(serverErrorText(e, l));
      }
    } on Object catch (e) {
      debugPrint('Password reset failed: $e');
      if (mounted) await bus.say(l.serverProblem);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend(CommandBus bus) async {
    if (_busy) return;
    final l = bus.strings;
    setState(() => _busy = true);
    try {
      await ref
          .read(accountServiceProvider)
          .forgotPassword(AuthRules.normalizeEmail(_email.value));
      if (!mounted) return;
      unawaited(ref.read(hapticsProvider).confirm());
      await bus.say('${l.codeResent} ${_form.focusStart(l)}');
    } on AccountApiException catch (e) {
      if (!mounted) return;
      unawaited(ref.read(hapticsProvider).error());
      await bus.say(serverErrorText(e, l));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  ScreenRegistration _registration(WidgetRef ref) {
    final form = _form;
    final submitId = Ids.resetSubmit;
    return ScreenRegistration(
      id: _screenId,
      title: (l) => l.screenForgotPassword,
      prompt: (l) => _codeSent
          ? '${l.resetCodeSent(_email.value)} ${form.focusStart(l)}'
          : '${l.resetIntro} ${form.focusStart(l)}',
      autoListen: true,
      listOptions: false,
      includeModeHint: false,
      help: (l) => _codeSent ? l.helpVerify : l.helpForm,
      onUtterance: form.onUtterance,
      hasUnsavedInput: () => _codeSent && _password.value.isNotEmpty,
      actions: [
        ...form.actions(submitId),
        if (_codeSent)
          A11yAction(
            id: Ids.resetResend,
            label: (l) => l.actionResendCode,
            voiceSynonyms: resendPhrases,
            onActivate: _resend,
          ),
      ],
      intentHandlers: {
        ...form.intents(),
        if (_codeSent)
          NavIntent.back: (bus) {
            _code.controller.clear();
            _password.controller.clear();
            setState(() => _codeSent = false);
          },
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final focusedId = ref.watch(focusControllerProvider);
    final bus = ref.read(commandBusProvider);

    return AccessibleScreen(
      registration: _registration,
      dependencies: [_codeSent],
      child: FormScaffold(
        screenId: _screenId,
        title: l10n.screenForgotPassword,
        subtitle: _codeSent
            ? l10n.resetCodeSent(_email.value)
            : l10n.resetIntro,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            VoiceFormView(
              form: _form,
              rows: [
                for (final f in _form.fields) [f],
              ],
              submitId: Ids.resetSubmit,
              submit: PillButton(
                label: l10n.actionSubmit,
                focused: focusedId == Ids.resetSubmit,
                onPressed: _busy ? null : () => bus.activate(Ids.resetSubmit),
              ),
            ),
            if (_codeSent) ...[
              const SizedBox(height: 12),
              SmallLink(
                label: l10n.actionResendCode,
                icon: Icons.refresh,
                focused: focusedId == Ids.resetResend,
                onPressed: () => bus.activate(Ids.resetResend),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
