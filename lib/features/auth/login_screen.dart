import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ids.dart';
import '../../app/router.dart';
import '../../config/constants.dart';
import '../../core/accessibility/accessible_screen.dart';
import '../../core/accessibility/action_registry.dart';
import '../../core/accessibility/announcer.dart';
import '../../core/accessibility/command_bus.dart';
import '../../core/accessibility/focus_controller.dart';
import '../../core/accessibility/haptics.dart';
import '../../core/accessibility/screen_registration.dart';
import '../../core/auth/account.dart';
import '../../core/auth/account_api.dart';
import '../../core/auth/account_repository.dart';
import '../../core/auth/account_service.dart';
import '../../core/auth/biometrics.dart';
import '../../core/auth/login_throttle.dart';
import '../../core/auth/session.dart';
import '../../core/auth/session_store.dart';
import '../../core/auth/validators.dart';
import '../../core/widgets/pill_button.dart';
import '../../core/widgets/small_link.dart';
import '../../l10n/app_localizations.dart';
import 'form_scaffold.dart';
import 'lockout_countdown.dart';
import 'verify_email_screen.dart';
import 'voice_form.dart';

/// Login: Email Address and Password, then Submit (double-tap the Gesture
/// Pad, or "submit" / "tapos na").
///
/// With web app accounts ([AccountService.usesServer]) the server checks
/// the password (offline: the copy kept on this phone); an unverified or
/// phone-only account goes to the emailed code first.
///
/// If fingerprint login is on for the account last used here, the
/// fingerprint is tried first; the password is the fallback. After 5 wrong
/// passwords the email is locked for 30 s, doubling each time, with a
/// spoken countdown. Also offers "Nakalimutan ang password" and, while old
/// PIN accounts exist, "Lumang account (PIN)".
class LoginScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final VoiceField _email = VoiceField(
    id: 'login.email',
    kind: FieldKind.email,
    label: (l) => l.fieldEmail,
    prompt: (l) => l.askEmail,
  );
  late final VoiceField _password = VoiceField(
    id: 'login.password',
    kind: FieldKind.password,
    label: (l) => l.fieldPassword,
    prompt: (l) => l.askPassword,
  );
  late final VoiceForm _form = VoiceForm(
    ref: ref,
    fields: [_email, _password],
    onSubmit: _submit,
  );
  late final LockoutCountdown _countdown = LockoutCountdown(
    onTick: () {
      if (mounted) setState(() {});
    },
    speak: (text) => ref.read(commandBusProvider).say(text),
    strings: () => ref.read(commandBusProvider).strings,
  );

  /// The account with fingerprint login on, if any.
  Account? _fingerprintAccount;
  bool _hasLegacy = false;
  bool _busy = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    ref.listenManual(activeScreenProvider, (previous, next) {
      if (next?.id == Ids.login && previous?.id != Ids.login) {
        scheduleMicrotask(() => _form.focusStart(_bus.strings));
        if (_fingerprintAccount != null) {
          unawaited(_tryFingerprint(afterIntro: true));
        }
      }
    });
  }

  CommandBus get _bus => ref.read(commandBusProvider);

  Future<void> _load() async {
    final repo = ref.read(accountRepositoryProvider);
    final id = await ref.read(sessionStoreProvider).readFingerprintUserId();
    final account = id == null ? null : await repo.get(id);
    final usable =
        account != null &&
        account.fingerprintEnabled &&
        await ref.read(biometricsProvider).available();
    final legacy = (await repo.legacyAccounts()).isNotEmpty;
    if (!mounted) return;
    setState(() {
      _fingerprintAccount = usable ? account : null;
      if (usable && _email.isEmpty) _email.controller.text = account.email!;
      _hasLegacy = legacy;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _countdown.dispose();
    _form.dispose();
    super.dispose();
  }

  Future<void> _tryFingerprint({bool afterIntro = false}) async {
    final account = _fingerprintAccount;
    if (account == null) return;
    // On entry, let the screen introduction finish before the dialog.
    if (afterIntro) await ref.read(announcerProvider.notifier).idle();
    if (!mounted) return;
    final l = _bus.strings;
    final result = await ref
        .read(biometricsProvider)
        .authenticate(l.fingerprintReason);
    if (!mounted) return;
    switch (result) {
      case BiometricResult.success:
        await _loggedIn(account);
      case BiometricResult.failed:
        unawaited(ref.read(hapticsProvider).error());
        await _bus.say(l.fingerprintFailed(_form.focusStart(l)));
      case BiometricResult.unavailable:
        await _bus.say(l.fingerprintUnavailable(_form.focusStart(l)));
    }
  }

  Future<void> _loggedIn(Account account) async {
    await ref.read(currentAccountProvider.notifier).login(account);
    unawaited(ref.read(hapticsProvider).confirm());
    await _bus.say(
      _bus.strings.loginWelcomeBack(account.firstName),
      protect: true,
    );
    if (mounted) ref.read(routerProvider).go(AppRoutes.landing(account));
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
    final throttle = ref.read(loginThrottleProvider);
    final email = _email.value;
    final wait = await throttle.remaining(ThrottleKind.login, email);
    if (wait > Duration.zero) {
      // Still locked: the password is asked again once the time is up.
      _password.controller.clear();
      _countdown.start(wait, announce: false);
      return reportInvalid(
        _form,
        _password,
        l.lockoutWait(_countdown.seconds),
        bus,
        ref,
      );
    }

    setState(() => _busy = true);
    try {
      final service = ref.read(accountServiceProvider);
      if (service.usesServer) {
        try {
          return await _serverLogin(
            service,
            AuthRules.normalizeEmail(email),
            bus,
          );
        } on Object catch (e) {
          debugPrint('Login failed: $e');
          if (mounted) await bus.say(l.serverProblem);
          return;
        }
      }
      final account = await ref
          .read(accountRepositoryProvider)
          .verifyPassword(email, _password.value);
      if (!mounted) return;
      if (account == null) return await _wrongPassword(email, bus);
      await throttle.reset(ThrottleKind.login, email);
      await _loggedIn(account);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Counts a wrong password here too (so offline guessing is slowed the
  /// same way) and says how many tries are left, or starts the lockout.
  Future<void> _wrongPassword(String email, CommandBus bus) async {
    final l = bus.strings;
    final throttle = ref.read(loginThrottleProvider);
    final delay = await throttle.recordFailure(ThrottleKind.login, email);
    final failures = await throttle.failures(ThrottleKind.login, email);
    if (!mounted) return;
    _password.controller.clear();
    unawaited(ref.read(hapticsProvider).error());
    if (delay > Duration.zero) {
      _countdown.start(delay, announce: false);
      return reportInvalid(
        _form,
        _password,
        l.lockoutStarted(_countdown.seconds),
        bus,
        ref,
      );
    }
    final left = LoginThrottle.freeAttempts - failures;
    return reportInvalid(
      _form,
      _password,
      '${l.loginWrong} ${l.loginAttemptsLeft(left)}',
      bus,
      ref,
    );
  }

  Future<void> _serverLogin(
    AccountService service,
    String email,
    CommandBus bus,
  ) async {
    final l = bus.strings;
    final password = _password.value;
    final outcome = await service.login(email, password);
    if (!mounted) return;
    switch (outcome) {
      case LoggedIn(:final account, :final offline):
        await ref.read(loginThrottleProvider).reset(ThrottleKind.login, email);
        if (offline) await bus.say(l.loginOffline);
        await _loggedIn(account);
      case NeedsEmailCode(:final moved, :final emailSent):
        _password.controller.clear();
        unawaited(
          ref
              .read(routerProvider)
              .push(
                AppRoutes.verifyEmail,
                extra: VerifyEmailArgs(
                  email: email,
                  password: password,
                  moved: moved,
                  emailSent: emailSent,
                ),
              ),
        );
      case LoginRefused(reason: AccountApiError.invalidCredentials):
        await _wrongPassword(email, bus);
      case LoginRefused(:final reason, :final retryAfter):
        unawaited(ref.read(hapticsProvider).error());
        switch (reason) {
          case AccountApiError.tooManyAttempts:
            _password.controller.clear();
            _countdown.start(retryAfter, announce: false);
            await reportInvalid(
              _form,
              _password,
              l.lockoutStarted(_countdown.seconds),
              bus,
              ref,
            );
          case AccountApiError.offline:
            await bus.say(l.loginNeedsInternet);
          default:
            await bus.say(serverErrorText(AccountApiException(reason), l));
        }
    }
  }

  ScreenRegistration _registration(WidgetRef ref) {
    final fingerprint = _fingerprintAccount;
    return ScreenRegistration(
      id: Ids.login,
      title: (l) => l.screenLogin,
      prompt: (l) => fingerprint != null
          ? l.loginFingerprintIntro
          : '${l.formSubmitHint} ${_form.focusStart(l)}',
      autoListen: true,
      listOptions: false,
      includeModeHint: false,
      help: (l) => l.helpLogin,
      onUtterance: _form.onUtterance,
      hasUnsavedInput: () => _password.value.isNotEmpty,
      actions: [
        ..._form.actions(Ids.loginSubmit),
        A11yAction(
          id: Ids.loginForgot,
          label: (l) => l.actionForgotPassword,
          voiceSynonyms: const [
            'nakalimutan',
            'nakalimutan ang password',
            'forgot password',
            'forgot',
          ],
          onActivate: (_) => unawaited(
            ref
                .read(routerProvider)
                .push(
                  ref.read(accountServiceProvider).usesServer
                      ? AppRoutes.resetPassword
                      : AppRoutes.forgotPassword,
                  extra: _email.value,
                ),
          ),
        ),
        if (fingerprint != null)
          A11yAction(
            id: Ids.loginFingerprint,
            label: (l) => l.actionUseFingerprint,
            voiceSynonyms: const ['fingerprint', 'daliri'],
            onActivate: (_) => _tryFingerprint(),
          ),
        if (_hasLegacy)
          A11yAction(
            id: Ids.loginLegacy,
            label: (l) => l.actionLegacyAccount,
            voiceSynonyms: const ['lumang account', 'pin', 'old account'],
            onActivate: (_) => unawaited(
              ref.read(routerProvider).push(AppRoutes.legacyAccount),
            ),
          ),
      ],
      intentHandlers: _form.intents(),
    );
  }

  static List<Widget> _linkRows(
    List<(String, String, IconData)> links,
    String? focusedId,
    CommandBus bus,
  ) {
    Widget link((String, String, IconData) l, {required bool half}) =>
        SmallLink(
          label: l.$2,
          icon: l.$3,
          lines: half ? 2 : 1,
          focused: focusedId == l.$1,
          onPressed: () => bus.activate(l.$1),
        );
    if (links.length == 1) return [link(links.single, half: false)];
    return [
      for (var i = 0; i < links.length; i += 2) ...[
        if (i > 0) const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: link(links[i], half: true)),
            const SizedBox(width: 8),
            Expanded(
              child: i + 1 < links.length
                  ? link(links[i + 1], half: true)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final focusedId = ref.watch(focusControllerProvider);
    final bus = ref.read(commandBusProvider);
    if (!_loaded) return const Scaffold();
    final seconds = _countdown.seconds;

    return AccessibleScreen(
      registration: _registration,
      dependencies: [_fingerprintAccount?.id, _hasLegacy],
      child: FormScaffold(
        screenId: Ids.login,
        title: l10n.screenLogin,
        subtitle: l10n.formSubmitHint,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            VoiceFormView(
              form: _form,
              rows: [
                [_email],
                [_password],
              ],
              submitId: Ids.loginSubmit,
              submit: PillButton(
                label: l10n.actionSubmit,
                focused: focusedId == Ids.loginSubmit,
                onPressed: _busy || seconds > 0
                    ? null
                    : () => bus.activate(Ids.loginSubmit),
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
            const SizedBox(height: AppDimens.buttonGap),
            // Two per row when there are several, so the form never grows
            // past the screen.
            ..._linkRows(
              [
                if (_fingerprintAccount != null)
                  (
                    Ids.loginFingerprint,
                    l10n.actionUseFingerprint,
                    Icons.fingerprint,
                  ),
                (
                  Ids.loginForgot,
                  l10n.actionForgotPassword,
                  Icons.help_outline,
                ),
                if (_hasLegacy)
                  (
                    Ids.loginLegacy,
                    l10n.actionLegacyAccount,
                    Icons.pin_outlined,
                  ),
              ],
              focusedId,
              bus,
            ),
          ],
        ),
      ),
    );
  }
}
