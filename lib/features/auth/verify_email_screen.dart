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
import '../../core/auth/account_service.dart';
import '../../core/auth/biometrics.dart';
import '../../core/auth/session.dart';
import '../../core/auth/validators.dart';
import '../../core/widgets/pill_button.dart';
import '../../core/widgets/small_link.dart';
import '../../l10n/app_localizations.dart';
import 'form_scaffold.dart';
import 'voice_form.dart';

/// What [VerifyEmailScreen] needs from the screen before it.
@immutable
class VerifyEmailArgs {
  /// Creates the arguments.
  const VerifyEmailArgs({
    required this.email,
    required this.password,
    this.firstName,
    this.lastName,
    this.registering = false,
    this.moved = false,
    this.emailSent = true,
  });

  /// The account's email.
  final String email;

  /// The password just entered (kept in memory only, to save the offline
  /// copy once the account is confirmed).
  final String password;

  /// Names typed at registration (the web app keeps one full name).
  final String? firstName;

  /// Last name typed at registration.
  final String? lastName;

  /// Came from Register (then the setup follows); otherwise from Login.
  final bool registering;

  /// A phone-only account was just moved to the web app.
  final bool moved;

  /// Whether the code email went out.
  final bool emailSent;
}

/// "I-verify ang email": the 6-digit code the web app emailed, dictated
/// digit by digit or typed. Submit with a double-tap or "submit"; "ipadala
/// ulit" emails a new code. A right code logs the user in: a new account
/// goes on to the setup, a login to where the account left off.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const VerifyEmailScreen({super.key, required this.args});

  /// Who is verifying, and why.
  final VerifyEmailArgs args;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  late final VoiceField _code = VoiceField(
    id: 'verifyEmail.code',
    kind: FieldKind.code,
    label: (l) => l.fieldCode,
    prompt: (l) => l.askCode,
  );
  late final VoiceForm _form = VoiceForm(
    ref: ref,
    fields: [_code],
    onSubmit: _submit,
  );
  bool _busy = false;

  VerifyEmailArgs get _args => widget.args;

  @override
  void initState() {
    super.initState();
    focusFirstFieldWhenActive(ref, Ids.verifyEmail, () => _form);
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _submit(CommandBus bus) async {
    if (_busy) return;
    final l = bus.strings;
    if (_code.isEmpty) {
      return reportInvalid(_form, _code, l.formMissing(l.fieldCode), bus, ref);
    }
    if (!AuthRules.isValidCode(_code.value)) {
      return reportInvalid(_form, _code, l.codeFormat, bus, ref);
    }
    setState(() => _busy = true);
    try {
      final account = await ref
          .read(accountServiceProvider)
          .verifyEmail(
            email: _args.email,
            code: _code.value,
            password: _args.password,
            firstName: _args.firstName,
            lastName: _args.lastName,
          );
      if (!mounted) return;
      final router = ref.read(routerProvider);
      if (account == null) {
        unawaited(ref.read(hapticsProvider).confirm());
        await bus.say(l.accountPendingApproval, protect: true);
        if (mounted) router.go(AppRoutes.welcome);
        return;
      }
      final session = ref.read(currentAccountProvider.notifier);
      if (_args.registering) {
        await session.completeRegistration(account);
        unawaited(ref.read(hapticsProvider).confirm());
        await bus.say(l.registerDone(account.firstName), protect: true);
        // The emailed code replaces the security question for password
        // resets, so the setup follows directly.
        final fingerprint = await ref.read(biometricsProvider).available();
        if (mounted) {
          router.go(fingerprint ? AppRoutes.fingerprintOffer : AppRoutes.setup);
        }
      } else {
        await session.login(account);
        unawaited(ref.read(hapticsProvider).confirm());
        await bus.say(l.loginWelcomeBack(account.firstName), protect: true);
        if (mounted) router.go(AppRoutes.landing(account));
      }
    } on AccountApiException catch (e) {
      if (!mounted) return;
      _code.controller.clear();
      await _explain(e, bus, l);
    } on Object catch (e) {
      debugPrint('Verify email failed: $e');
      if (mounted) await bus.say(l.serverProblem);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _explain(
    AccountApiException e,
    CommandBus bus,
    AppLocalizations l,
  ) async {
    switch (e.error) {
      case AccountApiError.invalidCode:
      case AccountApiError.validationFailed:
        return reportInvalid(_form, _code, l.codeWrong, bus, ref);
      case AccountApiError.tooManyAttempts:
        return reportInvalid(_form, _code, l.codeVoided, bus, ref);
      default:
        unawaited(ref.read(hapticsProvider).error());
        await bus.say(serverErrorText(e, l));
    }
  }

  Future<void> _resend(CommandBus bus) async {
    if (_busy) return;
    final l = bus.strings;
    setState(() => _busy = true);
    try {
      await ref.read(accountServiceProvider).resendCode(_args.email);
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

  ScreenRegistration _registration(WidgetRef ref) => ScreenRegistration(
    id: Ids.verifyEmail,
    title: (l) => l.screenVerifyEmail,
    prompt: (l) => [
      if (_args.moved) l.accountMoving else l.verifyIntro(_args.email),
      if (!_args.emailSent) l.codeNotSent,
      _form.focusStart(l),
    ].join(' '),
    autoListen: true,
    listOptions: false,
    includeModeHint: false,
    help: (l) => l.helpVerify,
    onUtterance: _form.onUtterance,
    hasUnsavedInput: () => false,
    actions: [
      ..._form.actions(Ids.verifySubmit),
      A11yAction(
        id: Ids.verifyResend,
        label: (l) => l.actionResendCode,
        voiceSynonyms: resendPhrases,
        onActivate: _resend,
      ),
    ],
    intentHandlers: _form.intents(),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final focusedId = ref.watch(focusControllerProvider);
    final bus = ref.read(commandBusProvider);

    return AccessibleScreen(
      registration: _registration,
      child: FormScaffold(
        screenId: Ids.verifyEmail,
        title: l10n.screenVerifyEmail,
        subtitle: l10n.verifyIntro(_args.email),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            VoiceFormView(
              form: _form,
              rows: [
                [_code],
              ],
              submitId: Ids.verifySubmit,
              submit: PillButton(
                label: l10n.actionSubmit,
                focused: focusedId == Ids.verifySubmit,
                onPressed: _busy ? null : () => bus.activate(Ids.verifySubmit),
              ),
            ),
            const SizedBox(height: 12),
            SmallLink(
              label: l10n.actionResendCode,
              icon: Icons.refresh,
              focused: focusedId == Ids.verifyResend,
              onPressed: () => bus.activate(Ids.verifyResend),
            ),
          ],
        ),
      ),
    );
  }
}

/// Phrases that email a new code.
const List<String> resendPhrases = [
  'ipadala ulit',
  'ipadala muli',
  'bagong code',
  'send again',
  'resend',
  'new code',
];

/// What to say when the web app refused or couldn't be reached (the cases
/// a screen doesn't handle itself).
String serverErrorText(AccountApiException e, AppLocalizations l) =>
    switch (e.error) {
      AccountApiError.offline => l.serverUnreachable,
      AccountApiError.tooManyAttempts => l.lockoutStarted(
        e.retryAfter.inSeconds,
      ),
      AccountApiError.emailUnavailable => l.codeNotSent,
      AccountApiError.accountSuspended => l.accountSuspended,
      AccountApiError.pendingApproval => l.accountPendingApproval,
      AccountApiError.emailTaken => l.emailTakenServer,
      AccountApiError.invalidCode => l.codeWrong,
      _ => l.serverProblem,
    };
