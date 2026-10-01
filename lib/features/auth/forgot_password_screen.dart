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
import '../../core/auth/account.dart';
import '../../core/auth/account_repository.dart';
import '../../core/auth/login_throttle.dart';
import '../../core/auth/validators.dart';
import '../../core/widgets/pill_button.dart';
import '../../l10n/app_localizations.dart';
import 'form_scaffold.dart';
import 'lockout_countdown.dart';
import 'voice_form.dart';

enum _Stage { email, answer, newPassword }

/// Forgot password: email → the security question set at registration →
/// a new password. Wrong answers lock like wrong passwords. Also tells the
/// user that the administrator can reset the account.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  /// Creates the screen, starting with [email] if the Login form had one.
  const ForgotPasswordScreen({super.key, this.email});

  /// Email typed on Login, if any.
  final String? email;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  _Stage _stage = _Stage.email;
  Account? _account;
  bool _busy = false;

  late final VoiceField _email = VoiceField(
    id: 'forgot.email',
    kind: FieldKind.email,
    label: (l) => l.fieldEmail,
    prompt: (l) => l.askEmail,
    initial: widget.email ?? '',
  );
  late final VoiceField _answer = VoiceField(
    id: 'forgot.answer',
    kind: FieldKind.text,
    label: (l) => l.fieldAnswer,
    prompt: (l) => l.askAnswer(_questionText(l)),
  );
  late final VoiceField _password = VoiceField(
    id: 'forgot.password',
    kind: FieldKind.password,
    label: (l) => l.fieldNewPassword,
    prompt: (l) => l.askNewPassword,
  );
  late final Map<_Stage, VoiceForm> _forms = {
    _Stage.email: VoiceForm(ref: ref, fields: [_email], onSubmit: _submit),
    _Stage.answer: VoiceForm(ref: ref, fields: [_answer], onSubmit: _submit),
    _Stage.newPassword: VoiceForm(
      ref: ref,
      fields: [_password],
      onSubmit: _submit,
    ),
  };
  late final LockoutCountdown _countdown = LockoutCountdown(
    onTick: () {
      if (mounted) setState(() {});
    },
    speak: (text) => ref.read(commandBusProvider).say(text),
    strings: () => ref.read(commandBusProvider).strings,
  );

  VoiceForm get _form => _forms[_stage]!;

  String _questionText(AppLocalizations l) =>
      SecurityQuestion.tryParse(_account?.securityQuestion)?.text(l) ?? '';

  String get _screenId => switch (_stage) {
    _Stage.email => Ids.forgotPassword,
    _Stage.answer => '${Ids.forgotPassword}.answer',
    _Stage.newPassword => '${Ids.forgotPassword}.newPassword',
  };

  @override
  void dispose() {
    _countdown.dispose();
    for (final f in _forms.values) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _submit(CommandBus bus) async {
    if (_busy) return;
    final l = bus.strings;
    final field = _form.fields.single;
    if (field.isEmpty) {
      return reportInvalid(
        _form,
        field,
        l.formMissing(field.label(l)),
        bus,
        ref,
      );
    }
    setState(() => _busy = true);
    try {
      switch (_stage) {
        case _Stage.email:
          await _checkEmail(bus, l);
        case _Stage.answer:
          await _checkAnswer(bus, l);
        case _Stage.newPassword:
          await _savePassword(bus, l);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkEmail(CommandBus bus, AppLocalizations l) async {
    if (!AuthRules.isValidEmail(_email.value)) {
      return reportInvalid(_form, _email, l.emailInvalid, bus, ref);
    }
    final account = await ref
        .read(accountRepositoryProvider)
        .findByEmail(_email.value);
    if (account == null || account.securityQuestion == null) {
      unawaited(ref.read(hapticsProvider).error());
      return bus.say('${l.forgotNoQuestion} ${l.forgotAdmin}');
    }
    if (!mounted) return;
    setState(() {
      _account = account;
      _stage = _Stage.answer;
    });
  }

  Future<void> _checkAnswer(CommandBus bus, AppLocalizations l) async {
    final account = _account!;
    final throttle = ref.read(loginThrottleProvider);
    final email = account.email!;
    final wait = await throttle.remaining(ThrottleKind.reset, email);
    if (wait > Duration.zero) {
      _countdown.start(wait, announce: false);
      unawaited(ref.read(hapticsProvider).error());
      return bus.say(l.lockoutWait(_countdown.seconds));
    }
    final ok = await ref
        .read(accountRepositoryProvider)
        .verifySecurityAnswer(account.id, _answer.value);
    if (!mounted) return;
    if (!ok) {
      _answer.controller.clear();
      final delay = await throttle.recordFailure(ThrottleKind.reset, email);
      if (delay > Duration.zero) {
        _countdown.start(delay, announce: false);
        return reportInvalid(
          _form,
          _answer,
          l.lockoutStarted(_countdown.seconds),
          bus,
          ref,
        );
      }
      return reportInvalid(
        _form,
        _answer,
        '${l.forgotWrongAnswer} ${l.forgotAdmin}',
        bus,
        ref,
      );
    }
    await throttle.reset(ThrottleKind.reset, email);
    setState(() => _stage = _Stage.newPassword);
  }

  Future<void> _savePassword(CommandBus bus, AppLocalizations l) async {
    if (!AuthRules.isValidPassword(_password.value)) {
      return reportInvalid(
        _form,
        _password,
        l.passwordTooShort(_password.value.length),
        bus,
        ref,
      );
    }
    final account = _account!;
    await ref
        .read(accountRepositoryProvider)
        .setPassword(account.id, _password.value);
    // A fresh password starts with a clean slate.
    await ref
        .read(loginThrottleProvider)
        .reset(ThrottleKind.login, account.email!);
    unawaited(ref.read(hapticsProvider).confirm());
    await bus.say(l.forgotDone, protect: true);
    if (mounted) ref.read(routerProvider).pop();
  }

  ScreenRegistration _registration(WidgetRef ref) {
    final form = _form;
    return ScreenRegistration(
      id: _screenId,
      title: (l) => l.screenForgotPassword,
      prompt: (l) => switch (_stage) {
        _Stage.email =>
          '${l.forgotIntro} ${l.forgotAdmin} ${form.focusStart(l)}',
        _ => form.focusStart(l),
      },
      autoListen: true,
      listOptions: false,
      includeModeHint: false,
      help: (l) => l.helpForm,
      onUtterance: form.onUtterance,
      hasUnsavedInput: () => _stage == _Stage.newPassword && form.hasInput,
      actions: form.actions(Ids.forgotSubmit),
      intentHandlers: {
        ...form.intents(),
        if (_stage != _Stage.email)
          NavIntent.back: (bus) {
            _answer.controller.clear();
            _password.controller.clear();
            setState(() => _stage = _Stage.email);
          },
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final focusedId = ref.watch(focusControllerProvider);
    final bus = ref.read(commandBusProvider);
    final field = _form.fields.single;
    final seconds = _countdown.seconds;

    return AccessibleScreen(
      registration: _registration,
      dependencies: [_stage],
      child: FormScaffold(
        screenId: _screenId,
        title: l10n.screenForgotPassword,
        subtitle: field.prompt(l10n),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_stage == _Stage.answer)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _questionText(l10n),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            VoiceFormView(
              form: _form,
              rows: [
                [field],
              ],
              submitId: Ids.forgotSubmit,
              submit: PillButton(
                label: l10n.actionSubmit,
                focused: focusedId == Ids.forgotSubmit,
                onPressed: _busy || seconds > 0
                    ? null
                    : () => bus.activate(Ids.forgotSubmit),
              ),
            ),
            if (seconds > 0) ...[
              const SizedBox(height: 10),
              Semantics(
                liveRegion: true,
                child: Text(
                  l10n.lockoutWait(seconds),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
